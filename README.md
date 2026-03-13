# AWS OIDC Setup for GitHub Actions

Bash scripts to configure AWS IAM for GitHub Actions OIDC authentication — no long-lived access keys needed.

## What This Creates

| Resource | Description |
|----------|-------------|
| OIDC Identity Provider | `token.actions.githubusercontent.com` in your AWS account |
| IAM Role | Assumable by GitHub Actions via OIDC federation |
| IAM Policy | Permissions granted to the role (S3, ECR, ECS, CloudFormation, CloudWatch Logs by default) |

## Prerequisites

- AWS CLI v2 installed
- Sufficient IAM permissions to create OIDC providers, roles, and policies
- `bash` 4+

## Quick Start

1. **Setup Environment:**

   ```bash
   cp .env.example .env
   nano .env
   ```
   Fill in your AWS credentials, account ID, and GitHub org. Set `GITHUB_REPO` to control access scope:

   | `GITHUB_REPO` | Trust policy subject |
   |---|---|
   | `"*"` | `repo:ORG/*` — any repo in the org can assume the role |
   | `"my-app"` | `repo:ORG/my-app:*` — single repo, all refs |
   | `"my-app:{dev,main}"` | Branch-locked — only `dev` and `main` branches |
   | `"my-app:{dev,main},backend:{dev,main}"` | Multiple repos, each with specific branches |

2. **Run Setup:**

   ```bash
   ./setup.sh
   ```
   The script will confirm your settings before creating the OIDC provider, IAM role, and attaching policies.

3. **Use in GitHub Actions:**

   Add the following to your `.github/workflows/deploy.yml`:

   ```yaml
   permissions:
     id-token: write   # Required for requesting the JWT
     contents: read    # Required for actions/checkout

   jobs:
     deploy:
       runs-on: ubuntu-latest
       steps:
         - name: Configure AWS Credentials
           uses: aws-actions/configure-aws-credentials@v4
           with:
             role-to-assume: arn:aws:iam::<ACCOUNT_ID>:role/github-actions-oidc-role
             aws-region: us-east-1

         - name: Test AWS Access
           run: aws sts get-caller-identity
   ```

   For ECS deployments, you can extend the workflow:

   ```yaml
         - name: Login to Amazon ECR
           id: login-ecr
           uses: aws-actions/amazon-ecr-login@v2

         - name: Build, tag, and push image to ECR
           env:
             ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
             ECR_REPOSITORY: my-app
             IMAGE_TAG: ${{ github.sha }}
           run: |
             docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
             docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG

         - name: Download task definition
           run: |
             aws ecs describe-task-definition --task-definition my-app \
               --query taskDefinition > task-definition.json

         - name: Update ECS task definition
           id: task-def
           uses: aws-actions/amazon-ecs-render-task-definition@v1
           with:
             task-definition: task-definition.json
             container-name: my-app
             image: ${{ steps.login-ecr.outputs.registry }}/my-app:${{ github.sha }}

         - name: Deploy to ECS
           uses: aws-actions/amazon-ecs-deploy-task-definition@v2
           with:
             task-definition: ${{ steps.task-def.outputs.task-definition }}
             service: my-app-service
             cluster: my-cluster
             wait-for-service-stability: true
   ```

## File Structure

```
├── .env                              # Your private configuration (git-ignored)
├── .env.example                      # Template for configuration
├── .gitignore                        # Prevents committing secrets
├── README.md                         # This file
├── setup.sh                          # Main entry point (runs scripts 01-03)
├── scripts/
│   ├── 01-create-oidc-provider.sh    # Create/Update OIDC identity provider
│   ├── 02-create-iam-role.sh         # Create IAM role with trust policy
│   ├── 03-attach-policies.sh         # Attach permission policies
│   └── 99-cleanup.sh                 # Tear down all resources
└── policies/
    ├── trust-policy.json             # Who can assume the role
    └── permissions-policy.json       # What the role can do
```

## Included Permissions

The default `policies/permissions-policy.json` grants the following:

| Statement | Actions | Purpose |
|-----------|---------|---------|
| AllowS3Access | `s3:GetObject`, `PutObject`, `ListBucket` | Upload/download artifacts to S3 |
| AllowECRAccess | `ecr:GetAuthorizationToken`, `BatchCheckLayerAvailability`, `GetDownloadUrlForLayer`, `BatchGetImage`, `PutImage`, `InitiateLayerUpload`, `UploadLayerPart`, `CompleteLayerUpload` | Push/pull container images |
| AllowCloudFormationDescribe | `cloudformation:DescribeStacks`, `ListStacks` | Read CloudFormation stack info |
| AllowECSTaskDefinitions | `ecs:RegisterTaskDefinition`, `DescribeTaskDefinition`, `DeregisterTaskDefinition`, `ListTaskDefinitions` | Manage ECS task definitions |
| AllowECSServiceManagement | `ecs:UpdateService`, `DescribeServices`, `ListServices` | Deploy to ECS services |
| AllowECSTaskManagement | `ecs:DescribeTasks`, `ListTasks`, `RunTask`, `StopTask` | Run and monitor ECS tasks |
| AllowECSClusterRead | `ecs:DescribeClusters`, `ListClusters` | Read ECS cluster info |
| AllowPassRoleForECS | `iam:PassRole` (conditioned to `ecs-tasks.amazonaws.com`) | Pass execution/task roles to ECS |
| AllowCloudWatchLogsForECS | `logs:CreateLogGroup`, `CreateLogStream`, `PutLogEvents`, `DescribeLogGroups`, `DescribeLogStreams` | ECS container logging |

## Security Best Practices

### 1. Multi-Thumbprint OIDC
This project uses multiple thumbprints (`OIDC_THUMBPRINTS`) for the GitHub OIDC provider. This prevents your workflows from breaking when GitHub rotates its certificates.

### 2. Least Privilege
Edit `policies/permissions-policy.json` to grant only the specific permissions your workflow needs (e.g., only specific S3 buckets, ECR repositories, or ECS clusters/services).

### 3. Trust Policy Scoping
The `GITHUB_REPO` variable in `.env` controls how broadly the role can be assumed:

```bash
# All repos in the org
GITHUB_REPO="*"

# Single repo, all refs
GITHUB_REPO="my-app"

# Only specific branches from one repo
GITHUB_REPO="my-app:{dev,main}"

# Multiple repos, each with specific branches
GITHUB_REPO="my-app:{dev,main},backend:{staging,main}"
```

The generated trust policy `sub` condition patterns:

| `GITHUB_REPO` | Generated pattern |
|---------|--------|
| `"*"` | `repo:org/*` |
| `"my-app"` | `repo:org/my-app:*` |
| `"my-app:{dev,main}"` | `repo:org/my-app:ref:refs/heads/dev`, `repo:org/my-app:ref:refs/heads/main` |

## Cleanup

To remove all created resources from your AWS account:

```bash
./scripts/99-cleanup.sh
```
