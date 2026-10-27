WITH r AS (
  SELECT site, name, date, count, location, map,
         ROW_NUMBER() OVER (
           PARTITION BY location, site, name, map
           ORDER BY date DESC
         ) AS rn,
         COUNT(*) OVER (
           PARTITION BY location, site, name, map
         ) AS observacoes
  FROM sightings
  WHERE name LIKE '%' || $species || '%'
)
SELECT site, name, date AS ultima, count AS individuos, observacoes, location, map
FROM r
WHERE rn = 1
ORDER BY name, ultima;