#!/usr/bin/env python3
"""
Session Start Hook for Claude.
Loads the latest Ledger and Handoff to restore context.
Input: JSON from Claude (source: startup|resume|clear)
Output: JSON to Claude (hookSpecificOutput: { additionalContext: ... })
"""
import sys
import os
import json
import glob

# Determine root
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
# scripts/hooks/ -> scripts/ -> root
REPO_ROOT = os.path.dirname(os.path.dirname(SCRIPT_DIR))
CONTINUITY_DIR = os.path.join(REPO_ROOT, "docs", "continuity")
LEDGERS_DIR = os.path.join(CONTINUITY_DIR, "ledgers")
HANDOFFS_DIR = os.path.join(CONTINUITY_DIR, "handoffs")

def get_latest_content(directory, name):
    pattern = os.path.join(directory, "*.md")
    files = glob.glob(pattern)
    if not files:
        return f"No {name} found."
    files.sort(reverse=True)
    with open(files[0], "r") as f:
        return f.read()

def main():
    # Read input JSON from stdin
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        # Fallback if no input (e.g. manual test)
        input_data = {}

    # Logic: Fetch latest ledger and handoff
    ledger_content = get_latest_content(LEDGERS_DIR, "Ledger")
    handoff_content = get_latest_content(HANDOFFS_DIR, "Handoff")

    context_message = f"""
=== CONTINUITY RESTORED ===

[LATEST LEDGER]
{ledger_content}

[LATEST HANDOFF]
{handoff_content}

===========================
"""

    # Output JSON
    output = {
        "continue": True,
        "hookSpecificOutput": {
            "additionalContext": context_message
        }
    }
    print(json.dumps(output))

if __name__ == "__main__":
    main()
