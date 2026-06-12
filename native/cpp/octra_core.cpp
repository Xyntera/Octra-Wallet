#include <algorithm>
#include <array>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <exception>
#include <limits>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

#include "json.hpp"
#include "stealth.hpp"

extern "C" {
#include "tweetnacl.h"
}

extern "C" {
#include "pvac_c_api.h"
}

using json = nlohmann::json;

namespace {

constexpr const char* kHfhePrefix = "hfhe_v1|";
constexpr const char* kRangePrefix = "rp_v1|";
constexpr const char* kZeroPrefix = "zkzp_v2|";

char* into_c_string(const std::string& value) {
    char* out = static_cast<char*>(std::malloc(value.size() + 1));
    if (!out) return nullptr;
    std::memcpy(out, value.c_str(), value.size() + 1);
    return out;
}

char* ok(json body = json::object()) {
    body["ok"] = true;
    return into_c_string(body.dump());
}

char* err(const std::string& message) {
    json body;
    body["ok"] = false;
    body["error"] = message;
    return into_c_string(body.dump());
}

std::string read_c_string(const char* ptr, const char* field_name) {
    if (!ptr) throw std::invalid_argument(std::string("missing ") + field_name);
    return std::string(ptr);
}

std::string required_string(const json& j, const char* key) {
    if (!j.contains(key) || !j.at(key).is_string()) {
        throw std::invalid_argument(std::string("missing string field: ") + key);
    }
    return j.at(key).get<std::string>();
}

uint64_t required_u64(const json& j, const char* key) {
    if (!j.contains(key)) {
        throw std::invalid_argument(std::string("missing u64 field: ") + key);
    }
    if (j.at(key).is_number_unsigned()) return j.at(key).get<uint64_t>();
    if (j.at(key).is_number_integer()) {
        auto value = j.at(key).get<int64_t>();
        if (value < 0) throw std::invalid_argument(std::string("negative u64 field: ") + key);
        return static_cast<uint64_t>(value);
    }
    if (j.at(key).is_string()) {
        const auto s = j.at(key).get<std::string>();
        size_t pos = 0;
        unsigned long long value = std::stoull(s, &pos, 10);
        if (pos != s.size()) throw std::invalid_argument(std::string("invalid u64 field: ") + key);
        return static_cast<uint64_t>(value);
    }
    throw std::invalid_argument(std::string("invalid u64 field: ") + key);
}

std::string u64_to_string(uint64_t value) {
    std::ostringstream out;
    out << value;
    return out.str();
}

std::string i64_to_string(int64_t value) {
    std::ostringstream out;
    out << value;
    return out.str();
}

std::string hex_encode(const uint8_t* data, size_t len) {
    static constexpr char table[] = "0123456789abcdef";
    std::string out;
    out.reserve(len * 2);
    for (size_t i = 0; i < len; ++i) {
        out.push_back(table[data[i] >> 4]);
        out.push_back(table[data[i] & 0x0f]);
    }
    return out;
}

std::string base64_encode(const uint8_t* data, size_t len) {
    static constexpr char table[] =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    std::string out;
    out.reserve(((len + 2) / 3) * 4);
    for (size_t i = 0; i < len; i += 3) {
        uint32_t n = static_cast<uint32_t>(data[i]) << 16;
        if (i + 1 < len) n |= static_cast<uint32_t>(data[i + 1]) << 8;
        if (i + 2 < len) n |= static_cast<uint32_t>(data[i + 2]);
        out.push_back(table[(n >> 18) & 63]);
        out.push_back(table[(n >> 12) & 63]);
        out.push_back((i + 1 < len) ? table[(n >> 6) & 63] : '=');
        out.push_back((i + 2 < len) ? table[n & 63] : '=');
    }
    return out;
}

std::vector<uint8_t> base64_decode(const std::string& input) {
    int decode[256];
    std::fill(std::begin(decode), std::end(decode), -1);
    const char* table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    for (int i = 0; table[i]; ++i) decode[static_cast<uint8_t>(table[i])] = i;
    decode[static_cast<uint8_t>('=')] = 0;

    std::string s;
    s.reserve(input.size());
    for (char ch : input) {
        if (ch == '\r' || ch == '\n' || ch == '\t' || ch == ' ') continue;
        s.push_back(ch);
    }
    if (s.size() % 4 != 0) throw std::invalid_argument("invalid base64 length");

    std::vector<uint8_t> out;
    out.reserve((s.size() * 3) / 4);
    for (size_t i = 0; i + 3 < s.size(); i += 4) {
        int a = decode[static_cast<uint8_t>(s[i])];
        int b = decode[static_cast<uint8_t>(s[i + 1])];
        int c = decode[static_cast<uint8_t>(s[i + 2])];
        int d = decode[static_cast<uint8_t>(s[i + 3])];
        if (a < 0 || b < 0 || c < 0 || d < 0) throw std::invalid_argument("invalid base64 data");
        uint32_t n = (static_cast<uint32_t>(a) << 18) |
                     (static_cast<uint32_t>(b) << 12) |
                     (static_cast<uint32_t>(c) << 6) |
                     static_cast<uint32_t>(d);
        out.push_back((n >> 16) & 0xff);
        if (s[i + 2] != '=') out.push_back((n >> 8) & 0xff);
        if (s[i + 3] != '=') out.push_back(n & 0xff);
    }
    return out;
}

std::array<uint8_t, 32> required_b64_32(const json& j, const char* key) {
    auto raw = base64_decode(required_string(j, key));
    if (raw.size() != 32) {
        throw std::invalid_argument(std::string(key) + " must decode to 32 bytes");
    }
    std::array<uint8_t, 32> out{};
    std::memcpy(out.data(), raw.data(), 32);
    return out;
}

std::vector<uint8_t> required_b64(const json& j, const char* key, size_t expected_len) {
    auto raw = base64_decode(required_string(j, key));
    if (raw.size() != expected_len) {
        throw std::invalid_argument(std::string(key) + " must decode to " + std::to_string(expected_len) + " bytes");
    }
    return raw;
}

std::array<uint8_t, 32> required_hex_32(const json& j, const char* key) {
    const auto value = required_string(j, key);
    if (value.size() != 64) {
        throw std::invalid_argument(std::string(key) + " must be 64 hex chars");
    }
    std::array<uint8_t, 32> out{};
    for (size_t i = 0; i < out.size(); ++i) {
        const auto part = value.substr(i * 2, 2);
        out[i] = static_cast<uint8_t>(std::stoul(part, nullptr, 16));
    }
    return out;
}

std::array<uint8_t, 64> ed25519_secret_from_seed_b64(const std::string& private_key_b64) {
    auto seed = base64_decode(private_key_b64);
    if (seed.size() < 32) throw std::invalid_argument("private_key_b64 must contain at least 32 bytes");
    std::array<uint8_t, 64> sk{};
    uint8_t pk[32] = {0};
    crypto_sign_seed_keypair(pk, sk.data(), seed.data());
    return sk;
}

std::vector<uint8_t> serialize_bytes(uint8_t* (*fn)(void*, size_t*), void* handle) {
    size_t len = 0;
    uint8_t* ptr = fn(handle, &len);
    if (!ptr && len != 0) throw std::runtime_error("PVAC serialization returned null");
    std::vector<uint8_t> out(ptr, ptr + len);
    pvac_free_bytes(ptr);
    return out;
}

struct PvacContextNative {
    pvac_params params = nullptr;
    pvac_pubkey pubkey = nullptr;
    pvac_seckey seckey = nullptr;

