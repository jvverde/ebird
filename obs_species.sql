SELECT date, name, count, location, map
FROM sightings
WHERE site LIKE '%' || $site || '%'
  AND name LIKE '%' || $species || '%'
ORDER BY date DESC, name, location;