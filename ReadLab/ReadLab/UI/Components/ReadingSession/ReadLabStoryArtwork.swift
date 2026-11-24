import SwiftUI

/// Bounds use the original illustration's coordinates, before fitting or cropping.
struct StoryAnimalTarget: Identifiable {
    enum Animal: String {
        case monkey, elephant, bird

        var sound: ReadLabSound {
            switch self {
            case .monkey: .monkeyMascot
            case .elephant: .elephantMascot
            case .bird: .parrotMascot
            }
        }
    }

    let animal: Animal
    let bounds: CGRect
    var id: Animal { animal }

    private init(_ animal: Animal, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) {
        self.animal = animal
        bounds = CGRect(x: x, y: y, width: width, height: height)
    }

    static func targets(for artwork: String) -> [Self] {
        guard let page = Int(artwork.suffix(2)), (1...9).contains(page) else { return [] }
        if artwork.hasPrefix("MonkeyAdventure") {
            let monkey: Self
            switch page {
            case 7, 8: monkey = .init(.monkey, 0.61, 0.42, 0.13, 0.20)
            case 9: monkey = .init(.monkey, 0.52, 0.63, 0.15, 0.23)
            default: monkey = .init(.monkey, page == 1 ? 0.43 : 0.28, 0.63, 0.16, 0.21)
            }
            if page == 4 { return [monkey, .init(.elephant, 0.85, 0.59, 0.15, 0.25)] }
            if page >= 5 { return [monkey, .init(.elephant, 0.74, 0.51, 0.25, 0.34)] }
            return [monkey]
        }
        if artwork.hasPrefix("JourneyWest") {
            let monkeyX: [CGFloat] = [0.42, 0.71, 0.08, 0.75, 0.55, 0.59, 0.58, 0.28, 0.27]
            let monkey = Self(.monkey, monkeyX[page - 1], 0.48, 0.20, 0.29)
            if page == 2 { return [monkey, .init(.elephant, 0.40, 0.51, 0.12, 0.15)] }
            if page == 3 { return [monkey, .init(.elephant, 0.34, 0.55, 0.22, 0.26)] }
            return [monkey]
        }
        if artwork.hasPrefix("PoorLittleBird") {
            switch page {
            case 1: return [.init(.monkey, 0.19, 0.77, 0.16, 0.20)]
            case 2: return [.init(.monkey, 0.19, 0.77, 0.16, 0.20), .init(.bird, 0.76, 0.38, 0.09, 0.13)]
            case 3, 5: return [.init(.bird, 0.40, 0.62, 0.12, 0.23)]
            case 4, 6: return [.init(.monkey, 0.18, 0.80, 0.15, 0.18), .init(.bird, 0.76, 0.44, 0.09, 0.13)]
            case 7: return [.init(.monkey, 0.64, 0.82, 0.15, 0.18), .init(.bird, 0.76, 0.44, 0.09, 0.13)]
            case 8: return [.init(.monkey, 0.56, 0.45, 0.18, 0.23), .init(.bird, 0.76, 0.44, 0.09, 0.13)]
            default: return [.init(.monkey, 0.06, 0.56, 0.26, 0.38), .init(.bird, 0.40, 0.62, 0.12, 0.23)]
            }
        }
        return []
    }

    func frame(imageSize: CGSize, viewport: CGSize, mode: ContentMode) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let xScale = viewport.width / imageSize.width
        let yScale = viewport.height / imageSize.height
        let scale = mode == .fill ? max(xScale, yScale) : min(xScale, yScale)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        return CGRect(x: (viewport.width - width) / 2 + bounds.minX * width,
                      y: (viewport.height - height) / 2 + bounds.minY * height,
                      width: bounds.width * width, height: bounds.height * height)
    }
}

struct ReadLabStoryAnimalTargets: View {
    let artwork: String
    let viewport: CGSize
    let mode: ContentMode
    let enabled: Bool
    let playingSound: ReadLabSound?
    let onTap: (ReadLabSound) -> Void

