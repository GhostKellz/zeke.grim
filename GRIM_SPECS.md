# Zeke.grim - Grim Plugin Specifications

**Version:** 0.1.0-alpha
**Last Updated:** 2025-10-12
**Status:** Design Phase

---

## 🎯 Overview

**zeke.grim** is the **Grim editor plugin** that connects to the **zeke daemon** for AI-powered code intelligence.

### Architecture

```
┌────────────────────────────────────────────────────┐
│  Grim Editor (Zig)                                 │
│  ┌──────────────────────────────────────────────┐ │
│  │  zeke.grim Plugin (Ghostlang .gza)           │ │
│  │  ──────────────────────────────────────────  │ │
│  │                                              │ │
│  │  • Inline completion UI                      │ │
│  │  • Chat panel                                │ │
│  │  • Commands (:Zeke ask/refactor/etc)         │ │
│  │  • Keybindings                               │ │
│  │  • Context gathering (buffer, LSP, git)      │ │
│  └──────────────────────────────────────────────┘ │
└────────────────┬───────────────────────────────────┘
                 │ zRPC (local IPC)
┌────────────────▼───────────────────────────────────┐
│  zeke Daemon (Zig)                                 │
│  • Completion engine                               │
│  │  • Agentic engine                               │
│  • Provider management (Ollama, OpenAI, Claude)    │
│  • Caching & rate limiting                         │
└────────────────────────────────────────────────────┘
```

**Key Principle:** Plugin is **thin client** - all heavy lifting (AI requests, caching, context) done by daemon.

---

## 📦 Components

### 1. Client Manager

**Purpose:** Maintain connection to zeke daemon

**Responsibilities:**
- Connect to daemon on plugin load
- Reconnect on disconnect
- Health checks
- Error handling

**Implementation:**
```ghostlang
-- src/client.gza
local zrpc = require("zrpc")

local Client = {
    socket_path = "/tmp/zeke.sock",
    conn = nil,
    connected = false,
    retry_count = 0,
    max_retries = 3,
}

function Client.connect()
    if Client.connected then
        return true
    end

    -- Try to connect
    local ok, conn = pcall(zrpc.connect, Client.socket_path)
    if not ok then
        log("Failed to connect to zeke daemon: " .. tostring(conn))
        return false
    end

    Client.conn = conn
    Client.connected = true
    Client.retry_count = 0

    log("Connected to zeke daemon")
    return true
end

function Client.disconnect()
    if Client.conn then
        Client.conn:close()
        Client.conn = nil
        Client.connected = false
    end
end

function Client.call(method, params)
    if not Client.connected then
        if not Client.connect() then
            return nil, "Not connected to zeke daemon"
        end
    end

    local ok, result = pcall(Client.conn.call, method, params)
    if not ok then
        log("RPC call failed: " .. tostring(result))
        Client.disconnect()

        -- Retry once
        if Client.retry_count < Client.max_retries then
            Client.retry_count = Client.retry_count + 1
            if Client.connect() then
                return Client.call(method, params)
            end
        end

        return nil, result
    end

    return result, nil
end

return Client
```

---

### 2. Completion UI

**Purpose:** Display inline suggestions

**Features:**
- Ghost text rendering
- Accept/reject keybindings
- Cycle through alternatives
- Streaming support

**Visual Example:**
```zig
fn fibonacci(n: u32) u32 {
    |if (n <= 1) return n;|  ← Ghost text (grayed out)
    |return fibonacci(n - 1) + fibonacci(n - 2);|
}
```

