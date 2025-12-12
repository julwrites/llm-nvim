#!/usr/bin/env python3
import os
import sys
import shutil
import argparse
import re
import json
import random
import string
from datetime import datetime

# Determine the root directory of the repo
# Assumes this script is in scripts/
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.getenv("TASKS_REPO_ROOT", os.path.dirname(SCRIPT_DIR))
DOCS_DIR = os.path.join(REPO_ROOT, "docs", "tasks")
TEMPLATES_DIR = os.path.join(REPO_ROOT, "templates")

CATEGORIES = [
    "foundation",
    "infrastructure",
    "domain",
    "presentation",
    "migration",
    "features",
    "testing",
    "review",
    "security",
    "research",
]

VALID_STATUSES = [
    "pending",
    "in_progress",
    "wip_blocked",
    "review_requested",
    "verified",
    "completed",
    "blocked",
    "cancelled",
    "deferred"
]

VALID_TYPES = [
    "epic",
    "story",
    "task",
    "bug"
]

ARCHIVE_DIR_NAME = "archive"

def init_docs():
    """Scaffolds the documentation directory structure."""
    print("Initializing documentation structure...")

    # Create docs/tasks/ directories
    for category in CATEGORIES:
        path = os.path.join(DOCS_DIR, category)
        os.makedirs(path, exist_ok=True)
        # Create .keep file to ensure git tracks the directory
        with open(os.path.join(path, ".keep"), "w") as f:
            pass

    # Copy GUIDE.md if missing
    guide_path = os.path.join(DOCS_DIR, "GUIDE.md")
    guide_template = os.path.join(TEMPLATES_DIR, "GUIDE.md")
    if not os.path.exists(guide_path) and os.path.exists(guide_template):
        shutil.copy(guide_template, guide_path)
        print(f"Created {guide_path}")

    # Create other doc directories
    for doc_type in ["architecture", "features", "security"]:
        path = os.path.join(REPO_ROOT, "docs", doc_type)
        os.makedirs(path, exist_ok=True)
        readme_path = os.path.join(path, "README.md")
        if not os.path.exists(readme_path):
            if doc_type == "security":
                content = """# Security Documentation

Use this section to document security considerations, risks, and mitigations.

## Risk Assessment
*   [ ] Threat Model
*   [ ] Data Privacy

## Compliance
*   [ ] Requirements

## Secrets Management
*   [ ] Policy
"""
            else:
                content = f"# {doc_type.capitalize()} Documentation\n\nAdd {doc_type} documentation here.\n"

            with open(readme_path, "w") as f:
                f.write(content)

    # Create memories directory
    memories_path = os.path.join(REPO_ROOT, "docs", "memories")
    os.makedirs(memories_path, exist_ok=True)
    if not os.path.exists(os.path.join(memories_path, ".keep")):
        with open(os.path.join(memories_path, ".keep"), "w") as f:
            pass

    print(f"Created directories in {os.path.join(REPO_ROOT, 'docs')}")

def generate_task_id(category):
    """Generates a timestamp-based ID to avoid collisions."""
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    suffix = ''.join(random.choices(string.ascii_uppercase, k=3))
    return f"{category.upper()}-{timestamp}-{suffix}"

def extract_frontmatter(content):
    """Extracts YAML frontmatter if present."""
    # Check if it starts with ---
    if not re.match(r"^\s*---\s*(\n|$)", content):
        return None, content

    # Find the second ---
    lines = content.splitlines(keepends=True)
    if not lines:
        return None, content

    yaml_lines = []
    body_start_idx = -1

    # Skip the first line (delimiter)
    for i, line in enumerate(lines[1:], 1):
        if re.match(r"^\s*---\s*(\n|$)", line):
            body_start_idx = i + 1
            break
        yaml_lines.append(line)

    if body_start_idx == -1:
        # No closing delimiter found
        return None, content

    yaml_block = "".join(yaml_lines)
    body = "".join(lines[body_start_idx:])

    data = {}
    for line in yaml_block.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if ":" in line:
            key, val = line.split(":", 1)
            data[key.strip()] = val.strip()

    return data, body

