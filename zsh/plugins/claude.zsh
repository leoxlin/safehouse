function run_kimi_claude() {
  ANTHROPIC_BASE_URL="https://openrouter.ai/api" \
  ANTHROPIC_AUTH_TOKEN="$KIMI_OR_API_KEY" \
  ANTHROPIC_API_KEY="" \
  ANTHROPIC_MODEL="kimi-k2.5" \
  ANTHROPIC_SMALL_FAST_MODEL="kimi-k2.5" \
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
  API_TIMEOUT_MS=600000 \
  claude $@
}

alias kimi-code='run_kimi_claude'
