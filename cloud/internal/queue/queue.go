// Package queue defines the message queue abstraction used by the worker
// service to consume events for re-verification and materialization. Keeping
// this in its own package lets both the local MemQueue and the AWS SQSQueue
// implement it without the worker importing the api service internals, so the
// processes stay decoupled (microservice isolation).
package queue

import "context"

// Message is a single queued payload plus the opaque handle needed to delete it
// after successful processing.
type Message struct {
	// Body is the raw payload (a serialized SignedEvent, typically).
	Body []byte
	// Handle is the queue-specific receipt handle used to Delete the message.
	Handle string
}

// Queue is a minimal receive/delete message queue. Implementations must be safe
// for a single consumer loop.
type Queue interface {
	// Receive returns zero or more messages, blocking up to the
	// implementation's poll timeout. An empty slice with a nil error means no
	// messages were available this cycle.
	Receive(ctx context.Context) ([]Message, error)
	// Delete acknowledges messages by their handles so they are not redelivered.
	Delete(ctx context.Context, handles ...string) error
}