def parse_task_content(content, filepath=None):
    """Parses task markdown content into a dictionary."""

    # Try Frontmatter first
    frontmatter, body = extract_frontmatter(content)
    if frontmatter:
        deps_val = frontmatter.get("dependencies") or ""
        deps = []
        if deps_val:
            # Handle both string list "[a, b]" and plain string "a, b"
            cleaned = deps_val.strip(" []")
            if cleaned:
                deps = [d.strip() for d in cleaned.split(",") if d.strip()]

        return {
            "id": frontmatter.get("id", "unknown"),
            "status": frontmatter.get("status", "unknown"),
            "title": frontmatter.get("title", "No Title"),
            "priority": frontmatter.get("priority", "medium"),
            "type": frontmatter.get("type", "task"),
            "sprint": frontmatter.get("sprint", ""),
            "estimate": frontmatter.get("estimate", ""),
            "dependencies": deps,
            "filepath": filepath,
            "content": content
        }

    # Fallback to Legacy Regex Parsing
    id_match = re.search(r"\*\*Task ID\*\*: ([\w-]+)", content)
    status_match = re.search(r"\*\*Status\*\*: ([\w_]+)", content)
    title_match = re.search(r"# Task: (.+)", content)
    priority_match = re.search(r"\*\*Priority\*\*: ([\w]+)", content)

    task_id = id_match.group(1) if id_match else "unknown"
    status = status_match.group(1) if status_match else "unknown"
    title = title_match.group(1).strip() if title_match else "No Title"
    priority = priority_match.group(1) if priority_match else "unknown"

    return {
        "id": task_id,
        "status": status,
        "title": title,
        "priority": priority,
        "type": "task",
        "sprint": "",
        "estimate": "",
        "dependencies": [],
        "filepath": filepath,
        "content": content
    }

def create_task(category, title, description, priority="medium", status="pending", dependencies=None, task_type="task", sprint="", estimate="", output_format="text"):
    if category not in CATEGORIES:
        msg = f"Error: Category '{category}' not found. Available: {', '.join(CATEGORIES)}"
        if output_format == "json":
            print(json.dumps({"error": msg}))
        else:
            print(msg)
        sys.exit(1)

    task_id = generate_task_id(category)

    slug = title.lower().replace(" ", "-")
    # Sanitize slug
    slug = re.sub(r'[^a-z0-9-]', '', slug)
    filename = f"{task_id}-{slug}.md"
    filepath = os.path.join(DOCS_DIR, category, filename)

    # New YAML Frontmatter Format
    deps_str = ""
    if dependencies:
        # Use Flow style list
        deps_str = "[" + ", ".join(dependencies) + "]"

    extra_fm = ""
    if task_type:
        extra_fm += f"type: {task_type}\n"
    if sprint:
        extra_fm += f"sprint: {sprint}\n"
    if estimate:
        extra_fm += f"estimate: {estimate}\n"

    content = f"""---
id: {task_id}
status: {status}
title: {title}
priority: {priority}
created: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
category: {category}
dependencies: {deps_str}
{extra_fm}---

# {title}

{description}
"""

    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with open(filepath, "w") as f:
        f.write(content)

    if output_format == "json":
        print(json.dumps({
            "id": task_id,
            "title": title,
            "filepath": filepath,
            "status": status,
            "priority": priority,
            "type": task_type
        }))
    else:
        print(f"Created task: {filepath}")

def find_task_file(task_id):
    """Finds the file path for a given task ID."""
    task_id = task_id.upper()

    # Optimization: Check if ID starts with a known category
    parts = task_id.split('-')
    if len(parts) > 1:
        category = parts[0].lower()
        if category in CATEGORIES:
            category_dir = os.path.join(DOCS_DIR, category)
            if os.path.exists(category_dir):
                for file in os.listdir(category_dir):
                     if file.startswith(task_id) and file.endswith(".md"):
                         return os.path.join(category_dir, file)
            # Fallback to full search if not found in expected category (e.g. moved to archive)

    for root, _, files in os.walk(DOCS_DIR):
        for file in files:
            # Match strictly on ID at start of filename or substring
            # New ID: FOUNDATION-2023...
            # Old ID: FOUNDATION-001
            if file.startswith(task_id) and file.endswith(".md"):
                return os.path.join(root, file)
    return None

def show_task(task_id, output_format="text"):
    filepath = find_task_file(task_id)
    if not filepath:
        msg = f"Error: Task ID {task_id} not found."
        if output_format == "json":
            print(json.dumps({"error": msg}))
        else:
            print(msg)
        sys.exit(1)

    try:
        with open(filepath, "r") as f:
            content = f.read()

        if output_format == "json":
            task_data = parse_task_content(content, filepath)
            print(json.dumps(task_data))
        else:
            print(content)
    except Exception as e:
        msg = f"Error reading file: {e}"
        if output_format == "json":
            print(json.dumps({"error": msg}))
        else:
            print(msg)
        sys.exit(1)

def delete_task(task_id, output_format="text"):
    filepath = find_task_file(task_id)
    if not filepath:
        msg = f"Error: Task ID {task_id} not found."
        if output_format == "json":
            print(json.dumps({"error": msg}))
        else:
            print(msg)
        sys.exit(1)

    try:
        os.remove(filepath)
        if output_format == "json":
            print(json.dumps({"success": True, "id": task_id, "message": "Deleted task"}))
        else:
            print(f"Deleted task: {task_id}")
    except Exception as e:
        msg = f"Error deleting file: {e}"
        if output_format == "json":
            print(json.dumps({"error": msg}))
        else:
            print(msg)
        sys.exit(1)

