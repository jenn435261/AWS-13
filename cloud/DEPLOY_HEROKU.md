# Deploy the Resilience API to Heroku

The Go API is a normal long-running HTTP server (`cmd/api`) that reads `$PORT`
(Heroku injects it) and calls Amazon Bedrock using AWS credentials supplied as
Heroku **config vars**. Nothing secret is ever committed.

## Prerequisites
- Heroku CLI installed and `heroku login` done locally (interactive — never
  paste a full-account API key into chat; rotate any key that was exposed).
- AWS credentials with `bedrock:InvokeModel` permission. For the hackathon the
  event STS creds work (they expire at event end); for anything longer-lived,
  create a Bedrock-only IAM user.

## One-time setup
```bash
cd cloud
heroku create resilience-api-<you>            # or use an existing app name
heroku stack:set container -a resilience-api-<you>
```

## Set config vars (NEVER commit these)
```bash
heroku config:set -a resilience-api-<you> \
  AWS_REGION=us-east-1 \
  AWS_ACCESS_KEY_ID=... \
  AWS_SECRET_ACCESS_KEY=... \
  AWS_SESSION_TOKEN=... \
  BEDROCK_MODEL_ID=us.anthropic.claude-sonnet-4-5-20250929-v1:0 \
  ORG_API_TOKENS=<random>   CLIENT_API_KEYS=<random>      # gates /v1/events*, /v1/ai/* via X-Api-Key
```
(Omit `AWS_SESSION_TOKEN` if you use a long-lived IAM user instead of STS.)

## Web app
The Dockerfile also serves the Flutter web bundle from `cloud/web` (`WEB_DIR=/web`).
`../scripts/deploy-heroku.ps1` builds it (`flutter build web --release`), stages it
into `cloud/web` on a throwaway branch (it is git-ignored), and pushes the `cloud/`
subtree to Heroku (`git subtree`; no local Docker needed).

## Deploy (container build on Heroku)
Because `cloud/` is a subdirectory of the monorepo, deploy it with the Heroku
container registry (simplest, no monorepo buildpack gymnastics):
```bash
cd cloud
heroku container:login
heroku container:push web -a resilience-api-<you>
heroku container:release web -a resilience-api-<you>
heroku open -a resilience-api-<you>            # hits /healthz
```

## Verify live Bedrock through the deployed API
```bash
APP=https://resilience-api-<you>.herokuapp.com
curl -s $APP/healthz
curl -s -X POST $APP/v1/ai/structure -H 'Content-Type: application/json' \
  -d '{"text":"gas leak near the shelter, people need to evacuate now","lang_hint":"en"}'
# Expect: {"category":"SHELTER","priority":"high",...,"degraded":false}
```
`degraded:false` confirms the deployed backend is making real Bedrock calls.

## Point the app at it
Set the Flutter app's `cloudBaseUrlProvider` to `$APP` (via a build define or
the Settings screen) and the app's AI + sync will use the hosted backend. With
an empty URL the app stays fully offline (AI falls back to local rules) — the
offline-first guarantee is intact either way.
