-- Loot Survivor — Claim 1: Median score by player experience
-- Source: https://api.cartridge.gg/x/pg-mainnet-10/torii/sql  (SQLite)
-- Each game is grouped by the player's experience AT THE TIME it was played
-- (i.e. where the game falls in that player's own chronological sequence), then we
-- take the median score per experience tier. This measures experience-at-time-of-play
-- and is monotonic; it avoids the confound of bucketing by a player's lifetime game
-- total (which mixes in selection effects and produces a spurious mid-range dip).
WITH g AS (
  SELECT ( (instr('0123456789abcdef',substr(s.score,7,1))-1)*17592186044416
         + (instr('0123456789abcdef',substr(s.score,8,1))-1)*1099511627776
         + (instr('0123456789abcdef',substr(s.score,9,1))-1)*68719476736
         + (instr('0123456789abcdef',substr(s.score,10,1))-1)*4294967296
         + (instr('0123456789abcdef',substr(s.score,11,1))-1)*268435456
         + (instr('0123456789abcdef',substr(s.score,12,1))-1)*16777216
         + (instr('0123456789abcdef',substr(s.score,13,1))-1)*1048576
         + (instr('0123456789abcdef',substr(s.score,14,1))-1)*65536
         + (instr('0123456789abcdef',substr(s.score,15,1))-1)*4096
         + (instr('0123456789abcdef',substr(s.score,16,1))-1)*256
         + (instr('0123456789abcdef',substr(s.score,17,1))-1)*16
         + (instr('0123456789abcdef',substr(s.score,18,1))-1) ) AS sc,
         ROW_NUMBER() OVER (PARTITION BY o.owner ORDER BY s.internal_executed_at) AS game_no
  FROM "relayer_0_0_1-TokenMetadataUpdate" m
  JOIN "relayer_0_0_1-TokenScoreUpdate"   s ON s.id = m.id
  JOIN "relayer_0_0_1-OwnersUpdate"       o ON o.token_id = m.id
  WHERE m.settings_id = 1 AND m.minted_by = '0x0000000000000006'
),
b AS (
  SELECT CASE WHEN game_no=1 THEN '1st game'
              WHEN game_no<=5 THEN '2nd-5th game'
              WHEN game_no<=20 THEN '6th-20th game'
              WHEN game_no<=50 THEN '21st-50th game'
              ELSE '51st+ game' END AS experience,
         CASE WHEN game_no=1 THEN 1 WHEN game_no<=5 THEN 2 WHEN game_no<=20 THEN 3
              WHEN game_no<=50 THEN 4 ELSE 5 END AS ord,
         sc
  FROM g WHERE sc BETWEEN 1 AND 3000
),
r AS (SELECT experience, ord, sc,
             ROW_NUMBER() OVER (PARTITION BY experience ORDER BY sc) rn,
             COUNT(*)     OVER (PARTITION BY experience) c FROM b)
SELECT experience,
       c AS games,
       ROUND(AVG(CASE WHEN rn IN ((c+1)/2,(c+2)/2) THEN sc END),1) AS median_score
FROM r GROUP BY experience ORDER BY MIN(ord);
