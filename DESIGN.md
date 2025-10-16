🧩 Layer Breakdown
🏗️ Omen

Language: Rust
Role: Unified AI Gateway / Provider Router

OpenAI-compatible API (/v1/chat/completions)

Smart routing across OpenAI, Anthropic, Gemini, Ollama, Bedrock

Manages budgets, latency, and provider health

Feeds usage data and telemetry back into Glyph

Auth via SSO (OIDC/JWT)

Think: “API router + cost manager for all AI models.”

🌀 Glyph

Language: Rust
Role: Protocol Authority / MCP Layer

Defines the Machine Control Protocol (MCP) for Ghost agents

Handles session, consent, logging, and tracing

Converts raw requests → structured “AI operations”

Forms the contract layer between Zeke/Jarvis ↔ Omen

Backed by Postgres or SQLite for audit trails

Think: “The nervous system and legal layer between humans and AI.”

⚡ Rune

Language: Zig
Role: Local Performance Layer

Ultra-fast file scanning, diffing, patching, and text ops

Integrated in Grim and Zeke for hot-path file tasks

Exposed to Rust via rune-ffi

No logic, no network — pure compute and deterministic builds

Acts like a muscle fiber under the Rust brain

Think: “Performance grease for the editor and local AI clients.”

💬 Zeke

Language: Rust + Ghostlang (GZA)
Role: Local AI Client / Developer Assistant

CLI and library for AI-enhanced coding tasks

Uses Glyph → Omen → GhostLLM chain for inference

Integrates directly into Grim (zeke.grim) and other apps

Can delegate local file ops to Rune

Supports tool use, function calls, inline editing, and patch generation

Think: “Claude Code meets Ghostctl — local-first AI developer companion.”

🧑‍💻 Zeke.grim

Language: Zig / Ghostlang
Role: Grim Plugin Layer

Adds inline AI completions, refactors, and context chat

Leverages Rune for file I/O and edits

Communicates with Zeke and Omen

Mirrors Zeke.nvim structure but for Grim’s native TUI runtime

🧠 Jarvis

Language: Rust
Role: Agent Framework / CLI Automation

Multi-agent CLI runtime for Ghost workflows

Calls Glyph and Omen via internal APIs

Uses Zeke for LLM prompts, GhostFlow for orchestration

Optional Rune usage for local codebase inspection

Agent registry + scheduling coming via GhostFlow

Think: “Zeke for automation and teams — programmable AI orchestrator.”

⚙️ GhostFlow

Language: Rust
Role: Workflow Engine (n8n Alternative)

Defines flow-based orchestration for Ghost agents

Connects Jarvis tasks, model calls, and external APIs

Persistent DAG execution with audit + replay

Built on top of Glyph and GhostLLM

🧩 GhostLLM

Language: Rust
Role: Model Adapter / LiteLLM Alternative

Connects to OpenAI, Anthropic, Gemini, Ollama, Bedrock, etc.

Standardizes request/response schema for Glyph/Omen

Tracks token usage and latency metrics

Local & remote model compatibility (via HTTP or gRPC)

🧠 Grim

Language: Zig
Role: Editor Core

TUI-based modern editor (Neovim-style, Zig-native)

Hosts Phantom.grim (config distro)

Integrates Zeke.grim, GhostLS, Grove, and Rune

Uses Ghostlang (GZA) for scripting/config

🪞 Summary Flow
Grim / Zeke / Jarvis
   │
   ├─ Rune (local file ops)
   ├─ Glyph (protocol + session)
   ├─ Omen (AI routing)
   └─ GhostLLM (model backend)


Data Direction:
Editor/CLI → Glyph → Omen → Model → back through Glyph → Editor.
Rune acts locally; it never leaves the machine.

🧭 Design Philosophy

Glyph = law.
Omen = voice.
Rune = muscle.
Zeke = mind.
Grim = body.
Jarvis = ghost.

Together, they form the Ghost Stack — a unified, modular AI and developer ecosystem
that balances speed, clarity, and control.