    var body: some View {
        if let imageSize = UIImage(named: artwork)?.size {
            ForEach(StoryAnimalTarget.targets(for: artwork)) { target in
                let rect = target.frame(imageSize: imageSize, viewport: viewport, mode: mode)
                Button { onTap(target.animal.sound) } label: {
                    Color.clear
                        .contentShape(Ellipse())
                        .overlay(alignment: .topTrailing) {
                            if playingSound == target.animal.sound {
                                Image(systemName: "pause.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .padding(9)
                                    .background(.white.opacity(0.94), in: Circle())
                                    .accessibilityHidden(true)
                            }
                        }
                }
                .buttonStyle(.plain)
                .frame(width: max(44, rect.width), height: max(44, rect.height))
                .position(x: rect.midX, y: rect.midY)
                .disabled(!enabled)
                .accessibilityLabel("Play \(target.animal.rawValue) sound")
                .accessibilityValue(playingSound == target.animal.sound ? "Taking a short pause" : "")
                .accessibilityIdentifier("storyAnimal-\(target.animal.rawValue)")
            }
        }
    }
}

/// Ground belongs to the visible illustration, including when the book crops its edges to fill.
struct ReadLabStoryArtwork: View {
    let name: String
    var mode: ContentMode = .fit
    var viewport: CGSize?

    private var image: some View {
        ReadLabMissionArt(name: name).aspectRatio(contentMode: mode)
    }

    var body: some View {
        if let viewport, mode == .fill {
            image
                .frame(width: viewport.width, height: viewport.height)
                .clipped()
                .overlay(alignment: .bottom) { ground }
        } else if let viewport {
            fittedArtwork.frame(width: viewport.width, height: viewport.height)
        } else {
            fittedArtwork
        }
    }

    private var fittedArtwork: some View {
        image.overlay(alignment: .bottom) { ground }
    }

    private var border: StoryGround? {
        if name.hasPrefix("JourneyWest") {
            return StoryGround(light: Color(red: 0.54, green: 0.68, blue: 0.47),
                               dark: Color(red: 0.44, green: 0.60, blue: 0.40), depth: 0.021)
        }
        if name.hasPrefix("MonkeyAdventure") {
            return StoryGround(light: Color(red: 0.43, green: 0.59, blue: 0.40),
                               dark: Color(red: 0.32, green: 0.47, blue: 0.36), depth: 0.016)
        }
        return nil
    }

    @ViewBuilder private var ground: some View {
        if let border {
            GeometryReader { geometry in
                let size = geometry.size
                ZStack(alignment: .bottom) {
                    GrassSilhouette().fill(border.light)
                    GrassSilhouette(phase: 1.4).fill(border.dark)
                        .frame(height: size.height * border.depth * 0.75)
                }
                .frame(width: size.width, height: size.height * border.depth)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .accessibilityHidden(true)
            .allowsHitTesting(false)
        }
    }

    private struct StoryGround {
        let light: Color
        let dark: Color
        let depth: CGFloat
    }
}

private struct GrassSilhouette: Shape {
    var phase: Double = 0

    func path(in rect: CGRect) -> Path {
        Path { path in
            let tuftCount = max(12, Int(rect.width / 14))
            let width = rect.width / CGFloat(tuftCount)
            func shoulder(at index: Int) -> CGFloat {
                rect.height * (0.33 + 0.12 * sin(Double(index) * 0.48 + phase))
            }
            path.move(to: CGPoint(x: 0, y: shoulder(at: 0)))
            for index in 0..<tuftCount {
                let x = CGFloat(index) * width
                let lift = rect.height * (0.15 + 0.07 * cos(Double(index) * 1.8 + phase))
                path.addQuadCurve(to: CGPoint(x: x + width, y: shoulder(at: index + 1)),
                                  control: CGPoint(x: x + width * 0.52, y: shoulder(at: index) - lift))
            }
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: 0, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
