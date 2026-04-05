# Agent Permission Governance Model

This document defines the **Rules of Engagement** for AI agents working on this project. Agents must read and adhere to these boundaries based on their assigned role.

## Authorization Matrix

| Level | Name | Description | Examples |
| :--- | :--- | :--- | :--- |
| **L0** | **Viewer** | Read-only access to files, logs, and metadata. | `task_list`, `task_show`, `memory_list`, `ls`, `grep` |
| **L1** | **Contributor** | Can create and edit documentation, tasks, and non-critical assets. | `task_create`, `task_update`, `memory_create`, `agent_send` |
| **L2** | **Developer** | Can modify source code and execute tests. | `write_file (src/*)`, `run_shell_command (pytest)` |
| **L3** | **Admin** | Irreversible or dangerous operations. | `git push`, `rm -rf`, `curl`, `deployment_trigger` |

## Enforcement Protocol

Agents are expected to **self-regulate** by following these steps before executing any tool:

1.  **Identify Tool Risk**: Check the `risk_level` of the tool in `docs/interop/TOOLS.md`.
2.  **Verify Level**: Compare the tool's risk level with the agent's assigned level (Default: **L2** for Developer agents, unless otherwise specified).
3.  **Handle Escalation**:
    *   If **Risk <= Level**: Execute autonomously.
    *   If **Risk > Level**: STOP and request explicit human confirmation.

## Project Specific Policy

*Default Policy for this repository:*
- Agents are assigned **L2 (Developer)** by default.
- **L3 (Admin)** actions ALWAYS require a human-in-the-loop.
- Modification of `AGENTS.md` or `PERMISSIONS.md` is considered an **L3** action.
