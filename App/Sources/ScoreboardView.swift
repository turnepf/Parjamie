import SwiftUI
import ParjamieEngine

/// Every finished game, with wins per player and the most recent results.
struct ScoreboardView: View {
    /// The two people playing right now, if any, so their head-to-head shows first.
    var highlight: [String] = []
    @Environment(ScoreboardStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var board: Scoreboard { store.scoreboard }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("SCOREBOARD")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.white)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .accessibilityLabel("Close")
                }
                WeldBead().frame(width: 150, height: 6)

                if board.records.isEmpty {
                    empty
                } else {
                    if highlight.count == 2 {
                        headToHead
                    }
                    standings
                    recent
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background { ShopBackdrop().ignoresSafeArea() }
        .preferredColorScheme(.dark)
    }

    private var empty: some View {
        VStack(spacing: 12) {
            HelmetShape(tint: Palette.color(.red), lensLit: true)
                .frame(width: 56, height: 56)
            Text("No games finished yet")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Every game played to the end shows up here, on both phones.")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .steelPlate()
    }

    private var headToHead: some View {
        VStack(spacing: 8) {
            label("Head to head")
            Text(board.tally(between: highlight[0], and: highlight[1]))
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(Palette.arc)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .steelPlate(highlighted: true)
    }

    private var standings: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("Wins")
            ForEach(Array(board.standings.enumerated()), id: \.element.name) { place, standing in
                HStack(spacing: 12) {
                    Text("\(place + 1)")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(place == 0 ? Palette.arc : Color(white: 0.7)))
                    Text(standing.name)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(standing.wins) \(standing.wins == 1 ? "win" : "wins")")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("of \(standing.played) played")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steelPlate()
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 12) {
            label("Recent games")
            ForEach(board.records.prefix(30)) { record in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: record.onePhone ? "iphone" : "iphone.gen3.radiowaves.left.and.right")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.loser.map { "\(record.winner) beat \($0)" } ?? "\(record.winner) won")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("\(record.finishedAt.formatted(date: .abbreviated, time: .shortened)) · \(record.setup.title) · \(record.onePhone ? "one phone" : "two phones")")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steelPlate()
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .tracking(2)
            .foregroundStyle(Palette.arc)
    }
}
