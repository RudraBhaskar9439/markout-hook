#!/usr/bin/env python3
"""Fetch and freeze the configured Uniswap v3 Swap event window."""

from __future__ import annotations

import argparse
import csv
import json
import os
import time
import urllib.request
from pathlib import Path
from typing import Any

from markout_experiment.historical import load_historical_config

SWAP_TOPIC = "0xc42079f94a6350d7e6235f29174924f928cc2ac818eb64fed8004e115fbcca67"
FIELDS = [
    "block_number", "block_hash", "transaction_hash", "transaction_index", "log_index", "timestamp",
    "amount0_raw", "amount1_raw", "sqrt_price_x96", "liquidity", "tick",
]


class RpcClient:
    def __init__(self, url: str) -> None:
        self.url = url
        self.next_id = 1

    def call(self, method: str, params: list[Any]) -> Any:
        request_id = self.next_id
        self.next_id += 1
        payload = {"jsonrpc": "2.0", "id": request_id, "method": method, "params": params}
        response = self._post(payload)
        if "error" in response:
            raise RuntimeError(f"RPC {method} failed: {response['error']}")
        return response["result"]

    def batch(self, calls: list[tuple[str, list[Any]]]) -> list[Any]:
        payload = []
        ordered_ids = []
        for method, params in calls:
            request_id = self.next_id
            self.next_id += 1
            ordered_ids.append(request_id)
            payload.append({"jsonrpc": "2.0", "id": request_id, "method": method, "params": params})
        responses = self._post(payload)
        by_id = {response["id"]: response for response in responses}
        results = []
        for request_id in ordered_ids:
            response = by_id[request_id]
            if "error" in response:
                raise RuntimeError(f"RPC batch call failed: {response['error']}")
            results.append(response["result"])
        return results

    def _post(self, payload: Any) -> Any:
        body = json.dumps(payload).encode()
        request = urllib.request.Request(
            self.url,
            data=body,
            headers={"Content-Type": "application/json", "User-Agent": "MARKOUT-historical-replay/1.0"},
        )
        last_error: Exception | None = None
        for attempt in range(4):
            try:
                with urllib.request.urlopen(request, timeout=30) as response:
                    return json.loads(response.read())
            except Exception as error:  # pragma: no cover - network-dependent retry path
                last_error = error
                time.sleep(0.5 * (2**attempt))
        raise RuntimeError(f"RPC request failed after retries: {last_error}")


def signed_word(word: str, bits: int = 256) -> int:
    value = int(word, 16)
    return value - (1 << bits) if value >= (1 << (bits - 1)) else value


def decode_swap(log: dict[str, Any], timestamp: int) -> dict[str, Any]:
    data = log["data"][2:]
    words = [data[index:index + 64] for index in range(0, len(data), 64)]
    if len(words) != 5:
        raise ValueError(f"unexpected Swap data word count: {len(words)}")
    return {
        "block_number": int(log["blockNumber"], 16),
        "block_hash": log["blockHash"].lower(),
        "transaction_hash": log["transactionHash"].lower(),
        "transaction_index": int(log["transactionIndex"], 16),
        "log_index": int(log["logIndex"], 16),
        "timestamp": timestamp,
        "amount0_raw": signed_word(words[0]),
        "amount1_raw": signed_word(words[1]),
        "sqrt_price_x96": int(words[2], 16),
        "liquidity": int(words[3], 16),
        "tick": signed_word(words[4], 24),
    }


def fetch(config: dict[str, Any], client: RpcClient) -> list[dict[str, Any]]:
    capture = config["capture"]
    pool = config["chain"]["poolAddress"]
    logs: list[dict[str, Any]] = []
    for start in range(capture["fetchStartBlock"], capture["fetchEndBlock"] + 1, capture["blockChunkSize"]):
        end = min(start + capture["blockChunkSize"] - 1, capture["fetchEndBlock"])
        logs.extend(client.call("eth_getLogs", [{
            "address": pool,
            "topics": [SWAP_TOPIC],
            "fromBlock": hex(start),
            "toBlock": hex(end),
        }]))
    block_numbers = sorted({int(log["blockNumber"], 16) for log in logs})
    timestamps: dict[int, int] = {}
    # Public archive providers differ on JSON-RPC batch support. Individual header reads are slower but portable,
    # and this command is an optional provenance refresh rather than part of the offline verification gate.
    for number in block_numbers:
        block = client.call("eth_getBlockByNumber", [hex(number), False])
        timestamps[number] = int(block["timestamp"], 16)
    decoded = [decode_swap(log, timestamps[int(log["blockNumber"], 16)]) for log in logs]
    return sorted(decoded, key=lambda row: (row["block_number"], row["transaction_index"], row["log_index"]))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--rpc-url", default=os.environ.get("ETHEREUM_RPC_URL", "https://eth.drpc.org"))
    args = parser.parse_args()
    config = load_historical_config(args.config)
    rows = fetch(config, RpcClient(args.rpc_url))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    print(f"Frozen {len(rows)} canonical Swap logs in {args.output}")


if __name__ == "__main__":
    main()
