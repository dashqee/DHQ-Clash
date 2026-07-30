# TURN video-call fallback

DHQ-Clash can run the pinned `whitelist-bypass` headless VK joiner as a local
SOCKS5 sidecar. When enabled, the generated mihomo configuration adds
`DHQ TURN` as the last member of every `fallback` proxy group.

Supported application targets:

- Android
- macOS
- Windows
- Linux

The repository does not currently contain an iOS Flutter target. The pinned
upstream project has an iOS gomobile binding that can be connected to a future
NetworkExtension target.

## Build

Initialize both Go sources before building:

```bash
git submodule update --init --recursive
```

The existing platform build hooks build both `DHQClashCore` and
`DHQClashTurn`. No prebuilt TURN executable is committed.

## Manual smoke test

1. Keep the matching headless VK creator running on the RF bridge.
2. Copy its current `https://vk.ru/call/join/...` invitation.
3. In DHQ-Clash open **Tools → Emergency video-call tunnel**.
4. Enable the feature, paste the invitation, select the same transport as the
   creator (`Data channel` by default), and save.
5. Start DHQ-Clash and wait for the status **Tunnel connected**.
6. Inspect the active configuration or proxy page:
   - `DHQ TURN` must be a SOCKS5 proxy on `127.0.0.1:11789`;
   - it must be last in the subscription's fallback group.
7. Disable or block the direct VLESS providers and verify that the fallback
   switches to `DHQ TURN`.
8. Check the public address on a foreign and a Russian destination according
   to the RF bridge routing policy.

The join invitation is call-scoped. If the creator rotates the call, paste the
new invitation and save again. Automated entitlement and join-link rotation
belong to the subscription backend and are intentionally not hard-coded into
the client.
