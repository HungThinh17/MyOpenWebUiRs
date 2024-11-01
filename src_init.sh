#!/bin/bash

# Base directory where the structure will be created
BASE_DIR="src"

# Log file paths
SUCCESS_LOG="creation_success.log"
FAIL_LOG="creation_fail.log"

# Function to log messages
log_message() {
    local log_file="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$log_file"
}

# Function to create directories
create_directory() {
    if [ -d "$1" ]; then
        echo "Directory already exists: $1"
        log_message "$SUCCESS_LOG" "Directory already exists: $1"
    else
        if mkdir -p "$1" 2>/dev/null; then
            echo "Created directory: $1"
            log_message "$SUCCESS_LOG" "Created directory: $1"
        else
            echo "Failed to create directory: $1"
            log_message "$FAIL_LOG" "Failed to create directory: $1"
        fi
    fi
}

# Function to create README.md in leaf directories
create_readme() {
    local dir="$1"
    if [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
        readme_path="$dir/README.md"
        echo "# $(basename "$dir")" > "$readme_path"
        echo "" >> "$readme_path"
        echo "This is a placeholder README file for the $(basename "$dir") directory." >> "$readme_path"
        
        if [ -f "$readme_path" ]; then
            echo "Created README.md in leaf directory: $dir"
            log_message "$SUCCESS_LOG" "Created README.md in leaf directory: $dir"
        else
            echo "Failed to create README.md in leaf directory: $dir"
            log_message "$FAIL_LOG" "Failed to create README.md in leaf directory: $dir"
        fi
    fi
}

# Function to parse JSON and create directories
parse_json() {
    local prefix="$1"
    local json="$2"

    # Extract keys from the JSON object
    keys=$(echo "$json" | jq -r 'keys[]')

    for key in $keys; do
        if [ "$key" != "subdirectories" ]; then
            local path="$prefix/$key"
            create_directory "$path"

            # Check if there are subdirectories
            subdirs=$(echo "$json" | jq -r ".[\"$key\"].subdirectories[]?" 2>/dev/null)
            if [ ! -z "$subdirs" ]; then
                for subdir in $subdirs; do
                    create_directory "$path/$subdir"
                done
            fi

            # Recursively parse nested objects
            local nested_json=$(echo "$json" | jq -r ".[\"$key\"]")
            if [[ "$nested_json" == {* ]]; then
                parse_json "$path" "$nested_json"
            fi
        fi
    done
}

# Function to recursively add README.md to leaf directories
add_readme_to_leaves() {
    local dir="$1"
    local subdirs=()
    
    # Collect subdirectories
    while IFS= read -r -d '' subdir; do
        subdirs+=("$subdir")
    done < <(find "$dir" -type d -print0)

    # Process subdirectories
    for subdir in "${subdirs[@]}"; do
        create_readme "$subdir"
    done
}

# Clear previous log files
> "$SUCCESS_LOG"
> "$FAIL_LOG"

# Check if src_structure.json exists
if [ ! -f "src_structure.json" ]; then
    echo "Error: src_structure.json not found in the current directory."
    log_message "$FAIL_LOG" "src_structure.json not found in the current directory."
    exit 1
fi

# Read the JSON file
json_content=$(cat src_structure.json)

# Start parsing from the root to create directories
parse_json "$BASE_DIR" "$json_content"

# Add README.md files to leaf directories
add_readme_to_leaves "$BASE_DIR"

echo "Folder structure process completed in $BASE_DIR"
log_message "$SUCCESS_LOG" "Folder structure process completed in $BASE_DIR"
echo "Success log: $SUCCESS_LOG"
echo "Failure log: $FAIL_LOG"
