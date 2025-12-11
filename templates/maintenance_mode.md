# AI Agent Instructions

You are an expert Software Engineer working on this project. Your primary responsibility is to implement features and fixes while strictly adhering to the **Task Documentation System**.

## Core Philosophy
**"If it's not documented in `docs/tasks/`, it didn't happen."**

## Workflow
1.  **Pick a Task**: Run `python3 scripts/tasks.py context` to see active tasks, or `list` to see pending ones.
2.  **Plan & Document**:
    *   **Memory Check**: Run `python3 scripts/memory.py list` (or use the Memory Skill) to recall relevant long-term information.
    *   **Security Check**: Ask the user about specific security considerations for this task.
    *   If starting a new task, use `scripts/tasks.py create` (or `python3 scripts/tasks.py create`) to generate a new task file.
    *   Update the task status: `python3 scripts/tasks.py update [TASK_ID] in_progress`.
3.  **Implement**: Write code, run tests.
4.  **Update Documentation Loop**:
    *   As you complete sub-tasks, check them off in the task document.
    *   If you hit a blocker, update status to `wip_blocked` and describe the issue in the file.
    *   Record key architectural decisions in the task document.
    *   **Memory Update**: If you learn something valuable for the long term, use `scripts/memory.py create` to record it.
5.  **Review & Verify**:
    *   Once implementation is complete, update status to `review_requested`: `python3 scripts/tasks.py update [TASK_ID] review_requested`.
    *   Ask a human or another agent to review the code.
    *   Once approved and tested, update status to `verified`.
6.  **Finalize**:
    *   Update status to `completed`: `python3 scripts/tasks.py update [TASK_ID] completed`.
    *   Record actual effort in the file.
    *   Ensure all acceptance criteria are met.

## Tools
*   **Wrapper**: `./scripts/tasks` (Checks for Python, recommended).
*   **Create**: `./scripts/tasks create [category] "Title"`
*   **List**: `./scripts/tasks list [--status pending]`
*   **Context**: `./scripts/tasks context`
*   **Update**: `./scripts/tasks update [ID] [status]`
*   **Migrate**: `./scripts/tasks migrate` (Migrate legacy tasks to new format)
*   **Memory**: `./scripts/memory.py [create|list|read]`
*   **JSON Output**: Add `--format json` to any command for machine parsing.

## Documentation Reference
*   **Guide**: Read `docs/tasks/GUIDE.md` for strict formatting and process rules.
*   **Architecture**: Refer to `docs/architecture/` for system design.
*   **Features**: Refer to `docs/features/` for feature specifications.
*   **Security**: Refer to `docs/security/` for risk assessments and mitigations.
*   **Memories**: Refer to `docs/memories/` for long-term project context.

## Code Style & Standards
*   Follow the existing patterns in the codebase.
*   Ensure all new code is covered by tests (if testing infrastructure exists).

## PR Review Methodology
When performing a PR review, follow this "Human-in-the-loop" process to ensure depth and efficiency.

### 1. Preparation
1.  **Create Task**: `python3 scripts/tasks.py create review "Review PR #<N>: <Title>"`
2.  **Fetch Details**: Use `gh` to get the PR context.
    *   `gh pr view <N>`
    *   `gh pr diff <N>`

### 2. Analysis & Planning (The "Review Plan")
**Do not review line-by-line yet.** Instead, analyze the changes and document a **Review Plan** in the task file (or present it for approval).

Your plan must include:
*   **High-Level Summary**: Purpose, new APIs, breaking changes.
*   **Dependency Check**: New libraries, maintenance status, security.
*   **Impact Assessment**: Effect on existing code/docs.
*   **Focus Areas**: Prioritized list of files/modules to check.
*   **Suggested Comments**: Draft comments for specific lines.
    *   Format: `File: <path> | Line: <N> | Comment: <suggestion>`
    *   Tone: Friendly, suggestion-based ("Consider...", "Nit: ...").

### 3. Execution
Once the human approves the plan and comments:
1.  **Pending Review**: Create a pending review using `gh`.
    *   `COMMIT_SHA=$(gh pr view <N> --json headRefOid -q .headRefOid)`
    *   `gh api repos/{owner}/{repo}/pulls/{N}/reviews -f commit_id="$COMMIT_SHA"`
2.  **Batch Comments**: Add comments to the pending review.
    *   `gh api repos/{owner}/{repo}/pulls/{N}/comments -f body="..." -f path="..." -f commit_id="$COMMIT_SHA" -F line=<L> -f side="RIGHT"`
3.  **Submit**:
    *   `gh pr review <N> --approve --body "Summary..."` (or `--request-changes`).

### 4. Close Task
*   Update task status to `completed`.

## Agent Interoperability
- **Task Manager Skill**: `.claude/skills/task_manager/`
- **Memory Skill**: `.claude/skills/memory/`
- **Tool Definitions**: `docs/interop/tool_definitions.json`
