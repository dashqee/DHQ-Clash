//go:build !cgo

package main

import "github.com/metacubex/mihomo/listener"

// tunListenerUp reports whether the desktop TUN listener is actually up.
// ReCreateTun clears Enable on the stored config when sing_tun.New fails, so
// GetTunConf().Enable is the fact, not the wish.
func tunListenerUp() bool {
	return listener.GetTunConf().Enable
}
