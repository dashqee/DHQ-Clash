# TURN video-call fallback

DHQ-Clash can run the pinned `whitelist-bypass` headless VK joiner as a local
SOCKS5 sidecar. When enabled for the active subscription, the client requests
the current call link from `/turn/link/{public_file}` and adds `DHQ TURN` as
the last member of the primary `Fallback` proxy group.

Supported application targets:

- Android
- macOS
- Windows
- Linux

The repository does not currently contain an iOS Flutter target. The pinned
upstream project has an iOS gomobile binding that can be connected to a future
NetworkExtension target.

The link is runtime-only and is never persisted in application settings. All
current targets use the same fixed local SOCKS port (`11789`) and data-channel
mode (`dc`). Android owns the sidecar in the remote service process so it can
survive Flutter activity and engine recreation.

## Build

Initialize both Go sources before building:

```bash
git submodule update --init --recursive
```

The existing platform build hooks build both `DHQClashCore` and
`DHQClashTurn`. No prebuilt TURN executable is committed.

## Manual smoke test

1. Keep the matching headless VK creator running on the RF bridge.
2. Ensure the active subscription is entitled and its backend TURN link is
   available.
3. In DHQ-Clash open **Tools → Emergency video-call tunnel** and enable it.
4. Start DHQ-Clash and wait for **Tunnel connected**. Complete the CAPTCHA if
   the application opens it.
5. Inspect the active configuration or proxy page:
   - `DHQ TURN` must be a SOCKS5 proxy on `127.0.0.1:11789`;
   - it must come from the `DHQ TURN provider` inline provider;
   - that provider must be last in `Fallback.use`, after the subscription
     providers (Mihomo places explicit `proxies` before `use` regardless of
     their visual YAML position);
   - the group must have an active URL health check.
6. Disable or block the direct VLESS providers and verify that the fallback
   switches to `DHQ TURN`.
7. Check the public address on a foreign and a Russian destination according
   to the RF bridge routing policy.
8. Turn the emergency tunnel off manually and verify that the creator logs a
   participant leave within 1–2 seconds and no `DHQClashTurn` process remains.

Also verify backend state transitions: `403` shows unavailable for the current
subscription, `503` shows temporary unavailability, and link rotation causes
the sidecar to restart without persisting or displaying the new invitation.