def archive_task(task_id, output_format="text"):
    filepath = find_task_file(task_id)
    if not filepath:
        msg = f"Error: Task ID {task_id} not found."
        if output_format == "json":
            print(json.dumps({"error": msg}))
        else:
            print(msg)
        sys.exit(1)

    try:
        archive_dir = os.path.join(DOCS_DIR, ARCHIVE_DIR_NAME)
        os.makedirs(archive_dir, exist_ok=True)
        filename = os.path.basename(filepath)
        new_filepath = os.path.join(archive_dir, filename)

        os.rename(filepath, new_filepath)

        if output_format == "json":
            print(json.dumps({"success": True, "id": task_id, "message": "Archived task", "new_path": new_filepath}))
        else:
            print(f"Archived task: {task_id} -> {new_filepath}")

    except Exception as e:
        msg = f"Error archiving task: {e}"
        if output_format == "json":
            print(json.dumps({"error": msg}))
        else:
            print(msg)
        sys.exit(1)

def migrate_to_frontmatter(content, task_data):
    """Converts legacy content to Frontmatter format."""
    # Strip the header section from legacy content

    body = content
    if "## Task Details" in content:
        parts = content.split("## Task Details")
        if len(parts) > 1:
            body = parts[1].strip()

    description = body
    # Remove footer
    if "*Created:" in description:
        description = description.split("---")[0].strip()

    # Check for extra keys in task_data that might need preservation
    extra_fm = ""
    if task_data.get("type"): extra_fm += f"type: {task_data['type']}\n"
    if task_data.get("sprint"): extra_fm += f"sprint: {task_data['sprint']}\n"
    if task_data.get("estimate"): extra_fm += f"estimate: {task_data['estimate']}\n"

    deps = task_data.get("dependencies", [])
    if deps:
        if isinstance(deps, list):
            deps_str = "[" + ", ".join(deps) + "]"
        else:
            deps_str = str(deps)
        extra_fm += f"dependencies: {deps_str}\n"

    new_content = f"""---
id: {task_data['id']}
status: {task_data['status']}
title: {task_data['title']}
priority: {task_data['priority']}
created: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
category: unknown
{extra_fm}---

# {task_data['title']}

{description}
"""
    return new_content

def update_task_status(task_id, new_status, output_format="text"):
    if new_status not in VALID_STATUSES:
         msg = f"Error: Invalid status '{new_status}'. Valid statuses: {', '.join(VALID_STATUSES)}"
         if output_format == "json":
            print(json.dumps({"error": msg}))
         else:
            print(msg)
         sys.exit(1)

    filepath = find_task_file(task_id)
    if not filepath:
        msg = f"Error: Task ID {task_id} not found."
        if output_format == "json":
            print(json.dumps({"error": msg}))
        else:
            print(msg)
        sys.exit(1)

    with open(filepath, "r") as f:
        content = f.read()

    # Check dependencies if moving to active status
    if new_status in ["in_progress", "review_requested", "verified", "completed"]:
        task_data = parse_task_content(content, filepath)
        deps = task_data.get("dependencies", [])
        if deps:
            blocked_by = []
            for dep_id in deps:
                # Resolve dependency file
                dep_path = find_task_file(dep_id)
                if not dep_path:
                    blocked_by.append(f"{dep_id} (missing)")
                    continue

                try:
                    with open(dep_path, "r") as df:
                        dep_content = df.read()
                    dep_data = parse_task_content(dep_content, dep_path)

                    if dep_data["status"] not in ["completed", "verified"]:
                         blocked_by.append(f"{dep_id} ({dep_data['status']})")
                except Exception:
                    blocked_by.append(f"{dep_id} (error reading)")

            if blocked_by:
                msg = f"Error: Cannot move to '{new_status}' because task is blocked by dependencies: {', '.join(blocked_by)}"
                if output_format == "json":
                    print(json.dumps({"error": msg}))
                else:
                    print(msg)
                sys.exit(1)

    frontmatter, body = extract_frontmatter(content)

    if frontmatter:
        # Update Frontmatter
        lines = content.splitlines()
        new_lines = []
        in_fm = False
        updated = False

        # Simple finite state machine for update
        for line in lines:
            if re.match(r"^\s*---\s*$", line):
                if not in_fm:
                    in_fm = True
                    new_lines.append(line)
                    continue
                else:
                    in_fm = False
                    new_lines.append(line)
                    continue

            match = re.match(r"^(\s*)status:", line)
            if in_fm and match:
                indent = match.group(1)
                new_lines.append(f"{indent}status: {new_status}")
                updated = True
            else:
                new_lines.append(line)

        new_content = "\n".join(new_lines) + "\n"

    else:
        # Legacy Format: Migrate on Update
        task_data = parse_task_content(content, filepath)
        task_data['status'] = new_status # Set new status
        new_content = migrate_to_frontmatter(content, task_data)
        if output_format == "text":
            print(f"Migrated task {task_id} to new format.")

    with open(filepath, "w") as f:
        f.write(new_content)

    if output_format == "json":
        print(json.dumps({"success": True, "id": task_id, "status": new_status}))
    else:
        print(f"Updated {task_id} status to {new_status}")

