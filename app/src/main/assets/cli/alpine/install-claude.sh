#!/bin/sh
# Installs Claude Code natively (musl build); falls back to npm. Quiet: log only.
exec >>/root/setup.log 2>&1
export USE_BUILTIN_RIPGREP=0
if curl -fsSL https://claude.ai/install.sh | bash; then exit 0; fi
npm install -g @anthropic-ai/claude-code
