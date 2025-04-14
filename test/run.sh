#!/bin/bash
# Simple test runner for llm-nvim

# Check if plenary.nvim exists and clone it if needed
if [ ! -d "test/plenary.nvim" ]; then
  echo "Plenary.nvim not found, cloning it now..."
  git clone --depth 1 https://github.com/nvim-lua/plenary.nvim.git test/plenary.nvim
  if [ $? -ne 0 ]; then
    echo "Error: Failed to clone plenary.nvim"
    exit 1
  fi
  echo "Plenary.nvim cloned successfully"
fi

# Run the tests using Neovim headless mode with proper runtime path setup
nvim --headless -u NONE -i NONE -n \
  -c "lua vim.opt.rtp:append('./test/plenary.nvim')" \
  -c "lua vim.opt.rtp:append('.')" \
  -c "runtime plugin/llm.lua" \
  -c "lua require('plenary.busted').run('./test/spec/llm_spec.lua')" \
  -c "qa!"
