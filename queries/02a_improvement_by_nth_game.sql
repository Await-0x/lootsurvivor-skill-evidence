-- Loot Survivor — Claim 2a: A player's score rises with experience (median score by their Nth game)
-- Source: https://api.cartridge.gg/x/pg-mainnet-10/torii/sql  (SQLite)
-- Each game is numbered within the player's own career (1st, 2nd, ... by time).
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
r AS (SELECT game_no, sc,
             ROW_NUMBER() OVER (PARTITION BY game_no ORDER BY sc) rn,
             COUNT(*)     OVER (PARTITION BY game_no) c
      FROM g WHERE sc BETWEEN 1 AND 3000)
SELECT game_no,
       c AS players,
       ROUND(AVG(CASE WHEN rn IN ((c+1)/2,(c+2)/2) THEN sc END),1) AS median_score
FROM r
GROUP BY game_no HAVING c >= 30   -- drop the thin long tail
ORDER BY game_no;
