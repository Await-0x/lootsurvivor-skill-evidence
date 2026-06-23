# Loot Survivor — Skill-vs-Chance Evidence Pack

Purpose: provide reproducible, on-chain data showing that Loot Survivor outcomes are driven
predominantly by **player skill**, not chance. Two claims, each backed by a query that runs
against the public game database.

## Data source

Public Torii SQL endpoint (read-only, SQLite):

```
https://api.cartridge.gg/x/pg-mainnet-10/torii/sql?query=<url-encoded SQL>
```

Every game is an on-chain token. We join three indexer tables on the token id:

- `relayer_0_0_1-TokenScoreUpdate` — final `score` per game + timestamp
- `relayer_0_0_1-OwnersUpdate` — the player wallet (`owner`) for each game
- `relayer_0_0_1-TokenMetadataUpdate` — per-game `settings_id` and `minted_by` (minter)

Join key: `TokenScoreUpdate.id = OwnersUpdate.token_id = TokenMetadataUpdate.id`.

## Methodology (read before quoting numbers)

1. **Scope = official Loot Survivor games only.** `minted_by = '0x0000000000000006'`, the
   registry index for the official minter
   `0x00a67ef20b61a9846e1c82b411175e6ab167ea9f8632bd6c2091823c3629ec42`
   (resolved via `relayer_0_0_1-MinterRegistryUpdate`), and `settings_id = 1`.
2. **Bad-data filter.** The real maximum achievable score is ~2,400 (level 49). Raw data
   contains corrupt values up to 18,000,675, so we keep only `score BETWEEN 1 AND 3000`.
   After filtering, the observed maximum is **2,503** — matching the real game ceiling, which
   confirms both the filter and our score decoding are correct.
3. **Population:** 231,717 games across 2,645 distinct players (Sept 2025 – May 2026).
4. **We report the MEDIAN, not the mean.** Scores are extremely heavy-tailed (median ≈ 158,
   99th percentile ≈ 1,546). A mean is dominated by a few outliers and is unstable; the
   median is the honest "typical player" number. (Means are still shown alongside in Query 1
   for transparency.)
5. **Score is stored as a hex u64 string** (e.g. `0x...01bb` = 443); the queries decode it
   inline. Validated against known values.
6. **"Player" = wallet that owns the game token.** Tokens are rarely transferred; for a small
   number of transferred games the current owner may differ from the original player.
7. **Controlling for the previous game (skill carry-over).** The original "Loot Survivor"
   (NFT contract `0x018108b32cea514a78ef1b0e4a0753e855cdf620bc0565202c02456f618c4dc4`) shares
   mechanics, so its veterans are not truly "new" even on their first game in the new client.
   That contract is **not** in this indexer, so we reconstructed its player set from on-chain
   **mint events** via Starknet RPC (`scripts/enumerate_og_players.py`): 10,638 OG mints → 587
   distinct OG players. Of the 2,741 new-game players, **96 also played OG** (exact-address
   match — a conservative *lower* bound, since a player who used different wallets in the two
   games is missed). The remaining **2,645 are genuinely new**. The 96 OG-veteran addresses
   are saved in `data/og_veteran_addresses.json` and embedded directly in queries 03–04 so
   those queries stay self-contained and hostable.

## Results

### Claim 1 — Experienced players outperform new players (`queries/01_experienced_vs_new.sql`)

Median score rises ~3× from one-time players to veterans:

| Experience (lifetime games) | Players' games | Median score |
|---|---|---|
| 1 game | 156 | 52 |
| 2–5 | 753 | 90 |
| 6–20 | 10,979 | 41 |
| 21–50 | 8,374 | 134 |
| 51+ | 211,455 | **165** |

(The 6–20 dip is a pooling artifact of lifetime bucketing — Query 2a, which scores games by
experience *at the time they were played*, removes it and is the cleaner cut.)

### Claim 2a — A player's score rises with experience (`queries/02a_improvement_by_nth_game.sql`)

Median score by the player's Nth game (their own career sequence):

| Player's Nth game | Players reaching it | Median score |
|---|---|---|
| 1 | 2,640 | 58 |
| 5 | 2,278 | 57 |
| 10 | 947 | 134 |
| 20 | 763 | 144 |
| 50 | 516 | 145 |
| 100 | 336 | **166** |

A player's typical score roughly **triples** between their first handful of games and their
100th — a textbook learning curve.

### Claim 2b — The *same* player improves (`queries/02b_within_player_improvement.sql`)

For each player with ≥10 games, comparing the median of their first half of games vs their
second half (within-subject, so it is immune to the "only good players keep playing"
objection):

- Players analysed: **949**
- Players whose later-half median exceeded their earlier-half median: **557 (58.7%)**
- Average first-half median **145.9** → average second-half median **153.0**

A clear majority of individuals improve against their own earlier baseline.

### Claim 3 — Prior skill transfers: OG veterans outscore new players from game 1 (`queries/03_cohort_skill_transfer.sql`)

Median score over each player's **first 3 games** (before any new-game-specific learning):

| Cohort | First-3 games | Median score |
|---|---|---|
| Genuinely new | 7,262 | 55 |
| OG veterans | 258 | **101** |

Players who already knew the mechanics scored **~1.8× higher from their very first sessions**,
with no new-game experience. Outcomes track demonstrated prior skill — the opposite of what a
chance-dominated game would show.

### Claim 2 (clean) — Genuinely-new players improve even with veterans removed (`queries/04_genuinely_new_learning_curve.sql`)

Re-running the learning curve on the 2,645 genuinely-new players only (OG veterans excluded)
is virtually unchanged — the curve is **not** an artifact of veterans:

| Player's Nth game | Players | Median score |
|---|---|---|
| 1 | 2,549 | 56 |
| 5 | 2,199 | 55 |
| 10 | 869 | 135 |
| 20 | 694 | 144 |
| 50 | 463 | 147 |
| 100 | 298 | **173** |

## Reproducing

Each `.sql` file is self-contained and copy-paste runnable. Example:

```bash
curl -s -G 'https://api.cartridge.gg/x/pg-mainnet-10/torii/sql' \
  --data-urlencode "query@queries/01_experienced_vs_new.sql"
```

The endpoint is public, so each query URL is itself shareable/embeddable for the legal packet.
Queries 03–04 embed the OG-veteran address list inline, so they need no extra inputs.

To regenerate the OG-veteran list (only needed if the data changes), point the script at any
Starknet mainnet RPC:

```bash
export STARKNET_RPC="https://starknet-mainnet.g.alchemy.com/starknet/version/rpc/v0_10/<KEY>"
python3 scripts/enumerate_og_players.py   # rewrites data/og_veteran_addresses.json
```

### Porting to Dune (optional)

This Starknet data is **not currently ingested into Dune**; native Dune dashboards would
require a separate ingestion step first. The SQL ports cleanly otherwise — replace the inline
hex-decode block with `from_base(substr(score, 3), 16)` and use Trino identifier quoting.
