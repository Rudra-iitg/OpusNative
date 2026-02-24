import SwiftUI
import SwiftData

// MARK: - Prompt Library View

/// Full prompt library with version history, diffing, and category management.
/// Uses SwiftData `PromptEntry` for persistence with version stacking.
struct PromptLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PromptEntry.updatedAt, order: .reverse) private var prompts: [PromptEntry]

    @State private var searchText = ""
    @State private var selectedCategory: String?
    @State private var showingAddPrompt = false
    @State private var selectedPrompt: PromptEntry?
    @State private var showingVersionHistory = false

    // Add/Edit form state
    @State private var editName = ""
    @State private var editPromptText = ""
    @State private var editCategory = "General"

    private var accentColor: Color { ThemeManager.shared.accent }

    private var filteredPrompts: [PromptEntry] {
        var result = prompts
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.currentPrompt.lowercased().contains(query) ||
                $0.category.lowercased().contains(query)
            }
        }
        return result
    }

    private var categories: [String] {
        Array(Set(prompts.map { $0.category })).sorted()
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider().overlay(Color.white.opacity(0.06))

            HSplitView {
                // Left: prompt list
                promptListSection
                    .frame(minWidth: 280, idealWidth: 320)

                // Right: detail/editor
                detailSection
                    .frame(minWidth: 400)
            }
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.07, blue: 0.12), Color(red: 0.04, green: 0.04, blue: 0.09)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .sheet(isPresented: $showingAddPrompt) {
            addPromptSheet
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Prompt Library")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(prompts.count) prompts saved")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            Button {
                editName = ""
                editPromptText = ""
                editCategory = "General"
                showingAddPrompt = true
            } label: {
                Label("New Prompt", systemImage: "plus")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(accentColor))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .padding(.top, 24)
    }

    // MARK: - Prompt List

    private var promptListSection: some View {
        VStack(spacing: 0) {
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.4))
                TextField("Search prompts...", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    categoryPill("All", isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }
                    ForEach(categories, id: \.self) { cat in
                        categoryPill(cat, isSelected: selectedCategory == cat) {
                            selectedCategory = cat
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            .padding(.bottom, 8)

            Divider().overlay(Color.white.opacity(0.06))

            // Prompt list
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredPrompts) { prompt in
                        promptRow(prompt)
                    }
                }
                .padding(8)
            }
        }
    }

    private func categoryPill(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(isSelected ? accentColor.opacity(0.3) : Color.white.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
    }

    private func promptRow(_ prompt: PromptEntry) -> some View {
        let isSelected = selectedPrompt?.id == prompt.id
        return Button {
            selectedPrompt = prompt
            editName = prompt.name
            editPromptText = prompt.currentPrompt
            editCategory = prompt.category
        } label: {
            promptRowContent(prompt, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete", role: .destructive) {
                if selectedPrompt?.id == prompt.id { selectedPrompt = nil }
                modelContext.delete(prompt)
            }
        }
    }

    private func promptRowContent(_ prompt: PromptEntry, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(prompt.name)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.8))
                    .lineLimit(1)

                Text(prompt.currentPrompt)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(2)
            }

            Spacer()

            promptRowTrailing(prompt)
        }
        .padding(10)
        .background(promptRowBackground(isSelected: isSelected))
        .contentShape(Rectangle())
    }

    private func promptRowTrailing(_ prompt: PromptEntry) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(prompt.category)
                .font(.caption2)
                .foregroundStyle(accentColor.opacity(0.8))

            if prompt.versionCount > 1 {
                Text("v\(prompt.versionCount)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
    }

    private func promptRowBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isSelected ? accentColor.opacity(0.15) : Color.clear)
    }

    // MARK: - Detail Section

    @ViewBuilder
    private var detailSection: some View {
        if let prompt = selectedPrompt {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Name & Category
                    HStack {
                        TextField("Prompt Name", text: $editName)
                            .textFieldStyle(.plain)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)

                        Spacer()

                        Picker("", selection: $editCategory) {
                            ForEach(["General", "Coding", "Writing", "Analysis", "Learning", "Custom"], id: \.self) {
                                Text($0)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }

                    // Prompt editor
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Prompt Text")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.5))

                        TextEditor(text: $editPromptText)
                            .font(.body.monospaced())
                            .foregroundStyle(.white)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 200)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(Color.white.opacity(0.08))
                                    )
                            )
                    }

                    // Save button
                    HStack {
                        Button {
                            prompt.name = editName
                            prompt.category = editCategory
                            prompt.addVersion(editPromptText)
                            try? modelContext.save()
                        } label: {
                            Label("Save Changes", systemImage: "checkmark.circle")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(accentColor))
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        // Version info
                        if prompt.versionCount > 1 {
                            Button {
                                showingVersionHistory.toggle()
                            } label: {
                                Label("\(prompt.versionCount) versions", systemImage: "clock.arrow.circlepath")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule().fill(Color.white.opacity(0.06))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Version History
                    if showingVersionHistory && prompt.versionCount > 1 {
                        versionHistorySection(prompt)
                    }
                }
                .padding(24)
            }
        } else {
            VStack(spacing: 16) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.15))
                Text("Select a prompt to view or edit")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Version History

    private func versionHistorySection(_ prompt: PromptEntry) -> some View {
        let totalVersions = prompt.versionCount
        return VStack(alignment: .leading, spacing: 12) {
            Text("Version History")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))

            ForEach((0..<totalVersions).reversed(), id: \.self) { version in
                versionRow(prompt: prompt, version: version, totalVersions: totalVersions)
            }
        }
        .padding(16)
        .background(versionHistoryBackground)
    }

    private func versionRow(prompt: PromptEntry, version: Int, totalVersions: Int) -> some View {
        let isCurrent = version == totalVersions - 1
        let bgOpacity: Double = isCurrent ? 0.06 : 0.03
        let titleColor: Color = isCurrent ? accentColor : .white.opacity(0.6)

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Version \(version + 1)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(titleColor)

                if let text = prompt.promptAt(version: version) {
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(3)
                }
            }

            Spacer()

            if !isCurrent {
                Button("Revert") {
                    prompt.revertTo(version: version)
                    editPromptText = prompt.currentPrompt
                    try? modelContext.save()
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(accentColor)
                .buttonStyle(.plain)
            } else {
                Text("Current")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.green.opacity(0.7))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(bgOpacity))
        )
    }

    private var versionHistoryBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.03))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.06))
            )
    }

    // MARK: - Add Prompt Sheet

    private var addPromptSheet: some View {
        VStack(spacing: 20) {
            Text("New Prompt")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            TextField("Name", text: $editName)
                .textFieldStyle(.roundedBorder)

            Picker("Category", selection: $editCategory) {
                ForEach(["General", "Coding", "Writing", "Analysis", "Learning", "Custom"], id: \.self) {
                    Text($0)
                }
            }

            TextEditor(text: $editPromptText)
                .font(.body.monospaced())
                .frame(minHeight: 150)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.04))
                )

            HStack {
                Button("Cancel") {
                    showingAddPrompt = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    let entry = PromptEntry(name: editName, prompt: editPromptText, category: editCategory)
                    modelContext.insert(entry)
                    try? modelContext.save()
                    showingAddPrompt = false
                    selectedPrompt = entry
                }
                .keyboardShortcut(.defaultAction)
                .disabled(editName.isEmpty || editPromptText.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 500, height: 400)
        .background(Color(red: 0.1, green: 0.1, blue: 0.15))
    }
}
