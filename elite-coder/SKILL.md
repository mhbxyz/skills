---
name: elite-coder
description: >
  Enforces elite coding standards and conventions when writing code,
  refactoring, reviewing, or discussing best practices. Use when user
  asks to write code, do a code review, apply clean code principles,
  or follow best practices. Covers Python primarily, with universal
  principles for any language.
license: MIT
metadata:
  author: mhbxyz
  version: 1.0.0
---

# Elite Coder Standards

## Core Philosophy

Apply these principles in strict priority order:

1. **Correctness** — Code does what it claims. No silent failures.
2. **Clarity** — A stranger reads it and understands it immediately.
3. **Simplicity** — The least code that solves the actual problem.
4. **Robustness** — Graceful handling of edge cases and bad input.
5. **Performance** — Fast enough, measured not guessed.

## Hard Limits

These are non-negotiable. NEVER violate them.

### 80 characters max per line

No exception. Break the line. Use intermediate variables, extract
helpers, or restructure the expression. Long lines are a code smell
indicating excessive nesting or complexity.

### 20 lines max per function

Count only logic lines (exclude blank lines, docstrings, and the
signature). If a function exceeds 20 lines, decompose it. Extract
a helper, split the workflow, or rethink the approach.

### 5 functions max per file

If a module needs more than 5 functions (excluding `__init__` and
dunder methods), it has too many responsibilities. Split it into
focused modules with clear names.

## Naming Conventions

- Names reveal intent: `remaining_retries` not `r`, `is_valid` not `flag`
- Use domain vocabulary: `invoice`, `order`, not `data`, `item`
- Booleans: prefix with `is_`, `has_`, `can_`, `should_`
- Functions: strong verbs — `parse_config`,
  `validate_input`, `send_notification`
- Python: `snake_case` for functions/variables,
  `PascalCase` for classes, `UPPER_SNAKE` for constants
- No abbreviations unless universally understood (`url`, `id`, `http`)

## Function Design

- **Single responsibility**: one function, one job
- **Max 3 parameters**: beyond that, use a dataclass or config object
- **Guard clauses first**: handle invalid cases early with early returns
- **Pure functions preferred**: same input, same output, no side effects
- **20 lines max**: if it does not fit, decompose (see Hard Limits)

```python
# Good: guard clauses + single responsibility
def calculate_discount(price: float, tier: str) -> float:
    if price <= 0:
        raise ValueError("Price must be positive")
    if tier not in DISCOUNT_TIERS:
        raise ValueError(f"Unknown tier: {tier}")

    rate = DISCOUNT_TIERS[tier]
    return round(price * rate, 2)
```

## Error Handling

- **Never** use bare `except:` or `except Exception:`
- Catch specific exceptions: `except ValueError`, `except KeyError`
- **Fail fast**: validate inputs at boundaries, crash early
- Error messages must be actionable: say what went wrong AND what to do
- Use custom exceptions for domain errors

```python
# Bad
try:
    process(data)
except:
    pass

# Good
try:
    process(data)
except ValidationError as e:
    logger.warning("Invalid input: %s", e)
    raise
```

## Code Structure

Python project layout:

```
project/
  pyproject.toml
  src/
    package/
      __init__.py
      module.py
  tests/
    test_module.py
```

- **Imports**: stdlib first, then third-party, then
  local — separated by blank lines
- **No dead code**: delete unused functions,
  commented-out blocks, and TODO-marked stubs
- **Max 5 functions per file**: split into focused modules (see Hard Limits)
- **One class per file** when the class is non-trivial

## Testing

- Test **behavior**, not implementation details
- Descriptive names: `test_expired_token_returns_401` not `test_auth`
- **AAA pattern**: Arrange, Act, Assert — clearly separated
- Cover edge cases: empty inputs, boundaries, error paths
- **Reproduce the bug first**: write a failing test before fixing

```python
def test_discount_rejects_negative_price():
    with pytest.raises(ValueError, match="positive"):
        calculate_discount(-10, "gold")
```

## Security

- **No hardcoded secrets**: use environment variables or a vault
- **Validate all external input**: user data, API payloads, file content
- **Parameterized queries**: never concatenate SQL strings
- **Least privilege**: request minimal permissions, scopes, and access

## Performance

- Choose the right data structure: `set` for membership, `dict` for lookup
- Avoid N+1 queries: batch database calls
- Know your complexity: O(n) vs O(n^2) matters at scale
- Paginate large result sets — never return unbounded lists

## Git Discipline

- **Atomic commits**: one logical change per commit
- **Conventional commits**: `type(scope): description`
  - Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`
- Never commit: `.env`, `__pycache__`, `.pyc`, IDE configs, build artifacts
- Write meaningful commit messages that explain WHY, not WHAT

## Documentation

- **Code is self-documenting** when names and structure are clear
- Comments explain **WHY**, never WHAT — the code shows WHAT
- Docstrings for public API only (public functions, classes, modules)
- Keep docstrings concise: one-line summary, then params if needed

```python
def retry(fn, max_attempts=3):
    """Call fn with exponential backoff on failure."""
```

## Self-Review Checklist

Before finalizing any code, verify:

- [ ] All lines under 80 characters
- [ ] All functions under 20 lines
- [ ] All files under 5 functions
- [ ] Names reveal intent
- [ ] No bare except clauses
- [ ] No hardcoded secrets
- [ ] Guard clauses used for validation
- [ ] Tests cover the happy path and edge cases
- [ ] No dead code or commented-out blocks
- [ ] Imports are sorted (stdlib / third-party / local)

For detailed conventions, refactoring patterns, and API design
guidance, consult `references/detailed-guidelines.md`.
