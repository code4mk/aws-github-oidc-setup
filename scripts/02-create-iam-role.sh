#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../.env"

TRUST_POLICY_FILE="${SCRIPT_DIR}/../policies/trust-policy.json"

echo "==> Preparing trust policy..."

REPO="${GITHUB_REPO// /}"

if [[ "${REPO}" == "*" ]]; then
  SUBJECT_CLAIM="repo:${GITHUB_ORG}/*"
  SCOPE_LABEL="all repos in ${GITHUB_ORG}"
else
  SUBJECT_CLAIM="repo:${GITHUB_ORG}/${REPO}:*"
  SCOPE_LABEL="${GITHUB_ORG}/${REPO}"
fi

echo "    Scope: ${SCOPE_LABEL}"

TRUST_POLICY=$(sed -e "s|ACCOUNT_ID|${AWS_ACCOUNT_ID}|g" \
                   -e "s|SUBJECT_CLAIM|${SUBJECT_CLAIM}|g" \
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
    --description "Role assumed by GitHub Actions via OIDC for ${SCOPE_LABEL}" \
    --max-session-duration 3600 \
    > /dev/null
  echo "    Role created."
fi

ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${IAM_ROLE_NAME}"
echo "    Role ARN: ${ROLE_ARN}"