**Implementation:**
```ghostlang
-- src/completion_ui.gza
local bridge = require("grim.bridge")

local CompletionUI = {
    active_suggestion = nil,
    alternatives = {},
    current_index = 1,
}

function CompletionUI.show(suggestion)
    if not suggestion or #suggestion.text == 0 then
        return
    end

    CompletionUI.active_suggestion = suggestion
    CompletionUI.current_index = 1

    -- Render as virtual text (ghost text)
    local bufnr = bridge.get_current_buffer()
    local cursor = bridge.get_cursor()

    bridge.set_virtual_text(
        bufnr,
        cursor.line,
        cursor.col,
        suggestion.text,
        "ZekeGhostText"  -- Highlight group
    )
end

function CompletionUI.hide()
    if not CompletionUI.active_suggestion then
        return
    end

    -- Clear virtual text
    local bufnr = bridge.get_current_buffer()
    bridge.clear_virtual_text(bufnr)

    CompletionUI.active_suggestion = nil
    CompletionUI.alternatives = {}
end

function CompletionUI.accept()
    if not CompletionUI.active_suggestion then
        return false
    end

    local suggestion = CompletionUI.active_suggestion
    local bufnr = bridge.get_current_buffer()
    local cursor = bridge.get_cursor()

    -- Insert suggestion text
    bridge.insert_text(bufnr, cursor.line, cursor.col, suggestion.text)

    CompletionUI.hide()
    return true
end

function CompletionUI.reject()
    CompletionUI.hide()
    return true
end

function CompletionUI.cycle_next()
    if #CompletionUI.alternatives == 0 then
        -- Request alternatives from daemon
        local result = Client.call("completion.alternatives", {
            suggestion_id = CompletionUI.active_suggestion.id,
        })

        if result then
            CompletionUI.alternatives = result.alternatives
        end
    end

    if #CompletionUI.alternatives > 0 then
        CompletionUI.current_index = CompletionUI.current_index + 1
        if CompletionUI.current_index > #CompletionUI.alternatives then
            CompletionUI.current_index = 1
        end

        local alt = CompletionUI.alternatives[CompletionUI.current_index]
        CompletionUI.show(alt)
    end
end

function CompletionUI.cycle_prev()
    -- Similar to cycle_next but reverse
end

return CompletionUI
```

---

### 3. Chat Panel

**Purpose:** Conversational AI interface

**Features:**
- Sidebar panel (left/right/bottom)
- Persistent conversation history
- Code block rendering
- Action buttons (Apply, Copy, Insert)

**Visual Layout:**
```
┌─ Zeke AI ────────────────────────────────┐
│ You:                                     │
│ How do I read a file in Zig?             │
│                                          │
│ ─────────────────────────────────────── │
│                                          │
│ Zeke:                                    │
│ Here's how to read a file in Zig:       │
│                                          │
│ ```zig                                   │
│ const std = @import("std");              │
│ ...                                      │
│ ```                                      │
│                                          │
│ [Apply] [Copy] [Insert at cursor]       │
│                                          │
│ ─────────────────────────────────────── │
│                                          │
│ > Type your question...                  │
└──────────────────────────────────────────┘
```

**Implementation:**
```ghostlang
-- src/chat_panel.gza
local bridge = require("grim.bridge")
local client = require("client")

local ChatPanel = {
    buffer = nil,
    window = nil,
    visible = false,
    messages = {},  -- Conversation history
    position = "right",  -- left, right, bottom
    width = 50,  -- columns
}

function ChatPanel.toggle()
    if ChatPanel.visible then
        ChatPanel.hide()
    else
        ChatPanel.show()
    end
end

function ChatPanel.show()
    if ChatPanel.visible then
        return
    end

    -- Create buffer for chat
    ChatPanel.buffer = bridge.create_buffer({
        listed = false,
        scratch = true,
        filetype = "zeke-chat",
    })

    -- Create window (split)
    local split_cmd = "vsplit"  -- or "split" for horizontal
    if ChatPanel.position == "right" then
        split_cmd = "vsplit"
    elseif ChatPanel.position == "left" then
        split_cmd = "vsplit | wincmd H"
    elseif ChatPanel.position == "bottom" then
        split_cmd = "split | wincmd J"
    end

    bridge.execute_command(split_cmd)
    ChatPanel.window = bridge.get_current_window()

    -- Set buffer in window
    bridge.set_window_buffer(ChatPanel.window, ChatPanel.buffer)

    -- Set window size
    if ChatPanel.position == "right" or ChatPanel.position == "left" then
        bridge.set_window_width(ChatPanel.window, ChatPanel.width)
    else
        bridge.set_window_height(ChatPanel.window, 20)
    end

    -- Render chat history
    ChatPanel.render()

    ChatPanel.visible = true
end

function ChatPanel.hide()
    if not ChatPanel.visible then
        return
    end

    if ChatPanel.window then
        bridge.close_window(ChatPanel.window)
        ChatPanel.window = nil
    end

    ChatPanel.visible = false
end

function ChatPanel.send_message(message)
    -- Add user message to history
    table.insert(ChatPanel.messages, {
        role = "user",
        content = message,
    })

    -- Show "thinking" indicator
    ChatPanel.render()

    -- Send to daemon
    local response = client.call("agent.chat", {
        messages = ChatPanel.messages,
        context = ChatPanel.gather_context(),
    })

    if response then
        -- Add assistant response
        table.insert(ChatPanel.messages, {
            role = "assistant",
            content = response.content,
        })

        ChatPanel.render()
    else
        -- Show error
        ChatPanel.show_error("Failed to get response from zeke daemon")
    end
end

function ChatPanel.render()
    if not ChatPanel.buffer then
        return
    end

    local lines = {}

    -- Header
    table.insert(lines, "─ Zeke AI ────────────────────────")
    table.insert(lines, "")

    -- Render messages
    for _, msg in ipairs(ChatPanel.messages) do
        if msg.role == "user" then
            table.insert(lines, "You:")
            table.insert(lines, msg.content)
        else
            table.insert(lines, "")
            table.insert(lines, "Zeke:")
            table.insert(lines, msg.content)
        end

        table.insert(lines, "")
        table.insert(lines, "─────────────────────────────────")
        table.insert(lines, "")
    end

    -- Input prompt
    table.insert(lines, "> Type your question...")

    -- Update buffer
    bridge.set_buffer_lines(ChatPanel.buffer, 0, -1, false, lines)
end

function ChatPanel.gather_context()
    -- Get context from current editor state
    local bufnr = bridge.get_current_buffer()
    local filepath = bridge.get_buffer_path(bufnr)
    local content = bridge.get_buffer_lines(bufnr, 0, -1)

    return {
        file = filepath,
        content = table.concat(content, "\n"),
        cursor = bridge.get_cursor(),
        language = bridge.get_buffer_filetype(bufnr),
    }
end

return ChatPanel
```

