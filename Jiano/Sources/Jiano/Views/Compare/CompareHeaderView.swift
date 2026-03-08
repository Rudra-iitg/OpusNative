import SwiftUI

struct CompareHeaderView: View {
    @Bindable var viewModel: CompareViewModel
    let accentColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "rectangle.split.2x1.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Compare Models")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text("Add models and compare responses side by side")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            if !viewModel.results.isEmpty || !viewModel.entries.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.resetAll()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.08)))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .padding(.top, 40)
    }
}
