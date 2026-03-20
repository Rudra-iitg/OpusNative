# Requirements Document

## Introduction

This feature adds a two-level context window override system to Jiano's existing context tracking infrastructure. Currently, `ContextManager.detectLimit(for:)` falls back to 8,192 tokens for unrecognized models, causing models like `moonshotai/kimi-k2-instruct` (131k context) to display an artificially full context bar. The fix introduces: an expanded model lookup table, improved heuristic detection, a global default persisted in UserDefaults, and a per-session manual override settable directly from the chat panel. The priority chain is: session override → global default → auto-detect (exact match → partial match → heuristic → 128k fallback).

## Glossary

- **ContextManager**: The `@Observable` class responsible for tracking token usage, resolving context window limits, and exposing usage state to views.
- **ContextUsageBar**: The SwiftUI view rendered above the chat message list that displays a progress bar and token counts for the current context window.
- **SettingsModelTab**: The SwiftUI view in the Settings panel that exposes inference parameters (temperature, max tokens, top-p) and will host the new global context window default control.
- **AppDIContainer**: The dependency injection container that owns all manager instances; views must access `ContextManager` through it rather than via `ContextManager.shared`.
- **Session Override**: A per-conversation `Int?` value stored on `ContextManager` that overrides the resolved limit for the duration of the current conversation only.
- **Global Default**: A `UserDefaults`-backed integer (key `contextWindowGlobalDefault`) that applies to all conversations when no session override is active; `0` means auto-detect.
- **Auto-Detect**: The existing lookup table plus heuristic detection used when neither a session override nor a global default is set.
- **ContextPreset**: A named token-count pair (e.g. "128k" → 131,072) used to populate preset chip rows in the UI.
- **Preset Chip**: A tappable pill-shaped button representing a `ContextPreset` value.

## Requirements

### Requirement 1: Fix Fallback Token Limit

**User Story:** As a user running models not in the lookup table, I want the context bar to default to 128k tokens, so that the bar does not appear artificially full for modern large-context models.

#### Acceptance Criteria

1. THE ContextManager SHALL use 128,000 as the fallback token limit when no exact match, partial match, or heuristic match is found for a given model name.
2. WHEN the model name is `moonshotai/kimi-k2-instruct`, THE ContextManager SHALL resolve a limit of 131,072 tokens.
3. WHEN the model name is any string not present in the lookup table and not matching any heuristic pattern, THE ContextManager SHALL resolve a limit of 128,000 tokens rather than 8,192.

---

### Requirement 2: Expand Model Lookup Table

**User Story:** As a user of OpenAI, Grok, Gemini, Moonshot, or Ollama models, I want accurate context window sizes displayed, so that the context bar reflects the true capacity of the model I am using.

#### Acceptance Criteria

1. THE ContextManager SHALL include the following entries in its model limits dictionary:
   - `moonshotai/kimi-k2-instruct` → 131,072
   - `kimi-k2-instruct` → 131,072
   - `gpt-4o-mini` → 128,000
   - `o1` → 200,000
   - `o1-preview` → 128,000
   - `o1-mini` → 128,000
   - `grok-2` → 131,072
   - `grok-2-1212` → 131,072
   - `grok-beta` → 131,072
   - `gemini-2.0-flash` → 1,000,000
   - `gemini-2.0-flash-lite` → 1,000,000
   - `gemini-2.5-pro-preview-05-06` → 2,000,000
   - `gemma3:latest` → 128,000
   - `codellama` → 16,384
2. WHEN a model name exactly matches a key in the model limits dictionary, THE ContextManager SHALL return that entry's value as the resolved limit.

---

### Requirement 3: Improve Heuristic Detection

**User Story:** As a user of models whose names contain recognizable substrings, I want the context bar to use a reasonable limit even when the exact model ID is not in the lookup table, so that the bar is not misleadingly full.

#### Acceptance Criteria

