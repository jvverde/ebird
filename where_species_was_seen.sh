#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 [-s site] [-d lastdays] db species"
    exit 1
}

# Parse options
while getopts "s:d:" opt; do
    case "$opt" in
        d) declare -r days="$OPTARG" ;;
        s) declare -r site="$OPTARG" ;;
        *) usage ;;
    esac
done
shift $((OPTIND-1))

sqlite3 dbs/ebird-"${1?$(usage)}".db "SELECT COUNT(*) as count,name, location, map FROM sightings WHERE location LIKE '%${site:-}%' AND date >= date('now', '-${days:-30} days') ${2:+AND name LIKE '%${2}%'} GROUP BY name, location ORDER BY count DESC;"
