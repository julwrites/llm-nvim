#!/usr/bin/env python3
import os
import sys
import shutil
import subprocess

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
AGENTS_FILE = os.path.join(REPO_ROOT, "AGENTS.md")
CLAUDE_FILE = os.path.join(REPO_ROOT, "CLAUDE.md")
TEMPLATE_MAINTENANCE = os.path.join(REPO_ROOT, "templates", "maintenance_mode.md")

STANDARD_HEADERS = [
    "Helper Scripts",
    "Agent Interoperability",
    "Step 1: Detect Repository State",
    "Step 2: Execution Strategy",
    "Step 3: Finalize & Switch to Maintenance Mode"
]

PREAMBLE_IGNORE_PATTERNS = [
    "# AI Agent Bootstrap Instructions",
    "# AI Agent Instructions",
    "**CURRENT STATUS: BOOTSTRAPPING MODE**",
    "You are an expert Software Architect",
    "Your current goal is to bootstrap",
]

def is_ignored_preamble_line(line):
    l = line.strip()
    # Keep empty lines to preserve spacing in custom content,
    # but we will strip the final result to remove excess whitespace.
    if not l:
        return False

    for p in PREAMBLE_IGNORE_PATTERNS:
        if p in l:
            return True
    return False

def extract_custom_content(content):
    lines = content.splitlines()
    custom_sections = []
    preamble_lines = []
    current_header = None
    current_lines = []

    for line in lines:
        if line.startswith("## "):
            header = line[3:].strip()

            # Flush previous section
            if current_header:
                if current_header not in STANDARD_HEADERS:
                    custom_sections.append((current_header, "\n".join(current_lines)))
            else:
                # Capture preamble (lines before first header)
                for l in current_lines:
                    if not is_ignored_preamble_line(l):
                        preamble_lines.append(l)

            current_header = header
            current_lines = []
        else:
            current_lines.append(line)

    # Flush last section
    if current_header:
        if current_header not in STANDARD_HEADERS:
            custom_sections.append((current_header, "\n".join(current_lines)))
    else:
        # If no headers found, everything is preamble
        for l in current_lines:
             if not is_ignored_preamble_line(l):
                 preamble_lines.append(l)

    return "\n".join(preamble_lines).strip(), custom_sections

def check_state():
    print("Repository Analysis:")

    # Check if already in maintenance mode
    if os.path.exists(AGENTS_FILE):
        with open(AGENTS_FILE, "r") as f:
            content = f.read()
        if "BOOTSTRAPPING MODE" not in content:
            print("Status: MAINTENANCE MODE (AGENTS.md is already updated)")
            print("To list tasks: python3 scripts/tasks.py list")
            return

    files = [f for f in os.listdir(REPO_ROOT) if not f.startswith(".")]
    print(f"Files in root: {len(files)}")

    if os.path.exists(os.path.join(REPO_ROOT, "src")) or os.path.exists(os.path.join(REPO_ROOT, "lib")) or os.path.exists(os.path.join(REPO_ROOT, ".git")):
        print("Status: EXISTING REPOSITORY (Found src/, lib/, or .git/)")
    else:
        print("Status: NEW REPOSITORY (Likely)")

    # Check for hooks
    hook_path = os.path.join(REPO_ROOT, ".git", "hooks", "pre-commit")
    if not os.path.exists(hook_path):
        print("\nTip: Run 'python3 scripts/tasks.py install-hooks' to enable safety checks.")

    print("\nNext Steps:")
    print("1. Run 'python3 scripts/tasks.py init' to scaffold directories.")
    print("2. Run 'python3 scripts/tasks.py create foundation \"Initial Setup\"' to track your work.")
    print("3. Explore docs/architecture/ and docs/features/.")
    print("4. When ready to switch to maintenance mode, run: python3 scripts/bootstrap.py finalize --interactive")