1. WHEN the model name contains the substring `claude` (case-insensitive), THE ContextManager SHALL resolve a limit of 200,000 tokens via heuristic detection.
2. WHEN the model name contains the substring `gpt-4` (case-insensitive), THE ContextManager SHALL resolve a limit of 128,000 tokens via heuristic detection.
3. WHEN the model name contains the substring `gemini` (case-insensitive), THE ContextManager SHALL resolve a limit of 1,000,000 tokens via heuristic detection.
4. WHEN the model name contains the substring `flash` (case-insensitive), THE ContextManager SHALL resolve a limit of 1,000,000 tokens via heuristic detection.
5. WHEN the model name contains the substring `128k` (case-insensitive), THE ContextManager SHALL resolve a limit of 128,000 tokens via heuristic detection.
6. WHEN the model name contains the substring `32k` (case-insensitive), THE ContextManager SHALL resolve a limit of 32,000 tokens via heuristic detection.
7. WHEN the model name contains the substring `16k` (case-insensitive), THE ContextManager SHALL resolve a limit of 16,000 tokens via heuristic detection.

---

### Requirement 4: Limit Resolution Priority Chain

**User Story:** As a developer, I want a single, well-defined resolution order for context window limits, so that overrides are applied predictably and consistently.

#### Acceptance Criteria

1. THE ContextManager SHALL expose a `resolveLimit(for:)` function that returns an `Int` representing the resolved token limit for a given model name string.
2. WHEN `resolveLimit(for:)` is called, THE ContextManager SHALL evaluate candidates in this order and return the first non-zero match: (1) session override, (2) global default, (3) exact model name lookup, (4) case-insensitive partial model name match against lookup table keys, (5) heuristic pattern detection, (6) 128,000 fallback.
3. THE ContextManager SHALL use `resolveLimit(for:)` internally when computing `maxContext` inside `updateUsage(messages:model:)`.

---

### Requirement 5: Session Override

**User Story:** As a user, I want to set a temporary context window size for the current conversation, so that I can correct the displayed limit without affecting other conversations.

#### Acceptance Criteria

1. THE ContextManager SHALL expose a `manualOverride` property of type `Int?` that is `nil` by default.
2. WHEN `manualOverride` is set to a non-nil integer value, THE ContextManager SHALL use that value as the highest-priority input in `resolveLimit(for:)`.
3. THE ContextManager SHALL expose an `isManualOverride` computed property that returns `true` when `manualOverride` is not `nil` and `false` otherwise.
4. THE ContextManager SHALL expose a `@MainActor` `clearOverride()` method that sets `manualOverride` to `nil`.
5. WHEN the user selects a different conversation, THE ChatViewModel SHALL call `diContainer.contextManager.clearOverride()` so that the session override does not persist across conversations.

---

### Requirement 6: Global Default

**User Story:** As a user, I want to set a default context window size that applies to all conversations, so that I can correct the limit for providers whose models are not in the lookup table without adjusting it every session.

#### Acceptance Criteria

1. THE ContextManager SHALL expose a `globalDefaultLimit` computed property of type `Int` backed by `UserDefaults` under the key `contextWindowGlobalDefault`.
2. WHEN `globalDefaultLimit` is set to `0`, THE ContextManager SHALL treat it as "auto-detect" and not apply a global default in `resolveLimit(for:)`.
3. WHEN `globalDefaultLimit` is set to a positive integer, THE ContextManager SHALL use that value as the second-priority input in `resolveLimit(for:)`, applied only when no session override is active.
4. THE ContextManager SHALL persist the `globalDefaultLimit` value across app launches via `UserDefaults`.

---

### Requirement 7: Context Presets

**User Story:** As a user, I want a set of named preset token counts to choose from, so that I can quickly select a common context window size without typing a number.

#### Acceptance Criteria

