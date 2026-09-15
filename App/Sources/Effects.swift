import SwiftUI
import AVFoundation
import ParjamieEngine

/// A short-lived flourish drawn on the board at a spot where something happened.
struct BoardEffect: Identifiable, Equatable {
    enum Kind: Equatable {
        /// A capture: a shower of sparks and the +20 bonus.
        case sparks
        /// A pawn reaching home: a bright flash and the +10 bonus.
        case homeFlash
        /// Three doubles: a puff of heat where the pawn was.
        case overheat
    }

    let id = UUID()
    let kind: Kind
    let position: PawnPosition
    let color: PlayerColor
    var label: String?

    static let lifetime: Duration = .milliseconds(1400)
}

/// Draws one effect, animating itself from the moment it appears.
struct EffectView: View {
    let effect: BoardEffect
    let unit: CGFloat
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = min(timeline.date.timeIntervalSince(start) / 1.3, 1)
            ZStack {
                Canvas { context, size in
                    let c = CGPoint(x: size.width / 2, y: size.height / 2)
                    switch effect.kind {
                    case .sparks: drawSparks(in: &context, center: c, t: t)
                    case .homeFlash: drawFlash(in: &context, center: c, t: t)
                    case .overheat: drawHeat(in: &context, center: c, t: t)
                    }
                }
                if let label = effect.label {
                    Text(label)
                        .font(.system(size: unit * 1.1, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: Palette.arc, radius: unit * 0.4)
                        .shadow(color: Palette.arc, radius: unit * 0.15)
                        .offset(y: -unit * (0.6 + 1.6 * t))
                        .opacity(t < 0.7 ? 1 : (1 - t) / 0.3)
                }
            }
        }
        .frame(width: unit * 8, height: unit * 8)
    }

    private func drawSparks(in context: inout GraphicsContext, center c: CGPoint, t: Double) {
        let flash = max(0, 1 - t * 2.5)
        context.fill(Path(ellipseIn: CGRect(x: c.x - unit * 2, y: c.y - unit * 2, width: unit * 4, height: unit * 4)),
                     with: .radialGradient(Gradient(colors: [.white.opacity(flash), Palette.arc.opacity(flash * 0.85), .clear]),
                                           center: c, startRadius: 0, endRadius: unit * 2))
        var rng = SeededGenerator(seed: UInt64(bitPattern: Int64(effect.id.hashValue)))
        for _ in 0..<48 {
            let angle = Double.random(in: 0..<(2 * .pi), using: &rng)
            let speed = CGFloat.random(in: 2.0...4.6, using: &rng) * unit
            let life = Double.random(in: 0.55...1.0, using: &rng)
            let local = min(t / life, 1)
            guard local < 1 else { continue }
            let head = CGPoint(x: c.x + cos(angle) * speed * local,
                               y: c.y + sin(angle) * speed * local + unit * 2.2 * local * local)
            let tailT = max(local - 0.18, 0)
            let tail = CGPoint(x: c.x + cos(angle) * speed * tailT,
                               y: c.y + sin(angle) * speed * tailT + unit * 2.2 * tailT * tailT)
            var streak = Path()
            streak.move(to: tail)
            streak.addLine(to: head)
            let fade = 1 - local * local
            // A dark edge first so the sparks read against bright steel, then the hot core.
            context.stroke(streak, with: .color(Color(red: 0.55, green: 0.15, blue: 0.0).opacity(0.6 * fade)),
                           style: StrokeStyle(lineWidth: unit * 0.26, lineCap: .round))
            context.stroke(streak, with: .linearGradient(
                Gradient(colors: [Palette.arc.opacity(0.2 * fade), Palette.arc.opacity(fade), Color(red: 1, green: 0.97, blue: 0.8).opacity(fade)]),
                startPoint: tail, endPoint: head
            ), style: StrokeStyle(lineWidth: unit * 0.16, lineCap: .round))
        }
    }

    private func drawFlash(in context: inout GraphicsContext, center c: CGPoint, t: Double) {
        let radius = unit * (0.6 + 3.0 * t)
        let fade = 1 - t
        context.fill(Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2)),
                     with: .radialGradient(Gradient(colors: [.white.opacity(fade), Palette.arc.opacity(fade * 0.6), .clear]),
                                           center: c, startRadius: 0, endRadius: radius))
        context.stroke(Path(ellipseIn: CGRect(x: c.x - radius * 0.8, y: c.y - radius * 0.8, width: radius * 1.6, height: radius * 1.6)),
                       with: .color(.white.opacity(fade * 0.8)), lineWidth: unit * 0.12)
    }

    private func drawHeat(in context: inout GraphicsContext, center c: CGPoint, t: Double) {
        let fade = 1 - t
        for k in 0..<3 {
            let rise = unit * CGFloat(0.5 + 2.2 * t + Double(k) * 0.5)
            let r = unit * CGFloat(0.5 + t * 1.2)
            let p = CGPoint(x: c.x + CGFloat(k - 1) * unit * 0.5, y: c.y - rise)
            context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                         with: .radialGradient(Gradient(colors: [Color.white.opacity(0.5 * fade), .clear]), center: p, startRadius: 0, endRadius: r))
        }
        context.fill(Path(ellipseIn: CGRect(x: c.x - unit, y: c.y - unit, width: unit * 2, height: unit * 2)),
                     with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.3, blue: 0.1).opacity(0.8 * fade), .clear]),
                                           center: c, startRadius: 0, endRadius: unit))
    }
}

