import Foundation
import Network
import Observation
import ParjamieEngine

/// Owns the match: discovery, the connection, and whose turn it is.
///
/// The host holds the only copy of the dice and the only authority to change the
/// game. A guest asks for a roll or a move and redraws from the snapshot it receives.
@MainActor
@Observable
public final class MatchSession {

    public enum Role: Hashable, Sendable {
        /// Advertises on the network and decides everything.
        case host
        /// Found a host and plays seat two.
        case guest
        /// Both seats on one device, for trying the board without a second phone.
        case local
    }

    public enum Status: Hashable, Sendable {
        case idle
        case waitingForPlayer
        case searching
        case connecting
        case playing
        /// The connection dropped mid-game. The game is kept and the devices are finding each other again.
        case reconnecting
        case lost(String)
    }

    public struct Peer: Identifiable, Hashable, Sendable {
        public let id: String
        public let name: String
        let endpoint: NWEndpoint
    }

    // MARK: Observable state

    public private(set) var role: Role = .local
    public private(set) var status: Status = .idle
    public private(set) var game: GameState?
    public private(set) var mySeat: Seat = .one
    public private(set) var peerName: String?
    public private(set) var discovered: [Peer] = []
    public private(set) var lastOutcome: MoveOutcome?
    /// The house rules new games on this phone use. The host's rules decide a two-phone
    /// game, including rematches the guest asks for.
    public private(set) var houseRules = HouseRules.classic

    /// The seat the computer plays, when playing against it on this phone.
    public private(set) var computerSeat: Seat?
    public private(set) var computerLevel: ComputerPlayer.Level = .easy
    private var computerTurn: Task<Void, Never>?

    /// Names for each seat when both players share this phone, in seat order.
    public private(set) var localPlayerNames: [String] = []

    /// Supplies the finished games to share with the other phone after connecting.
    public var scoreboardRecords: @MainActor () -> [GameRecord] = { [] }
    /// Receives the other phone's finished games.
    public var onScoreboardReceived: @MainActor ([GameRecord]) -> Void = { _ in }

    /// The player's own name, shown to the other device. Set it before hosting or joining.
    public var displayName: String

    private var listener: NWListener?
    private var browser: NWBrowser?
    private var link: PeerLink?
    private var cup = DiceCup()
    private var heartbeat: Task<Void, Never>?
    private var lastHeard = Date()
    /// The host a guest joined, remembered so it can find its way back after a drop.
    private var hostEndpoint: NWEndpoint?
    private var reconnectLoop: Task<Void, Never>?

    public init(displayName: String = ProcessInfo.processInfo.hostName) {
        self.displayName = displayName
    }

    // MARK: Turn ownership

    /// Whether this device may act right now.
    public var canAct: Bool {
        guard let game, game.winner == nil else { return false }
        if role == .local { return game.turn.seat != computerSeat }
        return status == .playing && game.turn.seat == mySeat
    }

    /// The seat this device draws as "yours". In local play that follows the turn.
    public var viewingSeat: Seat {
        if role == .local, computerSeat == nil { return game?.turn.seat ?? .one }
        return mySeat
    }

    // MARK: Starting a match

    /// Play both seats on this device. Useful for checking the board before Jamie is around.
    /// Play against the computer on this phone. The player takes seat one and moves first.
    public func startComputerGame(setup: PawnSetup, playerName: String, level: ComputerPlayer.Level, rules: HouseRules = .classic) {
        startLocalGame(setup: setup, names: [playerName, Self.computerName(for: level)], rules: rules)
        computerSeat = .two
        computerLevel = level
    }

    public static func computerName(for level: ComputerPlayer.Level) -> String {
        switch level {
        case .easy: "Sparky"
        case .hard: "Torch"
        }
    }

    public func startLocalGame(setup: PawnSetup, names: [String] = [], rules: HouseRules = .classic) {
        stop()
        localPlayerNames = names
        houseRules = rules
        role = .local
        mySeat = .one
        game = GameState(setup: setup, rules: rules)
        status = .playing
    }

    public func startHosting(setup: PawnSetup, rules: HouseRules = .classic) {
        stop()
        houseRules = rules
        role = .host
        mySeat = .one
        game = GameState(setup: setup, rules: rules)
        status = .waitingForPlayer
        startListener()
    }

