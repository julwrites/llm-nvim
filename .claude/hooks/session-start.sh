#!/bin/bash
# Wrapper for the Python SessionStart hook
# $CLAUDE_PROJECT_DIR is provided by Claude, but we can fallback to PWD
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
python3 "$PROJECT_DIR/scripts/hooks/session_start.py"
