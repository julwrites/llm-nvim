---
id: TESTING-002
status: completed
title: Add CI/CD Pipeline for Automated Testing
priority: medium
created: 2025-12-11 09:19:52
category: completed
type: task
---

# Add CI/CD Pipeline for Automated Testing

## Task Information

### Investigation Summary (2025-11-16)
This task was verified as **Implemented**.
- A CI workflow file exists at `.github/workflows/ci.yml`.
- The workflow runs on push and pull_request events.
- It includes a `coverage` job that runs tests with Luacov and checks if the total coverage is above a certain threshold, failing the build if it's not.

- **Estimated Effort**: 1 day

## Task Details

### Description
Implement GitHub Actions workflow to automatically run tests on every push and pull request. This will catch issues like the `unpack` compatibility bug before they reach users.

### Problem Statement
Currently, tests are only run manually via `make test`. This means:
- Issues can be committed without test verification
- Contributors may not run tests before submitting PRs
- No automated verification across different environments
- Regressions can slip through code review

### Architecture Components
- **CI/CD**: New `.github/workflows/` directory
- **Test Configuration**: Existing `Makefile`, `.busted` config
- **Documentation**: Update README.md with CI badge

### Acceptance Criteria
- [ ] Create `.github/workflows/test.yml` workflow
- [ ] Run tests on push to main branch
- [ ] Run tests on all pull requests
- [ ] Test on multiple Lua versions (5.1, 5.2, LuaJIT)
- [ ] Fail build if tests fail
- [ ] Add CI badge to README.md
- [ ] Document CI setup in docs/architecture.md

### Optional Enhancements
- [ ] Run luacheck for linting
- [ ] Generate code coverage reports
- [ ] Cache luarocks dependencies
- [ ] Test on multiple OS (Linux, macOS)
- [ ] Run integration tests with actual Neovim

### Implementation Notes

**Workflow File** (.github/workflows/test.yml):
```yaml
name: Tests

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        lua-version: ['5.1', '5.2', '5.3', 'luajit']
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Lua ${{ matrix.lua-version }}
        uses: leafo/gh-actions-lua@v9
        with:
          luaVersion: ${{ matrix.lua-version }}
      
      - name: Setup LuaRocks
        uses: leafo/gh-actions-luarocks@v4
      
      - name: Install dependencies
        run: make test-deps
      
      - name: Run tests
        run: make test
```

**README Badge**:
```markdown
[![Tests](https://github.com/julwrites/llm-nvim/actions/workflows/test.yml/badge.svg)](https://github.com/julwrites/llm-nvim/actions/workflows/test.yml)
```

**Benefits**:
- Automatic verification on every change
- Multi-version Lua compatibility testing
- Visible test status in README
- Prevents broken code from merging

**Future Enhancements**:
- Add luacheck linting
- Code coverage with luacov
- Performance benchmarks
- Integration tests with Neovim headless mode

*Status: pending - Improves code quality and prevents regressions*
