#!/bin/bash
# PreToolUse hook: reminds about safety check when editing critical modules.
# Fires BEFORE the edit happens — can block with exit 2.
#
# CUSTOMIZE: Update the file pattern matchers below to match your project's
# critical modules (the ones where domain invariant violations would be dangerous).
#
# Examples:
#   Git project:  */git.ex|*/git/*.ex|*/repo_server.ex
#   API project:  */auth/*|*/middleware/*|*/db/queries/*
#   Data pipeline: */transforms/*|*/ingestion/*|*/schema/*

FILE_PATH=$(jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# CUSTOMIZE: Replace this pattern with your critical file paths
case "$FILE_PATH" in
  */REPLACE_WITH_YOUR_CRITICAL_PATTERN*)
    jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: "KEEL SAFETY: You are editing a file that touches critical domain operations. Run /safety-check before committing."}}'
    ;;
esac
