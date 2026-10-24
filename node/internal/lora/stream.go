package lora

import (
	"context"
	"encoding/binary"
	"io"
)

// StreamSource reads length-delimited LoRa fragments from any io.Reader:
// each record is [uint16 big-endian length][fragment bytes]. This is the seam
// that makes the gateway testable — a test feeds a bytes.Reader of canned
// fragments; production feeds a serial port. Returns io.EOF when the stream
// ends.
type StreamSource struct {
	r io.Reader
}

// NewStreamSource wraps r as a FrameSource.
func NewStreamSource(r io.Reader) *StreamSource { return &StreamSource{r: r} }

// Next reads the next length-delimited fragment. The context is honoured only
// between records (an in-flight blocking read is not cancellable here, which is
// acceptable for a canned test reader and a line-rate serial port).
func (s *StreamSource) Next(ctx context.Context) ([]byte, error) {
	if ctx != nil && ctx.Err() != nil {
		return nil, ctx.Err()
	}
	var lenBuf [2]byte
	if _, err := io.ReadFull(s.r, lenBuf[:]); err != nil {
		if err == io.ErrUnexpectedEOF {
			return nil, io.EOF
		}
		return nil, err
	}
	n := int(binary.BigEndian.Uint16(lenBuf[:]))
	if n == 0 {
		return []byte{}, nil
	}
	buf := make([]byte, n)
	if _, err := io.ReadFull(s.r, buf); err != nil {
		if err == io.ErrUnexpectedEOF {
			return nil, io.EOF
		}
		return nil, err
	}
	return buf, nil
}

// Close is a no-op for a plain reader source.
func (s *StreamSource) Close() error { return nil }

// EncodeStream writes frames to a buffer in the length-delimited stream format,
// handy for building canned test inputs.
func EncodeStream(frames [][]byte) []byte {
	var out []byte
	for _, f := range frames {
		var lenBuf [2]byte
		binary.BigEndian.PutUint16(lenBuf[:], uint16(len(f)))
		out = append(out, lenBuf[:]...)
		out = append(out, f...)
	}
	return out
}
