#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../.env"

POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${IAM_POLICY_NAME}"
PROVIDER_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

echo "========================================="
echo "  AWS OIDC Cleanup"
echo "  This will DELETE the following:"
echo "    - IAM policy: ${IAM_POLICY_NAME}"
echo "    - IAM role:   ${IAM_ROLE_NAME}"
echo "    - OIDC provider: token.actions.githubusercontent.com"
echo "========================================="
read -rp "Are you sure? (y/N): " CONFIRM
if [[ "${CONFIRM}" != "y" && "${CONFIRM}" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

echo "==> Detaching policy from role..."
aws iam detach-role-policy \
  --role-name "${IAM_ROLE_NAME}" \
  --policy-arn "${POLICY_ARN}" 2>/dev/null || echo "    (already detached or not found)"

echo "==> Deleting all policy versions..."
VERSIONS=$(aws iam list-policy-versions --policy-arn "${POLICY_ARN}" --query 'Versions[?IsDefaultVersion==`false`].VersionId' --output text 2>/dev/null || true)
for V in ${VERSIONS}; do
  aws iam delete-policy-version --policy-arn "${POLICY_ARN}" --version-id "${V}"
  echo "    Deleted version ${V}"
done

echo "==> Deleting IAM policy..."
aws iam delete-policy --policy-arn "${POLICY_ARN}" 2>/dev/null || echo "    (not found)"

echo "==> Deleting IAM role..."
aws iam delete-role --role-name "${IAM_ROLE_NAME}" 2>/dev/null || echo "    (not found)"

echo "==> Deleting OIDC provider..."
aws iam delete-open-id-connect-provider \
  --open-id-connect-provider-arn "${PROVIDER_ARN}" 2>/dev/null || echo "    (not found)"

echo "==> Cleanup complete."
