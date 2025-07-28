.PHONY: test test-deps

test:
	@if [ -n "${file}" ]; then \
		busted tests/spec/${file}; \
	else \
		busted tests/spec/; \
	fi

test-deps:
	@if ! command -v busted &> /dev/null; then \
		echo "busted not found, installing..."; \
		sudo luarocks install busted; \
	fi
	@if ! lua -e "require('luassert')" &> /dev/null; then \
		echo "luassert not found, installing..."; \
		sudo luarocks install luassert; \
	fi
