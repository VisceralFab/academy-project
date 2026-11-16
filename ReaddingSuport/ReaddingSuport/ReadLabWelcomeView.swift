import SwiftUI

struct ReadLabWelcomeView: View {
    let onGetStarted: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > 850 && !typeSize.isAccessibilitySize
            ZStack {
                ReadLabPastelBackground()
                VStack(spacing: 0) {
                    ReadLabStepHeader(step: 1)
                    ScrollView {
                        if wide {
                            HStack(spacing: 46) {
                                copy.frame(maxWidth: .infinity, alignment: .leading)
                                logo.frame(maxWidth: .infinity)
                            }
                            .frame(minHeight: max(500, geo.size.height - 150))
                        } else {
                            VStack(alignment: .leading, spacing: 36) {
                                logo.frame(maxWidth: .infinity)
                                copy
                            }
                            .padding(.vertical, 30)
                        }
                    }
                    .scrollIndicators(.hidden)
                }
                .padding(.horizontal, wide ? 80 : 28)
                .padding(.top, 14)
            }
        }
    }
    private var logo: some View {
        Image("ReadLabLogo").resizable().scaledToFit()
            .frame(maxWidth: 390, maxHeight: 350)
            .accessibilityHidden(true)
    }
    private var copy: some View {
        VStack(alignment: .leading, spacing: 30) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Learn to read with").readLabFont(48, weight: .medium)
                Text("ReadLab.").readLabFont(62, weight: .bold)
            }.accessibilityAddTraits(.isHeader)
            Text("A reading journey designed around each child’s pace and individual needs.")
                .readLabFont(25, weight: .light, rounded: false)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 24) { start; Text("About 2 minutes").readLabFont(18, rounded: false) }
                VStack(alignment: .leading, spacing: 14) { start; Text("About 2 minutes").readLabFont(18, rounded: false) }
            }
            Divider().padding(.top, 8)
            HStack(alignment: .top, spacing: 18) {
                feature("5+", "Years")
                feature("Playful", "Environment")
                feature("Effort", "No grades")
            }
        }.foregroundStyle(ReadLabStyle.ink)
    }
    private var start: some View { ReadLabActionButton(title: "Get Started", action: onGetStarted) }
    private func feature(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).readLabFont(23, weight: .semibold)
            Text(subtitle).readLabFont(17, rounded: false)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
