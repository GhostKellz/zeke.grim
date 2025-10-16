# Zeke.grim Plugin

AI-powered coding assistant for Grim editor with Ollama-first, multi-provider support.

## Features

- 🤖 **AI Chat Panel** - Interactive conversation with AI about your code
- ✨ **Inline Suggestions** - Ghost text completions as you type
- 🔍 **Code Explanation** - Understand complex code sections
- 🔧 **Smart Refactoring** - AI-powered code transformations
- 🐛 **Issue Fixing** - Automatic bug detection and fixes
- 📝 **Context Management** - Multi-file context for better AI responses
- 🎯 **Multiple Providers** - Ollama (local), OpenAI, Anthropic, Azure

## Installation

### Prerequisites

- Grim >= 0.1.0
- Ollama (recommended) or API keys for OpenAI/Anthropic/Azure

### Via Grim Plugin Manager

```bash
grim plugin install ghostkellz/zeke.grim
```

### Manual Installation

```bash
# Clone to plugins directory
git clone https://github.com/ghostkellz/zeke.grim ~/.config/grim/plugins/zeke

# Build Zig core (optional, for better performance)
cd ~/.config/grim/plugins/zeke/core
zig build -Doptimize=ReleaseFast
```

## Configuration

Add to your `~/.config/grim/init.gza`:

```ghostlang
local zeke = require("zeke")

zeke.setup({
    -- API Configuration
    api_base = "http://127.0.0.1:8080/v1",  -- Omen/LiteLLM
    ollama_host = "http://127.0.0.1:11434",

    -- Model aliases
    models = {
        ["code-fast"] = "ollama:deepseek-coder:14b",
        ["code-plus"] = "ollama:deepseek-coder:33b",
        ["code-smart"] = "openai:gpt-4o-mini",
        ["reason-deep"] = "anthropic:claude-sonnet-4-5-20250929",
    },

    -- UI settings
    ui = {
        chat_position = "right",
        chat_width = 50,
        show_inline_suggestions = true,
    },

    -- Keybindings (optional, uses defaults if not specified)
    keymaps = {
        chat_toggle = "<leader>ac",
        accept = "<Tab>",
        explain = "<leader>ae",
        fix = "<leader>af",
        refactor = "<leader>ar",
    },
})
```

## Environment Variables

```bash
# Primary API endpoint (Omen/LiteLLM)
export ZEKE_API_BASE="http://127.0.0.1:8080/v1"

# Ollama endpoint
export OLLAMA_HOST="http://127.0.0.1:11434"

# Provider API keys (optional if using Omen)
export OPENAI_API_KEY="sk-..."
export ANTHROPIC_API_KEY="sk-ant-..."
export AZURE_OPENAI_API_KEY="..."
export AZURE_OPENAI_ENDPOINT="https://..."
```

## Commands

| Command | Description |
|---------|-------------|
| `:ZekeChat [msg]` | Open chat panel (optionally send message) |
| `:ZekeSend` | Send current selection to chat |
| `:ZekeExplain` | Explain selected code |
| `:ZekeFix` | Fix issue at cursor |
| `:ZekeRefactor <instruction>` | Refactor code with instruction |
| `:ZekeAddFile [path]` | Add file to context |
| `:ZekeShowContext` | Show current context |
| `:ZekeClearContext` | Clear context |
| `:ZekeModels` | List available models |
| `:ZekeModel <alias>` | Switch to model |
| `:ZekeDoctor` | Health check |
| `:ZekeLogLevel <level>` | Set log level |

## Keybindings

| Mode | Key | Action |
|------|-----|--------|
| Normal | `<leader>ac` | Toggle chat panel |
| Visual | `<leader>as` | Send selection to chat |
| Insert | `<Tab>` | Accept inline suggestion |
| Insert | `<C-]>` | Next suggestion |
| Insert | `<C-[>` | Previous suggestion |
| Insert | `<C-\>` | Dismiss suggestion |
| Visual | `<leader>ae` | Explain code |
| Normal | `<leader>af` | Fix issue at cursor |
| Visual | `<leader>ar` | Refactor code |
| Normal | `<leader>aa` | Add current file to context |
| Normal | `<leader>ax` | Clear context |

## Usage Examples

### Chat with AI

```
:ZekeChat How do I implement a binary tree in Zig?
```

### Explain Code

1. Select code in visual mode
2. Press `<leader>ae` or `:ZekeExplain`

### Fix Issues

1. Move cursor to line with diagnostic
2. Press `<leader>af` or `:ZekeFix`

### Refactor Code

1. Select code in visual mode
2. Press `<leader>ar`
3. Enter refactoring instruction (e.g., "extract this into a separate function")

### Manage Context

```
:ZekeAddFile src/main.zig    # Add file to context
:ZekeShowContext              # Show current context
:ZekeClearContext             # Clear context
```

## Architecture

- **init.gza** - Main plugin entry point, command/keymap registration
- **runtime/api.gza** - OpenAI-compatible API client with SSE streaming
- **runtime/context.gza** - Context packing, token counting, truncation
- **runtime/ui.gza** - Chat panel, ghost text, notifications
- **runtime/diff.gza** - Unified diff parsing and patching
- **core/zeke_core.zig** - High-performance hot paths (optional)

## Performance

The plugin includes optional Zig implementations for hot paths:

- `tokenCount()` - Fast token estimation
- `packContext()` - Zero-copy context concatenation
- `applyPatch()` - Fast diff application

Build with: `cd core && zig build -Doptimize=ReleaseFast`

## Troubleshooting

### Check Health

```
:ZekeDoctor
```

This will check:
- API connectivity
- Ollama availability
- Provider configurations

### Common Issues

**Chat not responding:**
- Check `:ZekeDoctor` for API connectivity
- Verify Ollama is running: `ollama list`
- Check API base URL in config

**Inline suggestions not working:**
- Ensure `show_inline_suggestions = true` in config
- Check current model supports completions

**Diff preview not applying:**
- Check file permissions
- Ensure `patch` command is available

## Development

### Project Structure

```
plugins/zeke/
├── plugin.toml          # Plugin manifest
├── init.gza             # Entry point
├── runtime/             # Ghostlang modules
│   ├── api.gza
│   ├── context.gza
│   ├── ui.gza
│   └── diff.gza
└── core/                # Zig hot paths
    ├── build.zig
    └── zeke_core.zig
```

### Testing

```bash
# Test Zig core
cd core
zig build test

# Test in Grim
grim --cmd "lua require('zeke').doctor()"
```

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for guidelines.

## License

MIT License - See [LICENSE](../../LICENSE) for details.

## Related Projects

- [grim](https://github.com/ghostkellz/grim) - Modal text editor
- [phantom.grim](https://github.com/ghostkellz/phantom.grim) - Grim distribution
- [reaper.grim](https://github.com/ghostkellz/reaper.grim) - Multi-provider AI daemon
- [ghostlang](https://github.com/ghostkellz/ghostlang) - Scripting language
