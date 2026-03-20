<p align="center">
  <img src="assets/logo.svg" width="256" height="256" alt="Jiano Logo" />
</p>

<h1 align="center">Jiano</h1>

<p align="center">
  <strong>A native macOS AI Workstation — one app, every provider.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue?style=flat-square" alt="Platform" />
  <img src="https://img.shields.io/badge/swift-5.9-orange?style=flat-square" alt="Swift" />
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="License" />
  <img src="https://img.shields.io/badge/providers-11-purple?style=flat-square" alt="Providers" />
</p>

---

OpusNative is a **native macOS application** built with SwiftUI and SwiftData that connects you to multiple AI providers through a single, premium interface. Switch between Anthropic Claude, OpenAI GPT, Google Gemini, xAI Grok, HuggingFace, Ollama (local), OpenRouter, LiteLLM, LM Studio, Azure OpenAI, Custom Generic APIs, and AWS Bedrock — or compare them side-by-side in real time.

## ✨ Features

### 💬 Multi-Provider Chat
- **11 AI providers** in one unified interface — switch with a single click
- **Real-time streaming** via SSE and NDJSON
- Support for **System Prompts / Personas** and **Custom API Endpoints** with live sync
- Full conversation history persisted with SwiftData (branch-aware message threading)
- **Vision / Image Input**: attach up to 5 images per message via file picker or drag-and-drop; inline thumbnail strip, full-screen tap-to-expand, and automatic base64 encoding for Anthropic and OpenAI vision APIs
- Premium glassmorphism dark mode UI with smooth micro-animations

### ⚖️ Provider Comparison
- Send the **same prompt to multiple providers** simultaneously
- Dynamic **Compare Model Selector** to add/remove models on the fly
- Results displayed side-by-side with color-coded latency ranking

### 🛠 Code Assistant & Plugins
- **5 built-in code actions**: Explain, Review, Optimize, Find Bugs, Generate Tests
- Split-pane editor with automatic language detection
- **Plugin System** for custom tools and third-party integrations
- **Prompt Library** & **Command Palette** for fast workflow access

### 🔌 Provider Ecosystem
| Provider | Type | Vision |
|----------|------|--------|
| Anthropic Claude | Cloud | ✅ |
| OpenAI GPT | Cloud | ✅ |
| Google Gemini | Cloud | ✅ |
| xAI Grok | Cloud | — |
| HuggingFace | Cloud | — |
| AWS Bedrock | Cloud | — |
| OpenRouter | Cloud | — |
| LiteLLM | Self-hosted | — |
| LM Studio | Local | — |
| Azure OpenAI | Cloud | ✅ |
| Ollama | Local | — |
| Custom Generic API | Any | — |

### 🔧 System Tools
| Tool | Description |
|------|-------------|
| **File Analyzer** | Drag-and-drop any file for AI-powered analysis |
| **Clipboard Monitor** | Auto-detect clipboard content and analyze with AI |
| **Screenshot Analyzer** | Capture your screen and get AI vision analysis |

### 🧠 Advanced Embeddings & Search
- **Semantic Search**: Find relevant past conversations using cosine vector similarity.
- **Advanced Workspace**: K-Means clustering, Anomaly Detection, PCA, and specialized t-SNE engines.
- **Radar Charts & Heatmaps**: Compare models across axes like Speed, Context, Cost, and Intelligence.

### ☁️ Cloud Backup & Data
- Encrypted S3 backups with **AES-256-GCM** encryption and AWS SigV4 authentication
- **Binary VectorStore format** with metadata for efficient memory and storage handling
- **Export Conversations** to Markdown, raw JSON, or Jupyter Notebook format.

### 📊 Observability & Performance
- **System Health Dashboard**: Real-time charts for latency, error rates, and token throughput.
- **Performance Mode**: Auto-throttles UI effects based on thermal state.
- **Robust Queueing & Error Recovery**: Smart error boundaries, request retries, and rate-limit handling.

### 🔐 Security First
- All API keys stored in **macOS Keychain** — never in UserDefaults or plaintext
- Per-provider credential management

---

## 🏗 Architecture

```
OpusNative/Sources/OpusNative/
├── Core/                    # Protocol layer (AIProvider, AppDIContainer)
├── Managers/                # Application Logic Orchestration
├── Providers/               # AI Implementations (Anthropic, OpenAI, Ollama, Gemini, Grok, etc.)
├── Features/                # Functional Modules
│   ├── Embeddings/          # Vector Store, t-SNE Engine, Anomaly Detection
│   ├── Reporting/           # Export Logic & Notebook execution
│   └── S3BackupManager/
├── ViewModels/              # MVVM State Objects
├── Models/                  # SwiftData Models
├── Views/                   # SwiftUI Interface
│   ├── Chat/                # Main Chat, Input Toolbar, Empty States
│   ├── Compare/             # Side-by-Side Model Comparison
│   ├── Settings/            # Modular Settings Tabs
│   ├── Observability/       # Health Dashboard
│   └── Components/          # Reusable UI (Bubbles, Badges, Layouts)
└── Services/                # Low-level helpers (Keychain, Networking)
```

**Design Principles:**
- **MVVM** with `@Observable` and Swift Concurrency (`async/await`)
- **Protocol-oriented** — all providers share `AIProvider` with `Sendable` compliance
- **Zero external dependency networking** where possible, pure Foundation networking
- **SwiftData** for lightweight persistence and automatic migrations
- **Clean Architecture** via highly modular UI and Dependency Injection (AppDIContainer)

---

## 🚀 Getting Started

### Requirements
- **macOS 14.0+** (Sonoma)
- **Xcode 15.0+**
- At least one AI provider API key

### Build & Run

```bash
git clone https://github.com/Rudra-iitg/OpusNative.git
cd OpusNative
open OpusNative.xcodeproj
```

Press **⌘R** in Xcode to build and run.

### Configure Providers

1. Open the app → **Settings** (⌘,)
2. Navigate to the **Providers** tab
3. Add your API key(s) for your desired services (OpenAI, Anthropic, Gemini, Grok, HuggingFace, AWS Bedrock, etc.)

---

## 🎨 UI Design

The interface features a **premium dark aesthetic** redesigned for maximum developer experience:
- Modular Chat Input and Provider Toolbars
- Custom FlowLayouts and Provider Badges
- Dynamic gradient backgrounds & Glassmorphism cards
- Smooth micro-animations and streaming message bubbles

---

## 🤝 Contributing

Contributions are welcome! Feel free to:
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  Built with ❤️ using SwiftUI
</p>
