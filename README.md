# llm-nvim

A Neovim plugin for integrating with [Simon Willison's llm CLI tool](https://github.com/simonw/llm).

## Feature Demos

### Model, Plugin and Key Management
https://github.com/user-attachments/assets/d8c9b2f8-4617-4534-9a64-05a2447d9380

### Schema Management
https://github.com/user-attachments/assets/b326370e-5752-46af-ba5c-6ae08d157f01

### Fragment Management
https://github.com/user-attachments/assets/2fc30538-6fd5-4cfa-9b7b-7fd7757f20c1

### Template Management
https://github.com/user-attachments/assets/d9e16473-90fe-4ccc-a480-d5452070afc2


## Feature List

- Unified LLM command interface (`:LLM`)
- Interactive prompting with fragments support
- Process selected text or entire files with LLMs 
- Explain code in current buffer
- Support for custom models and system prompts
- API key management for multiple providers
- Fragment management (files, URLs, GitHub repos)
- Template creation and execution
- Schema management and execution
- Unified manager window (`:LLMToggle`) with views for:
  - Models
  - Plugins  
  - API Keys
  - Fragments
  - Templates
  - Schemas
- Markdown-formatted responses with syntax highlighting
- Asynchronous command execution

## Requirements

- Neovim 0.7.0 or later
- [llm CLI tool](https://github.com/simonw/llm) installed (`pip install llm` or `brew install llm`)

## Installation

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'julwrites/llm-nvim'
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use 'julwrites/llm-nvim'
```

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
-- Example lazy.nvim configuration
return {
  {
    'julwrites/llm-nvim',
    -- Optional: Specify dependencies if needed, e.g., for UI components
    -- dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      -- Configure the plugin
      require('llm').setup({
        -- Specify the default LLM model to use
        model = 'gpt-4o', -- Or 'claude-3-haiku-20240307', 'llama3', etc.

        -- Define a default system prompt (optional)
        system_prompt = 'You are a helpful Neovim assistant.',

        -- Disable default key mappings if you prefer to set your own
        -- no_mappings = true,

        -- Enable debug logging (optional)
        -- debug = true,
      })

      -- Example custom key mappings (if no_mappings = true or for overrides)
      -- vim.keymap.set('n', '<leader>lp', '<Plug>(llm-prompt)', { desc = "LLM Prompt" })
      -- vim.keymap.set('v', '<leader>ls', '<Plug>(llm-selection)', { desc = "LLM Selection" })
      -- vim.keymap.set('n', '<leader>lt', '<Plug>(llm-toggle)', { desc = "LLM Toggle Manager" })
    end
  }
}
```

## Configuration

```lua
-- Setup with configuration options
require('llm').setup({
  model = 'gpt-4o',                          -- Default model to use
  system_prompt = 'You are a helpful assistant.', -- Default system prompt
  no_mappings = false,                       -- Set to true to disable default mappings
  debug = false,                             -- Set to true to enable debug output
})

-- Custom mappings
vim.keymap.set('n', '<leader>lp', '<Plug>(llm-prompt)')
vim.keymap.set('v', '<leader>ls', '<Plug>(llm-selection)')
vim.keymap.set('n', '<leader>le', '<Plug>(llm-explain)')
vim.keymap.set('n', '<leader>lm', '<Plug>(llm-models)') -- Note: <Plug>(llm-select-model) is deprecated
```

## Usage Examples

### Commands

#### Unified LLM Command
- `:LLM {prompt}` - Send prompt to LLM
- `:LLM file [{prompt}]` - Send current file's content with optional prompt  
- `:LLM selection [{prompt}]` - Send visual selection with optional prompt
- `:LLM explain` - Explain current buffer's code
- `:LLM fragments` - Interactive prompt with fragment selection
- `:LLM schema` - Select and run schema
- `:LLM template` - Select and run template

#### Unified Manager
- `:LLMToggle [view]` - Toggle unified manager window
  - Optional views: `models`, `plugins`, `keys`, `fragments`, `templates`, `schemas`
- `:LLMToggle models` - Open Models view
- `:LLMToggle plugins` - Open Plugins view  
- `:LLMToggle keys` - Open API Keys view
- `:LLMToggle fragments` - Open Fragments view
- `:LLMToggle templates` - Open Templates view
- `:LLMToggle schemas` - Open Schemas view

### Basic Prompting

1.  Type `:LLM Write a short poem about Neovim` and press Enter.
2.  A new buffer will open with the LLM's response.

### Working with Code

1.  Visually select a block of code.
2.  Type `:LLMWithSelection Refactor this code for clarity` and press Enter.
3.  The selected code and your prompt will be sent to the LLM.

### Explaining Code

1.  Open a code file.
2.  Type `:LLMExplain` and press Enter.
3.  The LLM will explain the code in the current buffer.

### Using the Unified Manager

1.  Type `:LLMToggle` or press `<leader>ll` (default mapping).
2.  The manager window opens, likely showing the Models view first.
3.  Press `P` to switch to the Plugins view.
4.  Press `K` to switch to the API Keys view.
5.  Navigate the list using `j` and `k`.
6.  Follow the instructions in the header for actions (e.g., press `s` in the Models view to set a default model).
7.  Press `q` or `<Esc>` to close the manager.

### Default Mappings

- `<leader>ll` - Toggle the unified manager window
- `<leader>llp` - Prompt for input and send to LLM
- `<leader>lle` - Explain the current buffer
- `<leader>llm` - Open the Models manager view
- `<leader>llg` - Open the Plugins manager view
- `<leader>llk` - Open the API Keys manager view
- `<leader>llf` - Open the Fragments manager view
- `<leader>llsf` - Select a file to use as a fragment
- `<leader>llwf` - Send a prompt with fragments
- `<leader>llwf` - In visual mode, send selection with fragments
- `<leader>llt` - Open the Templates manager view
- `<leader>llrt` - Select and run a template
- `<leader>llcs` - Create a new schema
- `<leader>lls` - Open the Schemas manager view
- `<leader>llrs` - Select and run a schema

## Development

### Testing

The plugin includes a test suite using [plenary.nvim](https://github.com/nvim-lua/plenary.nvim). To run the tests:

```bash
# Run all tests
./test/run.sh

# Or using the Lua test runner
nvim --headless -l test/run_tests.lua
```

Tests cover:
- Core functionality (prompts, code explanation)
- Model management
- Plugin management
- API key management
- Fragment management

## License

Apache 2.0
