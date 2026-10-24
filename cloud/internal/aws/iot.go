package aws

import (
	"context"
	"fmt"

	awssdk "github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/iotdataplane"
)

// Publisher abstracts publishing a payload to a pub/sub topic (AWS IoT Core
// MQTT over the data plane). Used to fan out high-priority alerts to connected
// nodes. Kept behind an interface so the core never depends on AWS IoT.
type Publisher interface {
	Publish(ctx context.Context, topic string, payload []byte) error
}

// IoTPublisher publishes to AWS IoT Core via the data plane HTTP API. It is a
// real, minimal MQTT publish helper (no placeholders): it targets your IoT data
// endpoint and uses the SDK's Publish operation. Inert until invoked with valid
// credentials and endpoint.
type IoTPublisher struct {
	client *iotdataplane.Client
	// QoS is the MQTT quality of service (0 or 1). Default 0.
	QoS int32
}

var _ Publisher = (*IoTPublisher)(nil)

// NewIoTPublisher builds an IoTPublisher. endpoint is the account/region IoT
// data endpoint, e.g. "https://xxxx-ats.iot.us-east-1.amazonaws.com".
func NewIoTPublisher(ctx context.Context, endpoint string) (*IoTPublisher, error) {
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return nil, fmt.Errorf("load aws config: %w", err)
	}
	client := iotdataplane.NewFromConfig(cfg, func(o *iotdataplane.Options) {
		if endpoint != "" {
			o.BaseEndpoint = awssdk.String(endpoint)
		}
	})
	return &IoTPublisher{client: client}, nil
}

// Publish sends payload to the given MQTT topic.
func (p *IoTPublisher) Publish(ctx context.Context, topic string, payload []byte) error {
	if _, err := p.client.Publish(ctx, &iotdataplane.PublishInput{
		Topic:   awssdk.String(topic),
		Payload: payload,
		Qos:     p.QoS,
	}); err != nil {
		return fmt.Errorf("iot publish: %w", err)
	}
	return nil
}
