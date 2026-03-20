# Requirements Document

## Introduction

This feature adds vision/image input support to Jiano (OpusNative), a macOS SwiftUI AI playground app. Users will be able to attach images to chat messages via drag-and-drop or a file picker, preview thumbnails before sending, see images rendered inline in message bubbles, and have images transmitted as base64-encoded content to vision-capable providers (Anthropic and OpenAI). Image data is persisted alongside messages in SwiftData. Providers that do not support vision display a warning rather than silently dropping images.

## Glossary

- **Chat_Input_Bar**: The `ChatInputBarView` component at the bottom of the chat screen where users compose messages.
- **Message_Bubble**: The `MessageBubbleView` component that renders a single chat message.
- **Image_Attachment**: An image selected by the user to be sent alongside a text message.
- **Attachment_Thumbnail**: A small preview of an Image_Attachment shown in the Chat_Input_Bar before sending.
- **Chat_Message**: The `ChatMessage` SwiftData model that persists a single message.
- **Message_DTO**: The `MessageDTO` struct used to pass conversation history to providers across concurrency boundaries.
- **Provider**: Any type conforming to the `AIProvider` protocol (e.g., `AnthropicProvider`, `OpenAIProvider`).
- **Vision_Provider**: A Provider whose `supportsVision` property is `true`.
- **Chat_View_Model**: The `ChatViewModel` observable class that drives the chat experience.
- **Image_Store**: The subsystem responsible for persisting and loading image data associated with Chat_Messages.
- **Base64_Encoder**: The subsystem responsible for encoding raw image `Data` into a base64 string suitable for API payloads.

---

## Requirements

### Requirement 1: Image Attachment via File Picker

**User Story:** As a user, I want to attach images to my messages using a file picker button, so that I can easily select images from my Mac without dragging them.

#### Acceptance Criteria

1. THE Chat_Input_Bar SHALL display an image attachment button (paperclip or photo icon) to the left of the text input field.
2. WHEN the user clicks the attachment button, THE Chat_Input_Bar SHALL open a native `NSOpenPanel` restricted to image file types (JPEG, PNG, GIF, WebP, HEIC).
3. WHEN the user selects one or more image files in the panel, THE Chat_View_Model SHALL add each selected file as an Image_Attachment to the pending attachment list.
4. IF the user cancels the `NSOpenPanel`, THEN THE Chat_Input_Bar SHALL leave the pending attachment list unchanged.
5. THE Chat_Input_Bar SHALL allow attaching up to 5 images per message.
6. IF the user attempts to attach more than 5 images, THEN THE Chat_Input_Bar SHALL display an inline error message stating the 5-image limit has been reached.

---

### Requirement 2: Image Attachment via Drag-and-Drop

**User Story:** As a user, I want to drag images directly into the chat input area, so that I can attach images without navigating a file picker.

#### Acceptance Criteria

1. THE Chat_Input_Bar SHALL accept drag-and-drop of image files (JPEG, PNG, GIF, WebP, HEIC) onto the text input area.
2. WHEN an image file is dragged over the text input area, THE Chat_Input_Bar SHALL display a visual drop target highlight.
3. WHEN the user drops one or more valid image files onto the text input area, THE Chat_View_Model SHALL add each dropped file as an Image_Attachment to the pending attachment list.
4. IF a dropped file is not a supported image type, THEN THE Chat_Input_Bar SHALL display an inline error message identifying the unsupported file type and SHALL NOT add it to the pending attachment list.
5. IF adding dropped images would exceed the 5-image limit, THEN THE Chat_Input_Bar SHALL add images up to the limit and display an inline error message stating the limit has been reached.

---

### Requirement 3: Attachment Thumbnail Preview

**User Story:** As a user, I want to see thumbnail previews of my attached images before sending, so that I can confirm the correct images are attached.

#### Acceptance Criteria

1. WHEN the pending attachment list contains at least one Image_Attachment, THE Chat_Input_Bar SHALL display a horizontal scrollable row of Attachment_Thumbnails above the text input field.
2. THE Chat_Input_Bar SHALL render each Attachment_Thumbnail at 64×64 points with a rounded corner style.
3. WHEN the user hovers over an Attachment_Thumbnail, THE Chat_Input_Bar SHALL display a remove button (×) overlaid on the thumbnail.
4. WHEN the user clicks the remove button on an Attachment_Thumbnail, THE Chat_View_Model SHALL remove the corresponding Image_Attachment from the pending attachment list.
5. WHEN the pending attachment list becomes empty, THE Chat_Input_Bar SHALL hide the thumbnail row.

---

### Requirement 4: Vision Provider Capability Warning

**User Story:** As a user, I want to be warned when the active provider does not support vision, so that I understand why my images will not be sent.

#### Acceptance Criteria

1. WHILE the pending attachment list contains at least one Image_Attachment AND the active Provider's `supportsVision` is `false`, THE Chat_Input_Bar SHALL display a non-blocking inline warning banner stating that the active provider does not support image input.
2. WHEN the active Provider changes to a Vision_Provider, THE Chat_Input_Bar SHALL hide the vision warning banner.
3. WHEN the active Provider changes to a non-vision Provider, THE Chat_Input_Bar SHALL show the vision warning banner if Image_Attachments are pending.
4. IF the user sends a message while the active Provider's `supportsVision` is `false` AND the pending attachment list is non-empty, THEN THE Chat_View_Model SHALL send only the text content and SHALL NOT include image data in the API request.

---

### Requirement 5: Image Data Persistence in ChatMessage

**User Story:** As a user, I want images I sent to be stored with the message, so that they are visible when I scroll back through conversation history.

