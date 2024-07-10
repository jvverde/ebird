#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 [-m match] [-d lastdays] db"
    exit 1
}

# Parse options
while getopts "m:d:" opt; do
    case "$opt" in
        m) declare -r match="$OPTARG" ;;
        d) declare -r days="$OPTARG" ;;
        *) usage ;;
    esac
done
shift $((OPTIND-1))

sqlite3 dbs/ebird-"${1?$(usage)}".db "SELECT COUNT(DISTINCT name) AS species_count, location, map FROM sightings WHERE name LIKE '%${match:-}%' AND date >= date('now', '-${days:-7} days') GROUP BY location ORDER BY species_count DESC;"