import Network
import NetworkExtension

struct SocksDestination {
    let host: String
    let port: UInt16
}

final class Socks5TCPRelay {
    private enum RelayError: Error {
        case invalidEndpoint
        case invalidReply
        case proxyRejected(UInt8)
    }

    private let flow: NEAppProxyTCPFlow
    private let destination: SocksDestination
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "app.dhqclash.network-extension.socks-relay")
    private let onClose: () -> Void
    private var closed = false

    init(
        flow: NEAppProxyTCPFlow,
        destination: SocksDestination,
        socksPort: Network.NWEndpoint.Port,
        onClose: @escaping () -> Void
    ) {
        self.flow = flow
        self.destination = destination
        self.onClose = onClose
        connection = NWConnection(
            host: .ipv4(.loopback),
            port: socksPort,
            using: .tcp
        )
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.negotiateAuthentication()
            case .failed(let error):
                self.finish(error)
            case .cancelled:
                self.finish(nil)
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    func cancel() {
        queue.async {
            self.finish(nil)
        }
    }

    private func negotiateAuthentication() {
        send(Data([0x05, 0x01, 0x00])) { [weak self] error in
            guard let self else { return }
            if let error {
                self.finish(error)
                return
            }
            self.receive(exactly: 2) { data, error in
                guard error == nil, data == Data([0x05, 0x00]) else {
                    self.finish(error ?? RelayError.invalidReply)
                    return
                }
                self.sendConnectRequest()
            }
        }
    }

    private func sendConnectRequest() {
        do {
            let request = try makeConnectRequest(destination)
            send(request) { [weak self] error in
                guard let self else { return }
                if let error {
                    self.finish(error)
                    return
                }
                self.receive(exactly: 4) { header, error in
                    guard
                        error == nil,
                        header.count == 4,
                        header[0] == 0x05,
                        header[1] == 0x00
                    else {
                        self.finish(
                            error ?? RelayError.proxyRejected(
                                header.count > 1 ? header[1] : 0xff
                            )
                        )
                        return
                    }
                    self.consumeBoundAddress(type: header[3])
                }
            }
        } catch {
            finish(error)
        }
    }

    private func consumeBoundAddress(type: UInt8) {
        switch type {
        case 0x01:
            receive(exactly: 6, completion: openFlow)
        case 0x04:
            receive(exactly: 18, completion: openFlow)
        case 0x03:
            receive(exactly: 1) { [weak self] length, error in
                guard let self, error == nil, let size = length.first else {
                    self?.finish(error ?? RelayError.invalidReply)
                    return
                }
                self.receive(exactly: Int(size) + 2, completion: self.openFlow)
            }
        default:
            finish(RelayError.invalidReply)
        }
    }

    private func openFlow(_: Data, error: Error?) {
        if let error {
            finish(error)
            return
        }
        flow.open(withLocalEndpoint: nil) { [weak self] error in
            guard let self else { return }
            if let error {
                self.finish(error)
                return
            }
            self.readFromFlow()
            self.readFromProxy()
        }
    }

    private func readFromFlow() {
        flow.readData { [weak self] data, error in
            guard let self else { return }
            if let error {
                self.finish(error)
                return
            }
            guard let data, !data.isEmpty else {
                self.connection.send(
                    content: nil,
                    contentContext: .defaultMessage,
                    isComplete: true,
                    completion: .contentProcessed { _ in }
                )
                return
            }
            self.send(data) { error in
                if let error {
                    self.finish(error)
                } else {
                    self.readFromFlow()
                }
            }
        }
    }

    private func readFromProxy() {
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: 64 * 1024
        ) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let error {
                self.finish(error)
                return
            }
            guard let data, !data.isEmpty else {
                if isComplete {
                    self.finish(nil)
                } else {
                    self.readFromProxy()
                }
                return
            }
            self.flow.write(data) { error in
                if let error {
                    self.finish(error)
                } else if isComplete {
                    self.finish(nil)
                } else {
                    self.readFromProxy()
                }
            }
        }
    }

    private func send(_ data: Data, completion: @escaping (Error?) -> Void) {
        connection.send(
            content: data,
            completion: .contentProcessed(completion)
        )
    }

    private func receive(
        exactly count: Int,
        completion: @escaping (Data, Error?) -> Void
    ) {
        var buffer = Data()

        func receiveNext() {
            connection.receive(
                minimumIncompleteLength: 1,
                maximumLength: count - buffer.count
            ) { data, _, isComplete, error in
                if let data {
                    buffer.append(data)
                }
                if let error {
                    completion(buffer, error)
                } else if buffer.count == count {
                    completion(buffer, nil)
                } else if isComplete {
                    completion(buffer, RelayError.invalidReply)
                } else {
                    receiveNext()
                }
            }
        }

        receiveNext()
    }

    private func makeConnectRequest(_ destination: SocksDestination) throws -> Data {
        var request = Data([0x05, 0x01, 0x00])
        if let address = IPv4Address(destination.host) {
            request.append(0x01)
            request.append(contentsOf: address.rawValue)
        } else if let address = IPv6Address(destination.host) {
            request.append(0x04)
            request.append(contentsOf: address.rawValue)
        } else {
            let encoded = Data(destination.host.utf8)
            guard encoded.count <= UInt8.max else {
                throw RelayError.invalidEndpoint
            }
            request.append(0x03)
            request.append(UInt8(encoded.count))
            request.append(encoded)
        }
        request.append(UInt8(destination.port >> 8))
        request.append(UInt8(destination.port & 0xff))
        return request
    }

    private func finish(_ error: Error?) {
        guard !closed else { return }
        closed = true
        connection.cancel()
        flow.closeReadWithError(error)
        flow.closeWriteWithError(error)
        onClose()
    }
}