def finalize():
    interactive = "--interactive" in sys.argv
    print("Finalizing setup...")
    if not os.path.exists(TEMPLATE_MAINTENANCE):
        print(f"Error: Template {TEMPLATE_MAINTENANCE} not found.")
        sys.exit(1)

    # Safety check
    if os.path.exists(AGENTS_FILE):
        with open(AGENTS_FILE, "r") as f:
            content = f.read()
        if "BOOTSTRAPPING MODE" not in content and "--force" not in sys.argv:
            print("Error: AGENTS.md does not appear to be in bootstrapping mode.")
            print("Use --force to overwrite anyway.")
            sys.exit(1)

    # Ensure init is run
    print("Ensuring directory structure...")
    tasks_script = os.path.join(SCRIPT_DIR, "tasks.py")
    try:
        subprocess.check_call([sys.executable, tasks_script, "init"])
    except subprocess.CalledProcessError:
        print("Error: Failed to initialize directories.")
        sys.exit(1)

    # Analyze AGENTS.md for custom sections
    custom_sections = []
    custom_preamble = ""
    if os.path.exists(AGENTS_FILE):
        try:
            with open(AGENTS_FILE, "r") as f:
                current_content = f.read()
            custom_preamble, custom_sections = extract_custom_content(current_content)
        except Exception as e:
            print(f"Warning: Failed to parse AGENTS.md for custom sections: {e}")

    if interactive:
        print("\n--- Merge Analysis ---")
        if custom_preamble:
            print("[PRESERVED] Custom Preamble (lines before first header)")
            print(f"   Snippet: {custom_preamble.splitlines()[0][:60]}...")
        else:
            print("[INFO] No custom preamble found.")

        if custom_sections:
            print(f"[PRESERVED] {len(custom_sections)} Custom Sections:")
            for header, _ in custom_sections:
                print(f"   - {header}")
        else:
            print("[INFO] No custom sections found.")

        print("\n[REPLACED] The following standard bootstrapping sections will be replaced by Maintenance Mode instructions:")
        for header in STANDARD_HEADERS:
             print(f"   - {header}")

        print(f"\n[ACTION] AGENTS.md will be backed up to AGENTS.md.bak")

        try:
            # Use input if available, but handle non-interactive environments
            response = input("\nProceed with finalization? [y/N] ")
        except EOFError:
            response = "n"

        if response.lower() not in ["y", "yes"]:
            print("Aborting.")
            sys.exit(0)

    # Backup AGENTS.md
    if os.path.exists(AGENTS_FILE):
        backup_file = AGENTS_FILE + ".bak"
        try:
            shutil.copy2(AGENTS_FILE, backup_file)
            print(f"Backed up AGENTS.md to {backup_file}")
            if not custom_sections and not custom_preamble and not interactive:
                print("IMPORTANT: If you added custom instructions to AGENTS.md, they are now in .bak")
                print("Please review AGENTS.md.bak and merge any custom context into the new AGENTS.md manually.")
            elif not interactive:
                 print(f"NOTE: Custom sections/preamble were preserved in the new AGENTS.md.")
                 print("Please review AGENTS.md.bak to ensure no other context was lost.")
        except Exception as e:
            print(f"Warning: Failed to backup AGENTS.md: {e}")

    # Read template
    with open(TEMPLATE_MAINTENANCE, "r") as f:
        content = f.read()

    # Prepend custom preamble
    if custom_preamble:
        content = custom_preamble + "\n\n" + content

    # Append custom sections
    if custom_sections:
        content += "\n"
        for header, body in custom_sections:
            content += f"\n## {header}\n{body}"
        if not interactive:
            print(f"Appended {len(custom_sections)} custom sections to new AGENTS.md")

    # Overwrite AGENTS.md
    with open(AGENTS_FILE, "w") as f:
        f.write(content)

    print(f"Updated {AGENTS_FILE} with maintenance instructions.")

    # Check CLAUDE.md symlink
    if os.path.islink(CLAUDE_FILE):
        print(f"{CLAUDE_FILE} is a symlink. Verified.")
    else:
        print(f"{CLAUDE_FILE} is NOT a symlink. Recreating it...")
        if os.path.exists(CLAUDE_FILE):
            os.remove(CLAUDE_FILE)
        os.symlink("AGENTS.md", CLAUDE_FILE)
        print("Symlink created.")

    print("\nBootstrapping Complete! The agent is now in Maintenance Mode.")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "finalize":
        finalize()
    else:
        check_state()
