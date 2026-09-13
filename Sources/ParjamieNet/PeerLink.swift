import Foundation
import Network

/// One TCP connection to the other device, speaking framed game messages.
@MainActor
final class PeerLink {
    private let connection: NWConnection
    private var parser = MessageFraming.Parser()
    private static let queue = DispatchQueue(label: "net.parjamie.peer")

    var onReady: (() -> Void)?
    var onMessage: ((GameMessage) -> Void)?
    var onFailure: ((String) -> Void)?

    init(connection: NWConnection) {
        self.connection = connection
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in self?.handle(state) }
        }
        connection.start(queue: PeerLink.queue)
        receive()
    }

    private func handle(_ state: NWConnection.State) {
        switch state {
        case .ready:
            onReady?()
        case .failed(let error):
            onFailure?(error.localizedDescription)
        case .cancelled:
            onFailure?("Disconnected")
        default:
            // .waiting is transient, usually the other phone waking its radio.
            break
        }
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self else { return }
                if let data, !data.isEmpty {
                    do {
                        for message in try self.parser.append(data) { self.onMessage?(message) }
                    } catch {
                        self.onFailure?("Unreadable data from the other device")
                        return
                    }
                }
                if let error {
                    self.onFailure?(error.localizedDescription)
                    return
                }
                if isComplete {
                    self.onFailure?("The other device hung up")
                    return
                }
                self.receive()
            }
        }
    }

    func send(_ message: GameMessage) {
        guard let data = try? MessageFraming.encode(message) else { return }
        connection.send(content: data, completion: .contentProcessed { _ in })
    }

    func cancel() {
        connection.stateUpdateHandler = nil
        onReady = nil
        onMessage = nil
        onFailure = nil
        connection.cancel()
    }
}
