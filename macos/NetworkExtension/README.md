# Experimental macOS TUN backend

This target is the first no-root replacement for the legacy setuid
`DHQClashCore` path. It installs an `NETransparentProxyProvider` system
extension and relays claimed TCP flows to the local mihomo SOCKS/mixed port.

## Beta limitations

- TCP is proxied.
- UDP, including QUIC, is left on the direct path. The provider returns
  `false` for UDP instead of claiming and dropping it.
- The core process is excluded by its signing identifier to prevent an
  outbound proxy loop.
- If the embedded extension is unavailable or activation fails, the app falls
  back to the existing setuid authorization flow.

## Signing requirements

The host app and system extension must be signed by the same Apple Developer
team. Both need provisioning profiles that authorize the Network Extension
entitlement; the host also needs the System Extension install entitlement.
Ad-hoc signing is sufficient for compile-only checks, but macOS will not
activate this provider from an ad-hoc signed beta.

Before producing a test release, configure the release runner with:

1. a Developer ID Application certificate and private key;
2. the Apple Team ID;
3. Developer ID provisioning profiles for `app.dhqclash` and
   `app.dhqclash.network-extension`;
4. the `app-proxy-provider-systemextension` capability approved for both
   identifiers.

The first launch normally requires a local administrator to approve the system
extension and the tester to approve the new network configuration in macOS
System Settings. Administrator access is not required for subsequent proxy
starts. On managed Macs, an MDM System Extensions payload can preapprove the
team and bundle identifiers so a standard user can activate it without local
administrator authorization.
