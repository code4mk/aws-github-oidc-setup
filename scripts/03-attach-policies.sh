#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../.env"

PERMISSIONS_POLICY_FILE="${SCRIPT_DIR}/../policies/permissions-policy.json"
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${IAM_POLICY_NAME}"

echo "==> Checking if IAM policy '${IAM_POLICY_NAME}' already exists..."

if aws iam get-policy --policy-arn "${POLICY_ARN}" >/dev/null 2>&1; then
  echo "    Policy already exists. Creating new version..."

  # AWS allows max 5 policy versions — delete the oldest non-default version if at limit
  VERSIONS=$(aws iam list-policy-versions --policy-arn "${POLICY_ARN}" --query 'Versions[?IsDefaultVersion==`false`].VersionId' --output text)
  VERSION_COUNT=$(echo "${VERSIONS}" | wc -w | tr -d ' ')

  if [ "${VERSION_COUNT}" -ge 4 ]; then
    OLDEST=$(echo "${VERSIONS}" | awk '{print $NF}')
    echo "    Deleting oldest policy version ${OLDEST} to stay under limit..."
    aws iam delete-policy-version --policy-arn "${POLICY_ARN}" --version-id "${OLDEST}"
  fi

  aws iam create-policy-version \
    --policy-arn "${POLICY_ARN}" \
    --policy-document file://"${PERMISSIONS_POLICY_FILE}" \
    --set-as-default \
    > /dev/null
  echo "    Policy updated with new default version."
else
  echo "==> Creating IAM policy '${IAM_POLICY_NAME}'..."
  aws iam create-policy \
    --policy-name "${IAM_POLICY_NAME}" \
    --policy-document file://"${PERMISSIONS_POLICY_FILE}" \
    --description "Permissions for GitHub Actions OIDC role (${GITHUB_ORG}/${GITHUB_REPO})" \
    > /dev/null
  echo "    Policy created."
fi

echo "==> Attaching policy to role '${IAM_ROLE_NAME}'..."
aws iam attach-role-policy \
  --role-name "${IAM_ROLE_NAME}" \
  --policy-arn "${POLICY_ARN}"

echo "    Policy attached to role."
