#!/bin/bash

sqlite3 dbs/ebird-"${1?"Usage: $0 location"}".db "SELECT COUNT(DISTINCT checklist) AS freq, location, map FROM sightings WHERE date >= date('now', '-${2:-30} days') group by location order by freq desc"