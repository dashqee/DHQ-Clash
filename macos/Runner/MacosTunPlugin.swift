import FlutterMacOS
import NetworkExtension
import SystemExtensions

private let providerBundleIdentifier = "app.dhqclash.network-extension"

final class MacosTunPlugin: NSObject {
    private let channel: FlutterMethodChannel
    private var activationResult: FlutterResult?

    init(binaryMessenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "app.dhqclash/macos_tun",
            binaryMessenger: binaryMessenger
        )
        super.init()
        channel.setMethodCallHandler(handle)
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            result(isProviderEmbedded)
        case "prepare":
            prepare(result: result)
        case "start":
            guard
                let arguments = call.arguments as? [String: Any],
                let port = arguments["port"] as? Int,
                (1...65535).contains(port)
            else {
                result(
                    FlutterError(
                        code: "bad_args",
                        message: "A valid mixed proxy port is required",
                        details: nil
                    )
                )
                return
            }
            start(port: port, result: result)
        case "stop":
            stop(result: result)
        case "status":
            loadManager { manager in
                result(self.statusName(manager?.connection.status))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private var isProviderEmbedded: Bool {
        guard #available(macOS 11.0, *) else {
            return false
        }
        guard let providerURL = Bundle.main
            .builtInPlugInsURL?
            .deletingLastPathComponent()
            .appendingPathComponent("Library/SystemExtensions/\(providerBundleIdentifier).systemextension")
        else {
            return false
        }
        return (try? providerURL.checkResourceIsReachable()) == true
    }

    private func prepare(result: @escaping FlutterResult) {
        guard #available(macOS 11.0, *), isProviderEmbedded else {
            result(false)
            return
        }
        guard activationResult == nil else {
            result(
                FlutterError(
                    code: "activation_in_progress",
                    message: "Network Extension activation is already in progress",
                    details: nil
                )
            )
            return
        }

        activationResult = result
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: providerBundleIdentifier,
            queue: .main
        )
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    private func start(port: Int, result: @escaping FlutterResult) {
        loadManager { loadedManager in
            let manager = loadedManager ?? NETransparentProxyManager()
            let providerProtocol = NETunnelProviderProtocol()
            providerProtocol.providerBundleIdentifier = providerBundleIdentifier
            providerProtocol.serverAddress = "DHQClash local proxy"
            providerProtocol.providerConfiguration = ["socksPort": port]

            manager.localizedDescription = "DHQClash"
            manager.protocolConfiguration = providerProtocol
            manager.isEnabled = true
            manager.saveToPreferences { error in
                if let error {
                    result(self.flutterError("save_failed", error))
                    return
                }
                manager.loadFromPreferences { error in
                    if let error {
                        result(self.flutterError("reload_failed", error))
                        return
                    }
                    do {
                        try manager.connection.startVPNTunnel()
                        result(true)
                    } catch {
                        result(self.flutterError("start_failed", error))
                    }
                }
            }
        }
    }

    private func stop(result: @escaping FlutterResult) {
        loadManager { manager in
            manager?.connection.stopVPNTunnel()
            result(true)
        }
    }

    private func loadManager(completion: @escaping (NETransparentProxyManager?) -> Void) {
        NETransparentProxyManager.loadAllFromPreferences { managers, _ in
            completion(
                managers?.first {
                    ($0.protocolConfiguration as? NETunnelProviderProtocol)?
                        .providerBundleIdentifier == providerBundleIdentifier
                }
            )
        }
    }

    private func statusName(_ status: NEVPNStatus?) -> String {
        switch status {
        case .disconnected:
            return "disconnected"
        case .connecting, .reasserting:
            return "connecting"
        case .connected:
            return "connected"
        case .disconnecting:
            return "disconnecting"
        case .invalid:
            return "invalid"
        case nil:
            return "unavailable"
        @unknown default:
            return "invalid"
        }
    }

    private func flutterError(_ code: String, _ error: Error) -> FlutterError {
        FlutterError(code: code, message: error.localizedDescription, details: nil)
    }
}

@available(macOS 11.0, *)
extension MacosTunPlugin: OSSystemExtensionRequestDelegate {
    func request(
        _ request: OSSystemExtensionRequest,
        actionForReplacingExtension existing: OSSystemExtensionProperties,
        withExtension ext: OSSystemExtensionProperties
    ) -> OSSystemExtensionRequest.ReplacementAction {
        .replace
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        // Completion stays pending until macOS reports activation or failure.
    }

    func request(
        _ request: OSSystemExtensionRequest,
        didFinishWithResult result: OSSystemExtensionRequest.Result
    ) {
        activationResult?(result == .completed)
        activationResult = nil
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        activationResult?(flutterError("activation_failed", error))
        activationResult = nil
    }
}
