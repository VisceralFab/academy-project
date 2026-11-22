import SwiftUI

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
