WITH loc AS (
  SELECT name,
         site,
         location,
         map,
         COUNT(*) AS n,
         SUM(COUNT(*)) OVER (PARTITION BY name) AS total,
         ROW_NUMBER() OVER (PARTITION BY name ORDER BY COUNT(*) DESC, site, location) AS rk
  FROM sightings
  GROUP BY name, site, location
)
SELECT name, total, rk, n, site, location, map
FROM loc
WHERE total > 1 AND rk <= 10
ORDER BY total DESC, name, rk;