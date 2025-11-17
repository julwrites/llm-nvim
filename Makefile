.PHONY: test test-deps coverage

test:
	@LUA_PATH="lua/?.lua;;" busted --config-file=tests/.busted tests/spec

coverage:
	@luacov -c
	@LUA_PATH="lua/?.lua;;" busted --helper=luacov --config-file=tests/.busted tests/spec
	@luacov-console
	@luacov-console

test-deps:
	@if ! command -v busted &> /dev/null; then \
		echo "busted not found, installing..."; \
		sudo luarocks install busted; \
	fi
	@if ! lua -e "require('luassert')" &> /dev/null; then \
		echo "luassert not found, installing..."; \
		sudo luarocks install luassert; \
	fi
	@if ! lua -e "require('luacov')" &> /dev/null; then \
		echo "luacov not found, installing..."; \
		sudo luarocks install luacov; \
	fi
	@if ! lua -e "require('luacov.console')" &> /dev/null; then \
		echo "luacov-console not found, installing..."; \
		sudo luarocks install luacov-console; \
	fi
