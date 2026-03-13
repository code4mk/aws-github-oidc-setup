#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../.env"

TRUST_POLICY_FILE="${SCRIPT_DIR}/../policies/trust-policy.json"

echo "==> Preparing trust policy..."

CLAIMS=()
INPUT="${GITHUB_REPO// /}"

if [[ "${INPUT}" == "*" ]]; then
  CLAIMS+=("repo:${GITHUB_ORG}/*")
  SCOPE_LABEL="all repos in ${GITHUB_ORG}"
elif [[ "${INPUT}" != *"{"* ]]; then
  CLAIMS+=("repo:${GITHUB_ORG}/${INPUT}:*")
  SCOPE_LABEL="${GITHUB_ORG}/${INPUT}"
else
  SCOPE_LABEL=""
  while [[ -n "${INPUT}" ]]; do
    REPO="${INPUT%%:\{*}"
    INPUT="${INPUT#*\{}"
    BRANCHES="${INPUT%%\}*}"
    INPUT="${INPUT#*\}}"
    INPUT="${INPUT#,}"

    IFS=',' read -ra BRANCH_LIST <<< "${BRANCHES}"
    for BRANCH in "${BRANCH_LIST[@]}"; do
      CLAIMS+=("repo:${GITHUB_ORG}/${REPO}:ref:refs/heads/${BRANCH}")
    done

    [[ -n "${SCOPE_LABEL}" ]] && SCOPE_LABEL+=", "
    SCOPE_LABEL+="${REPO}:{${BRANCHES}}"
  done
fi

echo "    Scope: ${SCOPE_LABEL}"

# Build the trust policy JSON from the template
TRUST_POLICY=$(sed -e "s|ACCOUNT_ID|${AWS_ACCOUNT_ID}|g" "${TRUST_POLICY_FILE}")

if [[ ${#CLAIMS[@]} -eq 1 ]]; then
  TRUST_POLICY="${TRUST_POLICY/SUBJECT_CLAIM/${CLAIMS[0]}}"
else
  CLAIM_ARRAY="["
  for i in "${!CLAIMS[@]}"; do
    [[ $i -gt 0 ]] && CLAIM_ARRAY+=","
    CLAIM_ARRAY+="\"${CLAIMS[$i]}\""
  done
  CLAIM_ARRAY+="]"
  TRUST_POLICY="${TRUST_POLICY/\"SUBJECT_CLAIM\"/${CLAIM_ARRAY}}"
fi

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
