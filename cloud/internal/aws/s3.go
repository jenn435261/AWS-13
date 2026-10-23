// Package aws contains thin, optional AWS-native adapters (S3, SQS, IoT Core).
// All adapters sit behind small interfaces so the core API and worker services
// never depend on AWS for local runs. They use aws-sdk-go-v2 and are gated so
// nothing executes without real credentials / endpoints.
package aws

import (
	"context"
	"fmt"
	"io"
	"time"

	awssdk "github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

// ObjectStore abstracts the readiness-package object storage (S3). Both the
// presign and get operations are useful for serving large readiness bundles
// out of band of the event stream.
type ObjectStore interface {
	// PresignGet returns a time-limited GET URL for key in the configured
	// bucket.
	PresignGet(ctx context.Context, key string, expires time.Duration) (string, error)
	// Get fetches the raw object bytes for key.
	Get(ctx context.Context, key string) ([]byte, error)
}

// S3Store is an ObjectStore backed by Amazon S3.
type S3Store struct {
	client *s3.Client
	bucket string
}

var _ ObjectStore = (*S3Store)(nil)

// NewS3Store builds an S3Store using the default AWS credential chain. It does
// not perform any network call; adapters are inert until a method is invoked
// with valid credentials.
func NewS3Store(ctx context.Context, bucket string) (*S3Store, error) {
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return nil, fmt.Errorf("load aws config: %w", err)
	}
	return &S3Store{client: s3.NewFromConfig(cfg), bucket: bucket}, nil
}

// PresignGet returns a presigned GET URL valid for expires.
func (s *S3Store) PresignGet(ctx context.Context, key string, expires time.Duration) (string, error) {
	ps := s3.NewPresignClient(s.client)
	out, err := ps.PresignGetObject(ctx, &s3.GetObjectInput{
		Bucket: awssdk.String(s.bucket),
		Key:    awssdk.String(key),
	}, s3.WithPresignExpires(expires))
	if err != nil {
		return "", fmt.Errorf("presign get: %w", err)
	}
	return out.URL, nil
}

// Get fetches the object bytes for key.
func (s *S3Store) Get(ctx context.Context, key string) ([]byte, error) {
	out, err := s.client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: awssdk.String(s.bucket),
		Key:    awssdk.String(key),
	})
	if err != nil {
		return nil, fmt.Errorf("get object: %w", err)
	}
	defer out.Body.Close()
	data, err := io.ReadAll(out.Body)
	if err != nil {
		return nil, fmt.Errorf("read object body: %w", err)
	}
	return data, nil
}
