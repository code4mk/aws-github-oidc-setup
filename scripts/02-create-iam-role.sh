#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../.env"

TRUST_POLICY_FILE="${SCRIPT_DIR}/../policies/trust-policy.json"

echo "==> Preparing trust policy..."

TRUST_POLICY=$(sed \
  -e "s|ACCOUNT_ID|${AWS_ACCOUNT_ID}|g" \
  -e "s|GITHUB_ORG|${GITHUB_ORG}|g" \
  -e "s|GITHUB_REPO|${GITHUB_REPO}|g" \
  "${TRUST_POLICY_FILE}")

echo "==> Checking if IAM role '${IAM_ROLE_NAME}' already exists..."

if aws iam get-role --role-name "${IAM_ROLE_NAME}" >/dev/null 2>&1; then
  echo "    Role already exists. Updating trust policy..."
  aws iam update-assume-role-policy \
    --role-name "${IAM_ROLE_NAME}" \
    --policy-document "${TRUST_POLICY}"
  echo "    Trust policy updated."
else
  echo "==> Creating IAM role '${IAM_ROLE_NAME}'..."
  aws iam create-role \
    --role-name "${IAM_ROLE_NAME}" \
    --assume-role-policy-document "${TRUST_POLICY}" \
    --description "Role assumed by GitHub Actions via OIDC for ${GITHUB_ORG}/${GITHUB_REPO}" \
    --max-session-duration 3600
  echo "    Role created."
fi

ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${IAM_ROLE_NAME}"
echo "    Role ARN: ${ROLE_ARN}"
