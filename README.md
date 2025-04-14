# llm-nvim

A Neovim plugin for integrating with [Simon Willison's llm CLI tool](https://github.com/simonw/llm).

## Features

- Send prompts to LLMs directly from Neovim
- Process selected text with LLMs
- Explain code in the current buffer
- Start interactive chat sessions with LLMs
- Support for custom models and system prompts

## Requirements

- Neovim 0.5.0 or later
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
    -- Optional configuration
    vim.g.llm_model = 'gpt-4'
    vim.g.llm_system_prompt = 'You are a helpful assistant.'
  end
}
```

## Configuration

```vim
" Optional: Set default model
let g:llm_model = 'gpt-4'

" Optional: Set default system prompt
let g:llm_system_prompt = 'You are a helpful assistant.'

" Optional: Disable default mappings
let g:llm_no_mappings = 1

" Custom mappings
nmap <leader>lp <Plug>(llm-prompt)
vmap <leader>ls <Plug>(llm-selection)
nmap <leader>le <Plug>(llm-explain)
nmap <leader>lc <Plug>(llm-chat)
```

## Usage

### Commands

- `:LLM {prompt}` - Send a prompt to the LLM
- `:LLMWithSelection {prompt}` - Send selected text with an optional prompt
- `:LLMChat {model}` - Start an interactive chat session (optional model)
- `:LLMExplain` - Explain the code in the current buffer

### Default Mappings

- `<leader>llm` - Prompt for input and send to LLM
- `<leader>llm` - In visual mode, send selection to LLM
- `<leader>lle` - Explain the current buffer
- `<leader>llc` - Start a chat session

## License

Apache 2.0
