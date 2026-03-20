# Implementation Plan: Context Window Override

## Overview

Extend `ContextManager` with a two-level override system, expand the model lookup table, improve heuristic detection, surface a global default control in Settings, and add an inline session override picker to `ContextUsageBar`. Changes are ordered bottom-up: core manager logic first, then Settings UI, then chat UI, then ChatViewModel wiring.

## Tasks

- [x] 1. Expand ContextManager model lookup table and fix fallback
  - In `Jiano/Sources/Jiano/Managers/ContextManager.swift`, add the 14 new entries to `modelLimits`: `moonshotai/kimi-k2-instruct` → 131,072; `kimi-k2-instruct` → 131,072; `gpt-4o-mini` → 128,000; `o1` → 200,000; `o1-preview` → 128,000; `o1-mini` → 128,000; `grok-2` → 131,072; `grok-2-1212` → 131,072; `grok-beta` → 131,072; `gemini-2.0-flash` → 1,000,000; `gemini-2.0-flash-lite` → 1,000,000; `gemini-2.5-pro-preview-05-06` → 2,000,000; `gemma3:latest` → 128,000; `codellama` → 16,384
  - Update `detectLimit(for:)` to add `claude` → 200,000 and `gpt-4` → 128,000 heuristics, remove the `pro` heuristic, and change the final fallback from `8_192` to `128_000`
  - _Requirements: 1.1, 1.3, 2.1, 2.2, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

- [x] 2. Add ContextPreset, resolveLimit, manualOverride, and globalDefaultLimit to ContextManager
  - [x] 2.1 Add `ContextPreset` nested struct and `static let presets` array
    - Define `struct ContextPreset: Identifiable` with `id: UUID`, `label: String`, `tokens: Int` inside `ContextManager`
    - Add `static let presets: [ContextPreset]` with the 10 entries: Auto (0), 4k (4,096), 8k (8,192), 16k (16,384), 32k (32,768), 64k (65,536), 128k (131,072), 200k (200,000), 1M (1,000,000), 2M (2,000,000)
    - _Requirements: 7.1, 7.2, 7.3_

  - [x] 2.2 Add `manualOverride`, `isManualOverride`, and `clearOverride()`
    - Add `var manualOverride: Int?` observable property (default `nil`)
    - Add `var isManualOverride: Bool { manualOverride != nil }` computed property
    - Add `@MainActor func clearOverride()` that sets `manualOverride = nil`
    - _Requirements: 5.1, 5.2, 5.3, 5.4_

  - [x] 2.3 Add `globalDefaultLimit` UserDefaults-backed property
    - Add `var globalDefaultLimit: Int` computed property that reads/writes `UserDefaults.standard` under key `"contextWindowGlobalDefault"`, returning `0` if the key is absent
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

  - [x] 2.4 Implement `resolveLimit(for:)` with the full priority chain
    - Add `func resolveLimit(for model: String) -> Int` implementing the six-step chain: (1) `manualOverride` if > 0, (2) `globalDefaultLimit` if > 0, (3) exact `modelLimits[model]`, (4) case-insensitive partial key match, (5) `detectLimit(for:)`, (6) `128_000` fallback
    - Update `updateUsage(messages:model:)` to call `resolveLimit(for:)` instead of the inline lookup expression
    - _Requirements: 4.1, 4.2, 4.3_

  - [ ]* 2.5 Write property test for Property 1 — unknown model fallback is 128k
    - **Property 1: Unknown model fallback is 128k**
    - **Validates: Requirements 1.1, 1.3**

  - [ ]* 2.6 Write property test for Property 2 — exact lookup match is authoritative
    - **Property 2: Exact lookup match is authoritative**
    - **Validates: Requirements 2.2, 10.2**

  - [ ]* 2.7 Write property test for Property 3 — heuristic detection by substring
    - **Property 3: Heuristic detection by substring**
    - **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7**

  - [ ]* 2.8 Write property test for Property 4 — priority chain ordering
    - **Property 4: Priority chain ordering**
    - **Validates: Requirements 4.2, 5.2, 6.3**

  - [ ]* 2.9 Write property test for Property 5 — isManualOverride reflects manualOverride
    - **Property 5: isManualOverride reflects manualOverride**
    - **Validates: Requirements 5.3, 5.4**

  - [ ]* 2.10 Write property test for Property 6 — globalDefaultLimit round-trips through UserDefaults
    - **Property 6: globalDefaultLimit round-trips through UserDefaults**
    - **Validates: Requirements 6.1, 6.4**

