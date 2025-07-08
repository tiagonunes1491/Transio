#!/bin/bash

# This script generates the initial infra/versions.json file.
# Run it once from the root of your repository.

VERSIONS_FILE="infra/versions.json"
BICEP_ROOT="infra"

echo "{" > "$VERSIONS_FILE"

# Find all .bicep files, but not .bicepparam files
FIRST_LINE=true
find "$BICEP_ROOT" -type f -name "*.bicep" | while read -r file; do
  # Get the path relative to the 'infra' directory
  base_path=$(echo "$file" | sed "s|^$BICEP_ROOT/||")

  # Determine the artifact name (the key for the JSON)
  if [[ "$base_path" == */* ]]; then
    artifact_name=$(echo "$base_path" | sed 's|.bicep$||')
  else
    artifact_name=$(basename "$base_path" .bicep)
  fi

  # Add a comma before each line except the first
  if [ "$FIRST_LINE" = true ]; then
    FIRST_LINE=false
  else
    echo "," >> "$VERSIONS_FILE"
  fi

  # Write the JSON entry with initial version 1.0.0
  echo "  \"$artifact_name\": \"1.0.0\"" >> "$VERSIONS_FILE"
done

echo "}" >> "$VERSIONS_FILE"

echo "✅ Baseline $VERSIONS_FILE created successfully."
echo "Please review the file, then commit it to your 'development' branch."