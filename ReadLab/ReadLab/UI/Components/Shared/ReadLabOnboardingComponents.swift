import SwiftUI

// The three exact reference colors are shared by onboarding, home, and practice.
enum ReadLabStyle {
    static let ink = Color("Ink")
    static let background = Color("Canvas")
    static let blue = Color("Action")
    /// Deeper companion of `blue` for filled buttons that carry white text (≈4.4:1 contrast with white).
    static let actionFill = Color(red: 0.16, green: 0.49, blue: 0.73)
    /// Neutral slate for secondary filled buttons (e.g. Shuffle) with white text.
    static let secondaryFill = Color(red: 0.36, green: 0.42, blue: 0.48)
    static let sky = Color("Sky")
    static let sand = Color("Sand")
    static let coral = Color("Coral")
    static let muted = Color(red: 0.84, green: 0.85, blue: 0.89)
    static func color(for path: ReadingPath) -> Color {
        switch path { case .hearing: sky; case .words: coral; case .stories: sand }
    }
}

private struct DyslexicFontKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var useDyslexicFont: Bool {
        get { self[DyslexicFontKey.self] }
        set { self[DyslexicFontKey.self] = newValue }
    }
}

/// Compensates for the wider custom glyphs before applying the user's Dynamic Type scale.
enum ReadLabTypography {
    static func dyslexicSize(for size: CGFloat) -> CGFloat {
        let adjustment = min(0.17, max(0, size - 24) * 0.17 / 46)
        return size * (0.82 - adjustment)
    }
}

private struct ReadLabFont: ViewModifier {
    @Environment(\.useDyslexicFont) private var dyslexic
    @ScaledMetric private var size: CGFloat
    let weight: Font.Weight
    let rounded: Bool
    let baseSize: CGFloat
    init(size: CGFloat, weight: Font.Weight, rounded: Bool) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
        self.weight = weight
        self.rounded = rounded
        self.baseSize = size
    }
    func body(content: Content) -> some View {
        content.font(dyslexic
            ? .custom("OpenDyslexic-Bold", fixedSize: ReadLabTypography.dyslexicSize(for: baseSize) * size / baseSize)
            : .system(size: size, weight: weight, design: rounded ? .rounded : .default))
    }
}

extension View {
    func readLabFont(_ size: CGFloat, weight: Font.Weight = .regular, rounded: Bool = true) -> some View {
        modifier(ReadLabFont(size: size, weight: weight, rounded: rounded))
    }
    func readLabCard() -> some View {
        background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: ReadLabStyle.ink.opacity(0.12), radius: 8, y: 5)
    }
}

/// A closed Catmull–Rom contour keeps tangents continuous while its waves travel around the edge.
struct SoftBlob: Shape {
    var phase: Double
    var animatableData: Double { get { phase } set { phase = newValue } }

    func path(in rect: CGRect) -> Path {
        let count = 12
        let points: [CGPoint] = (0..<count).map { index in
            let angle = Double(index) * .pi * 2 / Double(count)
            let radius = 0.46 * (1 + 0.13 * sin(angle * 3 + phase) + 0.07 * cos(angle * 2 - phase))
            return CGPoint(x: rect.midX + cos(angle) * radius * rect.width,
                           y: rect.midY + sin(angle) * radius * rect.height)
        }
        return Path { path in
            path.move(to: points[0])
            for index in 0..<count {
                let previous = points[(index + count - 1) % count]
                let current = points[index]
                let next = points[(index + 1) % count]
                let following = points[(index + 2) % count]
                path.addCurve(to: next,
                    control1: CGPoint(x: current.x + (next.x - previous.x) / 6, y: current.y + (next.y - previous.y) / 6),
                    control2: CGPoint(x: next.x - (following.x - current.x) / 6, y: next.y - (following.y - current.y) / 6))
            }
            path.closeSubpath()
        }
    }
}

