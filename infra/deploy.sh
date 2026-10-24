#!/usr/bin/env bash
#
# One-command deploy for the Resilience Network cloud (us-east-1).
#
# Prereqs:
#   - AWS credentials in the environment (AWS_ACCESS_KEY_ID / _SECRET_ACCESS_KEY
#     / _SESSION_TOKEN) for the hackathon participant role.
#   - Node 22 + npm; Go (source ../.toolchain/env.sh) for the Lambda build.
#
# What it does:
#   1. Builds the Go API Lambda bootstrap binary (make lambda-build).
#   2. Installs infra npm deps if needed.
#   3. Bootstraps the CDK environment (idempotent).
#   4. Deploys the core stack (S3 + Bedrock-enabled Go API Lambda Function URL).
#      Pass --with-data to also deploy the optional RDS(PostGIS)+SQS data stack.
#   5. Prints stack outputs (API URL, bucket name, etc.).
#
# Usage:
#   ./deploy.sh                 # core stack only (default, serverless, ~$0 idle)
#   ./deploy.sh --with-data     # core + optional data stack
set -euo pipefail

INFRA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${INFRA_DIR}/.." && pwd)"

export AWS_REGION="${AWS_REGION:-us-east-1}"
export CDK_DEFAULT_REGION="${AWS_REGION}"
export CDK_DEFAULT_ACCOUNT="${CDK_DEFAULT_ACCOUNT:-996565898042}"

WITH_DATA=0
CDK_CTX=()
STACKS=("ResilienceCore")
if [[ "${1:-}" == "--with-data" ]]; then
  WITH_DATA=1
  CDK_CTX=(-c withData=true)
  STACKS=("ResilienceCore" "ResilienceData")
fi

echo "==> Region: ${AWS_REGION}  Account: ${CDK_DEFAULT_ACCOUNT}  with-data: ${WITH_DATA}"

# 1. Build the Go Lambda bootstrap (provided.al2023, arm64).
echo "==> Building Go API Lambda (make lambda-build)"
if [[ -f "${REPO_ROOT}/.toolchain/env.sh" ]]; then
  # shellcheck disable=SC1091
  source "${REPO_ROOT}/.toolchain/env.sh"
fi
make -C "${REPO_ROOT}" lambda-build

# 2. Install infra deps if node_modules is missing.
cd "${INFRA_DIR}"
if [[ ! -d node_modules ]]; then
  echo "==> npm install"
  npm install
fi

# 3. Bootstrap the CDK environment (safe to re-run).
echo "==> cdk bootstrap"
npx cdk bootstrap "aws://${CDK_DEFAULT_ACCOUNT}/${AWS_REGION}"

# 4. Deploy.
echo "==> cdk deploy ${STACKS[*]}"
npx cdk deploy "${STACKS[@]}" "${CDK_CTX[@]}" --require-approval never --outputs-file cdk-outputs.json

# 5. Print outputs.
echo "==> Stack outputs (cdk-outputs.json):"
cat cdk-outputs.json
echo
echo "Done. Hit the ApiUrl output + /healthz to verify."
