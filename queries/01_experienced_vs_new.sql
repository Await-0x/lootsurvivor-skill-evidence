-- Loot Survivor — Claim 1: Experienced players outperform new players (median score by experience)
-- Source: https://api.cartridge.gg/x/pg-mainnet-10/torii/sql  (SQLite)
-- Filters: official LS minter (registry id 0x6 = 0x00a67ef2...29ec42), settings_id=1, score 1..3000.
-- Headline metric is MEDIAN (scores are heavy-tailed; the raw mean is outlier-dominated).
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
         + (instr('0123456789abcdef',substr(s.score,18,1))-1) ) AS sc
  FROM "relayer_0_0_1-TokenMetadataUpdate" m
  JOIN "relayer_0_0_1-TokenScoreUpdate"   s ON s.id = m.id
  JOIN "relayer_0_0_1-OwnersUpdate"       o ON o.token_id = m.id
  WHERE m.settings_id = 1 AND m.minted_by = '0x0000000000000006'
),
gp AS (SELECT player, sc, COUNT(*) OVER (PARTITION BY player) AS games
       FROM g WHERE sc BETWEEN 1 AND 3000),
buck AS (
  SELECT CASE WHEN games=1 THEN '1' WHEN games<=5 THEN '2-5'
              WHEN games<=20 THEN '6-20' WHEN games<=50 THEN '21-50'
              ELSE '51+' END AS bucket, sc FROM gp
),
r AS (SELECT bucket, sc,
             ROW_NUMBER() OVER (PARTITION BY bucket ORDER BY sc) rn,
             COUNT(*)     OVER (PARTITION BY bucket) c FROM buck)
SELECT bucket,
       c AS games,
       ROUND(AVG(CASE WHEN rn IN ((c+1)/2,(c+2)/2) THEN sc END),1) AS median_score,
       ROUND(AVG(sc),1) AS mean_score   -- shown for completeness; median is the headline
FROM r GROUP BY bucket
ORDER BY MIN(CASE bucket WHEN '1' THEN 1 WHEN '2-5' THEN 2 WHEN '6-20' THEN 3
                         WHEN '21-50' THEN 4 ELSE 5 END);
