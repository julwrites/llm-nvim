.PHONY: test test-deps coverage

test:
	@LUA_PATH="lua/?.lua;;" busted --config-file=tests/.busted tests/spec

coverage:
	@rm -f luacov.stats.out luacov.report.out
	@LUA_PATH="lua/?.lua;;" busted --coverage --config-file=tests/.busted tests/spec
	@test -f luacov.stats.out && echo "Coverage stats generated successfully" || (echo "ERROR: luacov.stats.out not generated" && exit 1)
	@luacov
	@echo "Coverage report generated. Summary:"
	@luacov-console -s || echo "Note: luacov-console may show 0% if functions are mocked in tests"

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
