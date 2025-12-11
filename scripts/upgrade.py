#!/usr/bin/env python3
import os
import sys
import shutil
import subprocess

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
TASKS_SCRIPT = os.path.join(SCRIPT_DIR, "tasks.py")

def upgrade():
    print("Starting repository upgrade...")

    # 1. Migrate Tasks
    print("\n[1/3] Checking for legacy tasks...")
    try:
        subprocess.check_call([sys.executable, TASKS_SCRIPT, "migrate"])
    except subprocess.CalledProcessError:
        print("Warning: Task migration failed.")

    # 2. Update Tooling Configs
    print("\n[2/3] Verifying agent configuration...")
    # Check CLAUDE.md
    claude_md = os.path.join(REPO_ROOT, "CLAUDE.md")
    agents_md = os.path.join(REPO_ROOT, "AGENTS.md")

    if os.path.exists(agents_md):
        if not os.path.exists(claude_md):
            print("Creating CLAUDE.md symlink...")
            try:
                os.symlink("AGENTS.md", claude_md)
            except OSError:
                # Fallback for Windows or no symlink support
                shutil.copy(agents_md, claude_md)
        elif os.path.islink(claude_md):
            pass # Good
        else:
            print("CLAUDE.md exists but is not a symlink. Leaving it as is.")

    # 3. Finalize
    print("\n[3/3] Upgrade complete.")
    print("Please review AGENTS.md to ensure it reflects the latest workflow (Code Review).")

if __name__ == "__main__":
    upgrade()
