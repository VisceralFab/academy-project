import SwiftUI

struct ReadLabFocusView: View {
    @Binding var selected: ReadingPath
    let onBack: () -> Void
    let onContinue: () -> Void
    @Environment(\.readLabAudio) private var audio
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 1100 && !typeSize.isAccessibilitySize
            let contentWidth = min(geometry.size.width - 48, 868)
            let compactHeight = geometry.size.height < 860
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
                                .readLabFont(wide ? (compactHeight ? 52 : 64) : 48, weight: .medium)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityAddTraits(.isHeader)
                            Text("You can choose another reading path anytime in Account.")
                                .readLabFont(23, weight: .light, rounded: false)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 16)
                            if wide {
                                HStack(alignment: .top, spacing: 16) {
                                    ForEach(ReadingPath.allCases) { path in focusCard(path, compact: compactHeight) }
                                }.padding(.top, compactHeight ? 20 : 30)
                            } else {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 20)], alignment: .center, spacing: 24) {
                                    ForEach(ReadingPath.allCases) { path in focusCard(path, compact: false) }
                                }.padding(.top, 36)
                            }
                        }
                        .frame(width: contentWidth, alignment: .leading)
                        .padding(.top, compactHeight ? 16 : 32)
                        .padding(.bottom, 16)
                    }
                    .scrollIndicators(.hidden)
                    HStack {
                        Spacer()
                        ReadLabActionButton(title: "Continue", action: onContinue)
                    }
                    .padding(.horizontal, wide ? 67 : 24)
                    .padding(.vertical, 10)
                    ReadLabPrivacyCaption().padding(.bottom, 8)
                }
            }.foregroundStyle(ReadLabStyle.ink)
        }
    }

    private func focusCard(_ path: ReadingPath, compact: Bool) -> some View {
        let mascotHeight: CGFloat = compact ? 82 : 98
        return ZStack(alignment: .top) {
            Image(path.mascot).resizable().scaledToFit()
                .frame(width: 140, height: mascotHeight)
                .accessibilityHidden(true)
                .allowsHitTesting(false)

            Button {
                selected = path
                audio?.playAnimal(for: path)
            } label: {
                VStack(spacing: compact ? 8 : 14) {
                    Text(cardTitle(path))
                        .readLabFont(25, weight: .semibold)
                        .multilineTextAlignment(.center)
                        .frame(minHeight: 60)
                    Text(cardDetail(path))
                        .readLabFont(15, weight: .light, rounded: false)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: 72)
                    ReadLabPathIllustration(path: path)
                        .scaleEffect(compact ? 0.68 : 0.79)
                        .frame(height: compact ? 66 : 82)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, compact ? 14 : 18)
                .frame(maxWidth: .infinity)
                .readLabCard()
                .overlay { RoundedRectangle(cornerRadius: 28).strokeBorder(selected == path ? ReadLabStyle.blue : .clear, lineWidth: 4) }
            }
            .buttonStyle(ReadLabTapStyle())
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(selected == path ? .isSelected : [])
            .accessibilityIdentifier("readingPath-\(path.rawValue)")
            .padding(.top, mascotHeight * 0.78)
        }
        .foregroundStyle(ReadLabStyle.ink)
    }

    private func cardTitle(_ path: ReadingPath) -> String {
        switch path { case .hearing: "Hearing\nsounds"; case .words: "First\nwords"; case .stories: "Growing\nreaders" }
    }
    private func cardDetail(_ path: ReadingPath) -> String {
        switch path {
        case .hearing: "Explore letters, sounds,\nsyllables, and rhymes\nthrough playful activities"
        case .words: "Learn to combine syllables,\nrecognize familiar words\nand gradually read\nsimple sentences"
        case .stories: "Build reading skills and\ncomprehension through\nengaging stories."
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