1. THE ContextManager SHALL define a nested `ContextPreset` struct conforming to `Identifiable` with `label: String` and `tokens: Int` fields.
2. THE ContextManager SHALL expose a `static let presets: [ContextPreset]` array containing the following entries in order: Auto (0), 4k (4,096), 8k (8,192), 16k (16,384), 32k (32,768), 64k (65,536), 128k (131,072), 200k (200,000), 1M (1,000,000), 2M (2,000,000).
3. THE ContextManager SHALL make `presets` accessible without requiring an instance of `ContextManager`.

---

### Requirement 8: Settings UI — Global Default Control

**User Story:** As a user, I want a control in Settings → Model tab to set the global context window default, so that I can configure a persistent fallback without opening the chat panel.

#### Acceptance Criteria

1. THE SettingsModelTab SHALL display a `SettingsCardView` section titled "Context Window Default" with the system icon `text.alignleft` at the bottom of the existing inference parameter cards.
2. THE SettingsModelTab SHALL render a horizontally scrolling row of preset chips inside the card, one chip per entry in `ContextManager.presets`, plus a "Custom" chip.
3. WHEN a preset chip is tapped, THE SettingsModelTab SHALL set `ContextManager.shared.globalDefaultLimit` to the preset's `tokens` value (or `0` for the Auto chip).
4. WHEN the "Custom" chip is tapped, THE SettingsModelTab SHALL reveal a `TextField` allowing the user to enter an arbitrary positive integer token count.
5. WHEN a preset chip is selected, THE SettingsModelTab SHALL visually distinguish the selected chip from unselected chips.
6. THE SettingsModelTab SHALL display a brief description label inside the card explaining the purpose of the global default setting.

---

### Requirement 9: Chat Panel — Session Override UI

**User Story:** As a user, I want to set a per-session context window override directly from the context usage bar in the chat panel, so that I can quickly correct the displayed limit for the current conversation.

#### Acceptance Criteria

1. THE ContextUsageBar SHALL display a button on the right side of the percentage label row.
2. WHEN no session override is active, THE ContextUsageBar SHALL render the button as a `chevron.down` icon.
3. WHEN a session override is active, THE ContextUsageBar SHALL render the button as a `lock.fill` icon accompanied by an "Override" label, both styled in orange.
4. WHEN the override button is tapped, THE ContextUsageBar SHALL toggle an inline override picker panel below the bar row.
5. THE ContextUsageBar SHALL animate the picker panel open and closed using a spring animation with response 0.3 and damping fraction 0.8.
6. THE override picker panel SHALL contain a horizontally scrolling row of preset chips (one per `ContextManager.presets` entry, excluding Auto) and a "Clear Override" button.
7. WHEN a preset chip in the override picker is tapped, THE ContextUsageBar SHALL set `diContainer.contextManager.manualOverride` to the preset's `tokens` value and close the picker.
8. WHEN the "Clear Override" button is tapped, THE ContextUsageBar SHALL call `diContainer.contextManager.clearOverride()` and close the picker.
9. THE ContextUsageBar SHALL access `ContextManager` exclusively through `@Environment(AppDIContainer.self)` and never through `ContextManager.shared`.
10. THE ContextUsageBar SHALL preserve all existing color behavior: green below 75% usage, orange between 75% and 90%, red above 90%.

---

### Requirement 10: No Regressions

**User Story:** As a developer, I want all existing provider integrations and context bar behavior to continue working correctly after this change, so that the feature does not introduce regressions.

#### Acceptance Criteria

1. THE ContextManager SHALL continue to expose `currentUsage`, `usagePercentage`, and `maxContext` as `@Observable` properties consumed by existing views.
2. WHEN `updateUsage(messages:model:)` is called with a model that has an exact entry in the lookup table, THE ContextManager SHALL resolve the same limit as before this change.
3. THE ContextUsageBar SHALL continue to animate the progress bar using the existing spring animation on `percentage` changes.
4. IF a provider is not configured, THEN THE ChatViewModel SHALL continue to display an error message without calling `resolveLimit(for:)`.