    /// Opens (or reopens) the listener without touching the game. iOS can tear the
    /// listener down while the host's phone sleeps, so waking up calls this again.
    private func startListener() {
        listener?.cancel()
        listener = nil
        do {
            let listener = try NWListener(using: Self.parameters())
            listener.service = NWListener.Service(name: displayName, type: BonjourService.type)
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in self?.accept(connection) }
            }
            listener.stateUpdateHandler = { [weak self, weak listener] state in
                Task { @MainActor in
                    guard let self, let listener, listener === self.listener,
                          case .failed(let error) = state else { return }
                    self.listenerFailed(error.localizedDescription)
                }
            }
            listener.start(queue: .main)
            self.listener = listener
        } catch {
            listenerFailed(error.localizedDescription)
        }
    }

    private func listenerFailed(_ reason: String) {
        // Before anyone has joined, a failure is worth showing. Mid-game, keep trying.
        guard role == .host, peerName != nil else {
            status = .lost(reason)
            return
        }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, self.role == .host, self.status != .idle else { return }
            self.startListener()
        }
    }

    public func startSearching() {
        stop()
        role = .guest
        let browser = NWBrowser(
            for: .bonjour(type: BonjourService.type, domain: nil),
            using: Self.parameters()
        )
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                self?.discovered = results.compactMap { result in
                    guard case .service(let name, _, _, _) = result.endpoint else { return nil }
                    return Peer(id: name, name: name, endpoint: result.endpoint)
                }
            }
        }
        browser.start(queue: .main)
        self.browser = browser
        status = .searching
    }

    public func join(_ peer: Peer) {
        browser?.cancel()
        browser = nil
        hostEndpoint = peer.endpoint
        connect(to: peer.endpoint)
        status = .connecting
    }

    private func connect(to endpoint: NWEndpoint) {
        self.link?.cancel()
        let link = PeerLink(connection: NWConnection(to: endpoint, using: Self.parameters()))
        link.onReady = { [weak self] in
            guard let self else { return }
            self.link?.send(.hello(Hello(displayName: self.displayName)))
        }
        link.onMessage = { [weak self] in self?.guestReceived($0) }
        link.onFailure = { [weak self] in self?.linkFailed($0) }
        self.link = link
        link.start()
    }

    private func accept(_ connection: NWConnection) {
        // A fresh connection replaces the old one, which is how a reconnect heals itself.
        link?.cancel()
        let link = PeerLink(connection: connection)
        link.onMessage = { [weak self] in self?.hostReceived($0) }
        link.onFailure = { [weak self] in self?.linkFailed($0) }
        self.link = link
        link.start()
    }

    public func stop() {
        heartbeat?.cancel()
        heartbeat = nil
        computerTurn?.cancel()
        computerTurn = nil
        computerSeat = nil
        reconnectLoop?.cancel()
        reconnectLoop = nil
        hostEndpoint = nil
        link?.cancel()
        link = nil
        listener?.cancel()
        listener = nil
        browser?.cancel()
        browser = nil
        discovered = []
        peerName = nil
        status = .idle
    }

    // MARK: Player actions

    public func roll() {
        guard let current = game, current.turn.phase == .awaitingRoll, canAct else { return }
        switch role {
        case .host, .local:
            var next = current
            Rules.applyRoll(cup.roll(), to: &next)
            game = next
            broadcast()
            playComputerTurnIfNeeded()
        case .guest:
            link?.send(.requestRoll)
        }
    }

    public func perform(_ move: Move) {
        guard let current = game, canAct else { return }
        switch role {
        case .host, .local:
            var next = current
            lastOutcome = Rules.apply(move, to: &next)
            game = next
            broadcast()
            playComputerTurnIfNeeded()
        case .guest:
            link?.send(.requestMove(move))
        }
    }

    public func startNewGame(setup: PawnSetup) {
        switch role {
        case .host, .local:
            game = freshGame(setup: setup)
            lastOutcome = nil
            broadcast()
            playComputerTurnIfNeeded()
        case .guest:
            link?.send(.requestNewGame(setup))
        }
    }

    /// A new board whose version keeps counting up from the old game, because the guest
    /// ignores any snapshot older than the one it already has.
    private func freshGame(setup: PawnSetup) -> GameState {
        var fresh = GameState(setup: setup, rules: houseRules)
        fresh.version = (game?.version ?? 0) + 1
        return fresh
    }

    // MARK: Computer opponent

    /// Rolls and moves for the computer, one step at a time with pauses long enough to
    /// follow along, until the turn passes back to the player.
    private func playComputerTurnIfNeeded() {
        guard computerTurn == nil, let computerSeat, let game, game.winner == nil, game.turn.seat == computerSeat else { return }
        computerTurn = Task { [weak self] in
            var generator = SystemRandomNumberGenerator()
            while !Task.isCancelled {
                guard let self, let current = self.game, current.winner == nil, current.turn.seat == computerSeat else { break }
                try? await Task.sleep(for: .milliseconds(current.turn.phase == .awaitingRoll ? 900 : 1100))
                guard !Task.isCancelled, let latest = self.game, latest.turn.seat == computerSeat, latest.winner == nil else { break }
                var next = latest
                switch latest.turn.phase {
                case .awaitingRoll:
                    Rules.applyRoll(self.cup.roll(), to: &next)
                case .moving:
                    guard let move = ComputerPlayer.chooseMove(in: latest, level: self.computerLevel, using: &generator) else { break }
                    self.lastOutcome = Rules.apply(move, to: &next)
                case .finished:
                    break
                }
                self.game = next
            }
            self?.computerTurn = nil
        }
    }

    // MARK: Message handling

    private func hostReceived(_ message: GameMessage) {
        heard()
        switch message {
        case .hello(let hello):
            guard hello.protocolVersion == ProtocolVersion.current else {
                link?.send(.rejected(.protocolMismatch, hostProtocolVersion: ProtocolVersion.current))
                status = .lost("\(hello.displayName) is on a different version of Parjamie.")
                return
            }
            peerName = hello.displayName
            status = .playing
            let current = game ?? GameState(setup: .oneColorEach)
            game = current
            link?.send(.welcome(Welcome(displayName: displayName, seat: .two, state: current)))
            link?.send(.scoreboard(scoreboardRecords()))
            beginHeartbeat()

        case .requestRoll:
            guard let current = game, current.turn.seat == .two, current.turn.phase == .awaitingRoll else { return }
            var next = current
            Rules.applyRoll(cup.roll(), to: &next)
            game = next
            broadcast()

        case .requestMove(let move):
            guard let current = game, current.turn.seat == .two else { return }
            var next = current
            lastOutcome = Rules.apply(move, to: &next)
            game = next
            broadcast()

        case .requestNewGame(let setup):
            game = freshGame(setup: setup)
            lastOutcome = nil
            broadcast()

        case .scoreboard(let records):
            onScoreboardReceived(records)

        case .ping:
            link?.send(.pong)

        default:
            break
        }
    }

    private func guestReceived(_ message: GameMessage) {
        heard()
        switch message {
        case .welcome(let welcome):
            guard welcome.protocolVersion == ProtocolVersion.current else {
                status = .lost("\(welcome.displayName) is on a different version of Parjamie.")
                return
            }
            mySeat = welcome.seat
            peerName = welcome.displayName
            game = welcome.state
            status = .playing
            link?.send(.scoreboard(scoreboardRecords()))
            reconnectLoop?.cancel()
            reconnectLoop = nil
            beginHeartbeat()

        case .snapshot(let snapshot):
            // Snapshots can only move forward, so a late arrival never rewinds the board.
            if let current = game, snapshot.version < current.version { return }
            game = snapshot

        case .rejected(let reason, let hostVersion):
            switch reason {
            case .protocolMismatch:
                let mine = ProtocolVersion.current
                status = .lost(mine < hostVersion
                    ? "You need the newer build of Parjamie."
                    : "The other device needs the newer build of Parjamie.")
            case .gameInProgress:
                status = .lost("That game already has two players.")
            }

        case .scoreboard(let records):
            onScoreboardReceived(records)

        case .ping:
            link?.send(.pong)

        default:
            break
        }
    }

    private func linkFailed(_ reason: String) {
        switch status {
        case .connecting:
            status = .lost(reason)
            link = nil
        case .playing, .reconnecting:
            connectionDropped()
        default:
            break
        }
    }

    /// Anything arriving from the other device proves the link is alive again.
    private func heard() {
        lastHeard = Date()
        if status == .reconnecting, role == .host, peerName != nil {
            status = .playing
        }
    }

    /// Keeps the game and starts finding the other device again. The host just keeps
    /// listening, and a guest keeps dialing the host it joined.
    private func connectionDropped() {
        guard game != nil else { return }
        status = .reconnecting
        switch role {
        case .host:
            if listener == nil { startListener() }
        case .guest:
            startReconnecting()
        case .local:
            break
        }
    }

    private func startReconnecting() {
        guard reconnectLoop == nil, let hostEndpoint else { return }
        reconnectLoop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.status == .reconnecting else { break }
                self.connect(to: hostEndpoint)
                // Long enough for a sleepy radio to come up, short enough not to feel stuck.
                try? await Task.sleep(for: .seconds(6))
            }
            self?.reconnectLoop = nil
        }
    }

    private func broadcast() {
        guard role == .host, let game else { return }
        link?.send(.snapshot(game))
    }

    // MARK: Waking up

    /// Call when the app comes back to the foreground. Suspended apps lose their
    /// sockets and sometimes their listener, so check both instead of trusting them.
    public func appBecameActive() {
        guard role != .local, game != nil else { return }
        switch status {
        case .playing, .reconnecting:
            break
        default:
            return
        }
        // The clock kept running while the phone slept. Give the other device a fresh
        // window to answer before calling the connection dead.
        lastHeard = Date()
        if role == .host, listener == nil || listener?.state != .ready {
            startListener()
        }
        link?.send(.ping)
        beginHeartbeat()
    }

    // MARK: Liveness

    /// A dead socket can look healthy for a long time after someone leaves the house,
    /// so the two devices keep asking each other.
    private func beginHeartbeat() {
        heartbeat?.cancel()
        lastHeard = Date()
        heartbeat = Task { [weak self] in
            var lastTick = Date()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard let self else { return }
                let now = Date()
                // A long gap between ticks means this phone was asleep, not that the
                // other one went quiet, so start the silence count over.
                if now.timeIntervalSince(lastTick) > 8 { self.lastHeard = now }
                lastTick = now
                self.link?.send(.ping)
                if self.status == .playing, now.timeIntervalSince(self.lastHeard) > 12 {
                    self.connectionDropped()
                }
            }
        }
    }

    private static func parameters() -> NWParameters {
        let tcp = NWProtocolTCP.Options()
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 2
        tcp.noDelay = true
        let parameters = NWParameters(tls: nil, tcp: tcp)
        // Lets the two phones talk directly when there is no Wi-Fi network to share.
        parameters.includePeerToPeer = true
        return parameters
    }
}
