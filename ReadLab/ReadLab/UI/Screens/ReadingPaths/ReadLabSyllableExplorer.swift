import SwiftUI
import UIKit

/// Continuous proximity, rather than a selected integer, drives the reading lens.
enum SyllableLens {
    static func centers(widths: [CGFloat]) -> [CGFloat] {
        var x: CGFloat = 0
        return widths.map { width in
            defer { x += width + 6 }
            return x + width / 2
        }
    }

    static func scales(widths: [CGFloat], position: Double) -> [CGFloat] {
        let centers = centers(widths: widths)
        guard let first = centers.first, let last = centers.last else { return [] }
        let focus = first + (last - first) * CGFloat(min(1, max(0, position)))
        let reach = max(1, widths.reduce(0, +) / CGFloat(widths.count) * 1.2)
        return centers.map { center in
            let distance = (center - focus) / reach
            return 1 + 0.42 * exp(-2.3 * distance * distance)
        }
    }

    static func position(of index: Int, widths: [CGFloat]) -> Double {
        let centers = centers(widths: widths)
        guard centers.indices.contains(index), let first = centers.first, let last = centers.last, last > first else { return 0 }
        return Double((centers[index] - first) / (last - first))
    }
}

struct ReadLabSyllableExplorer: View {
    let parts: [String]
    let pointSize: CGFloat
    let completed: Bool
    @Binding var position: Double
    @Environment(\.useDyslexicFont) private var dyslexic
    @ScaledMetric(relativeTo: .body) private var dynamicScale: CGFloat = 1
    @State private var availableWidth: CGFloat = 600

    private var fontSize: CGFloat {
        (dyslexic ? ReadLabTypography.dyslexicSize(for: pointSize) : pointSize) * dynamicScale
    }
    private var measurementFont: UIFont {
        if dyslexic, let font = UIFont(name: "OpenDyslexic-Bold", size: fontSize) { return font }
        let system = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        return UIFont(descriptor: system.fontDescriptor.withDesign(.rounded) ?? system.fontDescriptor, size: fontSize)
    }
    private var widths: [CGFloat] {
        let font = measurementFont
        return parts.map { ($0 as NSString).size(withAttributes: [.font: font]).width + 12 }
    }
    private var lines: [[Int]] {
        let widths = self.widths
        var result: [[Int]] = []
        var line: [Int] = []
        var width: CGFloat = 0
        for index in parts.indices {
            // Reserve the lens space before wrapping, so dragging never moves a syllable to another line.
            let required = widths[index] * 1.5 + (line.isEmpty ? 0 : 6)
            if !line.isEmpty && width + required > availableWidth {
                result.append(line); line = []; width = 0
            }
            line.append(index)
            width += required
        }
        if !line.isEmpty { result.append(line) }
        return result
    }
    private var readingFont: Font {
        dyslexic ? .custom("OpenDyslexic-Bold", fixedSize: fontSize) : .system(size: fontSize, weight: .semibold, design: .rounded)
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(lines.enumerated()), id: \.offset) { lineIndex, indices in
                line(indices, index: lineIndex)
            }
            Text("Slide to explore each syllable")
                .readLabFont(15, rounded: false)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
            if width > 0 { availableWidth = width }
        }
    }

    private func line(_ indices: [Int], index: Int) -> some View {
        let widths = self.widths
        let lineHeight = measurementFont.lineHeight
        let lower = SyllableLens.position(of: indices.first ?? 0, widths: widths)
        let upper = SyllableLens.position(of: indices.last ?? 0, widths: widths)
        let scales = SyllableLens.scales(widths: widths, position: position)
        let gaps = CGFloat(max(0, indices.count - 1)) * 6
        // A stable width prevents a moving slider track from feeding back into the drag position.
        let target = (0...24).map { step -> CGFloat in
            let focus = lower + (upper - lower) * Double(step) / 24
            let samples = SyllableLens.scales(widths: widths, position: focus)
            return indices.reduce(0) { $0 + widths[$1] * samples[$1] }
        }.max() ?? 0
        let current = indices.reduce(CGFloat(0)) { $0 + widths[$1] * scales[$1] }
        let compensation = target / max(1, current)
        let lineWidth = min(availableWidth, target + gaps)
        let fit = min(1, lineWidth / max(1, target + gaps))
        let localPosition = Binding<Double>(
            get: { upper > lower ? min(1, max(0, (position - lower) / (upper - lower))) : 0 },
            set: { position = lower + (upper - lower) * $0 }
        )
        return VStack(spacing: 2) {
            HStack(alignment: .bottom, spacing: 6 * fit) {
                ForEach(indices, id: \.self) { partIndex in
                    let magnification = scales[partIndex] * compensation * fit
                    Text(parts[partIndex])
                        .font(readingFont)
                        .foregroundStyle(completed ? Color(red: 0.22, green: 0.43, blue: 0.28) : ReadLabStyle.ink)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(completed ? Color.green.opacity(0.16) : ReadLabStyle.sky.opacity(Double(scales[partIndex] - 1) * 0.75), in: RoundedRectangle(cornerRadius: 12))
                        .fixedSize()
                        .scaleEffect(magnification, anchor: .bottom)
                        .frame(width: widths[partIndex] * magnification,
                               height: lineHeight * 1.7 * fit + 12, alignment: .bottom)
                }
            }
            .frame(width: lineWidth)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(indices.map { parts[$0] }.joined(separator: " · "))
            .accessibilityIdentifier(index == 0 ? "readingPrompt" : "readingPrompt-line-\(index)")
            Slider(value: localPosition, in: 0...1)
                .frame(width: lineWidth, height: 44)
                .accessibilityLabel("Syllable focus")
                .accessibilityValue(focusedPart)
                .accessibilityIdentifier("syllableFocus-\(index)")
        }
        // Native slider updates are continuous; no spring or snap delays the finger's movement.
        .transaction { $0.animation = nil }
    }

    private var focusedPart: String {
        guard !parts.isEmpty else { return "" }
        let scales = SyllableLens.scales(widths: widths, position: position)
        let index = scales.indices.max { scales[$0] < scales[$1] } ?? 0
        return parts[index]
    }
}