#### Acceptance Criteria

1. THE Chat_Message SHALL store image attachments as an array of `Data` values using a SwiftData `@Attribute(.externalStorage)` annotation to avoid bloating the SQLite store.
2. THE Chat_Message SHALL store the corresponding MIME type string (e.g., `"image/jpeg"`) for each stored image `Data` value.
3. WHEN a user message is saved with Image_Attachments, THE Image_Store SHALL persist each attachment's `Data` and MIME type on the Chat_Message.
4. WHEN a Chat_Message is loaded from SwiftData, THE Image_Store SHALL make the stored image `Data` available for rendering in the Message_Bubble.
5. THE Chat_Message SHALL preserve the order of Image_Attachments as they were attached by the user.

---

### Requirement 6: Inline Image Rendering in Message Bubbles

**User Story:** As a user, I want to see images rendered inline in message bubbles, so that I can review what was sent in context with the conversation.

#### Acceptance Criteria

1. WHEN a Chat_Message contains one or more stored image `Data` values, THE Message_Bubble SHALL render each image above the text content of the message.
2. THE Message_Bubble SHALL render each image with a maximum display size of 300×300 points, preserving the original aspect ratio.
3. THE Message_Bubble SHALL render images in the same order they were attached.
4. WHEN the user clicks an image in a Message_Bubble, THE Message_Bubble SHALL present the image in a full-screen overlay with a close button.
5. IF image `Data` cannot be decoded into a displayable image, THEN THE Message_Bubble SHALL display a placeholder icon with the text "Image unavailable" in place of the broken image.

---

### Requirement 7: Anthropic Provider Vision Integration

**User Story:** As a developer, I want the Anthropic provider to send images as base64 content blocks, so that Claude models can analyze attached images.

#### Acceptance Criteria

1. WHEN `AnthropicProvider.buildRequest` is called with a Message_DTO that contains image data, THE AnthropicProvider SHALL construct a content array containing one image content block per attachment followed by a text content block.
2. THE AnthropicProvider SHALL format each image content block as `{"type": "image", "source": {"type": "base64", "media_type": "<mime_type>", "data": "<base64_string>"}}`.
3. THE Base64_Encoder SHALL encode image `Data` using standard base64 encoding without line breaks.
4. WHEN `AnthropicProvider.buildRequest` is called with a Message_DTO that contains no image data, THE AnthropicProvider SHALL send the message content as a plain string (existing behavior preserved).
5. IF the base64-encoded size of a single image exceeds 5 MB, THEN THE Chat_View_Model SHALL reject that attachment before sending and SHALL display an error message stating the image is too large.

---

### Requirement 8: OpenAI Provider Vision Integration

**User Story:** As a developer, I want the OpenAI provider to send images as base64 data URLs, so that GPT-4o and other vision models can analyze attached images.

#### Acceptance Criteria

1. WHEN `OpenAIProvider.buildRequest` is called with a Message_DTO that contains image data, THE OpenAIProvider SHALL construct a content array containing one image_url content block per attachment followed by a text content block.
2. THE OpenAIProvider SHALL format each image content block as `{"type": "image_url", "image_url": {"url": "data:<mime_type>;base64,<base64_string>"}}`.
3. THE Base64_Encoder SHALL encode image `Data` using standard base64 encoding without line breaks.
4. WHEN `OpenAIProvider.buildRequest` is called with a Message_DTO that contains no image data, THE OpenAIProvider SHALL send the message content as a plain string (existing behavior preserved).
5. IF the base64-encoded size of a single image exceeds 20 MB, THEN THE Chat_View_Model SHALL reject that attachment before sending and SHALL display an error message stating the image is too large.

---

### Requirement 9: MessageDTO Image Data Transport

**User Story:** As a developer, I want MessageDTO to carry image data across concurrency boundaries, so that providers can access image attachments without touching SwiftData models directly.

#### Acceptance Criteria

1. THE Message_DTO SHALL include an optional array of image payloads, where each payload contains a `Data` value and a MIME type string.
2. THE Message_DTO SHALL remain `Sendable` after the addition of image payload fields.
3. WHEN `ChatMessage.toDTO` is called on a message with stored image attachments, THE Message_DTO SHALL be populated with the corresponding image payloads.
4. WHEN `ChatMessage.toDTO` is called on a message with no stored image attachments, THE Message_DTO image payload array SHALL be empty.
5. FOR ALL Message_DTO values constructed from a Chat_Message, the count of image payloads in the DTO SHALL equal the count of stored image Data values on the Chat_Message (round-trip count invariant).

---

### Requirement 10: Image Size and Format Validation

**User Story:** As a user, I want invalid or oversized images to be rejected with a clear error, so that I don't accidentally send files that will fail at the API level.

#### Acceptance Criteria

1. WHEN an image file is selected or dropped, THE Chat_View_Model SHALL validate that the file's UTType conforms to one of: `UTType.jpeg`, `UTType.png`, `UTType.gif`, `UTType.webP`, `UTType.heic`.
2. IF an image file fails UTType validation, THEN THE Chat_View_Model SHALL display an error message naming the rejected file and SHALL NOT add it to the pending attachment list.
3. WHEN an image is added to the pending attachment list, THE Chat_View_Model SHALL read the file data and check that the raw byte size does not exceed 20 MB.
4. IF an image file exceeds 20 MB, THEN THE Chat_View_Model SHALL display an error message stating the file size limit and SHALL NOT add it to the pending attachment list.
5. WHEN the pending attachment list is cleared after a message is sent, THE Chat_View_Model SHALL release all in-memory image Data held for pending attachments.
