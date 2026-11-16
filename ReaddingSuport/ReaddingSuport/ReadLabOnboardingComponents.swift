import SwiftUI

// The three exact reference colors are shared by onboarding, home, and practice.
enum ReadLabStyle {
    static let ink = Color("Ink")
    static let background = Color("Canvas")
    static let blue = Color("Action")
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

private struct ReadLabFont: ViewModifier {
    @Environment(\.useDyslexicFont) private var dyslexic
    @ScaledMetric private var size: CGFloat
    let weight: Font.Weight
    let rounded: Bool
    init(size: CGFloat, weight: Font.Weight, rounded: Bool) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
        self.weight = weight
        self.rounded = rounded
    }
    func body(content: Content) -> some View {
        content.font(dyslexic
            ? .custom("OpenDyslexic-Bold", fixedSize: size * 0.9)
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

struct SoftBlob: Shape {
    var phase: CGFloat
    var animatableData: CGFloat { get { phase } set { phase = newValue } }
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let drift = phase * 0.07
        return Path { p in
            p.move(to: CGPoint(x: w * 0.46, y: 0))
            p.addCurve(to: CGPoint(x: w, y: h * 0.49), control1: CGPoint(x: w * (0.83 + drift), y: -h * 0.06), control2: CGPoint(x: w * 1.08, y: h * 0.23))
            p.addCurve(to: CGPoint(x: w * 0.54, y: h), control1: CGPoint(x: w * (0.93 - drift), y: h * 0.79), control2: CGPoint(x: w * 0.88, y: h * 1.05))
            p.addCurve(to: CGPoint(x: 0, y: h * 0.53), control1: CGPoint(x: w * 0.18, y: h * (1.04 - drift)), control2: CGPoint(x: -w * 0.08, y: h * 0.81))
            p.addCurve(to: CGPoint(x: w * 0.46, y: 0), control1: CGPoint(x: -w * 0.03, y: h * 0.2), control2: CGPoint(x: w * 0.16, y: h * (0.04 + drift)))
            p.closeSubpath()
        }
    }
}

struct ReadLabPastelBackground: View {
    var path: ReadingPath? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var moving = false
    private var upperColor: Color {
        if let path { return ReadLabStyle.color(for: path) }
        return ReadLabStyle.sand
    }
    private var lowerColor: Color {
        if let path { return ReadLabStyle.color(for: path) }
        return ReadLabStyle.sky
    }
    private var edgeColor: Color {
        if let path { return ReadLabStyle.color(for: path) }
        return ReadLabStyle.coral
    }
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ReadLabStyle.background
                blob(upperColor, size: CGSize(width: geo.size.width * 0.62, height: geo.size.height * 0.94), angle: moving ? 12 : -12)
                    .position(x: geo.size.width * 0.96, y: geo.size.height * 0.12)
                blob(lowerColor, size: CGSize(width: geo.size.width * 0.64, height: geo.size.height * 0.70), angle: moving ? -10 : 8)
                    .position(x: geo.size.width * 0.03, y: geo.size.height * 1.04)
                blob(edgeColor, size: CGSize(width: geo.size.width * 0.60, height: geo.size.height * 0.72), angle: moving ? 10 : -8)
                    .position(x: geo.size.width * 0.98, y: geo.size.height * 1.13)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .onAppear { moving = !reduceMotion }
        .onChange(of: reduceMotion) { _, value in moving = !value }
    }
    private func blob(_ color: Color, size: CGSize, angle: Double) -> some View {
        SoftBlob(phase: moving ? 1 : -1)
            .fill(color)
            .frame(width: size.width, height: size.height)
            .rotationEffect(.degrees(reduceMotion ? 0 : angle))
            .animation(reduceMotion ? nil : .easeInOut(duration: 22).repeatForever(autoreverses: true), value: moving)
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
                .foregroundStyle(ReadLabStyle.ink)
                .padding(.horizontal, 32)
                .padding(.vertical, 18)
                .frame(minWidth: 170, minHeight: 58)
                .background(ReadLabStyle.blue, in: Capsule())
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
                    .padding(.vertical, 10)
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
