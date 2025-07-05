#!/usr/bin/env bash
set -euo pipefail

# --- CONFIGURE THESE ---
KEYVAULT_NAME="ssdswakv"
SECRET_NAME="encryption-key"
RG="ss-d-swa-rg"
TEMPLATE="main.bicep"
PARAM_FILE="main.dev.bicepparam"

# --- FETCH VERSIONS AND SORT NEWEST→OLDEST ---
mapfile -t versions < <(
  az keyvault secret list-versions \
    --vault-name "$KEYVAULT_NAME" \
    --name "$SECRET_NAME" \
    --query "sort_by([], &attributes.created) | reverse(@) | [].id" \
    -o tsv
)

# --- PICK LATEST AND PREVIOUS (FALLBACK WHEN ONLY ONE) ---
if (( ${#versions[@]} == 0 )); then
  echo "ERROR: No versions found for $SECRET_NAME in $KEYVAULT_NAME" >&2
  exit 1
fi

latest="${versions[0]}"
if (( ${#versions[@]} > 1 )); then
  previous="${versions[1]}"
else
  previous="$latest"
  echo "WARNING: Only one secret version found; using same version for previous" >&2
fi

echo "Using latest   = $latest"
echo "Using previous = $previous"

# --- DEPLOY ---
az deployment group create \
  --resource-group "$RG" \
  --template-file "$TEMPLATE" \
  --parameters "$PARAM_FILE" \
  --parameters \
      encryptionKeyUri="$latest" \
      encryptionKeyPreviousUri="$previous"
