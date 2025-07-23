# Architectural Recommendations for llm-nvim

This document outlines a series of architectural recommendations to improve the modularity, maintainability, and testability of the `llm-nvim` codebase.

## 1. Proposed Architecture

The proposed architecture introduces a clear separation of concerns by organizing the codebase into three main layers: **core**, **managers**, and **ui**.

### 1.1. Directory Structure

```
lua/
└── llm/
    ├── core/
    │   ├── data/
    │   │   ├── llm_cli.lua
    │   │   └── cache.lua
    │   ├── utils/
    │   │   ├── file_utils.lua
    │   │   ├── notify.lua
    │   │   ├── shell.lua
    │   │   ├── text.lua
    │   │   └── ui.lua
    │   └── loaders.lua
    ├── managers/
    │   ├── models_manager.lua
    │   ├── plugins_manager.lua
    │   ├── keys_manager.lua
    │   ├── fragments_manager.lua
    │   ├── templates_manager.lua
    │   └── schemas_manager.lua
    ├── ui/
    │   ├── views/
    │   │   ├── models_view.lua
    │   │   ├── plugins_view.lua
    │   │   ├── keys_view.lua
    │   │   ├── fragments_view.lua
    │   │   ├── templates_view.lua
    │   │   └── schemas_view.lua
    │   ├── unified_manager.lua
    │   └── ui.lua
    ├── api.lua
    ├── commands.lua
    ├── config.lua
    ├── errors.lua
    ├── facade.lua
    └── init.lua
```

### 1.2. Key Components

*   **`core`**: This layer contains the core business logic and data access layer.
    *   **`data`**: This sub-layer is responsible for all data access, including interactions with the `llm` CLI tool and caching.
    *   **`utils`**: This sub-layer contains utility functions.
    *   **`loaders.lua`**: This module is responsible for loading all necessary data at startup.
*   **`managers`**: This layer contains the manager modules, which are responsible for the business logic of each feature (models, plugins, keys, etc.).
*   **`ui`**: This layer contains all UI-related modules, including the views and the unified manager.

## 2. Refactoring Sub-Tasks

The following sub-tasks should be completed to implement the new architecture:

**1. Create the new directory structure:**
    *   Create the directories: `lua/llm/core`, `lua/llm/core/data`, `lua/llm/core/utils`, `lua/llm/managers`, `lua/llm/ui`, `lua/llm/ui/views`.

**2. Move and refactor the utility modules:**
    *   Move `lua/llm/utils/` to `lua/llm/core/`.
    *   Merge the contents of `lua/llm/utils.lua` into the appropriate modules in `lua/llm/core/utils/`.
    *   Delete `lua/llm/utils.lua`.
    *   Update all `require` statements that reference the old `utils` modules.

**3. Create the data access layer:**
    *   Create `lua/llm/core/data/llm_cli.lua` to handle all interactions with the `llm` CLI tool.
    *   Create `lua/llm/core/data/cache.lua` to provide caching functionality.

**4. Refactor the manager modules:**
    *   Move all manager modules to `lua/llm/managers/`.
    *   Replace all direct calls to the `llm` CLI tool with calls to the `llm_cli.lua` module.
    *   Remove any UI-related logic and move it to the corresponding view module.
    *   Update all `require` statements.

**5. Refactor the UI modules:**
    *   Move all `_view.lua` files to `lua/llm/ui/views/` and rename them (e.g., `models_view.lua`).
    *   Move `unified_manager.lua` and `ui.lua` to `lua/llm/ui/`.
    *   Update all `require` statements in the UI modules.

**6. Consolidate the loader modules:**
    *   Create `lua/llm/core/loaders.lua`.
    *   Move the loading logic from the individual `_loader.lua` files into `loaders.lua`.
    *   Delete the `_loader.lua` files.
    *   Update `init.lua` to call `loaders.lua` at startup.

**7. Update the main plugin files:**
    *   Update `lua/llm/init.lua`, `lua/llm/facade.lua`, and `plugin/llm.lua` to reflect the new directory structure and module organization.

**8. Update the tests:**
    *   Update the test files in `test/spec/` to reflect the new architecture. This will likely involve updating `require` statements and mocking the new data access layer.
