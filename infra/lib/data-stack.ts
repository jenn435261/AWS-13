import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as rds from 'aws-cdk-lib/aws-rds';
import * as sqs from 'aws-cdk-lib/aws-sqs';

/**
 * DataStack is the OPTIONAL data layer: an RDS PostgreSQL instance (with the
 * PostGIS extension available) plus an SQS queue for async event processing.
 *
 * It is NOT deployed by default — the app entry only instantiates it when
 * `-c withData=true` is passed. RDS creation requires a VPC and can be slow or
 * restricted for participant roles, so the core demo path (S3 + Bedrock API)
 * never depends on this stack. The Go API picks up Postgres only when the
 * RESILIENCE_PG_DSN env var is wired to this instance.
 */
export class DataStack extends cdk.Stack {
  public readonly vpc: ec2.Vpc;
  public readonly database: rds.DatabaseInstance;
  public readonly queue: sqs.Queue;

  // Pin AZs to two concrete us-east-1 zones. This avoids an availability-zone
  // context lookup (which needs live credentials) so the stack synthesizes
  // credential-free, matching the core stack. us-east-1a/1b always exist.
  public get availabilityZones(): string[] {
    return ['us-east-1a', 'us-east-1b'];
  }

  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Minimal VPC with no NAT gateways (keep cost/complexity low). RDS lives in
    // isolated subnets; the API Lambda would need VPC wiring to reach it, which
    // is intentionally out of the default (serverless) path.
    this.vpc = new ec2.Vpc(this, 'DataVpc', {
      maxAzs: 2,
      natGateways: 0,
      subnetConfiguration: [
        {
          name: 'public',
          subnetType: ec2.SubnetType.PUBLIC,
          cidrMask: 24,
        },
        {
          name: 'isolated',
          subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
          cidrMask: 24,
        },
      ],
    });

    // RDS PostgreSQL. PostGIS is available as an extension on RDS Postgres and
    // can be enabled with `CREATE EXTENSION postgis;` after connect; the store
    // migrations handle schema setup.
    this.database = new rds.DatabaseInstance(this, 'PostgresPostGIS', {
      engine: rds.DatabaseInstanceEngine.postgres({
        version: rds.PostgresEngineVersion.VER_16,
      }),
      instanceType: ec2.InstanceType.of(
        ec2.InstanceClass.BURSTABLE3,
        ec2.InstanceSize.MICRO
      ),
      vpc: this.vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      allocatedStorage: 20,
      maxAllocatedStorage: 50,
      multiAz: false,
      databaseName: 'resilience',
      // Credentials are generated and stored in Secrets Manager.
      credentials: rds.Credentials.fromGeneratedSecret('resilience'),
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      deleteAutomatedBackups: true,
      backupRetention: cdk.Duration.days(1),
    });

    // SQS queue for async event / readiness-package processing, with a DLQ.
    const dlq = new sqs.Queue(this, 'EventsDLQ', {
      retentionPeriod: cdk.Duration.days(14),
      enforceSSL: true,
    });
    this.queue = new sqs.Queue(this, 'EventsQueue', {
      visibilityTimeout: cdk.Duration.seconds(60),
      retentionPeriod: cdk.Duration.days(4),
      enforceSSL: true,
      deadLetterQueue: {
        queue: dlq,
        maxReceiveCount: 5,
      },
    });

    // ---- Outputs ---------------------------------------------------------
    new cdk.CfnOutput(this, 'DbEndpoint', {
      value: this.database.dbInstanceEndpointAddress,
      description: 'RDS PostgreSQL endpoint hostname.',
    });
    new cdk.CfnOutput(this, 'DbPort', {
      value: this.database.dbInstanceEndpointPort,
      description: 'RDS PostgreSQL port.',
    });
    new cdk.CfnOutput(this, 'DbSecretArn', {
      value: this.database.secret?.secretArn ?? 'none',
      description: 'Secrets Manager ARN holding the RDS credentials.',
    });
    new cdk.CfnOutput(this, 'EventsQueueUrl', {
      value: this.queue.queueUrl,
      description: 'SQS queue URL for async event processing.',
    });
  }
}
