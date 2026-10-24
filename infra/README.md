# Resilience Network — AWS CDK infra (us-east-1)

A minimal, reliably-deployable AWS CDK (TypeScript) app that provisions the
Resilience Network cloud. It is deliberately **serverless and VPC-free** on the
default path so it deploys cleanly under an AWS Workshop Studio participant role
and costs ~$0 at idle.

## What gets created

### `ResilienceCore` (default)
- **S3 bucket** — private, versioned, SSL-enforced, S3-managed encryption. Holds
  readiness packages / PMTiles / APK / trust bundles. Output: `AssetsBucketName`.
- **Go API Lambda** — the existing `cloud/` HTTP API (`internal/api` handler)
  packaged for the `provided.al2023` runtime on **arm64**, fronted by a public
  **Lambda Function URL** (HTTPS). Serves `POST /v1/events`, `/v1/events/pull`,
  `/v1/ai/{structure,translate,summarize,dedup}`, `/v1/org/needs`, `/healthz`.
  Output: `ApiUrl`, `ApiFunctionName`.
  - **Bedrock enabled**: the function has an IAM policy allowing
    `bedrock:InvokeModel` / `bedrock:InvokeModelWithResponseStream` on the
    inference-profile and backing US foundation-model ARNs, and the env
    `BEDROCK_MODEL_ID=us.anthropic.claude-sonnet-4-5-20250929-v1:0`. With this
    set, the AI endpoints call **real Bedrock**; without reachable Bedrock they
    fall back to the deterministic rules path (`degraded:true`).
  - **Store**: in-memory (zero external deps). No RDS on the critical path.

### `ResilienceData` (optional, off by default)
Gated behind `-c withData=true`. Scaffolds the data layer:
- **RDS PostgreSQL 16** (PostGIS extension available) in a no-NAT VPC, isolated
  subnets, credentials in Secrets Manager. Outputs: `DbEndpoint`, `DbPort`,
  `DbSecretArn`.
- **SQS** queue + dead-letter queue for async event processing. Output:
  `EventsQueueUrl`.

This stack is **not** synthesized or deployed unless you opt in; the core demo
never depends on it.

## Prerequisites
- Node 22 + npm.
- Go toolchain for the Lambda build: `source ../.toolchain/env.sh`.
- AWS credentials in the environment for deploy (participant role), region
  `us-east-1`. **Never hardcode credentials.**

## Build & validate (no credentials required)
```bash
# From repo root — cross-compile the Go Lambda bootstrap (linux/arm64).
source .toolchain/env.sh
make lambda-build            # -> cloud/build/lambda/bootstrap

# In infra/ — install, typecheck, synth the core stack.
cd infra
npm install
npx tsc --noEmit
CDK_DEFAULT_ACCOUNT=996565898042 CDK_DEFAULT_REGION=us-east-1 npx cdk synth
```

`cdk synth` needs no credentials (a dummy account/region env is enough). Both
stacks synthesize credential-free.

## Deploy (credentials required)
```bash
cd infra
./deploy.sh                  # core stack only (S3 + Bedrock API)
./deploy.sh --with-data      # also deploy RDS(PostGIS)+SQS
```
`deploy.sh` builds the Lambda, installs deps if needed, runs `cdk bootstrap`,
then `cdk deploy`, and writes outputs to `cdk-outputs.json`.

Verify:
```bash
curl "$ApiUrl/healthz"
```

## Destroy
```bash
cd infra
npx cdk destroy ResilienceCore
# or, if the data stack was deployed:
npx cdk destroy --all -c withData=true
```
The S3 bucket is set to auto-delete objects on destroy so teardown is clean.

## Cost note
The default (core) stack is fully serverless: S3 + a Lambda behind a Function
URL. There are **no always-on resources**, so it costs ~$0 at idle and only
incurs per-request Lambda/S3/Bedrock charges. The optional data stack adds an
RDS instance (hourly cost) and is why it is off by default.

## Layout
```
infra/
  bin/app.ts          CDK app entry (account from CDK_DEFAULT_ACCOUNT, region us-east-1)
  lib/core-stack.ts   S3 + Bedrock-enabled Go API Lambda (Function URL)
  lib/data-stack.ts   optional RDS(PostGIS)+SQS, gated by -c withData=true
  deploy.sh           one-command build + bootstrap + deploy
  package.json / tsconfig.json / cdk.json
cloud/cmd/lambda/main.go   Lambda entrypoint reusing internal/api handler
Makefile (repo root)       `make lambda-build`
```