def update_frontmatter_field(filepath, field, value):
    """Updates a specific field in the frontmatter."""
    with open(filepath, "r") as f:
        content = f.read()

    frontmatter, body = extract_frontmatter(content)
    if not frontmatter:
        # Fallback for legacy: migrate first
        task_data = parse_task_content(content, filepath)
        task_data[field] = value
        new_content = migrate_to_frontmatter(content, task_data)
        with open(filepath, "w") as f:
            f.write(new_content)
        return True

    # Update Frontmatter line-by-line to preserve comments/order
    lines = content.splitlines()
    new_lines = []
    in_fm = False
    updated = False

    # Handle list values (like dependencies)
    if isinstance(value, list):
        # Serialize as Flow-style list [a, b] for valid YAML and easier regex
        val_str = "[" + ", ".join(value) + "]"
    else:
        val_str = str(value)

    for line in lines:
        if re.match(r"^\s*---\s*$", line):
            if not in_fm:
                in_fm = True
                new_lines.append(line)
                continue
            else:
                if in_fm and not updated:
                    # Field not found, add it before close
                    new_lines.append(f"{field}: {val_str}")
                in_fm = False
                new_lines.append(line)
                continue

        match = re.match(rf"^(\s*){field}:", line)
        if in_fm and match:
            indent = match.group(1)
            new_lines.append(f"{indent}{field}: {val_str}")
            updated = True
        else:
            new_lines.append(line)

    new_content = "\n".join(new_lines) + "\n"
    with open(filepath, "w") as f:
        f.write(new_content)
    return True

def add_dependency(task_id, dep_id, output_format="text"):
    filepath = find_task_file(task_id)
    if not filepath:
        msg = f"Error: Task ID {task_id} not found."
        print(json.dumps({"error": msg}) if output_format == "json" else msg)
        sys.exit(1)

    # Verify dep exists
    if not find_task_file(dep_id):
         msg = f"Error: Dependency Task ID {dep_id} not found."
         print(json.dumps({"error": msg}) if output_format == "json" else msg)
         sys.exit(1)

    with open(filepath, "r") as f:
        content = f.read()

    task_data = parse_task_content(content, filepath)
    deps = task_data.get("dependencies", [])

    if dep_id in deps:
        msg = f"Task {task_id} already depends on {dep_id}."
        print(json.dumps({"message": msg}) if output_format == "json" else msg)
        return

    deps.append(dep_id)
    update_frontmatter_field(filepath, "dependencies", deps)

    msg = f"Added dependency: {task_id} -> {dep_id}"
    print(json.dumps({"success": True, "message": msg}) if output_format == "json" else msg)

def remove_dependency(task_id, dep_id, output_format="text"):
    filepath = find_task_file(task_id)
    if not filepath:
        msg = f"Error: Task ID {task_id} not found."
        print(json.dumps({"error": msg}) if output_format == "json" else msg)
        sys.exit(1)

    with open(filepath, "r") as f:
        content = f.read()

    task_data = parse_task_content(content, filepath)
    deps = task_data.get("dependencies", [])

    if dep_id not in deps:
        msg = f"Task {task_id} does not depend on {dep_id}."
        print(json.dumps({"message": msg}) if output_format == "json" else msg)
        return

    deps.remove(dep_id)
    update_frontmatter_field(filepath, "dependencies", deps)

    msg = f"Removed dependency: {task_id} -x-> {dep_id}"
    print(json.dumps({"success": True, "message": msg}) if output_format == "json" else msg)

