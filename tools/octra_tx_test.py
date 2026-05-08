#!/usr/bin/env python3
import argparse
import base64
import hashlib
import json
import os
import sys
import time
from urllib import request

try:
    from nacl.signing import SigningKey
except ImportError as exc:
    raise SystemExit("missing PyNaCl: install python3-nacl or pip install pynacl") from exc


BASE58_ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"


def b58encode(data: bytes) -> str:
    n = int.from_bytes(data, "big")
    out = ""
    while n > 0:
        n, mod = divmod(n, 58)
        out = BASE58_ALPHABET[mod] + out
    zeros = len(data) - len(data.lstrip(b"\0"))
    return "1" * zeros + out


def octra_address(public_key: bytes) -> str:
    return "oct" + b58encode(hashlib.sha256(public_key).digest())


def rpc_call(base_url: str, method: str, params: list, timeout: int = 20):
    payload = json.dumps(
        {"jsonrpc": "2.0", "method": method, "params": params, "id": int(time.time() * 1000)}
    ).encode()
    req = request.Request(
        base_url.rstrip("/") + "/rpc",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with request.urlopen(req, timeout=timeout) as res:
        body = res.read().decode()
    decoded = json.loads(body)
    if decoded.get("error") is not None:
        raise RuntimeError(decoded["error"])
    return decoded.get("result")


def canonical_tx_json(tx: dict) -> str:
    fields = [
        f'"from":{json.dumps(tx["from"])}',
        f'"to_":{json.dumps(tx["to_"])}',
        f'"amount":{json.dumps(str(tx["amount"]))}',
        f'"nonce":{int(tx["nonce"])}',
        f'"ou":{json.dumps(str(tx["ou"]))}',
        f'"timestamp":{json.dumps(tx["timestamp"])}',
        f'"op_type":{json.dumps(str(tx.get("op_type", "standard")))}',
    ]
    encrypted_data = str(tx.get("encrypted_data", ""))
    if encrypted_data:
        fields.append(f'"encrypted_data":{json.dumps(encrypted_data)}')
    message = str(tx.get("message", ""))
    if message:
        fields.append(f'"message":{json.dumps(message)}')
    return "{" + ",".join(fields) + "}"


def load_private_key(args) -> bytes:
    if args.private_key_b64:
        return base64.b64decode(args.private_key_b64)
    env_key = os.environ.get("OCTRA_TEST_PRIVATE_KEY_B64")
    if env_key:
        return base64.b64decode(env_key)
    return bytes(range(32))


def main() -> int:
    parser = argparse.ArgumentParser(description="Octra wallet transaction dry-run/submit test")
    parser.add_argument("--base-url", default=os.environ.get("OCTRA_RPC_URL", "https://octra.network"))
    parser.add_argument("--private-key-b64")
    parser.add_argument("--to")
    parser.add_argument("--amount", type=float, default=0.000001)
    parser.add_argument("--submit", action="store_true")
    args = parser.parse_args()

    private_key = load_private_key(args)
    if len(private_key) != 32:
        raise SystemExit("private key must decode to 32 bytes")

    signing_key = SigningKey(private_key)
    public_key = bytes(signing_key.verify_key)
    address = octra_address(public_key)
    public_key_b64 = base64.b64encode(public_key).decode()

    print(json.dumps({"address": address, "public_key_b64": public_key_b64}, sort_keys=True))

    try:
        balance = rpc_call(args.base_url, "octra_balance", [address])
        print(json.dumps({"balance_result": balance}, sort_keys=True))
        nonce = int(balance.get("nonce", 0)) if isinstance(balance, dict) else 0
    except Exception as exc:
        print(json.dumps({"balance_error": str(exc)}, sort_keys=True))
        nonce = 0

    recipient = args.to or address
    tx = {
        "from": address,
        "to_": recipient,
        "amount": str(int(args.amount * 1_000_000)),
        "nonce": nonce + 1,
        "ou": "10000",
        "timestamp": int(time.time() * 1000) / 1000.0,
        "op_type": "standard",
    }
    canonical = canonical_tx_json(tx)
    signature = signing_key.sign(canonical.encode()).signature
    signed = dict(tx)
    signed["signature"] = base64.b64encode(signature).decode()
    signed["public_key"] = public_key_b64

    print(json.dumps({"canonical": canonical, "signed_tx": signed}, sort_keys=True))

    if args.submit:
        if private_key == bytes(range(32)):
            raise SystemExit("refusing to submit with deterministic dummy private key")
        result = rpc_call(args.base_url, "octra_submit", [signed], timeout=30)
        print(json.dumps({"submit_result": result}, sort_keys=True))
    else:
        print(json.dumps({"submit": "skipped; pass --submit to broadcast"}, sort_keys=True))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
