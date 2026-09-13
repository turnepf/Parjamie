import SwiftUI
import ParjamieEngine
import ParjamieNet

struct GameView: View {
    @Bindable var session: MatchSession
    @State private var selectedValueID: Int?

    var body: some View {
        if let game = session.game {
            board(game)
        }
    }

    // MARK: Layout

    private func board(_ game: GameState) -> some View {
        VStack(spacing: 0) {
            header(game)
            Spacer(minLength: 0)

            BoardView(
                game: game,
                viewingColor: viewingColor(game),
                movable: movablePawns(game),
                selected: nil,
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
                winnerBanner(game, winner: winner)
            } else if session.status == .reconnecting {
                reconnectingBanner
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
            Text(rollLabel(game))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
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

    private func winnerBanner(_ game: GameState, winner: Seat) -> some View {
        VStack(spacing: 18) {
            Text(winner == session.mySeat || session.role == .local ? "Winner" : "Well played")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .tracking(2)
                .foregroundStyle(Palette.ink.opacity(0.5))
            Text(name(of: winner, in: game))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)
            Button("New game") { session.startNewGame(setup: game.setup) }
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.parchment)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.felt))
        }
        .padding(36)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Palette.parchment))
        .shadow(color: .black.opacity(0.2), radius: 30, y: 10)
        .padding(30)
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
        if game.turn.phase == .awaitingRoll { return "Roll the dice" }
        if !session.canAct { return "Watching" }
        if game.turn.values.isEmpty { return "No moves left" }
        return selectedValueID == nil ? "Pick a number, then a pawn" : "Tap a pawn to move it"
    }

    private func rollLabel(_ game: GameState) -> String {
        if game.turn.phase == .moving { return "Move a pawn" }
        return session.canAct ? "Roll" : "Waiting"
    }

    private func canRoll(_ game: GameState) -> Bool {
        session.canAct && game.turn.phase == .awaitingRoll
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