def generate_index(output_format="text"):
    """Generates docs/tasks/INDEX.yaml reflecting task dependencies."""
    index_path = os.path.join(DOCS_DIR, "INDEX.yaml")

    all_tasks = {} # id -> filepath
    task_deps = {} # id -> [deps]

    for root, _, files in os.walk(DOCS_DIR):
        for file in files:
            if not file.endswith(".md") or file in ["GUIDE.md", "README.md", "INDEX.yaml"]:
                continue
            path = os.path.join(root, file)
            try:
                with open(path, "r") as f:
                    content = f.read()
                task = parse_task_content(content, path)
                if task["id"] != "unknown":
                    all_tasks[task["id"]] = path
                    task_deps[task["id"]] = task.get("dependencies", [])
            except:
                pass

    # Build YAML content
    yaml_lines = ["# Task Dependency Index", "# Generated by scripts/tasks.py index", ""]

    for tid, path in sorted(all_tasks.items()):
        rel_path = os.path.relpath(path, REPO_ROOT)
        yaml_lines.append(f"{rel_path}:")

        deps = task_deps.get(tid, [])
        if deps:
            yaml_lines.append("  depends_on:")
            for dep_id in sorted(deps):
                dep_path = all_tasks.get(dep_id)
                if dep_path:
                    dep_rel_path = os.path.relpath(dep_path, REPO_ROOT)
                    yaml_lines.append(f"    - {dep_rel_path}")
                else:
                    # Dependency not found (maybe archived or missing)
                    yaml_lines.append(f"    - {dep_id} # Missing")

        yaml_lines.append("")

    with open(index_path, "w") as f:
        f.write("\n".join(yaml_lines))

    msg = f"Generated index at {index_path}"
    print(json.dumps({"success": True, "path": index_path}) if output_format == "json" else msg)

def list_tasks(status=None, category=None, sprint=None, include_archived=False, output_format="text"):
    tasks = []

    for root, dirs, files in os.walk(DOCS_DIR):
        rel_path = os.path.relpath(root, DOCS_DIR)

        # Exclude archive unless requested
        if not include_archived:
            if rel_path == ARCHIVE_DIR_NAME or rel_path.startswith(ARCHIVE_DIR_NAME + os.sep):
                continue

        # Filter by category if provided
        if category:
            if rel_path != category and not rel_path.startswith(category + os.sep):
                continue

        for file in files:
            if not file.endswith(".md") or file in ["GUIDE.md", "README.md", "INDEX.yaml"]:
                continue

            path = os.path.join(root, file)
            try:
                with open(path, "r") as f:
                    content = f.read()
            except Exception as e:
                if output_format == "text":
                    print(f"Error reading {path}: {e}")
                continue

            # Parse content
            task = parse_task_content(content, path)

            # Skip files that don't look like tasks (no ID)
            if task["id"] == "unknown":
                continue

            if status and status.lower() != task["status"].lower():
                continue

            if sprint and sprint != task.get("sprint"):
                continue

            tasks.append(task)

    if output_format == "json":
        summary = [{k: v for k, v in t.items() if k != 'content'} for t in tasks]
        print(json.dumps(summary))
    else:
        # Adjust width for ID to handle longer IDs
        print(f"{'ID':<25} {'Status':<20} {'Type':<8} {'Title'}")
        print("-" * 85)
        for t in tasks:
            t_type = t.get("type", "task")[:8]
            print(f"{t['id']:<25} {t['status']:<20} {t_type:<8} {t['title']}")

def get_context(output_format="text"):
    """Lists tasks that are currently in progress."""
    if output_format == "text":
        print("Current Context (in_progress):")
    list_tasks(status="in_progress", output_format=output_format)

def migrate_all():
    """Migrates all legacy tasks to Frontmatter format."""
    print("Migrating tasks to Frontmatter format...")
    count = 0
    for root, dirs, files in os.walk(DOCS_DIR):
        for file in files:
            if not file.endswith(".md") or file in ["GUIDE.md", "README.md", "INDEX.yaml"]:
                continue

            path = os.path.join(root, file)
            with open(path, "r") as f:
                content = f.read()

            if content.startswith("---\n") or content.startswith("--- "):
                continue # Already migrated (simple check)

            task_data = parse_task_content(content, path)
            if task_data['id'] == "unknown":
                continue

            new_content = migrate_to_frontmatter(content, task_data)
            with open(path, "w") as f:
                f.write(new_content)

            print(f"Migrated {task_data['id']}")
            count += 1

    print(f"Migration complete. {count} tasks updated.")

