Who does what

OMEN → owns routing, “model=auto”, budgets, rate-limits, usage metering, and provider failover.
It’s the API front door. Strategies like single | race | speculate_k | parallel_merge live only here.

Reaper.grim / Zeke (clients) → hint, don’t decide.
They pass intent, latency/cost hints, and optional allowlists; they do not pick the final model.

Glyph (MCP) → tool governance only.
Consent, audit, schemas, broker tool calls. No model selection, no routing.

Rune (Zig MCP lib) → fast local execution + helper FFI.
Zero policy. Executes file/grep/git ops (and other hot paths) when Glyph authorizes them.

GhostLLM (if present) → can add higher-level policy (org rules, caching/RAG), but OMEN still does the cross-provider routing and accounting.


Client → OMEN (OpenAI-compat + hints):
POST /v1/chat/completions
{
  "model": "auto",
  "messages": [...],
  "stream": true,
  "omen": {
    "strategy": "speculate_k",
    "k": 2,
    "intent": "code",                 // guides model/bucket selection
    "providers": ["ollama","anthropic"],  // optional allowlist
    "budget_usd": 0.12,
    "max_latency_ms": 2500,
    "stickiness": "session"
  }
}

## OMEN responsibilities

Select/fan-out to providers (e.g., local Ollama + Claude) per strategy.

Enforce per-request budget and per-user/workspace quotas.

Cancel losers on race/speculate_k; swap streams mid-flight if upgraded.

Emit usage events (user, workspace, provider, model, tokens, cost, latency).

Expose /v1/usage & rollups; expose health and policy errors cleanly.

Glyph & Rune flow

If the model returns tool_calls, OMEN streams them; the client forwards to Glyph (MCP).

Glyph applies consent/audit → calls Rune for hot ops → returns tool results to the client → next turn to OMEN.

What not to do

Don’t put routing or quotas in Glyph or Rune.

Don’t let Reaper/Zeke hard-code model names except for dev/debug; use model=auto + hints.

Failure modes / fallbacks

If OMEN is unavailable, clients may fallback to local-only (direct Ollama) with a clear “degraded mode” banner; still keep tools via Glyph/Rune.

One-liner answer

OMEN is your router and meter. Reaper/Zeke provide hints. Glyph governs tools. Rune executes fast local work.

