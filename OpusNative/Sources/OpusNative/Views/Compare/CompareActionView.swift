import SwiftUI

struct CompareActionView: View {
    @Bindable var viewModel: CompareViewModel
    let accentColor: Color
    let accentGradient: LinearGradient
    
    var body: some View {
        VStack(spacing: 20) {
            // Prompt Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Prompt")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))

                TextEditor(text: $viewModel.prompt)
                    .font(.body)
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80, maxHeight: 160)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Color.white.opacity(0.08))
                            )
                    )
            }

            // Compare Button
            Button {
                Task { await viewModel.compare() }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isComparing {
                        ProgressView()
                            .scaleEffect(0.75)
                            .tint(.white)
                        Text("Comparing…")
                            .font(.callout.weight(.semibold))
                    } else {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 13))
                        Text("Compare (\(viewModel.entries.count) models)")
                            .font(.callout.weight(.semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            viewModel.entries.count >= 2 && !viewModel.prompt.isEmpty
                                ? AnyShapeStyle(accentGradient)
                                : AnyShapeStyle(Color.white.opacity(0.08))
                        )
                        .shadow(
                            color: viewModel.entries.count >= 2
                                ? accentColor.opacity(0.3) : .clear,
                            radius: 8, y: 4
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.entries.count < 2 || viewModel.prompt.isEmpty || viewModel.isComparing)
        }
    }
}
