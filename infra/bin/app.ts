#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
import { CoreStack } from '../lib/core-stack';
import { DataStack } from '../lib/data-stack';

const app = new cdk.App();

// Region is pinned to us-east-1 (the only region the hackathon participant
// role can use). Account comes from CDK_DEFAULT_ACCOUNT at synth/deploy time;
// it falls back to the known hackathon account id for credential-free synth.
const env: cdk.Environment = {
  account: process.env.CDK_DEFAULT_ACCOUNT ?? '996565898042',
  region: 'us-east-1',
};

new CoreStack(app, 'ResilienceCore', {
  env,
  description:
    'Resilience Network core: S3 bucket + Bedrock-enabled Go API Lambda (Function URL).',
});

// The data stack (RDS/PostGIS + SQS) is OPTIONAL and off by default. It is only
// synthesized/deployed when `-c withData=true` is passed. This keeps the
// default deploy lean (serverless, ~$0 at idle) and participant-role friendly.
const withData =
  app.node.tryGetContext('withData') === true ||
  app.node.tryGetContext('withData') === 'true';

if (withData) {
  new DataStack(app, 'ResilienceData', {
    env,
    description:
      'Resilience Network optional data layer: RDS PostgreSQL (PostGIS) + SQS. Gated by -c withData=true.',
  });
}

app.synth();
