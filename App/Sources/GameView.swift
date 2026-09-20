import SwiftUI
import ParjamieEngine
import ParjamieNet

struct GameView: View {
    @Bindable var session: MatchSession
    @State private var selectedValueID: Int?
    @AppStorage(HintSetting.key) private var showHints = true
    @AppStorage(SoundSetting.key) private var playSounds = true
    @State private var effects: [BoardEffect] = []
    @State private var showOverheated = false
    @State private var moveTick = 0
    @State private var captureTick = 0
    @State private var homeTick = 0
    @State private var overheatTick = 0
    @State private var winTick = 0
    @State private var nudge: String?
    @State private var nudgeTask: Task<Void, Never>?
    @State private var showHowToPlay = false
    @State private var showScoreboard = false
    @State private var showRules = false
    @Environment(ScoreboardStore.self) private var scoreboardStore
    @AppStorage(HowToPlaySetting.seenKey) private var seenHowToPlay = false

    var body: some View {
        if let game = session.game {
            board(game)
                .onChange(of: session.game) { old, new in
                    guard let old, let new else { return }
                    celebrate(GameEvents.between(old, new), in: new)
                }
                .sensoryFeedback(.impact(weight: .light), trigger: moveTick)
                .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: captureTick)
                .sensoryFeedback(.success, trigger: homeTick)
                .sensoryFeedback(.warning, trigger: overheatTick)
                .sensoryFeedback(.success, trigger: winTick)
                .sheet(isPresented: $showHowToPlay) {
                    HowToPlayView(
                        myColors: myColors(game),
                        rules: game.rules,
                        isLocal: session.role == .local,
                        otherName: session.peerName
                    )
                }
                .sheet(isPresented: $showRules) {
                    HouseRulesView(rules: .constant(game.rules), editable: false)
                }
                .sheet(isPresented: $showScoreboard) {
                    ScoreboardView(highlight: [playerName(of: .one, in: game), playerName(of: .two, in: game)])
                        .environment(scoreboardStore)
                }
                .onAppear {
                    if !seenHowToPlay {
                        seenHowToPlay = true
                        showHowToPlay = true
                    }
                }
        }
    }

    // MARK: Layout

    private func board(_ game: GameState) -> some View {
        VStack(spacing: 0) {
            header(game)
            hintCard(game)
            Spacer(minLength: 0)

            BoardView(
                game: game,
                viewingColor: viewingColor(game),
                movable: movablePawns(game),
                selected: nil,
                effects: effects,
                guides: guides(game),
                bayLabels: bayLabels(game),
                onTap: { tap($0, in: game) }
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .overlay(alignment: .top) {
                if let nudge {
                    Text(nudge)
                        .font(.rounded(14, .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.black.opacity(0.82)))
                        .overlay(Capsule().stroke(Palette.arc.opacity(0.7), lineWidth: 1))
                        .padding(.horizontal, 24)
                        .padding(.top, 14)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onTapGesture { withAnimation { self.nudge = nil } }
                }
            }

            diceRow(game)
            Spacer(minLength: 8)
            rollButton(game)
        }
        // On iPad and Mac, keep the header and controls close to the board.
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay {
            if let winner = game.winner {
                CertifiedPlate(
                    winnerName: name(of: winner, in: game),
                    isMine: session.computerSeat.map { winner != $0 } ?? (winner == session.mySeat || session.role == .local),
                    tally: scoreboardStore.scoreboard.tally(
                        between: playerName(of: .one, in: game),
                        and: playerName(of: .two, in: game)
                    ),
                    onNewGame: { session.startNewGame(setup: game.setup) },
                    onScoreboard: { showScoreboard = true }
                )
            } else if session.status == .reconnecting {
                reconnectingBanner
            } else if showOverheated {
                OverheatedBanner()
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: game.turn.values) { _, values in
            // With only one amount in hand there is nothing to choose between.
            selectedValueID = values.count == 1 ? values.first?.id : nil
        }
    }

    private func header(_ game: GameState) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(turnHeadline(game))
                    .font(.rounded(20, .semibold))
                    .foregroundStyle(Palette.ink)
                HStack(spacing: 6) {
                    identityBadge(game)
                    if !game.rules.isClassic {
                        Button { showRules = true } label: {
                            Label("House rules", systemImage: "slider.horizontal.3")
                                .font(.rounded(12, .bold))
                                .foregroundStyle(Palette.felt)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().stroke(Palette.felt.opacity(0.5), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text(subhead(game))
                    .font(.rounded(13, .regular))
                    .foregroundStyle(Palette.ink.opacity(0.55))
            }
            Spacer()
            HStack(spacing: 14) {
                Button {
                    showHowToPlay = true
                } label: {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Palette.felt)
                }
                .accessibilityLabel("How to play")
                Button("Leave") { session.stop() }
                    .font(.rounded(15, .medium))
                    .foregroundStyle(Palette.ink.opacity(0.5))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    /// Which color this phone is playing, so nobody has to guess.
    private func identityBadge(_ game: GameState) -> some View {
        let colors = myColors(game)
        let names = colors.map(Palette.name).joined(separator: " & ")
        return HStack(spacing: 6) {
            ForEach(colors, id: \.self) { color in
                HelmetShape(tint: Palette.color(color))
                    .frame(width: 18, height: 18)
            }
            Text(session.role == .local && session.computerSeat == nil ? "\(playerName(of: game.turn.seat, in: game)) · \(names)" : "You're \(names)")
                .font(.rounded(13, .bold))
                .foregroundStyle(Palette.ink)
        }
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .padding(.vertical, 3)
        .background(Capsule().fill(Palette.color(colors.first ?? .red).opacity(0.16)))
        .overlay(Capsule().stroke(Palette.color(colors.first ?? .red).opacity(0.5), lineWidth: 1))
    }

    @ViewBuilder
    private func hintCard(_ game: GameState) -> some View {
        if showHints, session.canAct, let hint = Hints.forTurn(in: game, selectedValueID: selectedValueID) {
            HStack(alignment: .top, spacing: 10) {
                HelmetShape(tint: Palette.felt, lensLit: true)
                    .frame(width: 20, height: 20)
                Text(hint)
                    .font(.rounded(14, .medium))
                    .foregroundStyle(Palette.ink.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    showHints = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.ink.opacity(0.35))
                        .frame(width: 24, height: 24)
                }
                .accessibilityLabel("Turn off hints")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 0.99, green: 0.93, blue: 0.78))
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .animation(.easeInOut(duration: 0.2), value: hint)
        }
    }

    private func diceRow(_ game: GameState) -> some View {
        HStack(spacing: 12) {
            if let roll = game.turn.roll {
                DieFace(value: roll.first).frame(width: 46, height: 46)
                DieFace(value: roll.second).frame(width: 46, height: 46)
            }

            // The other player's unspent numbers are theirs to pick from, not ours.
            if game.turn.phase == .moving && session.canAct {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(game.turn.values) { value in
                            ValueChip(
                                value: value,
                                isSelected: selectedValueID == value.id,
                                isEnabled: session.canAct
                            ) {
                                selectedValueID = selectedValueID == value.id ? nil : value.id
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(height: 52)
        .padding(.horizontal, 20)
    }

    private func rollButton(_ game: GameState) -> some View {
        Button {
                selectedValueID = nil
                session.roll()
        } label: {
            VStack(spacing: 1) {
                Text(rollLabel(game))
                    .font(.rounded(18, .semibold))
                if canRoll(game) {
                    Text("roll the dice")
                        .font(.rounded(11, .medium))
                        .opacity(0.7)
                }
            }
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(canRoll(game) ? Palette.felt : Palette.ink.opacity(0.12))
                )
                .foregroundStyle(canRoll(game) ? Palette.parchment : Palette.ink.opacity(0.45))
        }
        .buttonStyle(.plain)
        .disabled(!canRoll(game))
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var reconnectingBanner: some View {
        VStack(spacing: 14) {
            ProgressView().controlSize(.large)
            Text("Reconnecting")
                .font(.rounded(22, .bold))
                .foregroundStyle(Palette.ink)
            Text("The game is saved. Keep both phones awake with Parjamie open.")
                .font(.rounded(14))
                .foregroundStyle(Palette.ink.opacity(0.55))
                .multilineTextAlignment(.center)
            Button("Leave game") { session.stop() }
                .font(.rounded(15, .medium))
                .foregroundStyle(Palette.ink.opacity(0.5))
                .padding(.top, 4)
        }
        .padding(32)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Palette.parchment))
        .shadow(color: .black.opacity(0.2), radius: 30, y: 10)
        .padding(30)
    }

    // MARK: Wording

    private func name(of seat: Seat, in game: GameState) -> String {
        if session.role == .local { return playerName(of: seat, in: game) }
        return seat == session.mySeat ? "You" : (session.peerName ?? "The other player")
    }

    /// The name a seat's player typed, for the scoreboard and one-phone games. Falls
    /// back to the seat's colors when no name is known.
    private func playerName(of seat: Seat, in game: GameState) -> String {
        let typed: String?
        switch session.role {
        case .local:
            typed = session.localPlayerNames.indices.contains(seat.rawValue) ? session.localPlayerNames[seat.rawValue] : nil
        case .host, .guest:
            typed = seat == session.mySeat ? session.displayName : session.peerName
        }
        if let typed, !typed.trimmingCharacters(in: .whitespaces).isEmpty { return typed }
        return game.colors(for: seat).map(Palette.name).joined(separator: " and ")
    }

    private func turnHeadline(_ game: GameState) -> String {
        if game.winner != nil { return "Game over" }
        if session.role == .local {
            if let computer = session.computerSeat {
                return game.turn.seat == computer ? "\(playerName(of: computer, in: game))'s turn" : "Your turn"
            }
            return "\(playerName(of: game.turn.seat, in: game))'s turn"
        }
        return session.canAct ? "Your turn" : "\(session.peerName ?? "Waiting")'s turn"
    }

    private func subhead(_ game: GameState) -> String {
        if case .lost(let reason) = session.status { return reason }
        if session.status == .reconnecting { return "Reconnecting to \(session.peerName ?? "the other phone")…" }
        if game.winner != nil { return "Tap New game for a rematch" }
        if !session.canAct {
            if let roll = game.turn.roll, game.turn.phase == .moving {
                return "\(otherName) rolled \(roll.first) and \(roll.second). Nothing for you to do yet."
            }
            return "Nothing for you to do yet."
        }
        if game.turn.phase == .awaitingRoll { return "Strike an arc to roll" }
        if game.turn.values.isEmpty { return "No moves left" }
        return selectedValueID == nil ? "Pick a number, then a helmet" : "Tap a glowing helmet to move it"
    }

    private func rollLabel(_ game: GameState) -> String {
        if game.winner != nil { return "Game over" }
        if !session.canAct {
            return game.turn.phase == .moving ? "\(otherName) is moving…" : "\(otherName) is rolling…"
        }
        if game.turn.phase == .moving { return "Move a helmet" }
        return "Strike an arc"
    }

    private var otherName: String {
        if let computer = session.computerSeat, let game = session.game { return playerName(of: computer, in: game) }
        return session.peerName ?? "The other player"
    }

    private func canRoll(_ game: GameState) -> Bool {
        session.canAct && game.turn.phase == .awaitingRoll
    }

    // MARK: Game moments

    private func celebrate(_ events: [GameEvent], in game: GameState) {
        guard !events.isEmpty else { return }
        var sound: ShopSounds.Effect?
        for event in events {
            switch event {
            case .moved:
                moveTick += 1
                sound = sound ?? .arc
            case .captured(let pawn, let spot):
                add(BoardEffect(kind: .sparks, position: spot, color: pawn.color, label: "+20"))
                captureTick += 1
                sound = .burst
            case .reachedHome(let pawn):
                add(BoardEffect(kind: .homeFlash, position: .home, color: pawn.color, label: "+10"))
                homeTick += 1
                if sound != .sizzle { sound = .burst }
            case .overheated(let pawn, let spot):
                add(BoardEffect(kind: .overheat, position: spot, color: pawn.color))
                overheatTick += 1
                sound = .sizzle
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { showOverheated = true }
                Task {
                    try? await Task.sleep(for: .seconds(2.2))
                    withAnimation(.easeOut(duration: 0.3)) { showOverheated = false }
                }
            case .won(let winner):
                winTick += 1
                sound = .burst
                scoreboardStore.record(GameRecord(
                    id: game.id,
                    finishedAt: Date(),
                    setup: game.setup,
                    players: [playerName(of: .one, in: game), playerName(of: .two, in: game)],
                    winner: playerName(of: winner, in: game),
                    onePhone: session.role == .local,
                    vsComputer: session.computerSeat != nil
                ))
            }
        }
        if playSounds, let sound { ShopSounds.shared.play(sound) }
    }

    private func add(_ effect: BoardEffect) {
        effects.append(effect)
        Task {
            try? await Task.sleep(for: BoardEffect.lifetime)
            effects.removeAll { $0.id == effect.id }
        }
    }

    // MARK: Moves

    /// The colors this phone moves: its own seat online, or whoever's turn it is locally.
    private func myColors(_ game: GameState) -> [PlayerColor] {
        game.colors(for: session.viewingSeat)
    }

    private func bayLabels(_ game: GameState) -> [PlayerColor: String] {
        var labels: [PlayerColor: String] = [:]
        if session.role == .local {
            guard !session.localPlayerNames.isEmpty else { return [:] }
            for seat in Seat.allCases {
                for color in game.colors(for: seat) { labels[color] = playerName(of: seat, in: game).uppercased() }
            }
            return labels
        }
        for color in game.colors(for: session.mySeat) { labels[color] = "YOU" }
        let other = (session.peerName ?? "Them").uppercased()
        for color in game.colors(for: session.mySeat.opponent) { labels[color] = other }
        return labels
    }

    private func guides(_ game: GameState) -> BoardGuides {
        guard showHints else { return BoardGuides() }
        var guides = BoardGuides(showDirection: true)
        guard session.canAct, game.turn.phase == .moving else { return guides }
        let moves = availableMoves(game, selecting: selectedValueID ?? (game.turn.values.count == 1 ? game.turn.values.first?.id : nil))
        guides.startSquares = Array(Set(moves.compactMap { move -> PlayerColor? in
            if case .enter(let pawn, _) = move { pawn.color } else { nil }
        }))
        // Only preview landings once a number is chosen (or there is just one), so the
        // board stays readable.
        let chosen = selectedValueID ?? (game.turn.values.count == 1 ? game.turn.values.first?.id : nil)
        if chosen != nil {
            var seen = Set<PawnPosition>()
            guides.landings = moves.compactMap { move in
                guard let spot = Rules.landing(of: move, in: game), seen.insert(spot).inserted else { return nil }
                return PawnLanding(pawn: move.pawn, position: spot)
            }
        }
        return guides
    }

    /// The board never turns to face whoever's holding the phone: on one phone, passing
    /// it back and forth already tells players whose turn it is, and rotating the whole
    /// board on top of that just made people lose track of where their pawns were.
    private func viewingColor(_ game: GameState) -> PlayerColor {
        game.colors(for: session.mySeat).first ?? .red
    }

    private func availableMoves(_ game: GameState) -> [Move] {
        availableMoves(game, selecting: selectedValueID)
    }

    private func availableMoves(_ game: GameState, selecting valueID: Int?) -> [Move] {
        let moves = Rules.legalMoves(in: game)
        guard let valueID else { return moves }
        return moves.filter { $0.spentValueIDs.contains(valueID) }
    }

    private func movablePawns(_ game: GameState) -> Set<PawnID> {
        guard session.canAct else { return [] }
        return Set(availableMoves(game).map(\.pawn))
    }

    private func tap(_ pawn: PawnID, in game: GameState) {
        guard session.canAct else {
            if game.winner == nil { show("It's \(otherName)'s turn.") }
            return
        }
        guard let move = availableMoves(game).first(where: { $0.pawn == pawn }) else {
            show(Hints.whyCantMove(pawn, in: game, selectedValueID: selectedValueID))
            return
        }
        session.perform(move)
        selectedValueID = nil
        withAnimation { nudge = nil }
    }

    /// A short explanation over the board when a tap did nothing.
    private func show(_ message: String) {
        nudgeTask?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { nudge = message }
        AccessibilityNotification.Announcement(message).post()
        nudgeTask = Task {
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { nudge = nil }
        }
    }
}
