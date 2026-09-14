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

    var body: some View {
        if let game = session.game {
            board(game)
                .onChange(of: session.game) { old, new in
                    guard let old, let new else { return }
                    celebrate(GameEvents.between(old, new))
                }
                .sensoryFeedback(.impact(weight: .light), trigger: moveTick)
                .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: captureTick)
                .sensoryFeedback(.success, trigger: homeTick)
                .sensoryFeedback(.warning, trigger: overheatTick)
                .sensoryFeedback(.success, trigger: winTick)
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
                onTap: { tap($0, in: game) }
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            diceRow(game)
            Spacer(minLength: 8)
            rollButton(game)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay {
            if let winner = game.winner {
                CertifiedPlate(
                    winnerName: name(of: winner, in: game),
                    isMine: winner == session.mySeat || session.role == .local,
                    onNewGame: { session.startNewGame(setup: game.setup) }
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
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(turnHeadline(game))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Text(subhead(game))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.55))
            }
            Spacer()
            Button("Leave") { session.stop() }
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.5))
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func hintCard(_ game: GameState) -> some View {
        if showHints, session.canAct, let hint = Hints.forTurn(in: game, selectedValueID: selectedValueID) {
            HStack(alignment: .top, spacing: 10) {
                HelmetShape(tint: Palette.felt, lensLit: true)
                    .frame(width: 20, height: 20)
                Text(hint)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
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

            if game.turn.phase == .moving {
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
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                if canRoll(game) {
                    Text("roll the dice")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
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
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)
            Text("The game is saved. Keep both phones awake with Parjamie open.")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.55))
                .multilineTextAlignment(.center)
            Button("Leave game") { session.stop() }
                .font(.system(size: 15, weight: .medium, design: .rounded))
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
        if session.role == .local {
            return game.colors(for: seat).map(Palette.name).joined(separator: " and ")
        }
        return seat == session.mySeat ? "You" : (session.peerName ?? "The other player")
    }

    private func turnHeadline(_ game: GameState) -> String {
        if game.winner != nil { return "Game over" }
        if session.role == .local {
            return "\(name(of: game.turn.seat, in: game)) to play"
        }
        return session.canAct ? "Your turn" : "\(session.peerName ?? "Waiting")'s turn"
    }

    private func subhead(_ game: GameState) -> String {
        if case .lost(let reason) = session.status { return reason }
        if session.status == .reconnecting { return "Reconnecting to \(session.peerName ?? "the other phone")…" }
        if game.winner != nil { return "Tap New game for a rematch" }
        if game.turn.phase == .awaitingRoll { return session.canAct ? "Strike an arc to roll" : "Waiting for the roll" }
        if !session.canAct { return "Watching" }
        if game.turn.values.isEmpty { return "No moves left" }
        return selectedValueID == nil ? "Pick a number, then a pawn" : "Tap a pawn to move it"
    }

    private func rollLabel(_ game: GameState) -> String {
        if game.winner != nil { return "Game over" }
        if game.turn.phase == .moving { return "Move a pawn" }
        return session.canAct ? "Strike an arc" : "Waiting"
    }

    private func canRoll(_ game: GameState) -> Bool {
        session.canAct && game.turn.phase == .awaitingRoll
    }

    // MARK: Game moments

    private func celebrate(_ events: [GameEvent]) {
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
            case .won:
                winTick += 1
                sound = .burst
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

    private func viewingColor(_ game: GameState) -> PlayerColor {
        game.colors(for: session.viewingSeat).first ?? .red
    }

    private func availableMoves(_ game: GameState) -> [Move] {
        let moves = Rules.legalMoves(in: game)
        guard let selectedValueID else { return moves }
        return moves.filter { $0.spentValueIDs.contains(selectedValueID) }
    }

    private func movablePawns(_ game: GameState) -> Set<PawnID> {
        guard session.canAct else { return [] }
        return Set(availableMoves(game).map(\.pawn))
    }

    private func tap(_ pawn: PawnID, in game: GameState) {
        guard session.canAct, let move = availableMoves(game).first(where: { $0.pawn == pawn }) else { return }
        session.perform(move)
        selectedValueID = nil
    }
}
