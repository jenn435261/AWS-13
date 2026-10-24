// Serial-backed FrameSource/FrameSink for a Meshtastic radio over USB/UART.
//
// NEEDS REAL HARDWARE. This is the only file in the package that imports the
// serial driver; everything else (parse/reassemble/verify/store/rebroadcast)
// is pure Go and tested from a canned io.Reader. The framing here is a simple
// length-delimited stream: each LoRa fragment is written/read as
// [uint16 big-endian length][fragment bytes]. A real Meshtastic integration
// would instead speak the device's serial protobuf API; this stream framing is
// deliberately trivial and matches StreamSource so the two share one decoder.
package lora

import (
	"context"

	"go.bug.st/serial"
)

// OpenSerial opens the serial device at portName at the given baud rate and
// returns a FrameSource/FrameSink pair over it. The caller must Close the
// returned source to release the port.
//
// Typical Meshtastic USB serial runs at 115200 baud. Region/frequency is
// configured on the device itself (via the Meshtastic app/CLI), not here.
func OpenSerial(portName string, baud int) (FrameSource, FrameSink, error) {
	mode := &serial.Mode{BaudRate: baud}
	port, err := serial.Open(portName, mode)
	if err != nil {
		return nil, nil, err
	}
	src := NewStreamSource(port)
	sink := &serialSink{port: port}
	return &serialSource{StreamSource: src, port: port}, sink, nil
}

type serialSource struct {
	*StreamSource
	port serial.Port
}

func (s *serialSource) Close() error { return s.port.Close() }

type serialSink struct {
	port serial.Port
}

func (s *serialSink) Send(ctx context.Context, frame []byte) error {
	buf := make([]byte, 2+len(frame))
	buf[0] = byte(len(frame) >> 8)
	buf[1] = byte(len(frame))
	copy(buf[2:], frame)
	_, err := s.port.Write(buf)
	return err
}
