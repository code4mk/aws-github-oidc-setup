#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../.env"

echo "==> Checking if OIDC provider already exists..."

PROVIDER_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "${PROVIDER_ARN}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  echo "    OIDC provider already exists: ${PROVIDER_ARN}"
  echo "    Updating thumbprints to ensure they are current..."
  
  # Update existing provider with the list of thumbprints
  aws iam update-open-id-connect-provider-thumbprint \
    --open-id-connect-provider-arn "${PROVIDER_ARN}" \
    --thumbprint-list ${OIDC_THUMBPRINTS} \
    --region "${AWS_REGION}"
    
  echo "    Thumbprints updated."
else
  echo "==> Creating OIDC provider for GitHub Actions..."
  aws iam create-open-id-connect-provider \
    --url "https://token.actions.githubusercontent.com" \
    --client-id-list "${OIDC_AUDIENCE}" \
    --thumbprint-list ${OIDC_THUMBPRINTS} \
    --region "${AWS_REGION}" \
    > /dev/null

  echo "    OIDC provider created: ${PROVIDER_ARN}"
fi
