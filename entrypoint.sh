#!/bin/bash
set -e

mkdir -p "${HOME}/.aws"
echo "[default]" > $HOME/.aws/config
echo "  region = us-east-1
  credential_process = /usr/local/bin/aws-credential-process.sh" >> $HOME/.aws/config

# Claude Code recommended settings
export CLAUDE_CODE_USE_BEDROCK=1
export ANTHROPIC_MODEL='us.anthropic.claude-sonnet-4-20250514-v1:0'
export CLAUDE_CODE_MAX_OUTPUT_TOKENS=4096
export MAX_THINKING_TOKENS=1024

# Execute claude with all arguments
exec claude "$@"