/// Repeatable randomness, so a burst looks the same on every frame it is redrawn.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed | 1 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - Banners

/// Flashed over the board when three doubles send a pawn back.
struct OverheatedBanner: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("OVERHEATED!")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .tracking(2)
                .foregroundStyle(.linearGradient(colors: [.white, Color(red: 1, green: 0.75, blue: 0.3)], startPoint: .top, endPoint: .bottom))
                .shadow(color: Color(red: 1, green: 0.25, blue: 0.05), radius: 12)
            Text("Three doubles. Your farthest pawn cools off in the nest.")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.black.opacity(0.72)))
        .padding(30)
    }
}

/// The end-of-game plate, stamped like a welding certification.
struct CertifiedPlate: View {
    let winnerName: String
    let isMine: Bool
    var tally: String?
    let onNewGame: () -> Void
    var onScoreboard: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Text(isMine ? "CERTIFIED WELDER" : "WELL PLAYED")
                .font(.system(size: 15, weight: .heavy, design: .monospaced))
                .tracking(3)
                .foregroundStyle(Palette.ink.opacity(0.7))
            Text(winnerName)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(Palette.ink)
                .shadow(color: .white.opacity(0.6), radius: 0, x: 0, y: 1)
            if !isMine {
                Text("is a certified welder")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Palette.ink.opacity(0.6))
            }
            Text("BEAD QUALITY: FLAWLESS · PASS")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(Palette.color(.red).opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.color(.red).opacity(0.85), lineWidth: 2))
                .rotationEffect(.degrees(-4))
            if let tally {
                Text(tally)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.75))
            }
            HStack(spacing: 10) {
                if let onScoreboard {
                    Button(action: onScoreboard) {
                        Label("Scoreboard", systemImage: "list.number")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .fixedSize()
                            .foregroundStyle(Palette.felt)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Palette.felt, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
                Button(action: onNewGame) {
                    Text("New game")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(Palette.parchment)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.felt))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.linearGradient(colors: [Color(white: 0.88), Color(white: 0.66)], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(alignment: .topLeading) { rivet.padding(10) }
        .overlay(alignment: .topTrailing) { rivet.padding(10) }
        .overlay(alignment: .bottomLeading) { rivet.padding(10) }
        .overlay(alignment: .bottomTrailing) { rivet.padding(10) }
        .shadow(color: .black.opacity(0.35), radius: 30, y: 10)
        .padding(30)
    }

    private var rivet: some View {
        Circle()
            .fill(.radialGradient(colors: [Color(white: 0.95), Color(white: 0.4)], center: UnitPoint(x: 0.3, y: 0.3), startRadius: 0, endRadius: 8))
            .frame(width: 11, height: 11)
    }
}

// MARK: - Sound

/// Short shop sounds. They play through the ambient channel, so the ring/silent switch
/// mutes them and they never interrupt music.
///
/// Everything happens on a private queue. Starting audio can stall for a moment while
/// iOS brings up its audio service, and that must never freeze the board.
final class ShopSounds: @unchecked Sendable {
    enum Effect: String, CaseIterable, Sendable {
        case arc
        case burst
        case sizzle
    }

    static let shared = ShopSounds()

    private let queue = DispatchQueue(label: "net.parjamie.sounds", qos: .userInitiated)
    /// Only touched on `queue`.
    private var players: [Effect: AVAudioPlayer]?

    private init() {}

    /// Loads the sounds ahead of the first game so the first spark is not late.
    func warmUp() {
        queue.async { _ = self.loadedPlayers() }
    }

    func play(_ effect: Effect) {
        queue.async {
            guard let player = self.loadedPlayers()[effect] else { return }
            player.currentTime = 0
            player.play()
        }
    }

    private func loadedPlayers() -> [Effect: AVAudioPlayer] {
        if let players { return players }
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        var loaded: [Effect: AVAudioPlayer] = [:]
        for effect in Effect.allCases {
            guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.prepareToPlay()
            loaded[effect] = player
        }
        players = loaded
        return loaded
    }
}

/// Whether the shop sounds play. On unless the player turns them off.
enum SoundSetting {
    static let key = "playSounds"
}
