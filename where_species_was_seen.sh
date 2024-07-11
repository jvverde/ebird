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

sqlite3 dbs/ebird-"${1?$(usage)}".db "SELECT count,name, date, location, map FROM sightings WHERE name Like '%${2?$(usage)}%' AND location LIKE '%${site:-}%' AND date >= date('now', '-${days:-7} days') ORDER BY count DESC;"