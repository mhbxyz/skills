---
name: just-config
description: >
  Guides writing clean, idiomatic justfile configurations for the
  just command runner. Use when user asks to create a justfile,
  add just recipes, set up project automation, or configure task
  runners. Covers modules, settings, recipes, and best practices.
license: MIT
metadata:
  author: mhbxyz
  version: 1.0.0
---

# Just Configuration Standards

## Core Philosophy

Apply these principles in strict priority order:

1. **Discoverability** — `just --list` is the entry point. Every
   recipe is documented, grouped, and easy to find.
2. **Idiomaticity** — Follow `just` conventions. Use attributes,
   modules, and settings as the tool intends.
3. **Modularity** — Group related recipes into submodules. A flat
   file with 30 recipes is unmaintainable.
4. **Simplicity** — Recipes are thin wrappers. Complex logic
   belongs in scripts, not justfiles.

## Hard Rules

These are non-negotiable. NEVER violate them.

### Never use hyphens to namespace recipes

If two or more recipes share a prefix, they belong in a module.
Hyphenated namespacing creates a flat, unsearchable list and
defeats `just`'s built-in module system.

```just
# WRONG — hyphenated namespacing
docker-build:
    docker build -t app .

docker-run:
    docker run app

docker-push:
    docker push app

# RIGHT — use a submodule
mod docker
```

```just
# docker.just
[doc('Build the container image')]
build:
    docker build -t app .

[doc('Run the container')]
run:
    docker run app

[doc('Push to registry')]
push:
    docker push app
```

Invocation becomes `just docker build`, `just docker run` — clear,
grouped, and discoverable via `just --list`.

### Always use attributes for organization

Every public recipe MUST have a `[doc()]` attribute. Group related
recipes with `[group()]`. Hide helpers with `[private]`.

```just
[doc('Run the full test suite')]
[group('test')]
test:
    pytest

[doc('Run tests with coverage report')]
[group('test')]
coverage:
    pytest --cov

[private]
ensure-venv:
    [ -d .venv ] || python -m venv .venv
```

### Always set shell for non-POSIX environments

If the project may run on Windows or needs a specific shell,
declare it explicitly.

```just
set shell := ["bash", "-euo", "pipefail", "-c"]
```

### Use shebang recipes for multi-line logic

Each line in a normal recipe runs in a separate shell. For
multi-line logic, use a shebang recipe or the `[script]`
attribute.

```just
[script]
[doc('Generate release notes from git log')]
release-notes version:
    #!/usr/bin/env bash
    set -euo pipefail
    tag="v{{version}}"
    git log --oneline "$(git describe --tags --abbrev=0)..$tag"
```

## Module Organization

### The `mod` keyword

Use `mod` to split a justfile into focused submodules. Each
module gets its own namespace in `just --list`.

```just
# justfile (root)
mod docker
mod db
mod ci
```

### File layout

Two conventions — pick one per project:

```
# Flat: one file per module
justfile
docker.just
db.just
ci.just

# Nested: directory per module (for complex modules)
justfile
docker/
  mod.just
db/
  mod.just
  migrations.just    # sub-submodule
```

For nested modules, the entry point must be `mod.just` inside
the directory.

### Module comments

Add a doc comment above `mod` to describe the module in
`just --list`:

```just
# Docker container management
mod docker

# Database operations
mod db
```

## Recipe Design

### Parameters and defaults

```just
[doc('Deploy to target environment')]
deploy env="staging":
    ./scripts/deploy.sh {{env}}
```

### Variadic arguments

```just
[doc('Run specific test files')]
test *files:
    pytest {{files}}
```

The `+` prefix requires at least one argument:

```just
[doc('Install packages')]
install +packages:
    pip install {{packages}}
```

### Dependencies

```just
[doc('Build and run')]
run: build
    ./target/release/app

[doc('Compile the project')]
build:
    cargo build --release
```

Parameterized dependencies:

```just
[doc('Push to production')]
push: (deploy "production")
    @echo 'Pushed to production'
```

### Guard patterns

Use confirmation for destructive recipes:

```just
[confirm('This will drop the database. Continue? (y/N)')]
[doc('Drop and recreate the database')]
[group('db')]
db-reset:
    dropdb myapp && createdb myapp
```

## Settings

Place settings at the top of the justfile, before any recipes.

```just
# Load .env file automatically
set dotenv-load

# Use bash with strict mode
set shell := ["bash", "-euo", "pipefail", "-c"]

# Suppress recipe echo by default
set quiet

# Export all variables as environment variables
set export

# Enable positional arguments ($1, $2 in shell)
set positional-arguments
```

### Essential settings

| Setting                  | Purpose                             |
|--------------------------|-------------------------------------|
| `set dotenv-load`        | Auto-load `.env` file               |
| `set shell`              | Explicit shell for all recipes      |
| `set quiet`              | Suppress echoing recipe lines       |
| `set export`             | Export all `just` variables to env   |
| `set positional-arguments` | Pass args as `$1`, `$2`, etc.     |
| `set fallback`           | Search parent dirs for justfile     |
| `set tempdir`            | Directory for temporary files       |

## Attributes

| Attribute                | Purpose                                    |
|--------------------------|--------------------------------------------|
| `[doc('...')]`           | Description shown in `just --list`         |
| `[group('...')]`         | Group in `just --list` output              |
| `[private]`              | Hide from `just --list`                    |
| `[confirm('...')]`       | Require confirmation before running        |
| `[no-cd]`               | Don't change to justfile directory         |
| `[no-exit-message]`      | Suppress error exit message                |
| `[script]`              | Run recipe body as single script           |
| `[linux]`               | Only run on Linux                          |
| `[macos]`               | Only run on macOS                          |
| `[windows]`             | Only run on Windows                        |

## Anti-Patterns

### Hyphenated namespacing

Already covered in Hard Rules. Use `mod` submodules instead.

### Bare recipes without documentation

Every public recipe must have `[doc()]`. Without it, `just --list`
shows recipe names with no context.

```just
# Bad
build:
    cargo build

# Good
[doc('Build the project in release mode')]
build:
    cargo build --release
```

### Missing settings

A justfile without `set shell` is fragile across platforms.
A justfile without `set dotenv-load` forces users to manually
source environment files.

### Line-by-line shell pitfalls

Each line runs in a separate shell by default. Variables and
`cd` don't carry across lines.

```just
# BROKEN — cd has no effect on the next line
build:
    cd src
    make

# FIXED — single line or shebang
build:
    cd src && make

# BETTER — shebang for complex logic
[script]
build:
    #!/usr/bin/env bash
    set -euo pipefail
    cd src
    make
```

### Overloaded root justfile

If your root justfile has more than ~10 recipes, split into
modules. The root justfile should be a table of contents:
settings, module declarations, and a handful of top-level
convenience recipes.

## Self-Review Checklist

Before finalizing any justfile, verify:

- [ ] No hyphenated namespacing — modules used instead
- [ ] All public recipes have `[doc()]` attributes
- [ ] Related recipes are grouped with `[group()]`
- [ ] Helper recipes are marked `[private]`
- [ ] `set shell` is declared if non-POSIX compatibility needed
- [ ] `set dotenv-load` is used if `.env` file exists
- [ ] Multi-line logic uses shebang or `[script]`
- [ ] Destructive recipes use `[confirm()]`
- [ ] Root justfile has fewer than ~10 direct recipes
- [ ] Module file layout is consistent (flat or nested)

For complete settings reference, built-in functions, and
real-world examples, consult `references/detailed-guide.md`.