def validate_all(output_format="text"):
    """Validates all task files."""
    errors = []
    all_tasks = {}  # id -> {path, deps}

    # Pass 1: Parse and Basic Validation
    for root, dirs, files in os.walk(DOCS_DIR):
        for file in files:
            if not file.endswith(".md") or file in ["GUIDE.md", "README.md", "INDEX.yaml"]:
                continue
            path = os.path.join(root, file)
            try:
                with open(path, "r") as f:
                    content = f.read()

                # Check 1: Frontmatter exists
                frontmatter, body = extract_frontmatter(content)
                if not frontmatter:
                    errors.append(f"{file}: Missing valid frontmatter")
                    continue

                # Check 2: Required fields
                required_fields = ["id", "status", "title", "created"]
                missing = [field for field in required_fields if field not in frontmatter]
                if missing:
                    errors.append(f"{file}: Missing required fields: {', '.join(missing)}")
                    continue

                task_id = frontmatter["id"]

                # Check 3: Valid Status
                if "status" in frontmatter and frontmatter["status"] not in VALID_STATUSES:
                    errors.append(f"{file}: Invalid status '{frontmatter['status']}'")

                # Check 4: Valid Type
                if "type" in frontmatter and frontmatter["type"] not in VALID_TYPES:
                    errors.append(f"{file}: Invalid type '{frontmatter['type']}'")

                # Parse dependencies
                deps_str = frontmatter.get("dependencies") or ""
                # Use shared parsing logic
                deps = []
                if deps_str:
                    cleaned = deps_str.strip(" []")
                    if cleaned:
                        deps = [d.strip() for d in cleaned.split(",") if d.strip()]

                # Check for Duplicate IDs
                if task_id in all_tasks:
                    errors.append(f"{file}: Duplicate Task ID '{task_id}' (also in {all_tasks[task_id]['path']})")

                all_tasks[task_id] = {"path": path, "deps": deps}

            except Exception as e:
                errors.append(f"{file}: Error reading/parsing: {str(e)}")

    # Pass 2: Dependency Validation & Cycle Detection
    visited = set()
    recursion_stack = set()

    def detect_cycle(curr_id, path):
        visited.add(curr_id)
        recursion_stack.add(curr_id)

        if curr_id in all_tasks:
            for dep_id in all_tasks[curr_id]["deps"]:
                # Dependency Existence Check
                if dep_id not in all_tasks:
                    # This will be caught in the loop below, but we need to handle it here to avoid error
                    continue

                if dep_id not in visited:
                    if detect_cycle(dep_id, path + [dep_id]):
                        return True
                elif dep_id in recursion_stack:
                    path.append(dep_id)
                    return True

        recursion_stack.remove(curr_id)
        return False

    for task_id, info in all_tasks.items():
        # Check dependencies exist
        for dep_id in info["deps"]:
            if dep_id not in all_tasks:
                errors.append(f"{os.path.basename(info['path'])}: Invalid dependency '{dep_id}' (task not found)")

        # Check cycles
        if task_id not in visited:
            cycle_path = [task_id]
            if detect_cycle(task_id, cycle_path):
                errors.append(f"Circular dependency detected: {' -> '.join(cycle_path)}")

    if output_format == "json":
        print(json.dumps({"valid": len(errors) == 0, "errors": errors}))
    else:
        if not errors:
            print("All tasks validated successfully.")
        else:
            print(f"Found {len(errors)} errors:")
            for err in errors:
                print(f" - {err}")
            sys.exit(1)

def visualize_tasks(output_format="text"):
    """Generates a Mermaid diagram of task dependencies."""
    tasks = []
    # Collect all tasks
    for root, dirs, files in os.walk(DOCS_DIR):
        for file in files:
            if not file.endswith(".md") or file in ["GUIDE.md", "README.md", "INDEX.yaml"]:
                continue
            path = os.path.join(root, file)
            try:
                with open(path, "r") as f:
                    content = f.read()
                task = parse_task_content(content, path)
                if task["id"] != "unknown":
                    tasks.append(task)
            except:
                pass

    if output_format == "json":
        nodes = [{"id": t["id"], "title": t["title"], "status": t["status"]} for t in tasks]
        edges = []
        for t in tasks:
            for dep in t.get("dependencies", []):
                edges.append({"from": dep, "to": t["id"]})
        print(json.dumps({"nodes": nodes, "edges": edges}))
        return

    # Mermaid Output
    print("graph TD")

    status_colors = {
        "completed": "#90EE90",
        "verified": "#90EE90",
        "in_progress": "#ADD8E6",
        "review_requested": "#FFFACD",
        "wip_blocked": "#FFB6C1",
        "blocked": "#FF7F7F",
        "pending": "#D3D3D3",
        "deferred": "#A9A9A9",
        "cancelled": "#696969"
    }

    # Nodes
    for t in tasks:
        # Sanitize title for label
        safe_title = t["title"].replace('"', '').replace('[', '').replace(']', '')
        print(f'    {t["id"]}["{t["id"]}: {safe_title}"]')

        # Style
        color = status_colors.get(t["status"], "#FFFFFF")
        print(f"    style {t['id']} fill:{color},stroke:#333,stroke-width:2px")

    # Edges
    for t in tasks:
        deps = t.get("dependencies", [])
        for dep in deps:
            print(f"    {dep} --> {t['id']}")

