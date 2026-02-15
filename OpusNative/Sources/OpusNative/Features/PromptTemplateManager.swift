import Foundation
import SwiftUI

// MARK: - Prompt Template Manager

/// Manages reusable prompt templates with persistence via UserDefaults.
@Observable
@MainActor
final class PromptTemplateManager {
    var templates: [PromptTemplate] = []

    private let storageKey = "savedPromptTemplates"

    init() {
        loadTemplates()
    }

    // MARK: - CRUD Operations

    func add(name: String, prompt: String, category: String = "General") {
        let template = PromptTemplate(name: name, prompt: prompt, category: category)
        templates.append(template)
        saveTemplates()
    }

    func update(_ template: PromptTemplate, name: String, prompt: String, category: String) {
        guard let index = templates.firstIndex(where: { $0.id == template.id }) else { return }
        templates[index].name = name
        templates[index].prompt = prompt
        templates[index].category = category
        saveTemplates()
    }

    func delete(_ template: PromptTemplate) {
        templates.removeAll { $0.id == template.id }
        saveTemplates()
    }

    func delete(at offsets: IndexSet) {
        templates.remove(atOffsets: offsets)
        saveTemplates()
    }

    // MARK: - Persistence

    private func saveTemplates() {
        if let data = try? JSONEncoder().encode(templates) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadTemplates() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([PromptTemplate].self, from: data) {
            templates = saved
        } else {
            // Load built-in templates
            templates = PromptTemplate.builtInTemplates
            saveTemplates()
        }
    }

    /// Get templates grouped by category
    var groupedTemplates: [String: [PromptTemplate]] {
        Dictionary(grouping: templates, by: { $0.category })
    }

    /// Available categories
    var categories: [String] {
        Array(Set(templates.map { $0.category })).sorted()
    }
}

// MARK: - Prompt Template Model

struct PromptTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var prompt: String
    var category: String
    let createdAt: Date

    init(name: String, prompt: String, category: String = "General") {
        self.id = UUID()
        self.name = name
        self.prompt = prompt
        self.category = category
        self.createdAt = Date()
    }

    // MARK: - Built-in Templates

    static let builtInTemplates: [PromptTemplate] = [
        PromptTemplate(
            name: "Code Review",
            prompt: "Review the following code for best practices, potential bugs, and improvements:\n\n",
            category: "Coding"
        ),
        PromptTemplate(
            name: "Explain Like I'm 5",
            prompt: "Explain the following concept in simple terms that a 5-year-old could understand:\n\n",
            category: "Learning"
        ),
        PromptTemplate(
            name: "Summarize",
            prompt: "Provide a concise summary of the following text, highlighting key points:\n\n",
            category: "Writing"
        ),
        PromptTemplate(
            name: "Debug Helper",
            prompt: "I'm getting the following error. Help me understand what's wrong and how to fix it:\n\nError:\n",
            category: "Coding"
        ),
        PromptTemplate(
            name: "Technical Documentation",
            prompt: "Write clear technical documentation for the following code/system:\n\n",
            category: "Writing"
        ),
        PromptTemplate(
            name: "Pros and Cons",
            prompt: "List the pros and cons of the following approach/technology:\n\n",
            category: "Analysis"
        )
    ]
}