---

### 4. Command Interface

**Purpose:** Expose AI features via `:Zeke` commands

**Commands:**

| Command | Args | Description |
|---------|------|-------------|
| `:Zeke ask <question>` | question | Ask a question |
| `:Zeke explain` | - | Explain selected code |
| `:Zeke refactor <type>` | type | Refactor selection |
| `:Zeke fix` | - | Fix issue at cursor |
| `:Zeke docs` | - | Generate documentation |
| `:Zeke test` | - | Generate tests |
| `:Zeke review` | - | Code review |
| `:Zeke commit` | - | Generate commit message |
| `:Zeke chat` | - | Open chat panel |

**Implementation:**
```ghostlang
-- src/commands.gza
local bridge = require("grim.bridge")
local client = require("client")
local chat = require("chat_panel")

local Commands = {}

function Commands.register()
    -- Register :Zeke command
    bridge.register_command("Zeke", Commands.handle)
end

function Commands.handle(args)
    local subcommand = args[1]

    if subcommand == "ask" then
        local question = table.concat(args, " ", 2)
        Commands.ask(question)
    elseif subcommand == "explain" then
        Commands.explain()
    elseif subcommand == "refactor" then
        local refactor_type = args[2] or "auto"
        Commands.refactor(refactor_type)
    elseif subcommand == "fix" then
        Commands.fix()
    elseif subcommand == "docs" then
        Commands.generate_docs()
    elseif subcommand == "test" then
        Commands.generate_tests()
    elseif subcommand == "review" then
        Commands.code_review()
    elseif subcommand == "commit" then
        Commands.generate_commit_message()
    elseif subcommand == "chat" then
        chat.toggle()
    else
        print("Unknown Zeke command: " .. subcommand)
    end
end

function Commands.ask(question)
    -- Send question to daemon
    local response = client.call("agent.ask", {
        question = question,
        context = gather_context(),
    })

    if response then
        -- Show in chat panel or popup
        chat.add_message("user", question)
        chat.add_message("assistant", response.answer)
        chat.show()
    end
end

function Commands.explain()
    -- Get selected text
    local selection = bridge.get_visual_selection()

    if not selection or #selection == 0 then
        print("No code selected")
        return
    end

    local response = client.call("agent.explain", {
        code = selection,
        context = gather_context(),
    })

    if response then
        -- Show explanation in popup or chat
        show_explanation_popup(response.explanation)
    end
end

function Commands.refactor(refactor_type)
    local selection = bridge.get_visual_selection()

    if not selection or #selection == 0 then
        print("No code selected")
        return
    end

    local response = client.call("agent.refactor", {
        code = selection,
        type = refactor_type,  -- extract, inline, rename, etc.
        context = gather_context(),
    })

    if response then
        -- Show diff preview
        show_diff_preview(selection, response.refactored_code)
    end
end

function Commands.fix()
    local cursor = bridge.get_cursor()
    local line = bridge.get_line(cursor.line)

    -- Get diagnostics at cursor
    local diagnostics = bridge.get_diagnostics(cursor)

    local response = client.call("agent.fix", {
        line = line,
        diagnostics = diagnostics,
        context = gather_context(),
    })

    if response then
        -- Apply fix
        bridge.replace_line(cursor.line, response.fixed_line)
    end
end

function Commands.generate_docs()
    local selection = bridge.get_visual_selection()
    local cursor = bridge.get_cursor()

    -- If no selection, get function at cursor
    if not selection or #selection == 0 then
        selection = get_function_at_cursor(cursor)
    end

    local response = client.call("agent.generate_docs", {
        code = selection,
        context = gather_context(),
    })

    if response then
        -- Insert documentation above function
        bridge.insert_lines(cursor.line, response.documentation)
    end
end

-- ... other command implementations

return Commands
```

