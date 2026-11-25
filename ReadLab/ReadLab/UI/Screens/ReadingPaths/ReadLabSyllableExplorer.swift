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
    private var readingFont: Font {
        dyslexic ? .custom("OpenDyslexic-Bold", fixedSize: fontSize) : .system(size: fontSize, weight: .semibold, design: .rounded)
    }

    var body: some View {
        VStack(spacing: 8) {
            wordRow
            Text("Slide to explore each syllable")
                .readLabFont(15, rounded: false)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
            if width > 0 { availableWidth = width }
        }
    }

    private var wordRow: some View {
        let font = measurementFont
        let widths = parts.map { ceil(($0 as NSString).size(withAttributes: [.font: font]).width) + 12 }
        let scales = SyllableLens.scales(widths: widths, position: position)
        let gaps = CGFloat(max(0, parts.count - 1)) * 6
        // Budget for the whole word with the lens active, keeping the slider width stable as focus moves.
        let target = (0...24).map { step in
            let samples = SyllableLens.scales(widths: widths, position: Double(step) / 24)
            return zip(widths, samples).reduce(CGFloat(0)) { $0 + $1.0 * $1.1 }
        }.max() ?? 0
        let current = zip(widths, scales).reduce(CGFloat(0)) { $0 + $1.0 * $1.1 }
        let fit = min(1, availableWidth / max(1, target + gaps))
        let magnification = fit * target / max(1, current)
        let lineWidth = (target + gaps) * fit
        let focusedIndex = scales.indices.max { scales[$0] < scales[$1] }
        return VStack(spacing: 2) {
            HStack(alignment: .bottom, spacing: 6 * fit) {
                ForEach(parts.indices, id: \.self) { partIndex in
                    let scale = scales[partIndex] * magnification
                    Text(parts[partIndex])
                        .font(readingFont)
                        .foregroundStyle(completed ? Color(red: 0.22, green: 0.43, blue: 0.28) : ReadLabStyle.ink)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(completed ? Color.green.opacity(0.16) : ReadLabStyle.sky.opacity(Double(scales[partIndex] - 1) * 0.75), in: RoundedRectangle(cornerRadius: 12))
                        .fixedSize()
                        .scaleEffect(scale, anchor: .bottom)
                        .frame(width: widths[partIndex] * scale,
                               height: font.lineHeight * 1.7 * fit + 12, alignment: .bottom)
                }
            }
            .frame(width: lineWidth)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(parts.joined(separator: " · "))
            .accessibilityIdentifier("readingPrompt")
            Slider(value: $position, in: 0...1)
                .frame(width: lineWidth, height: 44)
                .accessibilityLabel("Syllable focus")
                .accessibilityValue(focusedIndex.map { parts[$0] } ?? "")
                .accessibilityIdentifier("syllableFocus-0")
        }
        // Native slider updates are continuous; no spring or snap delays the finger's movement.
        .transaction { $0.animation = nil }
    }
}
