# AWS OIDC Setup for GitHub Actions

Bash scripts to configure AWS IAM for GitHub Actions OIDC authentication — no long-lived access keys needed.

## What This Creates

| Resource | Description |
|----------|-------------|
| OIDC Identity Provider | `token.actions.githubusercontent.com` in your AWS account |
| IAM Role | Assumable by GitHub Actions via OIDC federation |
| IAM Policy | Permissions granted to the role (S3, ECR, CloudFormation by default) |

## Prerequisites

- AWS CLI v2 installed and configured (`aws configure`)
- Sufficient IAM permissions to create OIDC providers, roles, and policies
- `bash` 4+

## Quick Start

1. **Edit configuration:**

   ```bash
   cp config.env config.env.bak   # optional backup
   nano config.env                 # set your AWS account ID, GitHub org/repo, etc.
   ```

2. **Run setup:**

   ```bash
   chmod +x setup.sh scripts/*.sh
   ./setup.sh
   ```

3. **Use in GitHub Actions:**

   ```yaml
   permissions:
     id-token: write
     contents: read

   jobs:
     deploy:
       runs-on: ubuntu-latest
       steps:
         - uses: aws-actions/configure-aws-credentials@v4
           with:
             role-to-assume: arn:aws:iam::<ACCOUNT_ID>:role/github-actions-oidc-role
             aws-region: us-east-1

         - run: aws s3 ls
   ```

## File Structure

```
├── config.env                        # Configuration variables
├── setup.sh                          # Main entry point
├── scripts/
│   ├── 01-create-oidc-provider.sh    # Create OIDC identity provider
│   ├── 02-create-iam-role.sh         # Create IAM role with trust policy
│   ├── 03-attach-policies.sh         # Attach permission policies
│   └── 99-cleanup.sh                 # Tear down all resources
└── policies/
    ├── trust-policy.json             # Who can assume the role
    └── permissions-policy.json       # What the role can do
```

## Customizing Permissions

Edit `policies/permissions-policy.json` to grant only the permissions your workflow needs. The default policy includes S3, ECR, and CloudFormation read access.

## Restricting Access

The trust policy (`policies/trust-policy.json`) uses a `StringLike` condition on `sub` with `repo:ORG/REPO:*`. You can restrict further:

| Pattern | Allows |
|---------|--------|
| `repo:org/repo:*` | Any trigger from the repo |
| `repo:org/repo:ref:refs/heads/main` | Only the `main` branch |
| `repo:org/repo:environment:production` | Only the `production` environment |

## Cleanup

```bash
./scripts/99-cleanup.sh
```

This removes the OIDC provider, IAM role, and IAM policy from your account.
