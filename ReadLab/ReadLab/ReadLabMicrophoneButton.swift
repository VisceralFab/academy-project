import SwiftUI

/// The supplied classic microphone mark, drawn as a scalable native control.
struct ReadLabMicrophoneButton: View {
    let listening: Bool
    let preparing: Bool
    let finishing: Bool
    let inputLevel: Float
    let completed: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(white: 0.68), Color(white: 0.42)], startPoint: .top, endPoint: .bottom))
                Circle().strokeBorder(.white, lineWidth: 2)
                Circle().strokeBorder(Color(white: 0.46), lineWidth: 1).padding(3)
                ClassicMicrophoneMark().fill(.white).padding(11)
                if preparing || finishing {
                    Circle().fill(.black.opacity(0.25))
                    ProgressView().tint(.white).controlSize(.large)
                }
                if completed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 26)).foregroundStyle(.white, Color(red: 0.26, green: 0.47, blue: 0.31))
                        .offset(x: 32, y: 32)
                }
            }
            .frame(width: 96, height: 96)
            .overlay {
                Circle().stroke(ReadLabStyle.blue.opacity(listening ? 1 : 0), lineWidth: 5)
                    .scaleEffect(listening && !reduceMotion ? 1.08 + CGFloat(inputLevel) * 0.12 : 1.05)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: inputLevel)
            }
            .shadow(color: .black.opacity(0.18), radius: 4, y: 3)
            .opacity(completed ? 0.65 : 1)
        }
        .buttonStyle(ReadLabTapStyle())
        .disabled(preparing || finishing || completed)
        .accessibilityLabel(listening ? "Finish reading" : "Read aloud")
        .accessibilityValue(preparing ? "Preparing microphone" : (finishing ? "Recognising your words" : (listening ? "Listening" : "Ready")))
        .accessibilityHint("Tap once to start, and again when you have finished reading")
        .accessibilityIdentifier("microphoneButton")
    }
}

private struct ClassicMicrophoneMark: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let x = rect.midX - side / 2
        let y = rect.midY - side / 2
        var result = Path(roundedRect: CGRect(x: x + side * 0.375, y: y + side * 0.13,
                                             width: side * 0.25, height: side * 0.50), cornerRadius: side * 0.125)
        let stand = Path { path in
            path.move(to: CGPoint(x: x + side * 0.32, y: y + side * 0.39))
            path.addLine(to: CGPoint(x: x + side * 0.32, y: y + side * 0.52))
            path.addCurve(to: CGPoint(x: x + side * 0.68, y: y + side * 0.52),
                          control1: CGPoint(x: x + side * 0.32, y: y + side * 0.76),
                          control2: CGPoint(x: x + side * 0.68, y: y + side * 0.76))
            path.addLine(to: CGPoint(x: x + side * 0.68, y: y + side * 0.39))
            path.move(to: CGPoint(x: x + side * 0.50, y: y + side * 0.70))
            path.addLine(to: CGPoint(x: x + side * 0.50, y: y + side * 0.82))
            path.move(to: CGPoint(x: x + side * 0.38, y: y + side * 0.82))
            path.addLine(to: CGPoint(x: x + side * 0.62, y: y + side * 0.82))
        }
        result.addPath(stand.strokedPath(StrokeStyle(lineWidth: side * 0.014, lineCap: .square, lineJoin: .round)))
        return result
    }
}
