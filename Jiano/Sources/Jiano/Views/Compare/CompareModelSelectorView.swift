import SwiftUI

struct CompareModelSelectorView: View {
    @Bindable var viewModel: CompareViewModel
    let accentColor: Color
    let aiManager: AIManager
    
    @State private var showingAddModel = false
    @State private var addPickerProvider: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Models")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                if viewModel.entries.count >= 2 {
                    Text("\(viewModel.entries.count) models")
                        .font(.caption)
                        .foregroundStyle(accentColor.opacity(0.7))
                }
            }

            // Chips flow + add button
            FlowLayout(spacing: 8) {
                // Existing model chips
                ForEach(viewModel.entries) { entry in
                    modelChip(entry)
                        .transition(.scale.combined(with: .opacity))
                }

                // Add button
                addModelButton
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: viewModel.entries.count)
        }
    }

    /// A compact chip showing provider + model with ✕ to remove
    private func modelChip(_ entry: CompareViewModel.CompareEntry) -> some View {
        HStack(spacing: 6) {
            ProviderBadge(providerID: entry.providerID, compact: true)

            Text(shortModelName(entry.modelName))
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)

            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    viewModel.removeEntry(entry)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 6)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(accentColor.opacity(0.1))
                .overlay(
                    Capsule().strokeBorder(accentColor.opacity(0.25), lineWidth: 1)
                )
        )
    }

    /// The + button that opens the add model popover
    private var addModelButton: some View {
        Button {
            showingAddModel.toggle()
            addPickerProvider = nil
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                Text("Add Model")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .strokeBorder(accentColor.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingAddModel, arrowEdge: .bottom) {
            addModelPopover
        }
    }

    // MARK: - Add Model Popover

    private var addModelPopover: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if addPickerProvider != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            addPickerProvider = nil
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }

                Text(addPickerProvider != nil ? "Select Model" : "Select Provider")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().overlay(Color.white.opacity(0.1))

            ScrollView {
                VStack(spacing: 2) {
                    if let pid = addPickerProvider {
                        // Step 2: Show models for selected provider
                        let models = viewModel.modelsForProvider(pid)
                        ForEach(models, id: \.self) { model in
                            let alreadyAdded = viewModel.entries.contains {
                                $0.providerID == pid && $0.modelName == model
                            }
                            Button {
                                viewModel.addEntry(providerID: pid, modelName: model)
                                showingAddModel = false
                                addPickerProvider = nil
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "cpu")
                                        .font(.system(size: 12))
                                        .foregroundStyle(accentColor.opacity(0.6))
                                        .frame(width: 20)

                                    Text(model)
                                        .font(.callout)
                                        .foregroundStyle(.white.opacity(alreadyAdded ? 0.3 : 0.9))
                                        .lineLimit(1)

                                    Spacer()

                                    if alreadyAdded {
                                        Text("Added")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.3))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.001)) // Hit area
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(alreadyAdded)
                        }
                    } else {
                        // Step 1: Show providers
                        ForEach(viewModel.configuredProviders, id: \.id) { provider in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    addPickerProvider = provider.id
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    ProviderBadge(providerID: provider.id)

                                    Text(provider.displayName)
                                        .font(.callout.weight(.medium))
                                        .foregroundStyle(.white.opacity(0.9))

                                    Spacer()

                                    Text("\(viewModel.modelsForProvider(provider.id).count) models")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.3))

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.3))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.001))
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }

                        // Show unconfigured providers as disabled hints
                        let unconfigured = aiManager.providers.filter {
                            !aiManager.isProviderConfigured($0.id)
                        }
                        if !unconfigured.isEmpty {
                            Divider().overlay(Color.white.opacity(0.06)).padding(.vertical, 4)

                            ForEach(unconfigured, id: \.id) { provider in
                                HStack(spacing: 10) {
                                    ProviderBadge(providerID: provider.id)

                                    Text(provider.displayName)
                                        .font(.callout.weight(.medium))
                                        .foregroundStyle(.white.opacity(0.25))

                                    Spacer()

                                    Text("Not configured")
                                        .font(.caption2)
                                        .foregroundStyle(.orange.opacity(0.4))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .frame(width: 300, height: 340)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.10, green: 0.10, blue: 0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.08))
                )
        )
    }

    /// Shorten model names for display
    private func shortModelName(_ name: String) -> String {
        if let slashIndex = name.lastIndex(of: "/") {
            return String(name[name.index(after: slashIndex)...])
        }
        return name
    }
}
