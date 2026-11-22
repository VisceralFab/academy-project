import SwiftUI

/// The outgoing page bends at the spine, revealing the next illustration beneath it.
struct ReadLabTurningPage<Page: View>: View {
    let forward: Bool
    let onFinish: () -> Void
    @ViewBuilder var page: () -> Page
    @State private var turned = false

    var body: some View {
        page()
            .overlay(alignment: forward ? .trailing : .leading) {
                LinearGradient(colors: [.clear, .black.opacity(turned ? 0.26 : 0)],
                               startPoint: forward ? .leading : .trailing,
                               endPoint: forward ? .trailing : .leading)
            }
            .rotation3DEffect(.degrees(turned ? (forward ? -89 : 89) : 0),
                              axis: (x: 0, y: 1, z: 0), anchor: forward ? .leading : .trailing,
                              perspective: 0.58)
            .opacity(turned ? 0.12 : 1)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
            .task {
                withAnimation(.easeInOut(duration: 0.68), completionCriteria: .removed) {
                    turned = true
                } completion: {
                    onFinish()
                }
            }
    }
}
