#!/bin/bash
# PostToolUse hook: reminds Claude to run doc-gardener after git commits.
# Fires AFTER the commit succeeds.

COMMAND=$(jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

case "$COMMAND" in
  *"git commit"*)
    jq -n '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: "KEEL DOCS: Commit detected. Run doc-gardener agent to check for doc drift. (north-star.md: Garbage Collection)"}}'
    ;;
esac
