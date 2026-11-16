import SwiftUI

struct ReadLabFocusView: View {
    @Binding var selected: ReadingPath
    let onBack: () -> Void
    let onContinue: () -> Void
    var body: some View {
        ReadLabStepLayout(step: 4, onBack: onBack, onAction: onContinue) { compact in
            VStack(alignment: .leading, spacing: 32) {
                ReadLabPageTitle(title: "Choose a reading path for your child.", subtitle: "Let’s focus on one path. You can choose another whenever you like in Account.", compact: compact)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 22)], spacing: 24) {
                    ForEach(ReadingPath.allCases) { path in
                        Button { selected = path } label: {
                            VStack(spacing: 18) {
                                Image(path.mascot).resizable().scaledToFit().frame(height: 95)
                                    .accessibilityHidden(true)
                                HStack {
                                    Text(path.title).readLabFont(27, weight: .bold)
                                    Spacer(minLength: 4)
                                    Image(systemName: selected == path ? "checkmark.circle.fill" : "circle").font(.title2)
                                }
                                Text(path.detail).readLabFont(18, rounded: false)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Image(systemName: path.symbol).font(.system(size: 38)).padding(.top, 6)
                            }
                            .foregroundStyle(ReadLabStyle.ink)
                            .multilineTextAlignment(.leading)
                            .padding(28)
                            .frame(maxWidth: .infinity, minHeight: 320, alignment: .top)
                            .readLabCard()
                            .overlay { RoundedRectangle(cornerRadius: 28).strokeBorder(selected == path ? ReadLabStyle.blue : .clear, lineWidth: 4) }
                        }
                        .buttonStyle(ReadLabTapStyle())
                        .accessibilityAddTraits(selected == path ? .isSelected : [])
                    }
                }
            }
        }
    }
}
