# llm-nvim

A Neovim plugin for integrating with [Simon Willison's llm CLI tool](https://github.com/simonw/llm).

## Features

- Send prompts to LLMs directly from Neovim
- Process selected text with LLMs
- Explain code in the current buffer
- Start interactive chat sessions with LLMs
- Support for custom models and system prompts
- Use fragments (files, URLs, GitHub repos) with prompts
- Manage fragment aliases

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
{
  'julwrites/llm-nvim',
  config = function()
    -- Configure the plugin
    require('llm').setup({
      model = 'gpt-4o',
      system_prompt = 'You are a helpful assistant.'
    })
  end
}
```

## Configuration

```lua
-- Setup with configuration options
require('llm').setup({
  model = 'gpt-4o',                          -- Default model to use
  system_prompt = 'You are a helpful assistant.', -- Default system prompt
  no_mappings = false,                       -- Set to true to disable default mappings
})

-- Custom mappings
vim.keymap.set('n', '<leader>lp', '<Plug>(llm-prompt)')
vim.keymap.set('v', '<leader>ls', '<Plug>(llm-selection)')
vim.keymap.set('n', '<leader>le', '<Plug>(llm-explain)')
vim.keymap.set('n', '<leader>lc', '<Plug>(llm-chat)')
vim.keymap.set('n', '<leader>lm', '<Plug>(llm-select-model)')
```

## Usage

### Commands

- `:LLM {prompt}` - Send a prompt to the LLM
- `:LLMWithSelection {prompt}` - Send selected text with an optional prompt
- `:LLMChat {model}` - Start an interactive chat session (optional model)
- `:LLMExplain` - Explain the code in the current buffer
- `:LLMModels` - Manage models and aliases (set default, add/remove aliases)
- `:LLMPlugins` - Manage LLM plugins (install/uninstall)
- `:LLMKeys` - Manage API keys for different LLM providers
- `:LLMFragments` - Manage fragments (view, set aliases, remove aliases)
- `:LLMSelectFragment` - Select a file to use as a fragment
- `:LLMWithFragments` - Send a prompt with fragments
- `:LLMWithSelectionAndFragments` - Send selected text with fragments

### Default Mappings

- `<leader>llm` - Prompt for input and send to LLM
- `<leader>llm` - In visual mode, send selection to LLM
- `<leader>lle` - Explain the current buffer
- `<leader>llc` - Start a chat session
- `<leader>llm` - Manage models and aliases
- `<leader>llp` - Open the plugin manager
- `<leader>llk` - Manage API keys
- `<leader>llf` - Manage fragments
- `<leader>llsf` - Select a file to use as a fragment
- `<leader>llwf` - Send a prompt with fragments
- `<leader>llwf` - In visual mode, send selection with fragments

## License

Apache 2.0