def get_next_task(output_format="text"):
    """Identifies the next best task to work on."""
    # 1. Collect all tasks
    all_tasks = {}
    for root, _, files in os.walk(DOCS_DIR):
        for file in files:
            if not file.endswith(".md") or file in ["GUIDE.md", "README.md", "INDEX.yaml"]:
                continue
            path = os.path.join(root, file)
            try:
                with open(path, "r") as f:
                    content = f.read()
                task = parse_task_content(content, path)
                if task["id"] != "unknown":
                    all_tasks[task["id"]] = task
            except:
                pass

    candidates = []

    # Priority mapping
    prio_score = {"high": 3, "medium": 2, "low": 1, "unknown": 1}

    for tid, task in all_tasks.items():
        # Filter completed
        if task["status"] in ["completed", "verified", "cancelled", "deferred", "blocked"]:
            continue

        # Check dependencies
        deps = task.get("dependencies", [])
        blocked = False
        for dep_id in deps:
            if dep_id not in all_tasks:
                blocked = True # Missing dependency
                break

            dep_status = all_tasks[dep_id]["status"]
            if dep_status not in ["completed", "verified"]:
                blocked = True
                break

        if blocked:
            continue

        # Calculate Score
        score = 0

        # Status Bonus
        if task["status"] == "in_progress":
            score += 1000
        elif task["status"] == "pending":
            score += 100
        elif task["status"] == "wip_blocked":
             # Unblocked now
             score += 500

        # Priority
        score += prio_score.get(task.get("priority", "medium"), 1) * 10

        # Sprint Bonus
        if task.get("sprint"):
            score += 50

        # Type Bonus (Stories/Bugs > Tasks > Epics)
        t_type = task.get("type", "task")
        if t_type in ["story", "bug"]:
            score += 20
        elif t_type == "task":
            score += 10

        candidates.append((score, task))

    candidates.sort(key=lambda x: x[0], reverse=True)

    if not candidates:
        msg = "No suitable tasks found (all completed or blocked)."
        if output_format == "json":
            print(json.dumps({"message": msg}))
        else:
            print(msg)
        return

    best = candidates[0][1]

    if output_format == "json":
        print(json.dumps(best))
    else:
        print(f"Recommended Next Task (Score: {candidates[0][0]}):")
        print(f"ID:       {best['id']}")
        print(f"Title:    {best['title']}")
        print(f"Status:   {best['status']}")
        print(f"Priority: {best['priority']}")
        print(f"Type:     {best.get('type', 'task')}")
        if best.get("sprint"):
             print(f"Sprint:   {best.get('sprint')}")
        print(f"\nRun: scripts/tasks show {best['id']}")

