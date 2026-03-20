# Implementation Plan: Vision Image Input

## Overview

Extend Jiano's chat interface with image attachment support. Work proceeds bottom-up: data layer first (types + persistence), then provider integration, then ViewModel logic, then UI.

## Tasks

- [x] 1. Extend core data types with image support
  - [x] 1.1 Add `ImagePayload` struct and extend `MessageDTO` in `AIProvider.swift`
    - Add `struct ImagePayload: Sendable { let data: Data; let mimeType: String }` to `AIProvider.swift`
    - Add `images: [ImagePayload]` field to `MessageDTO` (default empty)
    - Update `ChatMessage.toDTO` extension to populate `images` from `imageData`/`imageMIMETypes`
    - _Requirements: 9.1, 9.2, 9.3, 9.4_

  - [x] 1.2 Write property test for `toDTO` image count invariant
    - **Property 8: toDTO image count invariant**
    - **Validates: Requirements 9.3, 9.5**

- [x] 2. Extend `ChatMessage` SwiftData model with image persistence
  - [x] 2.1 Add `imageData` and `imageMIMETypes` fields to `ChatMessage`
    - Add `@Attribute(.externalStorage) var imageData: [Data]` initialized to `[]`
    - Add `var imageMIMETypes: [String]` initialized to `[]`
    - Update `init` to accept and default both fields
    - Extend `CodingKeys`, `init(from:)`, and `encode(to:)` for both new fields
    - _Requirements: 5.1, 5.2, 5.5_

  - [x] 2.2 Write property test for image persistence round-trip
    - **Property 7: Image persistence round-trip**
    - **Validates: Requirements 5.2, 5.3, 5.5**

- [x] 3. Checkpoint — Ensure all tests pass, ask the user if questions arise.

- [x] 4. Add `ImageAttachment` type and attachment state to `ChatViewModel`
  - [x] 4.1 Define `ImageAttachment` struct and add pending state to `ChatViewModel`
    - Add `struct ImageAttachment: Identifiable, Sendable` (id, data, mimeType, filename) — can live in `ChatViewModel.swift` or a new `ImageAttachment.swift`
    - Add `var pendingAttachments: [ImageAttachment] = []` and `var attachmentError: String?` to `ChatViewModel`
    - _Requirements: 3.1, 3.4, 10.5_

  - [x] 4.2 Implement `addAttachments(_ urls: [URL])` on `ChatViewModel`
    - Validate each URL's UTType against `jpeg`, `png`, `gif`, `webP`, `heic`; set `attachmentError` and skip on failure
    - Read file data; reject files > 20 MB with error; skip on failure
    - Enforce 5-image cap: add up to remaining slots, set `attachmentError` if limit hit
    - _Requirements: 1.3, 1.5, 1.6, 2.3, 2.4, 2.5, 10.1, 10.2, 10.3, 10.4_

  - [x] 4.3 Write property test for attachment count cap
    - **Property 2: Attachment count never exceeds 5**
    - **Validates: Requirements 1.5, 2.5**

  - [x] 4.4 Write property test for valid file attachment adds to list
    - **Property 1: Valid file attachment adds to list**
    - **Validates: Requirements 1.3, 2.3**

  - [x] 4.5 Write property test for invalid UTType rejection
    - **Property 3: Invalid UTType files are rejected**
    - **Validates: Requirements 2.4, 10.1, 10.2**

  - [x] 4.6 Write property test for oversized file rejection
    - **Property 4: Oversized files are rejected**
    - **Validates: Requirements 10.4**

  - [x] 4.7 Implement `removeAttachment(id: UUID)` on `ChatViewModel`
    - Remove the attachment matching `id` from `pendingAttachments`
    - _Requirements: 3.4_

  - [x] 4.8 Write property test for clean deletion
    - **Property 5: Remove attachment is a clean deletion**
    - **Validates: Requirements 3.4**

  - [x] 4.9 Implement `openFilePicker()` on `ChatViewModel`
    - Present `NSOpenPanel` restricted to image UTTypes, allow multiple selection
    - On confirmation call `addAttachments` with selected URLs; on cancel no-op
    - _Requirements: 1.1, 1.2, 1.4_

- [x] 5. Update `ChatViewModel.sendMessage` to handle image attachments
  - [x] 5.1 Persist image data to `ChatMessage` and clear pending list after send
    - Before inserting the user `ChatMessage`, copy `pendingAttachments` data/mimeType into `userMessage.imageData` / `userMessage.imageMIMETypes`
    - Clear `pendingAttachments` and `attachmentError` after the message is saved
    - _Requirements: 5.3, 10.5_

  - [x] 5.2 Enforce per-image base64 size limits and strip images for non-vision providers
    - If `provider.supportsVision == false` and attachments are pending, send text only (images silently dropped)
    - Before sending, check each attachment's base64 size: > 5 MB for Anthropic → set `errorMessage`, abort; > 20 MB for OpenAI → set `errorMessage`, abort
    - _Requirements: 4.4, 7.5, 8.5_

  - [x] 5.3 Write property test for non-vision provider strips images
    - **Property 6: Non-vision provider strips images from request**
    - **Validates: Requirements 4.4**