    explicit PvacContextNative(const std::string& private_key_b64) {
        auto seed = base64_decode(private_key_b64);
        if (seed.size() < 32) throw std::invalid_argument("private_key_b64 must contain at least 32 bytes");

        params = pvac_default_params();
        if (!params) throw std::runtime_error("pvac_default_params failed");
        pvac_keygen_from_seed(params, seed.data(), &pubkey, &seckey);
        if (!pubkey || !seckey) throw std::runtime_error("pvac_keygen_from_seed failed");
    }

    ~PvacContextNative() {
        if (pubkey) pvac_free_pubkey(pubkey);
        if (seckey) pvac_free_seckey(seckey);
        if (params) pvac_free_params(params);
    }

    PvacContextNative(const PvacContextNative&) = delete;
    PvacContextNative& operator=(const PvacContextNative&) = delete;
};

struct CipherHandle {
    pvac_cipher value = nullptr;
    explicit CipherHandle(pvac_cipher v) : value(v) {}
    ~CipherHandle() { if (value) pvac_free_cipher(value); }
    CipherHandle(const CipherHandle&) = delete;
    CipherHandle& operator=(const CipherHandle&) = delete;
};

struct ZeroProofHandle {
    pvac_zero_proof value = nullptr;
    explicit ZeroProofHandle(pvac_zero_proof v) : value(v) {}
    ~ZeroProofHandle() { if (value) pvac_free_zero_proof(value); }
    ZeroProofHandle(const ZeroProofHandle&) = delete;
    ZeroProofHandle& operator=(const ZeroProofHandle&) = delete;
};

struct RangeProofHandle {
    pvac_range_proof value = nullptr;
    explicit RangeProofHandle(pvac_range_proof v) : value(v) {}
    ~RangeProofHandle() { if (value) pvac_free_range_proof(value); }
    RangeProofHandle(const RangeProofHandle&) = delete;
    RangeProofHandle& operator=(const RangeProofHandle&) = delete;
};

struct AggRangeProofHandle {
    pvac_agg_range_proof value = nullptr;
    explicit AggRangeProofHandle(pvac_agg_range_proof v) : value(v) {}
    ~AggRangeProofHandle() { if (value) pvac_free_agg_range_proof(value); }
    AggRangeProofHandle(const AggRangeProofHandle&) = delete;
    AggRangeProofHandle& operator=(const AggRangeProofHandle&) = delete;
};

std::array<uint8_t, 32> commit_ct_checked(pvac_pubkey pk, pvac_cipher ct) {
    std::array<uint8_t, 32> out{};
    size_t out_len = 0;
    int rc = pvac_commit_ct_v2(pk, ct, out.data(), out.size(), &out_len);
    if (rc != 0 || out_len != out.size()) throw std::runtime_error("pvac_commit_ct_v2 failed");
    return out;
}

std::array<uint8_t, 32> pedersen_commit_checked(uint64_t amount, const uint8_t blinding[32]) {
    std::array<uint8_t, 32> out{};
    size_t out_len = 0;
    int rc = pvac_pedersen_commit_v2(amount, blinding, out.data(), out.size(), &out_len);
    if (rc != 0 || out_len != out.size()) throw std::runtime_error("pvac_pedersen_commit_v2 failed");
    return out;
}

std::string encode_cipher(pvac_cipher cipher) {
    auto bytes = serialize_bytes(pvac_serialize_cipher, cipher);
    return std::string(kHfhePrefix) + base64_encode(bytes.data(), bytes.size());
}

std::string encode_zero_proof(pvac_zero_proof proof) {
    auto bytes = serialize_bytes(pvac_serialize_zero_proof, proof);
    return std::string(kZeroPrefix) + base64_encode(bytes.data(), bytes.size());
}

std::string encode_range_proof(pvac_range_proof proof) {
    auto bytes = serialize_bytes(pvac_serialize_range_proof, proof);
    return std::string(kRangePrefix) + base64_encode(bytes.data(), bytes.size());
}

std::string encode_agg_range_proof(pvac_agg_range_proof proof) {
    auto bytes = serialize_bytes(pvac_serialize_agg_range_proof, proof);
    return std::string(kRangePrefix) + base64_encode(bytes.data(), bytes.size());
}

CipherHandle decode_cipher(const std::string& encoded) {
    if (encoded.rfind(kHfhePrefix, 0) != 0) {
        throw std::invalid_argument("cipher must start with hfhe_v1|");
    }
    auto raw = base64_decode(encoded.substr(std::strlen(kHfhePrefix)));
    auto cipher = pvac_deserialize_cipher(raw.data(), raw.size());
    if (!cipher) throw std::runtime_error("pvac_deserialize_cipher failed");
    return CipherHandle(cipher);
}

int64_t signed_balance_from_field(uint64_t lo, uint64_t hi) {
    if (hi == 0) {
        if (lo > static_cast<uint64_t>(std::numeric_limits<int64_t>::max())) {
            return std::numeric_limits<int64_t>::max();
        }
        return static_cast<int64_t>(lo);
    }
#if defined(__SIZEOF_INT128__)
    __uint128_t p = (__uint128_t(1) << 127) - 1;
    __uint128_t value = (__uint128_t(hi) << 64) | lo;
    if (value > p / 2) return -static_cast<int64_t>(p - value);
    if (value > static_cast<__uint128_t>(std::numeric_limits<int64_t>::max())) {
        return std::numeric_limits<int64_t>::max();
    }
    return static_cast<int64_t>(value);
#else
    return std::numeric_limits<int64_t>::max();
#endif
}

json register_pubkey(const json& payload) {
    PvacContextNative ctx(required_string(payload, "private_key_b64"));
    auto pubkey = serialize_bytes(pvac_serialize_pubkey, ctx.pubkey);
    uint8_t kat[16] = {0};
    pvac_aes_kat(kat);
    return {
        {"operation", "register_pubkey"},
        {"pubkey_b64", base64_encode(pubkey.data(), pubkey.size())},
        {"aes_kat_hex", hex_encode(kat, sizeof(kat))},
    };
}

json fhe_encrypt(const json& payload) {
    PvacContextNative ctx(required_string(payload, "private_key_b64"));
    auto seed = required_b64_32(payload, "seed_b64");
    const uint64_t amount = required_u64(payload, "amount_raw");
    CipherHandle cipher(pvac_enc_value_seeded(ctx.pubkey, ctx.seckey, amount, seed.data()));
    if (!cipher.value) throw std::runtime_error("pvac_enc_value_seeded failed");
    return {
        {"operation", "fhe_encrypt"},
        {"amount_raw", u64_to_string(amount)},
        {"cipher", encode_cipher(cipher.value)},
    };
}

json fhe_decrypt(const json& payload) {
    PvacContextNative ctx(required_string(payload, "private_key_b64"));
    auto cipher = decode_cipher(required_string(payload, "cipher"));
    uint64_t lo = 0;
    uint64_t hi = 0;
    pvac_dec_value_fp(ctx.pubkey, ctx.seckey, cipher.value, &lo, &hi);
    const int64_t signed_value = signed_balance_from_field(lo, hi);
    return {
        {"operation", "fhe_decrypt"},
        {"amount_raw", i64_to_string(signed_value)},
        {"field_lo", u64_to_string(lo)},
        {"field_hi", u64_to_string(hi)},
    };
}

json encrypt_balance(const json& payload) {
    PvacContextNative ctx(required_string(payload, "private_key_b64"));
    auto seed = required_b64_32(payload, "seed_b64");
    auto blinding = required_b64_32(payload, "blinding_b64");
    const uint64_t amount = required_u64(payload, "amount_raw");

    CipherHandle cipher(pvac_enc_value_seeded(ctx.pubkey, ctx.seckey, amount, seed.data()));
    if (!cipher.value) throw std::runtime_error("pvac_enc_value_seeded failed");

    auto commitment = pedersen_commit_checked(amount, blinding.data());

    ZeroProofHandle proof(
        pvac_make_zero_proof_bound(ctx.pubkey, ctx.seckey, cipher.value, amount, blinding.data())
    );
    if (!proof.value) throw std::runtime_error("pvac_make_zero_proof_bound failed");

    json encrypted_data = {
        {"cipher", encode_cipher(cipher.value)},
        {"amount_commitment", base64_encode(commitment.data(), commitment.size())},
        {"zero_proof", encode_zero_proof(proof.value)},
        {"blinding", base64_encode(blinding.data(), blinding.size())},
    };

    return {
        {"operation", "encrypt_balance"},
        {"amount_raw", u64_to_string(amount)},
        {"encrypted_data", encrypted_data},
    };
}

json decrypt_balance(const json& payload) {
    PvacContextNative ctx(required_string(payload, "private_key_b64"));
    auto seed = required_b64_32(payload, "seed_b64");
    auto blinding = required_b64_32(payload, "blinding_b64");
    const uint64_t amount = required_u64(payload, "amount_raw");
    const uint64_t current_balance = required_u64(payload, "current_balance_raw");
    if (amount > current_balance) throw std::invalid_argument("amount exceeds current encrypted balance");

    auto current_cipher = decode_cipher(required_string(payload, "current_cipher"));
    CipherHandle amount_cipher(pvac_enc_value_seeded(ctx.pubkey, ctx.seckey, amount, seed.data()));
    if (!amount_cipher.value) throw std::runtime_error("pvac_enc_value_seeded failed");

    auto commitment = pedersen_commit_checked(amount, blinding.data());

    ZeroProofHandle proof(
        pvac_make_zero_proof_bound(ctx.pubkey, ctx.seckey, amount_cipher.value, amount, blinding.data())
    );
    if (!proof.value) throw std::runtime_error("pvac_make_zero_proof_bound failed");

    CipherHandle new_balance_cipher(
        pvac_ct_sub(ctx.pubkey, current_cipher.value, amount_cipher.value)
    );
    if (!new_balance_cipher.value) throw std::runtime_error("pvac_ct_sub failed");

    // webcli submits the aggregated R1CS proof for the post-decrypt balance.
    const uint64_t new_balance = current_balance - amount;
    AggRangeProofHandle range_proof(
        pvac_make_aggregated_range_proof(ctx.pubkey, ctx.seckey, new_balance_cipher.value, new_balance)
    );
    if (!range_proof.value) throw std::runtime_error("pvac_make_aggregated_range_proof failed");

    json encrypted_data = {
        {"cipher", encode_cipher(amount_cipher.value)},
        {"amount_commitment", base64_encode(commitment.data(), commitment.size())},
        {"zero_proof", encode_zero_proof(proof.value)},
        {"blinding", base64_encode(blinding.data(), blinding.size())},
        {"range_proof_balance", encode_agg_range_proof(range_proof.value)},
    };

    return {
        {"operation", "decrypt_balance"},
        {"amount_raw", u64_to_string(amount)},
        {"new_balance_raw", u64_to_string(new_balance)},
        {"encrypted_data", encrypted_data},
    };
}

json derive_view_keypair(const json& payload) {
    auto ed_sk = ed25519_secret_from_seed_b64(required_string(payload, "private_key_b64"));
    uint8_t view_sk[32] = {0};
    uint8_t view_pk[32] = {0};
    octra::derive_view_keypair(ed_sk.data(), view_sk, view_pk);
    return {
        {"operation", "derive_view_keypair"},
        {"view_private_key_b64", base64_encode(view_sk, sizeof(view_sk))},
        {"view_public_key_b64", base64_encode(view_pk, sizeof(view_pk))},
    };
}

json stealth_prepare_send(const json& payload) {
    PvacContextNative ctx(required_string(payload, "private_key_b64"));
    const auto recipient_public_key = required_b64(payload, "recipient_public_key_b64", 32);
    const auto recipient_address = required_string(payload, "recipient_address");
    const uint64_t amount = required_u64(payload, "amount_raw");
    const uint64_t current_balance = required_u64(payload, "current_balance_raw");
    if (amount > current_balance) throw std::invalid_argument("amount exceeds current encrypted balance");

    auto current_cipher = decode_cipher(required_string(payload, "current_cipher"));
    auto seed = required_b64_32(payload, "seed_b64");
    auto blinding = required_b64_32(payload, "blinding_b64");
    auto eph_sk = required_b64_32(payload, "ephemeral_private_key_b64");

    uint8_t recipient_view_pub[32] = {0};
    if (!octra::ed25519_pub_to_x25519(recipient_public_key.data(), recipient_view_pub)) {
        throw std::runtime_error("ed25519 to x25519 conversion failed");
    }

    uint8_t eph_pub[32] = {0};
    crypto_scalarmult_base(eph_pub, eph_sk.data());
    auto shared = octra::ecdh_shared_secret(eph_sk.data(), recipient_view_pub);
    auto stealth_tag = octra::compute_stealth_tag(shared);
    auto claim_secret = octra::compute_claim_secret(shared);
    auto claim_pub = octra::compute_claim_pub(claim_secret, recipient_address);
    auto enc_amount = octra::encrypt_stealth_amount(shared, amount, blinding.data());

    CipherHandle delta_cipher(pvac_enc_value_seeded(ctx.pubkey, ctx.seckey, amount, seed.data()));
    if (!delta_cipher.value) throw std::runtime_error("pvac_enc_value_seeded failed");

    auto commitment = commit_ct_checked(ctx.pubkey, delta_cipher.value);

    CipherHandle new_balance_cipher(
        pvac_ct_sub(ctx.pubkey, current_cipher.value, delta_cipher.value)
    );
    if (!new_balance_cipher.value) throw std::runtime_error("pvac_ct_sub failed");

    const uint64_t new_balance = current_balance - amount;
    RangeProofHandle range_delta(
        pvac_make_range_proof(ctx.pubkey, ctx.seckey, delta_cipher.value, amount)
    );
    if (!range_delta.value) throw std::runtime_error("pvac_make_range_proof delta failed");
    RangeProofHandle range_balance(
        pvac_make_range_proof(ctx.pubkey, ctx.seckey, new_balance_cipher.value, new_balance)
    );
    if (!range_balance.value) throw std::runtime_error("pvac_make_range_proof balance failed");

    auto amount_commitment = pedersen_commit_checked(amount, blinding.data());
    ZeroProofHandle send_proof(
        pvac_make_zero_proof_bound(ctx.pubkey, ctx.seckey, delta_cipher.value, amount, blinding.data())
    );
    if (!send_proof.value) throw std::runtime_error("pvac_make_zero_proof_bound failed");

    json encrypted_data = {
        {"version", 5},
        {"delta_cipher", encode_cipher(delta_cipher.value)},
        {"commitment", base64_encode(commitment.data(), commitment.size())},
        {"range_proof_delta", encode_range_proof(range_delta.value)},
        {"range_proof_balance", encode_range_proof(range_balance.value)},
        {"eph_pub", base64_encode(eph_pub, sizeof(eph_pub))},
        {"stealth_tag", hex_encode(stealth_tag.data(), stealth_tag.size())},
        {"enc_amount", enc_amount},
        {"claim_pub", hex_encode(claim_pub.data(), claim_pub.size())},
        {"amount_commitment", base64_encode(amount_commitment.data(), amount_commitment.size())},
        {"send_zero_proof", encode_zero_proof(send_proof.value)},
    };

    return {
        {"operation", "stealth_prepare_send"},
        {"amount_raw", u64_to_string(amount)},
        {"new_balance_raw", u64_to_string(new_balance)},
        {"encrypted_data", encrypted_data},
    };
}

json stealth_scan_outputs(const json& payload) {
    auto ed_sk = ed25519_secret_from_seed_b64(required_string(payload, "private_key_b64"));
    uint8_t view_sk[32] = {0};
    uint8_t view_pk[32] = {0};
    octra::derive_view_keypair(ed_sk.data(), view_sk, view_pk);

    json claims = json::array();
    const auto& outputs = payload.contains("outputs") && payload.at("outputs").is_array()
        ? payload.at("outputs")
        : json::array();
    for (const auto& output : outputs) {
        try {
            if (output.value("claimed", 0) != 0) continue;
            const auto eph_pub = base64_decode(output.at("eph_pub").get<std::string>());
            if (eph_pub.size() != 32) continue;
            auto shared = octra::ecdh_shared_secret(view_sk, eph_pub.data());
            auto tag = octra::compute_stealth_tag(shared);
            if (hex_encode(tag.data(), tag.size()) != output.value("stealth_tag", "")) continue;
            auto dec = octra::decrypt_stealth_amount(shared, output.value("enc_amount", ""));
            if (!dec.has_value()) continue;
            auto claim_secret = octra::compute_claim_secret(shared);
            claims.push_back({
                {"id", output.value("id", json())},
                {"amount_raw", u64_to_string(dec->amount)},
                {"epoch", output.value("epoch_id", json())},
                {"sender", output.value("sender_addr", "")},
                {"tx_hash", output.value("tx_hash", "")},
                {"claim_secret", hex_encode(claim_secret.data(), claim_secret.size())},
                {"blinding_b64", base64_encode(dec->blinding.data(), dec->blinding.size())},
                {"claimed", false},
            });
        } catch (...) {
            continue;
        }
    }
    return {
        {"operation", "stealth_scan_outputs"},
        {"claims", claims},
        {"view_public_key_b64", base64_encode(view_pk, sizeof(view_pk))},
    };
}

json stealth_prepare_claim(const json& payload) {
    PvacContextNative ctx(required_string(payload, "private_key_b64"));
    const uint64_t amount = required_u64(payload, "amount_raw");
    auto seed = required_b64_32(payload, "seed_b64");
    auto blinding = required_b64_32(payload, "blinding_b64");
    auto claim_secret = required_hex_32(payload, "claim_secret");

    CipherHandle claim_cipher(pvac_enc_value_seeded(ctx.pubkey, ctx.seckey, amount, seed.data()));
    if (!claim_cipher.value) throw std::runtime_error("pvac_enc_value_seeded failed");

    auto commitment = commit_ct_checked(ctx.pubkey, claim_cipher.value);
    ZeroProofHandle proof(
        pvac_make_zero_proof_bound(ctx.pubkey, ctx.seckey, claim_cipher.value, amount, blinding.data())
    );
    if (!proof.value) throw std::runtime_error("pvac_make_zero_proof_bound failed");

    json encrypted_data = {
        {"version", 5},
        {"output_id", payload.value("output_id", json())},
        {"claim_cipher", encode_cipher(claim_cipher.value)},
        {"commitment", base64_encode(commitment.data(), commitment.size())},
        {"claim_secret", hex_encode(claim_secret.data(), claim_secret.size())},
        {"zero_proof", encode_zero_proof(proof.value)},
    };

    return {
        {"operation", "stealth_prepare_claim"},
        {"amount_raw", u64_to_string(amount)},
        {"encrypted_data", encrypted_data},
    };
}

json run_privacy_operation(const json& payload) {
    const auto op = required_string(payload, "op");
    if (op == "register_pubkey") return register_pubkey(payload);
    if (op == "fhe_encrypt") return fhe_encrypt(payload);
    if (op == "fhe_decrypt") return fhe_decrypt(payload);
    if (op == "encrypt_balance") return encrypt_balance(payload);
    if (op == "decrypt_balance") return decrypt_balance(payload);
    if (op == "derive_view_keypair") return derive_view_keypair(payload);
    if (op == "stealth_prepare_send") return stealth_prepare_send(payload);
    if (op == "stealth_scan_outputs") return stealth_scan_outputs(payload);
    if (op == "stealth_prepare_claim") return stealth_prepare_claim(payload);
    throw std::invalid_argument("unsupported privacy op: " + op);
}

}  // namespace

