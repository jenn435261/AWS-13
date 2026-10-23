import * as path from 'path';
import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as logs from 'aws-cdk-lib/aws-logs';

/**
 * Bedrock inference-profile model id used by the Go API's AI endpoints.
 *
 * NOTE: raw foundation-model ids (e.g. anthropic.claude-sonnet-4-5-...) fail
 * with "on-demand throughput isn't supported" in this account. The us.* cross
 * region inference profile MUST be used for real inference.
 */
const BEDROCK_MODEL_ID = 'us.anthropic.claude-sonnet-4-5-20250929-v1:0';

/**
 * Directory holding the cross-compiled Go Lambda `bootstrap` binary.
 * Produced by `make lambda-build` (GOOS=linux GOARCH=arm64 -> provided.al2023).
 * Relative to this file: infra/lib -> repo root -> cloud/build/lambda.
 */
const LAMBDA_ASSET_DIR = path.join(__dirname, '..', '..', 'cloud', 'build', 'lambda');

/**
 * CoreStack provisions the minimal, reliably-deployable Resilience Network
 * cloud: a private versioned S3 bucket and the existing Go API packaged as a
 * Bedrock-enabled Lambda fronted by a public Function URL. No VPC/NAT, so it is
 * participant-role friendly and ~$0 at idle.
 */
export class CoreStack extends cdk.Stack {
  public readonly bucket: s3.Bucket;
  public readonly apiFunction: lambda.Function;
  public readonly functionUrl: lambda.FunctionUrl;

  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // ---- S3: readiness packages / PMTiles / APK / trust bundles ----------
    this.bucket = new s3.Bucket(this, 'AssetsBucket', {
      versioned: true,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      encryption: s3.BucketEncryption.S3_MANAGED,
      enforceSSL: true,
      // Demo bucket: allow teardown with `cdk destroy` without manual emptying.
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
    });

    // ---- Go API Lambda (provided.al2023, arm64) --------------------------
    this.apiFunction = new lambda.Function(this, 'ApiFunction', {
      runtime: lambda.Runtime.PROVIDED_AL2023,
      architecture: lambda.Architecture.ARM_64,
      handler: 'bootstrap',
      code: lambda.Code.fromAsset(LAMBDA_ASSET_DIR),
      memorySize: 512,
      timeout: cdk.Duration.seconds(30),
      logRetention: logs.RetentionDays.ONE_WEEK,
      environment: {
        // Enables the online Bedrock AI path in internal/ai. Without this the
        // API still works via deterministic rules (degraded:true).
        BEDROCK_MODEL_ID,
        // The in-memory store is used when RESILIENCE_PG_DSN is unset, so no
        // RDS is required on the critical path.
      },
    });

    // Grant the function read/write to the assets bucket.
    this.bucket.grantReadWrite(this.apiFunction);

    // ---- Bedrock IAM: allow real inference via the us.* profile ----------
    // The inference profile routes to foundation models across us-* regions,
    // so the policy must cover both the inference-profile ARN and the backing
    // foundation-model ARNs in the US regions.
    this.apiFunction.addToRolePolicy(
      new iam.PolicyStatement({
        sid: 'BedrockInvoke',
        effect: iam.Effect.ALLOW,
        actions: ['bedrock:InvokeModel', 'bedrock:InvokeModelWithResponseStream'],
        resources: [
          // Cross-region inference profile (what BEDROCK_MODEL_ID points at).
          `arn:aws:bedrock:${this.region}:${this.account}:inference-profile/${BEDROCK_MODEL_ID}`,
          // Backing foundation models the profile can route to (us-east-1,
          // us-west-2, us-east-2 are the US profile members).
          'arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-sonnet-4-5-20250929-v1:0',
          'arn:aws:bedrock:us-west-2::foundation-model/anthropic.claude-sonnet-4-5-20250929-v1:0',
          'arn:aws:bedrock:us-east-2::foundation-model/anthropic.claude-sonnet-4-5-20250929-v1:0',
        ],
      })
    );

    // ---- Public Function URL (simplest HTTPS front door) -----------------
    this.functionUrl = this.apiFunction.addFunctionUrl({
      authType: lambda.FunctionUrlAuthType.NONE,
      cors: {
        allowedOrigins: ['*'],
        allowedMethods: [lambda.HttpMethod.ALL],
        allowedHeaders: ['*'],
      },
    });

    // ---- Outputs ---------------------------------------------------------
    new cdk.CfnOutput(this, 'ApiUrl', {
      value: this.functionUrl.url,
      description: 'HTTPS base URL for the Resilience Network cloud API.',
    });
    new cdk.CfnOutput(this, 'ApiFunctionName', {
      value: this.apiFunction.functionName,
      description: 'Name of the Go API Lambda function.',
    });
    new cdk.CfnOutput(this, 'AssetsBucketName', {
      value: this.bucket.bucketName,
      description: 'S3 bucket for readiness packages / PMTiles / APK / trust bundles.',
    });
    new cdk.CfnOutput(this, 'BedrockModelId', {
      value: BEDROCK_MODEL_ID,
      description: 'Bedrock inference-profile model id used by the AI endpoints.',
    });
  }
}
