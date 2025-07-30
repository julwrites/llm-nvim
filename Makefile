.PHONY: test test-deps

test:
	@LUA_PATH="lua/?.lua;;" busted --config-file=tests/.busted tests/spec

test-deps:
	@if ! command -v busted &> /dev/null; then \
		echo "busted not found, installing..."; \
		sudo luarocks install busted; \
	fi
	@if ! lua -e "require('luassert')" &> /dev/null; then \
		echo "luassert not found, installing..."; \
		sudo luarocks install luassert; \
	fi