extern "C" {

char* octra_core_version() {
    return ok({
        {"version", "0.3.0"},
        {"bridge", "cpp-ffi"},
        {"pvac", "webcli-native-c-api"},
        {"webcli", "0.05.01-alpha"},
    });
}

char* octra_core_health() {
    uint8_t kat[16] = {0};
    pvac_aes_kat(kat);
    return ok({
        {"mode", "native-pvac"},
        {"server", false},
        {"pvac_available", true},
        {"aes_kat_hex", hex_encode(kat, sizeof(kat))},
    });
}

char* octra_core_public_snapshot(const char* address) {
    try {
        return ok({
            {"address", read_c_string(address, "address")},
            {"public_balance", 0},
            {"nonce", 0},
            {"source", "cpp-pvac-core-placeholder-rpc"},
        });
    } catch (const std::exception& e) {
        return err(e.what());
    }
}

char* octra_core_history_snapshot(const char* address, int limit, int offset) {
    try {
        return ok({
            {"address", read_c_string(address, "address")},
            {"limit", limit},
            {"offset", offset},
            {"transactions", json::array()},
            {"source", "cpp-pvac-core-placeholder-rpc"},
        });
    } catch (const std::exception& e) {
        return err(e.what());
    }
}

char* octra_core_tx_details(const char* hash) {
    try {
        return ok({
            {"hash", read_c_string(hash, "hash")},
            {"source", "cpp-pvac-core-placeholder-rpc"},
        });
    } catch (const std::exception& e) {
        return err(e.what());
    }
}

char* octra_core_execute_privacy_operation(const char* payload) {
    try {
        const auto text = read_c_string(payload, "privacy payload");
        const auto parsed = json::parse(text);
        auto result = run_privacy_operation(parsed);
        result["implemented"] = true;
        return ok(result);
    } catch (const std::exception& e) {
        return err(e.what());
    }
}

char* octra_core_recommend_fee(const char* payload) {
    try {
        const auto text = read_c_string(payload, "fee payload");
        return ok({
            {"payload", text},
            {"fee_raw", "10000"},
            {"source", "cpp-pvac-core-static-fee"},
        });
    } catch (const std::exception& e) {
        return err(e.what());
    }
}

char* octra_core_scan_stealth_inbox(const char* address) {
    try {
        return ok({
            {"address", read_c_string(address, "address")},
            {"claims", json::array()},
            {"source", "cpp-pvac-core-placeholder-stealth"},
        });
    } catch (const std::exception& e) {
        return err(e.what());
    }
}

char* octra_core_import_token(const char* contract_address) {
    try {
        return ok({
            {"contract_address", read_c_string(contract_address, "contract address")},
            {"source", "cpp-pvac-core-placeholder-token"},
        });
    } catch (const std::exception& e) {
        return err(e.what());
    }
}

void octra_core_free_string(char* ptr) {
    std::free(ptr);
}

}
