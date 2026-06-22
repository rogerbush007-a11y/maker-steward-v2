import SwiftUI

struct LiquidGlassBackground: View {
    var body: some View {
        ZStack {
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor).opacity(0.24),
                    Color.accentColor.opacity(0.08),
                    Color(nsColor: .windowBackgroundColor).opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

struct GlassPanelModifier: ViewModifier {
    var cornerRadius: CGFloat = 8
    var opacity: Double = 0.55

    func body(content: Content) -> some View {
        content
            .background(.regularMaterial.opacity(opacity), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.6)
            )
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = 8, opacity: Double = 0.55) -> some View {
        modifier(GlassPanelModifier(cornerRadius: cornerRadius, opacity: opacity))
    }
}
