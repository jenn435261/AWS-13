package aws

import (
	"context"
	"fmt"

	awssdk "github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"

	"github.com/resilience-network/aws13/cloud/internal/queue"
)

// SQSQueue is a queue.Queue backed by Amazon SQS. It long-polls for messages
// and deletes them by receipt handle after processing. It is inert until a
// method is called with valid AWS credentials and a real queue URL.
type SQSQueue struct {
	client   *sqs.Client
	queueURL string
	// MaxMessages is the batch size per Receive (1..10). Zero means 10.
	MaxMessages int32
	// WaitTimeSeconds is the long-poll wait (0..20). Zero means 20.
	WaitTimeSeconds int32
}

var _ queue.Queue = (*SQSQueue)(nil)

// NewSQSQueue builds an SQSQueue using the default AWS credential chain.
func NewSQSQueue(ctx context.Context, queueURL string) (*SQSQueue, error) {
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return nil, fmt.Errorf("load aws config: %w", err)
	}
	return &SQSQueue{client: sqs.NewFromConfig(cfg), queueURL: queueURL}, nil
}

// Receive long-polls SQS and returns the decoded messages.
func (q *SQSQueue) Receive(ctx context.Context) ([]queue.Message, error) {
	maxMsgs := q.MaxMessages
	if maxMsgs <= 0 || maxMsgs > 10 {
		maxMsgs = 10
	}
	wait := q.WaitTimeSeconds
	if wait < 0 || wait > 20 {
		wait = 20
	}

	out, err := q.client.ReceiveMessage(ctx, &sqs.ReceiveMessageInput{
		QueueUrl:            awssdk.String(q.queueURL),
		MaxNumberOfMessages: maxMsgs,
		WaitTimeSeconds:     wait,
	})
	if err != nil {
		return nil, fmt.Errorf("sqs receive: %w", err)
	}

	msgs := make([]queue.Message, 0, len(out.Messages))
	for _, m := range out.Messages {
		var body []byte
		if m.Body != nil {
			body = []byte(*m.Body)
		}
		handle := ""
		if m.ReceiptHandle != nil {
			handle = *m.ReceiptHandle
		}
		msgs = append(msgs, queue.Message{Body: body, Handle: handle})
	}
	return msgs, nil
}

// Delete removes the messages by receipt handle.
func (q *SQSQueue) Delete(ctx context.Context, handles ...string) error {
	for _, h := range handles {
		handle := h
		if _, err := q.client.DeleteMessage(ctx, &sqs.DeleteMessageInput{
			QueueUrl:      awssdk.String(q.queueURL),
			ReceiptHandle: awssdk.String(handle),
		}); err != nil {
			return fmt.Errorf("sqs delete: %w", err)
		}
	}
	return nil
}
