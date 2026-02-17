import SwiftUI

struct WelcomeView: View {
    @State private var isVisible = false
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [ThemeManager.shared.accent, ThemeManager.shared.accentLight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: ThemeManager.shared.accent.opacity(0.4), radius: 20)
                .scaleEffect(isVisible ? 1.0 : 0.8)
                .opacity(isVisible ? 1.0 : 0.0)
            
            VStack(spacing: 8) {
                Text("Welcome to OpusNative")
                    .font(.largeTitle.weight(.bold))
                
                Text("Your AI-powered coding companion")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .offset(y: isVisible ? 0 : 20)
            .opacity(isVisible ? 1.0 : 0.0)
            
            Text("Select an option from the sidebar to begin.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .padding(.top, 16)
                .opacity(isVisible ? 1.0 : 0.0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isVisible = true
            }
        }
    }
}
