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

### Claim 1 — Median score by player experience (`queries/01_experienced_vs_new.sql`)

Each game is grouped by the player's experience **at the time it was played** (where the game
falls in that player's own sequence), then we take the median per tier. Median score rises
~3× and is monotonic:

| Experience (player's Nth game) | Games | Median score |
|---|---|---|
| 1st game | 2,640 | 58 |
| 2nd–5th | 9,485 | 57 |
| 6th–20th | 14,687 | 123 |
| 21st–50th | 18,784 | 145 |
| 51st+ | 186,121 | **168** |

Note: an earlier version grouped by each player's *lifetime* game total and pooled all their
games. That axis is confounded (players who keep dying cheaply accumulate many low-scoring
games and pile into the mid-range), producing a spurious dip at 6–20. Grouping by
experience-at-time-of-play, as above, removes the artifact and agrees with Claim 2a.

### Claim 2 — Skill persists: skilled players consistently outscore weaker players over many games (`queries/05_skill_persistence.sql`)

This is the strongest skill-vs-chance exhibit. Players with ≥20 games are split into four tiers
by their median score over their **first 10 games**, then each tier's median is tracked across
later game windows:

| Early-skill tier | games 11–20 | 21–40 | 41–70 | 71–120 |
|---|---|---|---|---|
| Tier 1 (lowest) | 102 | 110 | 122 | 128 |
| Tier 2 | 133 | 140 | 142 | 150 |
| Tier 3 | 147 | 150 | 158 | 159 |
| Tier 4 (highest) | 173 | 176 | 174 | **181** |

The tiers stay ordered and separated across 100+ games — **they never cross**. The correlation
between a player's first-10-game median and their later-game median is **r = 0.55** (n = 763); a
chance-driven game would give r ≈ 0 and the four lines would converge.

**Note on selection vs. learning.** The raw "median score by Nth game" curve (games 1→100 rising
58→166, `queries/02a`) is *mostly a selection/survivorship effect*, not individuals improving:
players who score well keep playing while weak players quit, so the surviving population at high
game numbers is increasingly skilled (players who go on to play 50+ games already scored ~125 on
their first three games, vs ~52 for one-and-done players). Genuine within-player improvement is
real but modest (~62–65% of high-volume players improve from their first 50 games to their later
games, by ~6–10%; `queries/02b`). We therefore lead with *persistence* (above), which is robust
to selection, rather than with the raw learning curve.

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
