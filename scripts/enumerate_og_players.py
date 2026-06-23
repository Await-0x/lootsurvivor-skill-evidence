#!/usr/bin/env python3
"""Reconstruct the original Loot Survivor (OG) player set from on-chain mint events,
and intersect it with the new game's player set to identify OG veterans.

The OG NFT contract (0x018108b3...618c4dc4) is NOT indexed by the Torii endpoint, so we
read its Transfer(from=0x0, to=player) mint events directly from a Starknet RPC.

Usage:
    export STARKNET_RPC="https://starknet-mainnet.g.alchemy.com/starknet/version/rpc/v0_10/<KEY>"
    python3 scripts/enumerate_og_players.py

Writes data/og_veteran_addresses.json (new-game wallets that also played OG).
"""
import json, os, sys, urllib.request, urllib.parse

RPC   = os.environ.get("STARKNET_RPC")
TORII = "https://api.cartridge.gg/x/pg-mainnet-10/torii/sql"
OG    = "0x018108b32cea514a78ef1b0e4a0753e855cdf620bc0565202c02456f618c4dc4"
TRANSFER = "0x99cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9"
# OG activity is bounded to this block window (verified empirically).
FROM_BLOCK, TO_BLOCK = 700_000, 1_700_000

if not RPC:
    sys.exit("Set STARKNET_RPC to a Starknet mainnet RPC URL (e.g. Alchemy).")

def rpc(method, params):
    req = urllib.request.Request(RPC, data=json.dumps(
        {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
        headers={"Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(req, timeout=60))

def norm(addr):  # normalize Starknet address to an int for matching
    return int(addr, 16)

# 1) Enumerate every OG mint (Transfer with from=0x0); keys=[sel, from, to, id_lo, id_hi]
og, ct, mints = set(), None, 0
while True:
    flt = {"from_block": {"block_number": FROM_BLOCK}, "to_block": {"block_number": TO_BLOCK},
           "address": OG, "keys": [[TRANSFER], ["0x0"]], "chunk_size": 1000}
    if ct:
        flt["continuation_token"] = ct
    res = rpc("starknet_getEvents", [flt])["result"]
    for e in res["events"]:
        og.add(norm(e["keys"][2]))  # keys[2] = to = player wallet
        mints += 1
    ct = res.get("continuation_token")
    if not ct:
        break
print(f"OG mints={mints}  distinct OG players={len(og)}")

# 2) New-game players (official LS minter + settings_id=1)
q = ('SELECT DISTINCT o.owner FROM "relayer_0_0_1-TokenMetadataUpdate" m '
     'JOIN "relayer_0_0_1-OwnersUpdate" o ON o.token_id=m.id '
     "WHERE m.settings_id=1 AND m.minted_by='0x0000000000000006'")
rows = json.load(urllib.request.urlopen(TORII + "?" + urllib.parse.urlencode({"query": q}), timeout=60))
new = {norm(r["owner"]): r["owner"] for r in rows}
print(f"new-game players={len(new)}")

# 3) Intersection = OG veterans among new-game players
veterans = [orig for i, orig in new.items() if i in og]
print(f"OG veterans among new players={len(veterans)}  genuinely new={len(new)-len(veterans)}")

out = os.path.join(os.path.dirname(__file__), "..", "data", "og_veteran_addresses.json")
with open(out, "w") as f:
    json.dump(sorted(veterans), f, indent=0)
print(f"wrote {os.path.normpath(out)}")
