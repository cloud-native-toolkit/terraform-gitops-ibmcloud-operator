#!/usr/bin/env bash

NAMESPACE="$1"
REGION="$2"
OUTPUT_DIR="$3"

mkdir -p "${OUTPUT_DIR}"

export PATH="${BIN_DIR}:${PATH}"

kubectl create secret generic ibmcloud-operator-secret \
  -n "${NAMESPACE}" \
  --from-literal="api-key=${IBMCLOUD_API_KEY}" \
  --from-literal="region=${REGION}" \
  --dry-run=client \
  --output=json > "${OUTPUT_DIR}/secret.yaml"

echo "Created secret"
ls "${OUTPUT_DIR}"
