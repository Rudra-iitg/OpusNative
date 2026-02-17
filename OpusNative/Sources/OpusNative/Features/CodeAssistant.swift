import Foundation

// MARK: - Code Assistant

/// Provides AI-powered code analysis: explain, find bugs, refactor, generate tests, complexity estimation.
@Observable
@MainActor
final class CodeAssistant {
    var code: String = ""
    var detectedLanguage: String = "unknown"
    var isProcessing = false
    var result: String = ""
    var errorMessage: String?
    var lastAction: CodeAction?
    
    // Model Selection
    var selectedProviderID: String = "" {
        didSet {
            if oldValue != selectedProviderID {
                updateAvailableModels()
            }
        }
    }
    var selectedModel: String = ""
    var availableModels: [String] = []

    init() {
        initialize()
    }

    enum CodeAction: String, CaseIterable, Identifiable {
        case explain = "Explain Code"
        case findBugs = "Find Bugs"
        case refactor = "Suggest Refactor"
        case generateTests = "Generate Tests"
        case complexity = "Complexity Analysis"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .explain: return "text.magnifyingglass"
            case .findBugs: return "ladybug"
            case .refactor: return "arrow.triangle.2.circlepath"
            case .generateTests: return "checkmark.shield"
            case .complexity: return "chart.bar"
            }
        }

        var prompt: String {
            switch self {
            case .explain:
                return """
                Explain the following code in detail. Cover:
                1. Overall purpose
                2. How it works step-by-step
                3. Key concepts used
                4. Input/output behavior
                """
            case .findBugs:
                return """
                Analyze the following code for bugs and issues. For each issue found:
                1. Describe the bug
                2. Explain why it's problematic
                3. Provide a fix
                4. Rate severity (low/medium/high/critical)
                """
            case .refactor:
                return """
                Suggest refactoring improvements for the following code:
                1. Code organization
                2. Performance improvements
                3. Readability enhancements
                4. Design pattern suggestions
                5. Provide refactored code
                """
            case .generateTests:
                return """
                Generate comprehensive unit tests for the following code:
                1. Test all public methods/functions
                2. Include edge cases
                3. Include error cases
                4. Use appropriate testing framework for the language
                5. Add descriptive test names
                """
            case .complexity:
                return """
                Analyze the complexity of the following code:
                1. Time complexity (Big-O) for each function
                2. Space complexity
                3. Cyclomatic complexity
                4. Cognitive complexity
                5. Suggestions for optimization
                """
            }
        }
    }

    // MARK: - Language Detection

    /// Auto-detect programming language from code content
    func detectLanguage() {
        let code = self.code.lowercased()
        let firstLine = code.components(separatedBy: "\n").first ?? ""

        // Check shebangs and common first-line patterns
        if firstLine.contains("#!/usr/bin/python") || firstLine.contains("#!/usr/bin/env python") {
            detectedLanguage = "Python"; return
        }
        if firstLine.contains("#!/bin/bash") || firstLine.contains("#!/bin/sh") {
            detectedLanguage = "Shell"; return
        }

        // Keyword-based detection
        let detectors: [(language: String, keywords: [String])] = [
            ("Swift", ["import SwiftUI", "import Foundation", "import UIKit", "struct ", "func ", "@Observable", "@State", "@main", "let ", "var ", "guard ", "enum ", "@objc"]),
            ("Python", ["def ", "import ", "from ", "class ", "self.", "if __name__", "print(", "elif ", "lambda ", "async def"]),
            ("JavaScript", ["const ", "function ", "console.log", "=>", "require(", "module.exports", "addEventListener", "document."]),
            ("TypeScript", ["interface ", ": string", ": number", ": boolean", "import {", "export ", "type "]),
            ("Rust", ["fn ", "let mut", "impl ", "pub fn", "use std", "match ", "struct ", "#[derive", "println!"]),
            ("Go", ["func ", "package ", "import (", "fmt.", "go func", "chan ", "defer ", "interface {"]),
            ("Java", ["public class", "public static void main", "System.out", "import java", "private ", "protected "]),
            ("C++", ["#include", "std::", "cout", "cin", "namespace", "template<", "virtual "]),
            ("C", ["#include", "printf(", "scanf(", "int main", "malloc(", "typedef "]),
            ("HTML", ["<!doctype", "<html", "<head", "<body", "<div", "<script"]),
            ("CSS", ["{", ":", ";", "margin:", "padding:", "display:", "color:", ".class", "#id"]),
            ("SQL", ["select ", "from ", "where ", "insert into", "create table", "alter table", "join "]),
            ("Ruby", ["def ", "end", "puts ", "class ", "require ", "attr_accessor"]),
            ("Kotlin", ["fun ", "val ", "var ", "class ", "data class", "companion object"]),
        ]

        var bestMatch = "unknown"
        var bestScore = 0

        for detector in detectors {
            let score = detector.keywords.filter { code.contains($0.lowercased()) }.count
            if score > bestScore {
                bestScore = score
                bestMatch = detector.language
            }
        }

        detectedLanguage = bestMatch
    }

    // MARK: - Initialization & Model Management
    
    func initialize() {
        if let active = AIManager.shared.activeProvider {
            selectedProviderID = active.id
        } else if let first = AIManager.shared.providers.first(where: { AIManager.shared.isProviderConfigured($0.id) }) {
            selectedProviderID = first.id
        }
        updateAvailableModels()
    }
    
    func updateAvailableModels() {
        let aiManager = AIManager.shared
        
        // Handle Ollama special case (needs fetch usually, but we rely on what's cached or fetch if empty)
        if selectedProviderID == "ollama" && aiManager.ollamaModels.isEmpty {
            Task {
                await aiManager.fetchOllamaModels()
                self.availableModels = aiManager.ollamaModels.map(\.name)
                self.selectDefaultModel()
            }
        } else if selectedProviderID == "ollama" {
             self.availableModels = aiManager.ollamaModels.map(\.name)
             self.selectDefaultModel()
        } else {
            // Standard providers
            self.availableModels = aiManager.provider(for: selectedProviderID)?.availableModels ?? []
            self.selectDefaultModel()
        }
    }
    
    private func selectDefaultModel() {
        if !availableModels.contains(selectedModel) {
            selectedModel = availableModels.first ?? ""
        }
    }

    // MARK: - Execute Action

    func execute(action: CodeAction) async {
        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please paste some code first."
            return
        }

        guard let provider = AIManager.shared.provider(for: selectedProviderID) else {
            errorMessage = "Selected provider is not configured."
            return
        }

        detectLanguage()
        isProcessing = true
        errorMessage = nil
        result = ""
        lastAction = action

        let prompt = """
        Language: \(detectedLanguage)

        \(action.prompt)

        ```\(detectedLanguage.lowercased())
        \(code)
        ```
        """

        do {
            var settings = AIManager.shared.settings
            // Override model if specific one selected
            if !selectedModel.isEmpty {
                settings.modelName = selectedModel
            }
            
            let response = try await provider.sendMessage(prompt, conversation: [], settings: settings)
            result = response.content
            
            // Track usage
            UsageManager.shared.track(response: response)
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }
}
