-- Loot Survivor — Claim: skill persists (skilled players consistently outscore weaker players over many games)
-- Source: https://api.cartridge.gg/x/pg-mainnet-10/torii/sql  (SQLite)
-- Players (>=20 games) are split into four tiers by their MEDIAN score over their FIRST 10 games,
-- then each tier's median score is tracked across later game windows. If outcomes were driven by
-- chance the tiers would converge; instead they stay ordered and separated across 100+ games.
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
         ROW_NUMBER() OVER (PARTITION BY o.owner ORDER BY s.internal_executed_at) AS gn,
         COUNT(*)     OVER (PARTITION BY o.owner) AS n
  FROM "relayer_0_0_1-TokenMetadataUpdate" m
  JOIN "relayer_0_0_1-TokenScoreUpdate"   s ON s.id = m.id
  JOIN "relayer_0_0_1-OwnersUpdate"       o ON o.token_id = m.id
  WHERE m.settings_id = 1 AND m.minted_by = '0x0000000000000006'
),
e AS (SELECT player, sc, gn FROM g WHERE n >= 20 AND sc BETWEEN 1 AND 3000),
em AS (  -- each player's median over their first 10 games
  SELECT player, AVG(CASE WHEN rn IN ((c+1)/2,(c+2)/2) THEN sc END) AS e10
  FROM (SELECT player, sc, ROW_NUMBER() OVER (PARTITION BY player ORDER BY sc) rn,
               COUNT(*) OVER (PARTITION BY player) c FROM e WHERE gn <= 10) GROUP BY player),
q AS (SELECT player, NTILE(4) OVER (ORDER BY e10) AS skill_tier FROM em),
later AS (
  SELECT q.skill_tier, e.sc,
         CASE WHEN e.gn<=20 THEN 1 WHEN e.gn<=40 THEN 2 WHEN e.gn<=70 THEN 3 ELSE 4 END AS later_window
  FROM e JOIN q USING(player) WHERE e.gn > 10 AND e.gn <= 120),
r AS (SELECT skill_tier, later_window, sc,
             ROW_NUMBER() OVER (PARTITION BY skill_tier,later_window ORDER BY sc) rn,
             COUNT(*)     OVER (PARTITION BY skill_tier,later_window) c FROM later)
SELECT skill_tier, later_window, c AS games,
       ROUND(AVG(CASE WHEN rn IN ((c+1)/2,(c+2)/2) THEN sc END),1) AS median_score
FROM r GROUP BY skill_tier, later_window ORDER BY skill_tier, later_window;
