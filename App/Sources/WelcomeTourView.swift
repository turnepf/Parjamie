import SwiftUI
import ParjamieEngine

/// Whether this device has seen the welcome tour.
enum WelcomeTourSetting {
    static let key = "seenWelcomeTour"
}

/// Three quick pages the first time the app opens: what the game is, the ways to play,
/// and where help lives.
struct WelcomeTourView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private struct Page {
        let icon: AnyView
        let title: String
        let body: String
    }

    private var pages: [Page] {
        [
            Page(icon: AnyView(HelmetShape(tint: Palette.color(.red), lensLit: true).frame(width: 120, height: 120)),
                 title: "Welcome to the shop",
                 body: "Parjamie is a race home for two. Roll the dice, bring your welding helmets out of their bay, run them once around the steel board, and weld them all home first."),
            Page(icon: AnyView(HStack(spacing: 18) {
                     Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                     Image(systemName: "iphone")
                     Image(systemName: "cpu")
                 }.font(.system(size: 54)).foregroundStyle(Palette.arc)),
                 title: "Play your way",
                 body: "Host a game and have a friend join from their own phone nearby, pass one phone back and forth, or take on Sparky and Torch, the computer welders."),
            Page(icon: AnyView(Image(systemName: "lightbulb.max.fill").font(.system(size: 80)).foregroundStyle(Palette.arc)),
                 title: "Help as you go",
                 body: "Hints walk you through every turn, How to play explains the rules, and House rules let you change them. The scoreboard keeps track of who's winning.")
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    let item = pages[index]
                    VStack(spacing: 26) {
                        Spacer()
                        item.icon
                            .shadow(color: Palette.arc.opacity(0.4), radius: 24)
                            .accessibilityHidden(true)
                        Text(item.title)
                            .font(.rounded(28, .black))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        Text(item.body)
                            .font(.rounded(17))
                            .foregroundStyle(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                    .frame(maxWidth: 560)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(page < pages.count - 1 ? "Next" : "Get started")
                    .font(.rounded(18, .bold))
                    .frame(maxWidth: 480, minHeight: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.linearGradient(colors: [Color(red: 1, green: 0.72, blue: 0.3), Palette.arc, Color(red: 0.85, green: 0.38, blue: 0.05)],
                                                  startPoint: .top, endPoint: .bottom))
                    )
                    .foregroundStyle(Palette.ink)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)

            Button("Skip", action: onFinish)
                .font(.rounded(15, .medium))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.vertical, 14)
                .opacity(page < pages.count - 1 ? 1 : 0)
        }
        .background { ShopBackdrop().ignoresSafeArea() }
        .preferredColorScheme(.dark)
    }
}
