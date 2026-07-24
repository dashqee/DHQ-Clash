import Network
import NetworkExtension

final class TransparentProxyProvider: NETransparentProxyProvider {
    private var socksPort: Network.NWEndpoint.Port?
    private var relays: [ObjectIdentifier: Socks5TCPRelay] = [:]
    private let relayQueue = DispatchQueue(label: "app.dhqclash.network-extension.relays")

    override func startProxy(
        options: [String: Any]? = nil,
        completionHandler: @escaping (Error?) -> Void
    ) {
        guard
            let configuration = protocolConfiguration
                as? NETunnelProviderProtocol,
            let rawPort = configuration.providerConfiguration?["socksPort"] as? Int,
            let port = Network.NWEndpoint.Port(rawValue: UInt16(rawPort))
        else {
            completionHandler(
                NSError(
                    domain: "app.dhqclash.network-extension",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Missing local SOCKS port"]
                )
            )
            return
        }

        socksPort = port

        let settings = NETransparentProxyNetworkSettings(
            tunnelRemoteAddress: "127.0.0.1"
        )
        settings.includedNetworkRules = [
            NENetworkRule(
                destinationNetwork: NWHostEndpoint(hostname: "0.0.0.0", port: "0"),
                prefix: 0,
                protocol: .TCP
            ),
            NENetworkRule(
                destinationNetwork: NWHostEndpoint(hostname: "::", port: "0"),
                prefix: 0,
                protocol: .TCP
            ),
        ]
        settings.excludedNetworkRules = [
            NENetworkRule(
                destinationNetwork: NWHostEndpoint(hostname: "127.0.0.0", port: "0"),
                prefix: 8,
                protocol: .any
            ),
            NENetworkRule(
                destinationNetwork: NWHostEndpoint(hostname: "::1", port: "0"),
                prefix: 128,
                protocol: .any
            ),
        ]

        setTunnelNetworkSettings(settings, completionHandler: completionHandler)
    }

    override func stopProxy(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        relayQueue.sync {
            relays.values.forEach { $0.cancel() }
            relays.removeAll()
        }
        completionHandler()
    }

    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        if shouldBypass(flow) {
            return false
        }

        guard
            let tcpFlow = flow as? NEAppProxyTCPFlow,
            let socksPort,
            let destination = destination(for: tcpFlow)
        else {
            // NETransparentProxyProvider lets unclaimed flows continue normally.
            // UDP stays outside this beta backend until SOCKS UDP support lands.
            return false
        }

        let identifier = ObjectIdentifier(tcpFlow)
        let relay = Socks5TCPRelay(
            flow: tcpFlow,
            destination: destination,
            socksPort: socksPort
        ) { [weak self] in
            self?.relayQueue.async {
                self?.relays.removeValue(forKey: identifier)
            }
        }
        relayQueue.sync {
            relays[identifier] = relay
        }
        relay.start()
        return true
    }

    private func shouldBypass(_ flow: NEAppProxyFlow) -> Bool {
        let signingIdentifier = flow.metaData.sourceAppSigningIdentifier

        // The core opens the real outbound connection after receiving a
        // request through the local SOCKS proxy. Intercepting that connection
        // again would create a proxy loop.
        return signingIdentifier == "app.dhqclash.core"
            || signingIdentifier.hasPrefix("DHQClashCore-")
    }

    private func destination(for flow: NEAppProxyTCPFlow) -> SocksDestination? {
        if #available(macOS 15.0, *) {
            guard case let .hostPort(host, port) = flow.remoteFlowEndpoint else {
                return nil
            }
            switch host {
            case .ipv4(let address):
                return SocksDestination(
                    host: address.debugDescription,
                    port: port.rawValue
                )
            case .ipv6(let address):
                return SocksDestination(
                    host: address.debugDescription,
                    port: port.rawValue
                )
            case .name(let name, _):
                return SocksDestination(host: name, port: port.rawValue)
            @unknown default:
                return nil
            }
        }

        guard let endpoint = flow.remoteEndpoint as? NWHostEndpoint else {
            return nil
        }
        guard let port = UInt16(endpoint.port) else {
            return nil
        }
        return SocksDestination(host: endpoint.hostname, port: port)
    }
}
