import SwiftUI

struct ReadLabFocusView: View {
    @Binding var selected: ReadingPath
    let onBack: () -> Void
    let onContinue: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 1100 && !typeSize.isAccessibilitySize
            let contentWidth: CGFloat = wide ? 868 : min(geometry.size.width - 48, 868)
            ZStack {
                ReadLabPastelBackground()
                VStack(spacing: 0) {
                    ReadLabStepHeader(step: 4, onBack: onBack)
                        .frame(maxWidth: wide ? 864 : .infinity)
                        .padding(.horizontal, wide ? 0 : 24)
                        .padding(.top, 20)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(wide ? "Choose a reading path\nfor your child." : "Choose a reading path for your child.")
                                .readLabFont(wide ? 70 : 48, weight: .medium)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityAddTraits(.isHeader)
                            Text("Let’s focus on a specific path, you can select another path whenever you want in your account section.")
                                .readLabFont(25, weight: .light, rounded: false)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 24)
                            if wide {
                                HStack(alignment: .top, spacing: 16) {
                                    ForEach(ReadingPath.allCases) { path in focusCard(path, wide: true) }
                                }.padding(.top, 60)
                            } else {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 20)], alignment: .center, spacing: 24) {
                                    ForEach(ReadingPath.allCases) { path in focusCard(path, wide: false) }
                                }.padding(.top, 36)
                            }
                        }
                        .frame(width: contentWidth, alignment: .leading)
                        .padding(.top, wide ? 60 : 30)
                        .padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)
                    HStack {
                        Spacer()
                        ReadLabActionButton(title: "Continue", action: onContinue)
                    }
                    .padding(.horizontal, wide ? 67 : 24)
                    .padding(.vertical, 14)
                }
            }.foregroundStyle(ReadLabStyle.ink)
        }
    }

    private func focusCard(_ path: ReadingPath, wide: Bool) -> some View {
        Button { selected = path } label: {
            VStack(spacing: -24) {
                Image(path.mascot).resizable().scaledToFit()
                    .frame(width: path == .words ? 92 : 140, height: 114)
                    .accessibilityHidden(true)
                VStack(spacing: 0) {
                    Text(cardTitle(path))
                        .readLabFont(26, weight: .semibold)
                        .multilineTextAlignment(.center)
                        .frame(minHeight: 62)
                    Text(cardDetail(path))
                        .readLabFont(15, weight: .light, rounded: false)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: 72)
                        .padding(.top, 24)
                    ReadLabPathIllustration(path: path)
                        .frame(height: 110)
                        .padding(.top, 16)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, minHeight: 332)
                .readLabCard()
                .overlay { RoundedRectangle(cornerRadius: 28).strokeBorder(selected == path ? ReadLabStyle.blue : .clear, lineWidth: 4) }
            }
            .frame(width: wide ? 278 : nil)
            .foregroundStyle(ReadLabStyle.ink)
        }
        .buttonStyle(ReadLabTapStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected == path ? .isSelected : [])
        .accessibilityIdentifier("readingPath-\(path.rawValue)")
    }

    private func cardTitle(_ path: ReadingPath) -> String {
        switch path { case .hearing: "Hearing\nsounds"; case .words: "First\nwords"; case .stories: "Growing\nreaders" }
    }
    private func cardDetail(_ path: ReadingPath) -> String {
        switch path {
        case .hearing: "Explore letters, sounds,\nsyllables, and rhymes\nthrough playful activities"
        case .words: "Learn to combine syllables,\nrecognize familiar words\nand gradually read\nsimple sentences"
        case .stories: "Build reading skill\nthrough engaging stories\nand developing reading\ncomprehension"
        }
    }
}

private struct ReadLabPathIllustration: View {
    let path: ReadingPath
    var body: some View {
        Group {
            switch path {
            case .hearing:
                HStack(spacing: 4) {
                    Image(systemName: "ear").font(.system(size: 80, weight: .regular))
                    SoundWaves().stroke(ReadLabStyle.ink, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 40, height: 78)
                }
            case .words:
                VStack(spacing: 20) {
                    HStack(spacing: 15) {
                        ForEach(Array("BOAT"), id: \.self) { letter in
                            Text(String(letter)).font(.system(size: 19, weight: .semibold, design: .rounded))
                                .frame(width: 25, height: 29)
                                .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(ReadLabStyle.ink, lineWidth: 2) }
                        }
                    }
                    Text("BOAT").font(.system(size: 30, weight: .semibold, design: .rounded)).tracking(7)
                }
            case .stories:
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "book").font(.system(size: 70, weight: .regular))
                    Image(systemName: "sparkles").font(.system(size: 42, weight: .medium))
                }
            }
        }.accessibilityHidden(true)
    }
}

private struct SoundWaves: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            for index in 0..<3 {
                let x = CGFloat(index) * rect.width / 3
                let inset = CGFloat(2 - index) * 11
                path.move(to: CGPoint(x: x, y: inset))
                path.addQuadCurve(to: CGPoint(x: x, y: rect.height - inset), control: CGPoint(x: x + 24, y: rect.midY))
            }
        }
    }
}
