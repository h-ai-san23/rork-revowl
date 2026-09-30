import SwiftUI

/// Atmospheric canvas: pearl by day, midnight by night, with a soft teal and gold glow.
struct AppBackground: View {
    var accent: Color = Palette.teal

    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.canvas, Palette.canvasDeep], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [accent.opacity(0.17), .clear], center: UnitPoint(x: 0.95, y: 0.0), startRadius: 4, endRadius: 440)
            RadialGradient(colors: [Palette.gold.opacity(0.09), .clear], center: UnitPoint(x: 0.0, y: 1.0), startRadius: 4, endRadius: 420)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