- [x] 3. Checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Add global default control to SettingsModelTab
  - In `Jiano/Sources/Jiano/Views/Settings/SettingsModelTab.swift`, add a `SettingsCardView` titled "Context Window Default" with icon `text.alignleft` below the existing Top P card
  - Inside the card, add a description label explaining the global default purpose
  - Render a horizontally scrolling `ScrollView(.horizontal)` row of preset chips, one per `ContextManager.presets` entry, plus a "Custom" chip; chips should be pill-shaped buttons that visually distinguish the selected chip
  - Tapping a preset chip sets `ContextManager.shared.globalDefaultLimit` to the preset's `tokens` value
  - Tapping "Custom" reveals a `TextField` that accepts a positive integer and commits it to `ContextManager.shared.globalDefaultLimit` on valid input; display an inline validation hint for invalid input
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6_

- [x] 5. Add session override picker to ContextUsageBar
  - [x] 5.1 Add `@Environment(AppDIContainer.self)` and `@State var showPicker` to ContextUsageBar
    - Import `AppDIContainer` environment and add `@State private var showPicker = false` in `Jiano/Sources/Jiano/Views/Chat/ContextUsageBar.swift`
    - _Requirements: 9.9_

  - [x] 5.2 Add override button to the percentage label row
    - In the `HStack` labels row, add a `Button` on the right side of the percentage label
    - When `diContainer.contextManager.isManualOverride` is false, render a `chevron.down` system image
    - When true, render a `lock.fill` system image and "Override" text, both in `.orange`
    - Tapping the button toggles `showPicker`
    - _Requirements: 9.1, 9.2, 9.3, 9.4_

  - [x] 5.3 Implement the inline override picker panel
    - Below the labels `HStack`, conditionally show the picker panel when `showPicker` is true, animated with `.spring(response: 0.3, dampingFraction: 0.8)`
    - The panel contains a horizontally scrolling row of preset chips for all `ContextManager.presets` entries excluding Auto
    - Tapping a preset chip sets `diContainer.contextManager.manualOverride` to the preset's `tokens` value and sets `showPicker = false`
    - Add a "Clear Override" button that calls `diContainer.contextManager.clearOverride()` and sets `showPicker = false`
    - _Requirements: 9.4, 9.5, 9.6, 9.7, 9.8_

  - [ ]* 5.4 Write property test for Property 7 — context bar color thresholds
    - Extract `fillColor` logic into a `static func fillColor(for percentage: Double) -> Color` to make it testable
    - **Property 7: Context bar color thresholds**
    - **Validates: Requirements 9.10, 10.3**

- [x] 6. Wire clearOverride into ChatViewModel conversation switch
  - In `Jiano/Sources/Jiano/ViewModels/ChatViewModel.swift`, update the `selectedConversation` `didSet` to call `diContainer.contextManager.clearOverride()` before calling `updateUsage`
  - _Requirements: 5.5_

- [x] 7. Final checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Property tests require [SwiftCheck](https://github.com/typelift/SwiftCheck) added as a package dependency in a `ContextWindowOverrideTests` test target
- `SettingsModelTab` uses `ContextManager.shared` (not DI) per the existing Settings architecture
- `ContextUsageBar` must use `@Environment(AppDIContainer.self)` exclusively — never `ContextManager.shared`
