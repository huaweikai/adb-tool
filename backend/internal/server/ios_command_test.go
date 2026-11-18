package server

import (
	"bufio"
	"bytes"
	"context"
	"os/exec"
	"strings"
	"testing"
)

type daemonTestInput struct{ bytes.Buffer }

func (*daemonTestInput) Close() error { return nil }

func TestIOSDaemonResponseIDs(t *testing.T) {
	for _, tt := range []struct {
		name, response string
		wantErr        bool
	}{
		{"matching", `{"id":1,"ok":true,"output":"hello"}` + "\n", false},
		{"mismatched", `{"id":2,"ok":true,"output":"wrong request"}` + "\n", true},
	} {
		t.Run(tt.name, func(t *testing.T) {
			daemon := &iosDaemon{
				cmd:    &exec.Cmd{},
				stdin:  &daemonTestInput{},
				reader: bufio.NewReader(strings.NewReader(tt.response)),
			}
			out, err := daemon.Call(context.Background(), "usbmux", "list")
			if (err != nil) != tt.wantErr {
				t.Fatalf("Call = %q, %v", out, err)
			}
			if !tt.wantErr && string(out) != "hello" {
				t.Fatalf("output = %q", out)
			}
			if tt.wantErr && daemon.cmd != nil {
				t.Fatal("invalid response did not reset daemon")
			}
		})
	}
}
