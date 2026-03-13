#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================="
echo "  AWS OIDC Setup for GitHub Actions"
echo "========================================="
echo ""

source "${SCRIPT_DIR}/.env"

if [[ "${OIDC_SCOPE}" == "org" ]]; then
  SCOPE_DISPLAY="all repos in ${GITHUB_ORG}"
else
  SCOPE_DISPLAY="${GITHUB_ORG}/${GITHUB_REPO}"
fi

echo "  AWS Account:  ${AWS_ACCOUNT_ID}"
echo "  Region:       ${AWS_REGION}"
echo "  OIDC Scope:   ${OIDC_SCOPE} (${SCOPE_DISPLAY})"
echo "  IAM Role:     ${IAM_ROLE_NAME}"
echo ""
read -rp "Proceed with setup? (y/N): " CONFIRM
if [[ "${CONFIRM}" != "y" && "${CONFIRM}" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi
echo ""

echo "--- Step 1/3: OIDC Provider ---"
bash "${SCRIPT_DIR}/scripts/01-create-oidc-provider.sh"
echo ""

echo "--- Step 2/3: IAM Role ---"
bash "${SCRIPT_DIR}/scripts/02-create-iam-role.sh"
echo ""

echo "--- Step 3/3: IAM Policies ---"
bash "${SCRIPT_DIR}/scripts/03-attach-policies.sh"
echo ""

ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${IAM_ROLE_NAME}"
echo "========================================="
echo "  Setup complete!"
echo ""
echo "  Use this Role ARN in your GitHub Actions workflow:"
echo "    ${ROLE_ARN}"
echo ""
echo "  Example workflow step:"
echo "    - uses: aws-actions/configure-aws-credentials@v4"
echo "      with:"
echo "        role-to-assume: ${ROLE_ARN}"
echo "        aws-region: ${AWS_REGION}"
echo "========================================="