---

### 5. Context Gathering

**Purpose:** Collect context from Grim editor for AI requests

**Context Types:**

1. **Buffer Context**
   - Current file content
   - Cursor position
   - Selection (if any)
   - Language/filetype

2. **LSP Context** (if available)
   - Symbols at cursor
   - Type information
   - Diagnostics (errors/warnings)
   - Hover documentation

3. **Git Context** (if in repo)
   - Current branch
   - Recent commits
   - Diff for current file

4. **Project Context**
   - File tree
   - Related files (imports)
   - Build files (build.zig, etc.)

**Implementation:**
```ghostlang
-- src/context.gza
local bridge = require("grim.bridge")

local Context = {}

function Context.gather()
    local ctx = {}

    -- Buffer context
    ctx.buffer = Context.gather_buffer()

    -- LSP context (if available)
    if bridge.lsp and bridge.lsp.is_attached() then
        ctx.lsp = Context.gather_lsp()
    end

    -- Git context (if in repo)
    if bridge.git and bridge.git.is_repo() then
        ctx.git = Context.gather_git()
    end

    -- Project context
    ctx.project = Context.gather_project()

    return ctx
end

function Context.gather_buffer()
    local bufnr = bridge.get_current_buffer()
    local filepath = bridge.get_buffer_path(bufnr)
    local lines = bridge.get_buffer_lines(bufnr, 0, -1)
    local cursor = bridge.get_cursor()
    local selection = bridge.get_visual_selection()

    return {
        file = filepath,
        content = table.concat(lines, "\n"),
        cursor = cursor,
        selection = selection,
        language = bridge.get_buffer_filetype(bufnr),
        modified = bridge.is_buffer_modified(bufnr),
    }
end

function Context.gather_lsp()
    local cursor = bridge.get_cursor()

    -- Get symbol at cursor
    local symbol = bridge.lsp.get_symbol_at_cursor(cursor)

    -- Get hover documentation
    local hover = bridge.lsp.get_hover(cursor)

    -- Get diagnostics
    local diagnostics = bridge.lsp.get_diagnostics()

    return {
        symbol = symbol,
        hover = hover,
        diagnostics = diagnostics,
    }
end

function Context.gather_git()
    local filepath = bridge.get_buffer_path()

    -- Get git status
    local status = bridge.git.status()

    -- Get diff for current file
    local diff = bridge.git.diff(filepath)

    -- Get recent commits
    local commits = bridge.git.log(5)  -- Last 5 commits

    return {
        branch = status.branch,
        diff = diff,
        commits = commits,
    }
end

function Context.gather_project()
    local project_root = bridge.get_project_root()

    -- Get file tree
    local files = bridge.get_files(project_root)

    -- Get build files
    local build_files = {}
    for _, pattern in ipairs({"build.zig", "Cargo.toml", "package.json"}) do
        local path = project_root .. "/" .. pattern
        if bridge.file_exists(path) then
            build_files[pattern] = bridge.read_file(path)
        end
    end

    return {
        root = project_root,
        files = files,
        build_files = build_files,
    }
end

return Context
```

---

## 🎮 Keybindings

### Default Keymap

