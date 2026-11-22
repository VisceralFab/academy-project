import SwiftUI

struct ReadLabMissionArt: View {
    let name: String

    var body: some View {
        Image(name)
            .resizable()
            .accessibilityHidden(true)
    }
}

struct ReadLabMissionCircle: View {
    let symbol: String
    var size: CGFloat = 56

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(ReadLabStyle.ink)
            .frame(width: size, height: size)
            .frame(minWidth: 44, minHeight: 44)
            .background(.white.opacity(0.84), in: Circle())
            .overlay { Circle().strokeBorder(.white.opacity(0.65), lineWidth: 1) }
            .shadow(color: ReadLabStyle.ink.opacity(0.18), radius: 9, y: 3)
            .contentShape(Circle())
    }
}

struct ReadLabPracticeCloud: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.white)
                    .blur(radius: 9)
                    .padding(-5)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(.white)
                            .padding(5)
                            .blur(radius: 3)
                    }
            }
    }
}

struct ReadLabBookPaper: ViewModifier {
    var margin: CGFloat = 18
    var paper = Color(red: 0.995, green: 0.982, blue: 0.952)

    func body(content: Content) -> some View {
        content
            .clipShape(.rect(cornerRadius: 8))
            .padding(margin)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(paper)
            }
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.8), lineWidth: 1) }
            .shadow(color: .black.opacity(0.18), radius: 8, x: 1, y: 4)
    }
}
