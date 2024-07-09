#!/bin/bash
# Apply mail3db.pl (convert emailrecord to sqlite db) to all email files (.eml) found on a give or current directory

# Treat unset variables as an error and exit immediately
set -u

# Function to display usage information
usage() {
    echo "Usage: $0 [-d dbsdir] [-e errdir] datadirs..."
    exit 1
}

# Default values
declare dbsdir="dbs"
declare errdir="error_logs"

# Parse options
while getopts "d:e:" opt; do
    case "$opt" in
        d) dbsdir="$OPTARG" ;;
        e) errdir="$OPTARG" ;;
        *) usage ;;
    esac
done

shift $((OPTIND-1))

# Ensure error and dbs directories exists
mkdir -p "$errdir"
mkdir -p "$dbsdir"

# Declare an array for directories and use parameter expansion to set the default directory to current directory if no arguments are provided
declare -a dirs=("${@:-.}")

# Use find directly over the array of directories
find "${dirs[@]}" -type f -name '*.eml' -printf '%h\n' | sort -u | while read -r dir
do
    # Extract the directory name
    declare dirname="$(basename "$dir")"
    # Run the command
    ./mail2db.pl --db "${dbsdir}/ebird-${dirname}.db" "$dir"/* 2>"$errdir/${dirname}.lst"
done
