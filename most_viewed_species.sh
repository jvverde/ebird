#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 [-m match] [-s site] [-d lastdays] db"
    exit 1
}

# Parse options
while getopts "m:s:d:" opt; do
    case "$opt" in
        m) declare -r match="$OPTARG" ;;
        d) declare -r days="$OPTARG" ;;
        s) declare -r site="$OPTARG" ;;
        *) usage ;;
    esac
done
shift $((OPTIND-1))

sqlite3 dbs/ebird-"${1?$(usage)}".db "SELECT COUNT(*) AS count, name FROM sightings WHERE name LIKE '%${match:-}%' AND location LIKE '%${site:-}%' AND date >= date('now', '-${days:-7} days') GROUP BY name ORDER BY count DESC;"