- [x] 6. Checkpoint — Ensure all tests pass, ask the user if questions arise.

- [x] 7. Extend `AnthropicProvider.buildRequest` with vision content blocks
  - [x] 7.1 Add image content blocks to the Anthropic user message
    - When `dto.images` is non-empty, build `content` as an array: N image blocks (`type: "image"`, `source.type: "base64"`) followed by one text block
    - When `dto.images` is empty, keep `content` as a plain string (existing behavior)
    - Use `base64EncodedString()` with no line breaks (`.lineLength64Characters` option must NOT be used)
    - Update `buildRequest` signature to accept `MessageDTO` (or pass images alongside the message text)
    - _Requirements: 7.1, 7.2, 7.3, 7.4_

  - [x] 7.2 Write property test for Anthropic content block structure
    - **Property 9: Anthropic content block structure**
    - **Validates: Requirements 7.1, 7.2**

  - [x] 7.3 Write property test for text-only backward compatibility (Anthropic)
    - **Property 11: Text-only backward compatibility**
    - **Validates: Requirements 7.4**

- [x] 8. Extend `OpenAIProvider.buildRequest` with vision content blocks
  - [x] 8.1 Add image_url content blocks to the OpenAI user message
    - When `dto.images` is non-empty, build `content` as an array: N image_url blocks (`type: "image_url"`, `image_url.url: "data:<mime>;base64,<data>"`) followed by one text block
    - When `dto.images` is empty, keep `content` as a plain string (existing behavior)
    - _Requirements: 8.1, 8.2, 8.3, 8.4_

  - [x] 8.2 Write property test for OpenAI content block structure
    - **Property 10: OpenAI content block structure**
    - **Validates: Requirements 8.1, 8.2**

  - [x] 8.3 Write property test for base64 encoding round-trip
    - **Property 12: Base64 encoding round-trip**
    - **Validates: Requirements 7.3, 8.3**

- [x] 9. Checkpoint — Ensure all tests pass, ask the user if questions arise.

- [x] 10. Update `ChatInputBarView` with attachment UI
  - [x] 10.1 Add attachment button and thumbnail strip
    - Add paperclip/photo button to the left of the text field; tapping calls `chatVM.openFilePicker()`
    - Add a horizontal `ScrollView` thumbnail strip above the text field, visible only when `!chatVM.pendingAttachments.isEmpty`
    - Each thumbnail: 64×64 pt, rounded corners, `Image` from `NSImage(data:)`, with an `×` remove button on hover
    - _Requirements: 1.1, 3.1, 3.2, 3.3, 3.4, 3.5_

  - [x] 10.2 Add drag-and-drop support to the text input area
    - Apply `.onDrop(of: [.image, .fileURL], ...)` to the text input container
    - Show a visual highlight while dragging over the drop zone
    - On drop, extract file URLs and call `chatVM.addAttachments`
    - _Requirements: 2.1, 2.2, 2.3_

  - [x] 10.3 Add vision warning banner and attachment error label
    - Show a non-blocking inline warning banner when `!provider.supportsVision && !chatVM.pendingAttachments.isEmpty`
    - Show an inline error label driven by `chatVM.attachmentError`; auto-clear on next successful add or send
    - _Requirements: 4.1, 4.2, 4.3, 1.6, 2.4, 2.5_

- [x] 11. Update `MessageBubbleView` with inline image rendering
  - [x] 11.1 Render images above text content in the user bubble
    - Inside `userBubble`, if `!message.imageData.isEmpty`, render a `LazyVGrid` or `HStack` of images above the `Text`
    - Each image: max 300×300 pt, aspect ratio preserved, rounded corners
    - Render images in `imageData` order
    - Show placeholder (`Image(systemName: "photo")` + "Image unavailable") for any `Data` that fails `NSImage(data:)` init
    - _Requirements: 6.1, 6.2, 6.3, 6.5_

  - [x] 11.2 Write property test for image rendering order
    - **Property 13: Image rendering order matches attachment order**
    - **Validates: Requirements 6.3**

  - [x] 11.3 Write property test for invalid image data placeholder
    - **Property 14: Invalid image data shows placeholder**
    - **Validates: Requirements 6.5**

  - [x] 11.4 Add full-screen image overlay on tap
    - Add `@State var fullScreenImage: NSImage?` to `MessageBubbleView`
    - Tapping an image sets `fullScreenImage`; present a `.sheet` or `.overlay` with the full image and a close button
    - _Requirements: 6.4_

- [x] 12. Final checkpoint — Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Property tests use SwiftCheck or swift-testing with custom generators (minimum 100 iterations each)
- Each property test is tagged: `Feature: vision-image-input, Property N: <property text>`
- `buildRequest` in both providers needs to receive image data — thread the `MessageDTO` (or its images) through the call; the existing `message: String` + `conversation: [MessageDTO]` signature will need adjustment so the current user message is also a full `MessageDTO`
