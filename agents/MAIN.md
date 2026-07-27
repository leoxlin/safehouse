# Agents Instructions

## Tool selection

Use the first tool that works:

1. Native Codex/Claude connector (i.e `mcp__codex_apps__*`, `mcp__claude_ai_*`)
2. LiteLLM MCP (i.e. `mcp__github_litellm__*`, `mcp__slack_litellm__*`)
3. CLI (ie. `gh`, `curl`)

- Fall back only if blocked: unavailable, unauthorized, or unsupported.
- Follow the order. Convenience is not a reason to skip a tool.
- Never use a CLI when a connector works.

## Personal Style

### Reduce code complexity
- No try/catch without a recovery path. Let it throw.
- No `async` without I/O concurrency benefit.
- One lifecycle owner. If two layers create/clean the same resource, the boundary is wrong.
- On small surgical edits, change exactly what's named — nothing adjacent. 
- No volunteered refactors, redundancy removal, or "while I'm here" cleanups.

### Be concise in written output
- Break things down into bullet points rather than large paragraphs
- Unless you can cite a concrete example, put `[PLEASE VERIFY]`

### Commits and PRs
- Use conventional commits (feat:, fix:, chore:)
- Use conventional commits as PR title
