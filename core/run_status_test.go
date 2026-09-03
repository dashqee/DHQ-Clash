//go:build !cgo

package main

import (
	"testing"

	LC "github.com/metacubex/mihomo/listener/config"
	"github.com/metacubex/mihomo/listener"
)

func TestRunStatusReportsNothingBeforeStart(t *testing.T) {
	isRunning = false
	listener.LastTunConf = LC.Tun{}
	status := handleGetRunStatus()
	if status.Running || status.Tun {
		t.Fatalf("expected idle status, got %+v", status)
	}
}

func TestRunStatusDoesNotTrustTheWish(t *testing.T) {
	// Running says the listeners were asked for; a TUN that failed to come up
	// leaves LastTunConf.Enable false, and that is what must be reported.
	isRunning = true
	defer func() { isRunning = false }()
	listener.LastTunConf = LC.Tun{Enable: false}
	status := handleGetRunStatus()
	if !status.Running {
		t.Fatalf("expected running, got %+v", status)
	}
	if status.Tun {
		t.Fatalf("expected tun down, got %+v", status)
	}
}