struct ReadLabPastelBackground: View {
    var path: ReadingPath? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var start = Date()

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || scenePhase != .active)) { timeline in
                let elapsed = reduceMotion ? 0 : timeline.date.timeIntervalSince(start)
                let phase = elapsed * .pi * 2 / 8
                let rotation = reduceMotion ? 0 : sin(elapsed * .pi * 2 / 14) * 18
                let w = geometry.size.width
                let h = geometry.size.height
                ZStack {
                    ReadLabStyle.background
                    blob(color: path == nil ? ReadLabStyle.sand : ReadLabStyle.color(for: path!),
                         width: w * 0.82, height: h * 1.02, phase: phase, rotation: rotation - 12)
                        .position(x: w * 0.99, y: h * 0.10)
                    blob(color: path == nil ? ReadLabStyle.coral : ReadLabStyle.color(for: path!),
                         width: w * 1.10, height: h * 1.05, phase: phase + 2.1, rotation: -rotation + 16)
                        .position(x: w * 0.04, y: h * 1.04)
                    blob(color: path == nil ? ReadLabStyle.sky : ReadLabStyle.color(for: path!),
                         width: w * 0.68, height: h * 0.80, phase: phase + 4.2, rotation: rotation * 0.8 - 8)
                        .position(x: w * 1.01, y: h * 1.05)
                }
                .frame(width: w, height: h)
                .clipped()
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func blob(color: Color, width: CGFloat, height: CGFloat, phase: Double, rotation: Double) -> some View {
        SoftBlob(phase: phase).fill(color)
            .frame(width: width, height: height)
            .rotationEffect(.degrees(rotation))
    }
}

struct ReadLabTapStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

struct ReadLabActionButton: View {
    let title: String
    let action: () -> Void
    var enabled = true
    var body: some View {
        Button(action: action) {
            Text(title)
                .readLabFont(22, weight: .bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 18)
                .frame(minWidth: 170, minHeight: 58)
                .background(ReadLabStyle.actionFill, in: Capsule())
                .shadow(color: ReadLabStyle.actionFill.opacity(0.30), radius: 6, y: 3)
        }
        .buttonStyle(ReadLabTapStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }
}

struct ReadLabChoiceCard: View {
    let title: String
    let subtitle: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    Text(title).readLabFont(20, weight: .semibold)
                    Spacer(minLength: 8)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(ReadLabStyle.ink)
                }
                Text(subtitle).readLabFont(17, rounded: false)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(ReadLabStyle.ink)
            .multilineTextAlignment(.leading)
            .padding(24)
            .frame(maxWidth: .infinity, minHeight: 145, alignment: .topLeading)
            .readLabCard()
            .overlay { RoundedRectangle(cornerRadius: 28).strokeBorder(selected ? ReadLabStyle.blue : .clear, lineWidth: 4) }
        }
        .buttonStyle(ReadLabTapStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct ReadLabStepHeader: View {
    let step: Int
    var onBack: (() -> Void)?
    var body: some View {
        HStack {
            if let onBack {
                Button("Back", systemImage: "chevron.left", action: onBack)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
            } else { Color.clear.frame(width: 48, height: 48) }
            Spacer()
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { index in
                    Circle().fill(index == step ? ReadLabStyle.ink : ReadLabStyle.ink.opacity(0.25))
                        .frame(width: index == step ? 10 : 8, height: index == step ? 10 : 8)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step \(step) of 5")
            Spacer()
            Color.clear.frame(width: 48, height: 48)
        }
    }
}

struct ReadLabStepLayout<Content: View>: View {
    let step: Int
    let onBack: () -> Void
    var actionTitle = "Continue"
    var actionEnabled = true
    let onAction: () -> Void
    @ViewBuilder let content: (Bool) -> Content
    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.width < 850
            ZStack {
                ReadLabPastelBackground()
                VStack(spacing: 10) {
                    ReadLabStepHeader(step: step, onBack: onBack)
                    ScrollView {
                        content(compact)
                            .frame(maxWidth: 1080, alignment: .leading)
                            .frame(maxWidth: .infinity)
                            .padding(.top, compact ? 24 : 32)
                            .padding(.bottom, 24)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    HStack {
                        Spacer()
                        ReadLabActionButton(title: actionTitle, action: onAction, enabled: actionEnabled)
                    }
                    .padding(.top, 6)
                    ReadLabPrivacyCaption()
                }
                .padding(.horizontal, compact ? 24 : 64)
                .padding(.top, 14)
                .padding(.bottom, 8)
            }
        }
    }
}

struct ReadLabPageTitle: View {
    let title: String
    var subtitle: String? = nil
    var compact = false
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title).readLabFont(compact ? 38 : 52, weight: .medium)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle).readLabFont(21, weight: .light, rounded: false)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(ReadLabStyle.ink)
    }
}


struct ReadLabPrivacyCaption: View {
    var body: some View {
        Text("Your child’s profile and reading progress are saved on this iPad. This app does not upload them.")
            .readLabFont(14, weight: .medium, rounded: false)
            .foregroundStyle(ReadLabStyle.ink.opacity(0.86))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 620)
            .padding(.horizontal, 48)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("onboardingPrivacyCaption")
    }
}