```ghostlang
-- Default keybindings
local keymaps = {
    -- Completion
    accept = "<Tab>",           -- Accept suggestion
    reject = "<Esc>",           -- Dismiss suggestion
    next = "<C-]>",             -- Next alternative
    prev = "<C-[>",             -- Previous alternative

    -- Chat
    chat_toggle = "<leader>z",  -- Open/close chat
    ask = "<leader>za",         -- Ask question

    -- Commands
    explain = "<leader>ze",     -- Explain code (visual)
    refactor = "<leader>zr",    -- Refactor (visual)
    fix = "<leader>zf",         -- Fix issue at cursor
    docs = "<leader>zd",        -- Generate docs
    test = "<leader>zt",        -- Generate tests (visual)
    review = "<leader>zc",      -- Code review (visual)
}
```

### Keymap Registration

```ghostlang
-- src/keymaps.gza
function setup_keymaps(config)
    local keymaps = config.keymaps or default_keymaps

    -- Completion keybindings (insert mode)
    vim.keymap.set("i", keymaps.accept, function()
        require("completion_ui").accept()
    end, { silent = true, desc = "Zeke: Accept suggestion" })

    vim.keymap.set("i", keymaps.reject, function()
        require("completion_ui").reject()
    end, { silent = true, desc = "Zeke: Reject suggestion" })

    -- Chat keybindings (normal mode)
    vim.keymap.set("n", keymaps.chat_toggle, function()
        require("chat_panel").toggle()
    end, { desc = "Zeke: Toggle chat" })

    vim.keymap.set("n", keymaps.ask, function()
        vim.ui.input({ prompt = "Ask Zeke: " }, function(input)
            if input then
                require("commands").ask(input)
            end
        end)
    end, { desc = "Zeke: Ask question" })

    -- Command keybindings (visual mode)
    vim.keymap.set("v", keymaps.explain, ":Zeke explain<CR>",
        { desc = "Zeke: Explain code" })

    vim.keymap.set("v", keymaps.refactor, ":Zeke refactor<CR>",
        { desc = "Zeke: Refactor code" })

    -- ... more keybindings
end
```

---

## ⚙️ Configuration

### Plugin Configuration

```ghostlang
-- ~/.config/grim/init.gza
local zeke = require("zeke")

zeke.setup({
    -- Daemon connection
    socket_path = "/tmp/zeke.sock",
    auto_start_daemon = true,  -- Start daemon if not running

    -- Features
    inline_suggestions = true,  -- Enable completions
    chat_panel = true,          -- Enable chat
    auto_complete = true,       -- Auto-trigger completions

    -- UI
    chat_position = "right",    -- left, right, bottom
    chat_width = 50,            -- columns
    ghost_text_hl = "Comment",  -- Highlight group for suggestions

    -- Behavior
    trigger_chars = { ".", ":", "(", " " },
    debounce_ms = 300,          -- Wait before requesting completion
    max_suggestions = 5,        -- Max alternative suggestions

    -- Keybindings
    keymaps = {
        accept = "<Tab>",
        reject = "<Esc>",
        chat_toggle = "<leader>z",
        ask = "<leader>za",
        explain = "<leader>ze",
        refactor = "<leader>zr",
        fix = "<leader>zf",
        docs = "<leader>zd",
    },

    -- Context
    include_lsp = true,   -- Include LSP context
    include_git = true,   -- Include git context
    include_files = false, -- Include related files (slower)
})
```

---

## 🚀 Development Phases

### Phase 1: Foundation
- ✅ Plugin skeleton (main.gza)
- ✅ zRPC client integration
- 🚧 Completion UI (ghost text)
- 🚧 Basic commands (:Zeke ask)

### Phase 2: Completions
- Trigger on text change
- Debouncing
- Accept/reject keybindings
- Alternative suggestions

### Phase 3: Chat Panel
- Sidebar panel
- Persistent conversation
- Code block rendering
- Apply/Copy/Insert actions

### Phase 4: Advanced Features
- Refactoring UI (diff preview)
- Multi-file operations
- Voice input (via grim API)
- Analytics dashboard

---

## 📊 Performance

**Targets:**
- Plugin startup: <50ms
- Completion trigger: <5ms (debounce before daemon call)
- Chat panel open: <100ms
- Context gathering: <20ms

**Optimization:**
- Cache LSP/git context
- Debounce text changes
- Lazy-load components
- Reuse daemon connection

---

**Last Updated:** 2025-10-12
**Status:** Design Phase
**Related:** zeke (daemon), phantom.grim, grim
