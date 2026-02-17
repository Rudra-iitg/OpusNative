<p align="center">
  <img src="OpusNative/Sources/OpusNative/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png" width="128" height="128" alt="OpusNative Icon" />
</p>

<h1 align="center">OpusNative</h1>

<p align="center">
  <strong>A native macOS AI Workstation — one app, every provider.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue?style=flat-square" alt="Platform" />
  <img src="https://img.shields.io/badge/swift-5.9-orange?style=flat-square" alt="Swift" />
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="License" />
  <img src="https://img.shields.io/badge/providers-5-purple?style=flat-square" alt="Providers" />
</p>

---

OpusNative is a **native macOS application** built with SwiftUI and SwiftData that connects you to multiple AI providers through a single, premium interface. Switch between Anthropic Claude, OpenAI GPT, HuggingFace, Ollama (local), and AWS Bedrock — or compare them side-by-side in real time.

## ✨ Features

### 💬 Multi-Provider Chat
- **5 AI providers** in one unified interface — switch with a single click
- **Real-time streaming** via SSE (Anthropic, OpenAI) and NDJSON (Ollama)
- Token counts, response latency, and provider badges on every message
- Full conversation history persisted with SwiftData

### ⚖️ Provider Comparison
- Send the **same prompt to multiple providers** simultaneously
- Results displayed side-by-side with color-coded latency ranking
- Compare response quality, speed, and token usage at a glance

### 🛠 Code Assistant
- **5 code actions**: Explain, Review, Optimize, Find Bugs, Generate Tests
- Split-pane editor with automatic language detection
- Markdown-rendered analysis results

### 🔧 System Tools
| Tool | Description |
|------|-------------|
| **File Analyzer** | Drag-and-drop any file for AI-powered analysis |
| **Clipboard Monitor** | Auto-detect clipboard content and analyze with AI |
| **Screenshot Analyzer** | Capture your screen and get AI vision analysis |

### ☁️ Cloud Backup
- Encrypted S3 backups with **AES-256-GCM** encryption
- AWS SigV4 authentication — no SDK dependency
- One-click backup and restore of all conversation data

### 📊 Observability & Performance
- **System Health Dashboard**: Real-time charts for latency, error rates, and token throughput.
- **Performance Mode**: Auto-throttles UI effects (blur/translucency) based on thermal state.
- **Structured Logging**: Centralized log/metric collection for debugging.

### 🧠 Advanced Embeddings & Search
- **Semantic Search**: Find relevant past conversations using vector similarity (cosine).
- **Vector Store**: In-memory, hardware-accelerated (Accelerate framework) embedding database.
- **Radar Charts**: Compare models across 4 axes: Speed, Context, Cost, and Intelligence.

### 🔍 Context & Inspector
- **Prompt Inspector**: View the exact raw prompt sent to the LLM (system + history).
- **Context Monitor**: Real-time usage bar tracking token limits per model.

### 📈 Reporting
- **Export Conversations**: Download chats as nicely formatted **Markdown** or raw **JSON**.
- **Metadata**: Includes timestamps, model used, and cost per message.

### 🔐 Security First
- All API keys stored in **macOS Keychain** — never in UserDefaults or plaintext
- Per-provider credential management
- Encrypted cloud backups

---

## 🏗 Architecture

```
OpusNative/Sources/OpusNative/
├── Core/                    # Protocol layer (AIProvider, AIResponse)
├── Managers/                # Application Logic
│   ├── AIManager.swift      # Provider orchestration
│   ├── UsageManager.swift   # Token counting & cost tracking
│   ├── ContextManager.swift # Context window limits
│   ├── ObservabilityManager # Logs & Metrics
│   └── PerformanceManager   # Thermal state & UI optimizations
├── Providers/               # AI Implementations (Anthropic, OpenAI, Ollama, etc.)
├── Features/                # Functional Modules
│   ├── Embeddings/          # Vector Store & Search Engines
│   ├── Reporting/           # Export Logic
│   ├── ScreenshotAnalyzer
│   └── S3BackupManager
├── ViewModels/              # MVVM State Objects
├── Models/                  # SwiftData Models (ChatMessage, Conversation)
├── Views/                   # SwiftUI Interface
│   ├── Chat/                # Main Chat & Input
│   ├── Comparison/          # Radar Charts & Side-by-Side
│   ├── Observability/       # Health Dashboard
│   └── ...
└── Services/                # Low-level helpers (Keychain, Networking)
```

**Design Principles:**
- **MVVM** with `@Observable` and Swift Concurrency (`async/await`)
- **Protocol-oriented** — all providers share `AIProvider` with `Sendable` compliance
- **Zero external SDKs** — pure Foundation networking with manual SigV4 signing
- **SwiftData** for persistence — automatic migrations, lightweight schema

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
3. Add your API key(s):

| Provider | What You Need |
|----------|---------------|
| **Anthropic** | API key from [console.anthropic.com](https://console.anthropic.com) |
| **OpenAI** | API key from [platform.openai.com](https://platform.openai.com) |
| **HuggingFace** | Access token from [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens) |
| **Ollama** | Install [ollama.com](https://ollama.com), run `ollama serve` — no key needed |
| **AWS Bedrock** | AWS Access Key + Secret Key with Bedrock permissions |

---

## 🎨 UI Design

The interface features a **premium dark aesthetic** with:
- Glassmorphism cards and panels
- Dynamic gradient backgrounds
- Smooth micro-animations and transitions
- Provider-specific color coding throughout

---

## 📦 Tech Stack

| Component | Technology |
|-----------|-----------|
| UI Framework | SwiftUI |
| Data Layer | SwiftData |
| Networking | URLSession + async/await |
| Security | macOS Keychain + CryptoKit |
| Screen Capture | ScreenCaptureKit |
| Architecture | MVVM + Protocol-Oriented |
| Concurrency | Swift Concurrency (structured) |
| Minimum Target | macOS 14.0 (Sonoma) |

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
