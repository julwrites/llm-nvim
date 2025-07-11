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

# Create a temporary config directory
export XDG_CONFIG_HOME=$(mktemp -d)

# Run the tests using Neovim headless mode with a minimal init file
nvim --headless -u test/init.lua -i NONE -n \
  -c "lua require('plenary.busted').run('test/spec/llm_spec.lua')" \
  -c "qa!"

# Clean up the temporary config directory
rm -rf $XDG_CONFIG_HOME
