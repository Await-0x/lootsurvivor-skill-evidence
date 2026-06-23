-- Loot Survivor — Claim 2b: The SAME player scores higher later than early (within-subject)
-- Source: https://api.cartridge.gg/x/pg-mainnet-10/torii/sql  (SQLite)
-- For each player with >=10 games, compare the median of their first half of games vs second half.
-- This neutralises the survivorship objection: every player is compared only against themselves.
WITH g AS (
  SELECT o.owner AS player,
         ( (instr('0123456789abcdef',substr(s.score,7,1))-1)*17592186044416
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
         ROW_NUMBER() OVER (PARTITION BY o.owner ORDER BY s.internal_executed_at) AS game_no,
         COUNT(*)     OVER (PARTITION BY o.owner) AS n
  FROM "relayer_0_0_1-TokenMetadataUpdate" m
  JOIN "relayer_0_0_1-TokenScoreUpdate"   s ON s.id = m.id
  JOIN "relayer_0_0_1-OwnersUpdate"       o ON o.token_id = m.id
  WHERE m.settings_id = 1 AND m.minted_by = '0x0000000000000006'
),
f AS (SELECT player, sc, CASE WHEN game_no <= n/2 THEN 'first' ELSE 'second' END AS half
      FROM g WHERE n >= 10 AND sc BETWEEN 1 AND 3000),
r AS (SELECT player, half, sc,
             ROW_NUMBER() OVER (PARTITION BY player, half ORDER BY sc) rn,
             COUNT(*)     OVER (PARTITION BY player, half) c FROM f),
med AS (SELECT player, half, AVG(CASE WHEN rn IN ((c+1)/2,(c+2)/2) THEN sc END) m
        FROM r GROUP BY player, half),
p AS (SELECT player,
             MAX(CASE WHEN half='first'  THEN m END) AS first_med,
             MAX(CASE WHEN half='second' THEN m END) AS second_med
      FROM med GROUP BY player)
SELECT COUNT(*) AS players,
       SUM(CASE WHEN second_med > first_med THEN 1 ELSE 0 END) AS improved,
       ROUND(100.0*SUM(CASE WHEN second_med > first_med THEN 1 ELSE 0 END)/COUNT(*),1) AS pct_improved,
       ROUND(AVG(first_med),1)  AS avg_first_half_median,
       ROUND(AVG(second_med),1) AS avg_second_half_median
FROM p WHERE first_med IS NOT NULL AND second_med IS NOT NULL;
