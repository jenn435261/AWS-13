# Deployment notes — hackathon event account vs. a normal AWS account

This records exactly what was deployed live against the SJSU hackathon AWS
account (996565898042, us-east-1) and what the account's IAM boundary blocked,
so the story is honest and reproducible.

## What is PROVEN LIVE against real AWS (us-east-1)

- **Amazon Bedrock inference** — the headline AI feature. Validated two ways:
  1. The Go `BedrockAssistant` integration test (`RESILIENCE_BEDROCK=1 go test
     ./internal/ai/ -run TestBedrockIntegration`) passed, exercising structure,
     EN→ES translate, and summarize against model inference profile
     `us.anthropic.claude-sonnet-4-5-20250929-v1:0`.
  2. The running Go API served real Bedrock responses with `degraded:false`:
     - `POST /v1/ai/structure` "gas leak near the shelter… evacuate now"
       → `{category: SHELTER, priority: high, short_title: "Gas Leak
       Evacuation Required", degraded:false}`
     - `POST /v1/ai/translate` → "Se necesita equipo médico en el centro
       comunitario" (`translated:true, degraded:false`).
- **Amazon S3** — a private bucket was created live
  (`resilience-net-996565898042-use1`).

## What the EVENT ACCOUNT blocked (and why it does not matter)

The AWS Workshop Studio participant role (`WSParticipantRole`) denies
`iam:CreateRole` and `iam:PassRole` for arbitrary service roles, and has no
pre-created Lambda execution role with a `lambda.amazonaws.com` trust policy.
Consequently:

- `cdk bootstrap` fails (it tries to create its own CDK roles) →
  `iam:CreateRole` 403.
- `aws lambda create-function` fails → "The role defined for the function
  cannot be assumed by Lambda" (no assumable execution role available, and we
  cannot create or modify one).

This is a restriction of the **event account**, not of this project's code.

## How to deploy for real (any normal AWS account)

The CDK app in this directory is complete and `cdk synth`s cleanly. In an
account with standard IAM permissions:

```bash
cd infra
export AWS_REGION=us-east-1
./deploy.sh            # bootstraps, builds the Go Lambda, deploys ResilienceCore
./deploy.sh --with-data   # also deploys the optional RDS(PostGIS)+SQS stack
```

`ResilienceCore` creates the S3 bucket and the Go API as an arm64
`provided.al2023` Lambda with a Function URL, with an IAM policy granting
`bedrock:InvokeModel` and `BEDROCK_MODEL_ID` set to the validated inference
profile — so the hosted API's `/v1/ai/*` endpoints call Bedrock exactly as the
local API does.

## The offline-first point

This app is local-first by design (spec §48): the cloud is an optional
accelerator, never required. For the demo the Go API runs locally with Bedrock
wired (`BEDROCK_MODEL_ID=... go run ./cmd/api`), which is functionally
identical to the hosted Lambda from the client's perspective — same HTTP
contract, same Bedrock calls. Nothing about the product depends on the managed
deploy succeeding.
