# Makefile for llm-nvim
# License: Apache 2.0

.PHONY: test test-deps clean

# Run tests
test:
	@for file in `find ./test/spec -name "*_spec.lua"`; do \
		nvim --headless -u NONE -i NONE -n \
			-c "lua vim.opt.rtp:append('./test/plenary.nvim')" \
			-c "lua vim.opt.rtp:append('./test/lua')" \
			-c "lua vim.opt.rtp:append('.')" \
			-c "runtime plugin/llm.lua" \
			-c "lua require('plenary.busted').run('$$file')" \
			-c "q"; \
	done

# Install test dependencies
test-deps:
	git clone --depth 1 https://github.com/nvim-lua/plenary.nvim test/plenary.nvim

# Clean up test artifacts
clean:
	rm -rf test/plenary.nvim
