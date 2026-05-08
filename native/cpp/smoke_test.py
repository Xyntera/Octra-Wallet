#!/usr/bin/env python3
import base64
import ctypes
import json
import os
import sys


def main() -> int:
    lib_path = sys.argv[1] if len(sys.argv) > 1 else "native/cpp/target/local/liboctra_core.so"
    lib = ctypes.CDLL(os.path.abspath(lib_path))
    lib.octra_core_execute_privacy_operation.argtypes = [ctypes.c_char_p]
    lib.octra_core_execute_privacy_operation.restype = ctypes.c_void_p
    lib.octra_core_free_string.argtypes = [ctypes.c_void_p]

    def call(payload):
        raw = json.dumps(payload).encode()
        ptr = lib.octra_core_execute_privacy_operation(raw)
        try:
            text = ctypes.string_at(ptr).decode()
            data = json.loads(text)
        finally:
            lib.octra_core_free_string(ptr)
        if data.get("ok") is not True:
            raise RuntimeError(data)
        return data

    private_key = base64.b64encode(bytes(range(32))).decode()
    encrypted = call(
        {
            "op": "fhe_encrypt",
            "private_key_b64": private_key,
            "amount_raw": "777",
            "seed_b64": base64.b64encode(os.urandom(32)).decode(),
        }
    )
    decrypted = call(
        {
            "op": "fhe_decrypt",
            "private_key_b64": private_key,
            "cipher": encrypted["cipher"],
        }
    )
    if decrypted.get("amount_raw") != "777":
        raise RuntimeError(f"decrypt mismatch: {decrypted}")

    result = {
        "register": call({"op": "register_pubkey", "private_key_b64": private_key})["ok"],
        "encrypt": encrypted["ok"],
        "decrypt": decrypted["ok"],
        "view_keypair": call({"op": "derive_view_keypair", "private_key_b64": private_key})[
            "ok"
        ],
        "stealth_scan": call(
            {"op": "stealth_scan_outputs", "private_key_b64": private_key, "outputs": []}
        )["ok"],
    }
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