def install_hooks():
    """Installs the git pre-commit hook."""
    hook_path = os.path.join(REPO_ROOT, ".git", "hooks", "pre-commit")
    if not os.path.exists(os.path.join(REPO_ROOT, ".git")):
        print("Error: Not a git repository.")
        sys.exit(1)

    script_path = os.path.relpath(os.path.abspath(__file__), REPO_ROOT)

    hook_content = f"""#!/bin/sh
# Auto-generated by scripts/tasks.py
echo "Running task validation..."
python3 {script_path} validate --format text
"""

    try:
        with open(hook_path, "w") as f:
            f.write(hook_content)
        os.chmod(hook_path, 0o755)
        print(f"Installed pre-commit hook at {hook_path}")
    except Exception as e:
        print(f"Error installing hook: {e}")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description="Manage development tasks")

    # Common argument for format
    parent_parser = argparse.ArgumentParser(add_help=False)
    parent_parser.add_argument("--format", choices=["text", "json"], default="text", help="Output format")

    subparsers = parser.add_subparsers(dest="command", help="Command to run")

    # Init
    subparsers.add_parser("init", help="Initialize documentation structure")

    # Create
    create_parser = subparsers.add_parser("create", parents=[parent_parser], help="Create a new task")
    create_parser.add_argument("category", choices=CATEGORIES, help="Task category")
    create_parser.add_argument("title", help="Task title")
    create_parser.add_argument("--desc", default="To be determined", help="Task description")
    create_parser.add_argument("--priority", default="medium", help="Task priority")
    create_parser.add_argument("--status", choices=VALID_STATUSES, default="pending", help="Task status")
    create_parser.add_argument("--dependencies", help="Comma-separated list of task IDs this task depends on")
    create_parser.add_argument("--type", choices=VALID_TYPES, default="task", help="Task type")
    create_parser.add_argument("--sprint", default="", help="Sprint name/ID")
    create_parser.add_argument("--estimate", default="", help="Estimate (points/size)")

    # List
    list_parser = subparsers.add_parser("list", parents=[parent_parser], help="List tasks")
    list_parser.add_argument("--status", help="Filter by status")
    list_parser.add_argument("--category", choices=CATEGORIES, help="Filter by category")
    list_parser.add_argument("--sprint", help="Filter by sprint")
    list_parser.add_argument("--archived", action="store_true", help="Include archived tasks")

    # Show
    show_parser = subparsers.add_parser("show", parents=[parent_parser], help="Show task details")
    show_parser.add_argument("task_id", help="Task ID (e.g., FOUNDATION-001)")

    # Update
    update_parser = subparsers.add_parser("update", parents=[parent_parser], help="Update task status")
    update_parser.add_argument("task_id", help="Task ID (e.g., FOUNDATION-001)")
    update_parser.add_argument("status", help=f"New status: {', '.join(VALID_STATUSES)}")

    # Delete
    delete_parser = subparsers.add_parser("delete", parents=[parent_parser], help="Delete a task")
    delete_parser.add_argument("task_id", help="Task ID (e.g., FOUNDATION-001)")

    # Archive
    archive_parser = subparsers.add_parser("archive", parents=[parent_parser], help="Archive a task")
    archive_parser.add_argument("task_id", help="Task ID")

    # Context
    subparsers.add_parser("context", parents=[parent_parser], help="Show current context (in_progress tasks)")

    # Next
    subparsers.add_parser("next", parents=[parent_parser], help="Suggest the next task to work on")

    # Migrate
    subparsers.add_parser("migrate", parents=[parent_parser], help="Migrate legacy tasks to new format")

    # Complete
    complete_parser = subparsers.add_parser("complete", parents=[parent_parser], help="Mark a task as completed")
    complete_parser.add_argument("task_id", help="Task ID (e.g., FOUNDATION-001)")

    # Validate
    subparsers.add_parser("validate", parents=[parent_parser], help="Validate task files")

    # Visualize
    subparsers.add_parser("visualize", parents=[parent_parser], help="Visualize task dependencies (Mermaid)")

    # Graph (Alias to Visualize)
    subparsers.add_parser("graph", parents=[parent_parser], help="Graph task dependencies (Alias for visualize)")

    # Install Hooks
    subparsers.add_parser("install-hooks", parents=[parent_parser], help="Install git hooks")

    # Index
    subparsers.add_parser("index", parents=[parent_parser], help="Generate task dependency index")

    # Link (Add Dependency)
    link_parser = subparsers.add_parser("link", parents=[parent_parser], help="Add a dependency")
    link_parser.add_argument("task_id", help="Task ID")
    link_parser.add_argument("dep_id", help="Dependency Task ID")

    # Unlink (Remove Dependency)
    unlink_parser = subparsers.add_parser("unlink", parents=[parent_parser], help="Remove a dependency")
    unlink_parser.add_argument("task_id", help="Task ID")
    unlink_parser.add_argument("dep_id", help="Dependency Task ID")

    args = parser.parse_args()

    # Default format to text if not present (e.g. init doesn't have it)
    fmt = getattr(args, "format", "text")

    if args.command == "create":
        deps = []
        if args.dependencies:
            deps = [d.strip() for d in args.dependencies.split(",") if d.strip()]
        create_task(args.category, args.title, args.desc, priority=args.priority, status=args.status, dependencies=deps, task_type=args.type, sprint=args.sprint, estimate=args.estimate, output_format=fmt)
    elif args.command == "list":
        list_tasks(args.status, args.category, sprint=args.sprint, include_archived=args.archived, output_format=fmt)
    elif args.command == "init":
        init_docs()
    elif args.command == "show":
        show_task(args.task_id, output_format=fmt)
    elif args.command == "delete":
        delete_task(args.task_id, output_format=fmt)
    elif args.command == "archive":
        archive_task(args.task_id, output_format=fmt)
    elif args.command == "update":
        update_task_status(args.task_id, args.status, output_format=fmt)
    elif args.command == "context":
        get_context(output_format=fmt)
    elif args.command == "next":
        get_next_task(output_format=fmt)
    elif args.command == "migrate":
        migrate_all()
    elif args.command == "complete":
        update_task_status(args.task_id, "completed", output_format=fmt)
    elif args.command == "validate":
        validate_all(output_format=fmt)
    elif args.command == "visualize" or args.command == "graph":
        visualize_tasks(output_format=fmt)
    elif args.command == "install-hooks":
        install_hooks()
    elif args.command == "index":
        generate_index(output_format=fmt)
    elif args.command == "link":
        add_dependency(args.task_id, args.dep_id, output_format=fmt)
    elif args.command == "unlink":
        remove_dependency(args.task_id, args.dep_id, output_format=fmt)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
