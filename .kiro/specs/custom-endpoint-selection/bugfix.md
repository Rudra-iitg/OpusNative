# Bugfix Requirements Document

## Introduction

Custom OpenAI-compatible endpoints added by the user in Settings are never reflected in `AIManager`'s provider list after app launch. `registerDefaultProviders()` runs once at `AIManager.init`, so any endpoint added, edited, or deleted afterward has no effect on the live provider registry. As a result, the provider picker in `ChatProviderToolbarView` (and anywhere else providers are listed) never shows newly added custom endpoints, and users must restart the app to see them — if they appear at all.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN a user adds a new custom endpoint via `SettingsGenericEndpointsView` THEN the system does not register a corresponding provider in `AIManager`, so the endpoint never appears in the provider picker

1.2 WHEN a user edits an existing custom endpoint (name, URL, model, API key) THEN the system does not update the matching provider in `AIManager`, so the picker continues to show stale data

1.3 WHEN a user deletes a custom endpoint via `SettingsGenericEndpointsView` THEN the system does not remove the corresponding provider from `AIManager`, so the deleted endpoint continues to appear in the provider picker until the app is restarted

1.4 WHEN the app is running and `GenericEndpointManager.endpoints` changes THEN the system does not propagate those changes to `AIManager.providers`, leaving the two out of sync

### Expected Behavior (Correct)

2.1 WHEN a user adds a new custom endpoint THEN the system SHALL immediately register a `GenericOpenAICompatibleProvider` for that endpoint in `AIManager`, making it selectable in the provider picker without restarting

2.2 WHEN a user edits an existing custom endpoint THEN the system SHALL update the corresponding provider in `AIManager` in real-time, so the picker reflects the latest name, URL, and model

2.3 WHEN a user deletes a custom endpoint THEN the system SHALL immediately unregister the corresponding provider from `AIManager`, removing it from the provider picker

2.4 WHEN `GenericEndpointManager.endpoints` changes for any reason THEN the system SHALL keep `AIManager.providers` in sync with the current set of custom endpoints

### Unchanged Behavior (Regression Prevention)

3.1 WHEN the app launches with previously saved custom endpoints THEN the system SHALL CONTINUE TO register those endpoints as providers during `AIManager` initialization

3.2 WHEN a user selects a built-in provider (Anthropic, OpenAI, Gemini, etc.) THEN the system SHALL CONTINUE TO list and switch to those providers without any change in behavior

3.3 WHEN a user switches to a custom endpoint provider in the chat toolbar THEN the system SHALL CONTINUE TO use that provider for AI requests as before

3.4 WHEN a custom endpoint is registered and the user has not changed it THEN the system SHALL CONTINUE TO preserve its provider ID (`generic-<uuid>`) so that any persisted `activeProviderID` referencing it remains valid

---

## Bug Condition Pseudocode

**Bug Condition Function** — identifies the inputs that trigger the bug:

```pascal
FUNCTION isBugCondition(X)
  INPUT: X of type EndpointMutationEvent
         (where EndpointMutationEvent = { operation: add | edit | delete, endpoint: SavedEndpoint })
  OUTPUT: boolean

  // The bug fires whenever GenericEndpointManager is mutated after AIManager.init
  RETURN X.operation IN { add, edit, delete }
         AND AIManager has already completed init
END FUNCTION
```

**Property: Fix Checking** — desired behavior for buggy inputs:

```pascal
FOR ALL X WHERE isBugCondition(X) DO
  result ← AIManager.providers  // observed after the mutation
  ASSERT result reflects the current state of GenericEndpointManager.endpoints
         (i.e., every endpoint has a matching provider, no stale/missing entries)
END FOR
```

**Property: Preservation Checking** — non-buggy inputs must be unaffected:

```pascal
FOR ALL X WHERE NOT isBugCondition(X) DO
  // Built-in provider registrations and behavior
  ASSERT F(X) = F'(X)
END FOR
```
