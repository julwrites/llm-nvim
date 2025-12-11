#!/usr/bin/env python3
import os
import sys
import argparse
import json
import datetime
import re

# Determine the root directory of the repo
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
# Allow overriding root for testing, similar to tasks.py
REPO_ROOT = os.getenv("TASKS_REPO_ROOT", os.path.dirname(SCRIPT_DIR))
MEMORY_DIR = os.path.join(REPO_ROOT, "docs", "memories")

def init_memory():
    """Ensures the memory directory exists."""
    os.makedirs(MEMORY_DIR, exist_ok=True)
    if not os.path.exists(os.path.join(MEMORY_DIR, ".keep")):
        with open(os.path.join(MEMORY_DIR, ".keep"), "w") as f:
            pass

def slugify(text):
    """Creates a URL-safe slug from text."""
    text = text.lower().strip()
    return re.sub(r'[^a-z0-9-]', '-', text).strip('-')

def create_memory(title, content, tags=None, output_format="text"):
    init_memory()
    tags = tags or []
    if isinstance(tags, str):
        tags = [t.strip() for t in tags.split(",") if t.strip()]

    date_str = datetime.date.today().isoformat()
    slug = slugify(title)
    if not slug:
        slug = "untitled"

    filename = f"{date_str}-{slug}.md"
    filepath = os.path.join(MEMORY_DIR, filename)

    # Handle duplicates by appending counter
    counter = 1
    while os.path.exists(filepath):
        filename = f"{date_str}-{slug}-{counter}.md"
        filepath = os.path.join(MEMORY_DIR, filename)
        counter += 1

    # Create Frontmatter
    fm = f"""---
date: {date_str}
title: "{title}"
tags: {json.dumps(tags)}
created: {datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
---
"""

    full_content = fm + "\n" + content + "\n"

    try:
        with open(filepath, "w") as f:
            f.write(full_content)

        if output_format == "json":
            print(json.dumps({
                "success": True,
                "filepath": filepath,
                "title": title,
                "date": date_str
            }))
        else:
            print(f"Created memory: {filepath}")
    except Exception as e:
        msg = f"Error creating memory: {e}"
        if output_format == "json":
            print(json.dumps({"error": msg}))
        else:
            print(msg)
        sys.exit(1)

def list_memories(tag=None, limit=20, output_format="text"):
    if not os.path.exists(MEMORY_DIR):
        if output_format == "json":
            print(json.dumps([]))
        else:
            print("No memories found.")
        return

    memories = []
    try:
        files = [f for f in os.listdir(MEMORY_DIR) if f.endswith(".md") and f != ".keep"]
    except FileNotFoundError:
        files = []

    for f in files:
        path = os.path.join(MEMORY_DIR, f)
        try:
            with open(path, "r") as file:
                content = file.read()

                # Extract basic info from frontmatter
                title = "Unknown"
                date = "Unknown"
                tags = []

                # Simple regex parsing to avoid YAML dependency
                m_title = re.search(r'^title:\s*"(.*)"', content, re.MULTILINE)
                if m_title:
                    title = m_title.group(1)
                else:
                    # Fallback: unquoted title
                    m_title_uq = re.search(r'^title:\s*(.*)', content, re.MULTILINE)
                    if m_title_uq: title = m_title_uq.group(1).strip()

                m_date = re.search(r'^date:\s*(.*)', content, re.MULTILINE)
                if m_date: date = m_date.group(1).strip()

                m_tags = re.search(r'^tags:\s*(\[.*\])', content, re.MULTILINE)
                if m_tags:
                    try:
                        tags = json.loads(m_tags.group(1))
                    except:
                        pass

                if tag and tag not in tags:
                    continue

                memories.append({
                    "filename": f,
                    "title": title,
                    "date": date,
                    "tags": tags,
                    "path": path
                })
        except Exception:
            # Skip unreadable files
            pass

    # Sort by date desc (filename usually works for YYYY-MM-DD prefix)
    memories.sort(key=lambda x: x["filename"], reverse=True)
    memories = memories[:limit]

    if output_format == "json":
        print(json.dumps(memories))
    else:
        if not memories:
            print("No memories found.")
            return

        print(f"{'Date':<12} {'Title'}")
        print("-" * 50)
        for m in memories:
            print(f"{m['date']:<12} {m['title']}")

def read_memory(filename, output_format="text"):
    path = os.path.join(MEMORY_DIR, filename)
    if not os.path.exists(path):
         # Try finding by partial match if not exact
         if os.path.exists(MEMORY_DIR):
             matches = [f for f in os.listdir(MEMORY_DIR) if filename in f and f.endswith(".md")]
             if len(matches) == 1:
                 path = os.path.join(MEMORY_DIR, matches[0])
             elif len(matches) > 1:
                 msg = f"Error: Ambiguous memory identifier '{filename}'. Matches: {', '.join(matches)}"
                 if output_format == "json":
                     print(json.dumps({"error": msg}))
                 else:
                     print(msg)
                 sys.exit(1)
             else:
                msg = f"Error: Memory file '{filename}' not found."
                if output_format == "json":
                    print(json.dumps({"error": msg}))
                else:
                    print(msg)
                sys.exit(1)
         else:
             msg = f"Error: Memory directory does not exist."
             if output_format == "json":
                 print(json.dumps({"error": msg}))
             else:
                 print(msg)
             sys.exit(1)

    try:
        with open(path, "r") as f:
            content = f.read()

        if output_format == "json":
            print(json.dumps({"filename": os.path.basename(path), "content": content}))
        else:
            print(content)
    except Exception as e:
        msg = f"Error reading file: {e}"
        if output_format == "json":
            print(json.dumps({"error": msg}))
        else:
            print(msg)
        sys.exit(1)

def main():
    # Common argument for format
    parent_parser = argparse.ArgumentParser(add_help=False)
    parent_parser.add_argument("--format", choices=["text", "json"], default="text", help="Output format")

    parser = argparse.ArgumentParser(description="Manage long-term memories")

    subparsers = parser.add_subparsers(dest="command")

    # Create
    create_parser = subparsers.add_parser("create", parents=[parent_parser], help="Create a new memory")
    create_parser.add_argument("title", help="Title of the memory")
    create_parser.add_argument("content", help="Content of the memory")
    create_parser.add_argument("--tags", help="Comma-separated tags")

    # List
    list_parser = subparsers.add_parser("list", parents=[parent_parser], help="List memories")
    list_parser.add_argument("--tag", help="Filter by tag")
    list_parser.add_argument("--limit", type=int, default=20, help="Max results")

    # Read
    read_parser = subparsers.add_parser("read", parents=[parent_parser], help="Read a memory")
    read_parser.add_argument("filename", help="Filename or slug part")

    args = parser.parse_args()

    # Default format to text if not present (though parents default handles it)
    fmt = getattr(args, "format", "text")

    if args.command == "create":
        create_memory(args.title, args.content, args.tags, fmt)
    elif args.command == "list":
        list_memories(args.tag, args.limit, fmt)
    elif args.command == "read":
        read_memory(args.filename, fmt)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
