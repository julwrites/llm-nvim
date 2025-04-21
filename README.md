# llm-nvim

A Neovim plugin for integrating with [Simon Willison's llm CLI tool](https://github.com/simonw/llm).

## Features

- Send prompts to LLMs directly from Neovim
- Process selected text with LLMs
- Explain code in the current buffer
- Start interactive chat sessions with LLMs
- Support for custom models and system prompts
- Manage API keys for different LLM providers
- Use fragments (files, URLs, GitHub repos) with prompts
- Manage fragment aliases
- Manage templates (create, run, edit, delete)
- Manage schemas (create, run, view, edit, set/delete aliases)
- Unified manager window (`:LLMToggle`) to access Models, Plugins, Keys, Fragments, Templates, and Schemas management.

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
vim.keymap.set('n', '<leader>lc', '<Plug>(llm-chat)')
vim.keymap.set('n', '<leader>lm', '<Plug>(llm-models)') -- Note: <Plug>(llm-select-model) is deprecated
```

## Usage Examples

### Commands

- `:LLM {prompt}` - Send a prompt to the LLM
- `:LLMWithSelection {prompt}` - Send selected text with an optional prompt
- `:LLMChat {model}` - Start an interactive chat session (optional model)
- `:LLMExplain` - Explain the code in the current buffer
- `:LLMToggle [view]` - Open or close the unified manager window. Optionally specify an initial view (Models, Plugins, Keys, Fragments, Templates, Schemas).
- `:LLMModels` - Open the unified manager to the Models view.
- `:LLMPlugins` - Open the unified manager to the Plugins view.
- `:LLMKeys` - Open the unified manager to the API Keys view.
- `:LLMFragments` - Open the unified manager to the Fragments view.
- `:LLMWithFragments` - Send a prompt with fragments (does not use the unified manager).
- `:LLMWithSelectionAndFragments` - Send selected text with fragments (does not use the unified manager).
- `:LLMTemplates` - Open the unified manager to the Templates view.
- `:LLMTemplate` - Select and run a template (does not use the unified manager).
- `:LLMSchemas` - Open the unified manager to the Schemas view.
- `:LLMSchema` - Select and run a schema with various input sources (does not use the unified manager).

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

### Chatting

1.  Type `:LLMChat` to start a chat session with the default model.
2.  Type `:LLMChat llama3` to start a chat specifically with the `llama3` model.
3.  The chat happens in a terminal buffer within Neovim.

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
- `<leader>lls` - In visual mode, send selection to LLM
- `<leader>lle` - Explain the current buffer
- `<leader>llc` - Start a chat session
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
- Core functionality (prompts, chat, code explanation)
- Model management
- Plugin management
- API key management
- Fragment management

## License

Apache 2.0
