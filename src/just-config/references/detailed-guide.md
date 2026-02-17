# Detailed Guide

Extended reference for `just` configuration covering every
feature, built-in function, and real-world pattern.

## Complete Settings Reference

```just
# Shell configuration
set shell := ["bash", "-euo", "pipefail", "-c"]

# Environment
set dotenv-load            # load .env file
set dotenv-filename := ".env.local"  # custom .env file
set dotenv-path := "/etc/app/.env"   # absolute path to .env
set dotenv-required        # error if .env file missing
set export                 # export all vars to environment

# Behavior
set quiet                  # don't echo recipe lines
set positional-arguments   # pass args as $1, $2, etc.
set fallback               # search parent dirs for justfile
set ignore-comments        # don't pass comments to shell
set allow-duplicate-recipes  # last definition wins
set allow-duplicate-variables  # last assignment wins

# Directories
set tempdir := "/tmp"      # temp file directory
set working-directory := "src"  # recipe working directory

# Windows
set windows-shell := ["pwsh.exe", "-NoLogo", "-Command"]
set windows-powershell     # use legacy powershell.exe
```

## Variables and Exports

### Assignment

```just
version := "1.0.0"
build_dir := "target"
image := "myapp:" + version
```

### Environment variables

```just
# Read from environment with fallback
db_host := env("DB_HOST", "localhost")
db_port := env("DB_PORT", "5432")

# Required — errors if unset
api_key := env("API_KEY")
```

### Exporting to recipes

```just
# Export a single variable
export DATABASE_URL := "postgres://localhost/myapp"

# Or use `set export` to export everything
set export
version := "1.0.0"  # available as $version in recipes
```

## String Handling and Interpolation

### String types

```just
# Single-quoted (no escapes, no interpolation)
raw := 'hello\nworld'      # literal \n

# Double-quoted (escapes processed)
escaped := "hello\nworld"   # actual newline

# Backtick — shell evaluation
git_hash := `git rev-parse --short HEAD`
today := `date +%Y-%m-%d`
```

### Interpolation

Use `{{...}}` inside recipe bodies and default values:

```just
version := "1.0.0"
image := "myapp"

[doc('Tag and push docker image')]
tag:
    docker tag {{image}} {{image}}:{{version}}
    docker push {{image}}:{{version}}
```

### String functions

```just
# Case conversion
upper := uppercase("hello")           # "HELLO"
lower := lowercase("HELLO")           # "hello"
kebab := kebabcase("hello_world")     # "hello-world"
snake := snakecase("hello-world")     # "hello_world"
title := titlecase("hello world")     # "Hello World"
shout := shoutysnakecase("hello")     # "HELLO"

# Manipulation
trimmed := trim("  hello  ")          # "hello"
start := trim_start("  hello")        # "hello"
end := trim_end("hello  ")            # "hello"
replaced := replace("foo", "o", "a")  # "faa"
```

## Built-In Functions

### Path functions

```just
# Absolute and relative paths
abs := absolute_path("src")
rel := relative_path("src/main.rs")
canon := canonicalize("../src")

# Components
dir := parent_directory("src/main.rs")     # "src"
stem := file_stem("app.tar.gz")            # "app.tar"
name := file_name("src/app.rs")            # "app.rs"
ext := extension("app.tar.gz")             # "gz"
no_ext := without_extension("app.tar.gz")  # "app.tar"

# Joining
full := join("src", "main.rs")             # "src/main.rs"
nested := join("a", "b", "c")             # "a/b/c"

# Existence checks
_ := assert(path_exists("Cargo.toml"), "missing Cargo.toml")
```

### System functions

```just
# Platform detection
os_name := os()             # "linux", "macos", "windows"
arch_name := arch()         # "x86_64", "aarch64"
os_family_name := os_family()  # "unix", "windows"
num_cpus_val := num_cpus()  # "8"

# Directories
home := home_directory()
config := config_directory()
cache := cache_directory()
data := data_directory()
exe := executable_directory()
just_dir := justfile_directory()
just_file := justfile()
invocation := invocation_directory()

# Misc
rand := uuid()
hash := sha256("content")
hash_file := sha256_file("Cargo.lock")
```

### Error and assertion

```just
# Hard error
_ := error("this should not happen")

# Conditional error
_ := assert(env("CI", "") != "", "must run in CI")
```

## Conditional Expressions

### If expressions

```just
greeting := if env("LANG", "en") == "en" {
    "Hello"
} else {
    "Hola"
}

mode := if env("CI", "") != "" { "ci" } else { "local" }
```

### Regex matching

```just
check := if env("VERSION", "") =~ '\d+\.\d+\.\d+' {
    "valid"
} else {
    error("VERSION must be semver")
}
```

### In recipe bodies

```just
[doc('Build for the current platform')]
build:
    {{ if os() == "macos" { "swift" } else { "gcc" } }} \
        -o app main.c
```

## Import System

### `import` and `import?`

Import merges another justfile into the current namespace (no
module prefix). Use for shared settings and utility recipes.

```just
# Import shared settings (required — error if missing)
import 'common.just'

# Import optional local overrides (silent if missing)
import? 'local.just'
```

Unlike `mod`, imported recipes share the same namespace as the
importing file. Use `import` for shared config/settings, and
`mod` for namespaced grouping.

## Shebang Recipes

### Bash

```just
[script]
[doc('Run database migrations')]
migrate:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Running migrations..."
    alembic upgrade head
    echo "Done."
```

### Python

```just
[script]
[doc('Generate test fixtures')]
fixtures:
    #!/usr/bin/env python3
    import json
    data = [{"id": i, "name": f"user_{i}"} for i in range(10)]
    with open("fixtures.json", "w") as f:
        json.dump(data, f, indent=2)
    print(f"Generated {len(data)} fixtures")
```

### Node.js

```just
[script]
[doc('Check for outdated packages')]
outdated:
    #!/usr/bin/env node
    const { execSync } = require('child_process');
    const result = execSync('npm outdated --json', {
        encoding: 'utf8'
    });
    const pkgs = JSON.parse(result || '{}');
    const count = Object.keys(pkgs).length;
    console.log(`${count} outdated packages`);
```

### Ruby

```just
[script]
[doc('Seed the database')]
seed:
    #!/usr/bin/env ruby
    require 'faker'
    10.times do |i|
      puts "INSERT INTO users (name) VALUES ('#{Faker::Name.name}');"
    end
```

## Cross-Platform Recipes

### OS-specific recipes

```just
[doc('Open project in browser')]
[linux]
open:
    xdg-open http://localhost:3000

[doc('Open project in browser')]
[macos]
open:
    open http://localhost:3000

[doc('Open project in browser')]
[windows]
open:
    start http://localhost:3000
```

### Conditional logic in recipes

```just
[doc('Install system dependencies')]
deps:
    {{ if os() == "macos" { "brew install" } else { "apt-get install -y" } }} \
        curl git jq
```

## Error Handling Patterns

### Fail fast

```just
set shell := ["bash", "-euo", "pipefail", "-c"]
```

This ensures:
- `-e`: exit on first error
- `-u`: error on undefined variables
- `-o pipefail`: catch errors in piped commands

### Guard recipes

```just
[private]
require-cmd cmd:
    @command -v {{cmd}} > /dev/null 2>&1 \
        || (echo "error: {{cmd}} not found" && exit 1)

[private]
require-env var:
    @[ -n "${{{var}}:-}" ] \
        || (echo "error: {{var}} not set" && exit 1)

[doc('Deploy the application')]
deploy: (require-cmd "docker") (require-env "DEPLOY_KEY")
    docker push myapp:latest
```

### Confirmation gates

```just
[confirm('Drop all data and reseed? (y/N)')]
[doc('Reset database to seed state')]
reset: drop seed
    @echo "Database reset complete"
```

## Working Directory Management

### `set working-directory`

All recipes execute relative to this directory:

```just
set working-directory := "services/api"

[doc('Run API tests')]
test:
    pytest  # runs inside services/api/
```

### `[no-cd]` attribute

Prevents `just` from changing to the justfile's directory.
The recipe runs in the caller's current directory.

```just
[no-cd]
[doc('Show current directory')]
where:
    pwd  # prints wherever the user invoked `just`
```

### Per-recipe directory change

```just
[doc('Build the frontend')]
[script]
build-frontend:
    #!/usr/bin/env bash
    set -euo pipefail
    cd frontend
    npm install
    npm run build
```

## Real-World Examples

### Docker Module (`docker.just`)

```just
image := "myapp"
registry := env("DOCKER_REGISTRY", "ghcr.io/myorg")
tag := `git rev-parse --short HEAD`

[doc('Build the container image')]
[group('build')]
build *args:
    docker build {{args}} -t {{image}}:{{tag}} .

[doc('Build without cache')]
[group('build')]
build-fresh: (build "--no-cache")

[doc('Run the container locally')]
run *args:
    docker run --rm -it {{args}} {{image}}:{{tag}}

[doc('Push image to registry')]
push: build
    docker tag {{image}}:{{tag}} {{registry}}/{{image}}:{{tag}}
    docker push {{registry}}/{{image}}:{{tag}}

[doc('Remove dangling images')]
prune:
    docker image prune -f

[doc('Show image size')]
size:
    docker images {{image}}:{{tag}} --format \
        "{{{{.Repository}}}}:{{{{.Tag}}}} — {{{{.Size}}}}"
```

### Database Module (`db.just`)

```just
db_name := env("DB_NAME", "myapp_dev")
db_url := env("DATABASE_URL", "postgres://localhost/" + db_name)

[doc('Run pending migrations')]
[group('migrate')]
migrate:
    alembic upgrade head

[doc('Rollback last migration')]
[group('migrate')]
rollback:
    alembic downgrade -1

[doc('Generate new migration')]
[group('migrate')]
new-migration name:
    alembic revision --autogenerate -m "{{name}}"

[doc('Open database shell')]
shell:
    psql "{{db_url}}"

[doc('Dump database to file')]
dump file="dump.sql":
    pg_dump "{{db_url}}" > {{file}}

[doc('Restore database from file')]
restore file="dump.sql":
    psql "{{db_url}}" < {{file}}

[confirm('This will destroy all data. Continue? (y/N)')]
[doc('Drop and recreate the database')]
reset:
    dropdb --if-exists {{db_name}}
    createdb {{db_name}}
    just db migrate
```

### CI Module (`ci.just`)

```just
[doc('Run the full CI pipeline locally')]
all: lint test build
    @echo "CI passed"

[doc('Run linters')]
[group('check')]
lint:
    ruff check .
    ruff format --check .
    mypy src/

[doc('Run test suite with coverage')]
[group('check')]
test:
    pytest --cov --cov-report=term-missing

[doc('Build release artifacts')]
build:
    python -m build

[doc('Publish to PyPI')]
[confirm('Publish to PyPI? (y/N)')]
publish: all
    twine upload dist/*
```

### Root Justfile (Tying It Together)

```just
set dotenv-load
set shell := ["bash", "-euo", "pipefail", "-c"]
set quiet

# Docker container management
mod docker

# Database operations
mod db

# CI/CD pipeline
mod ci

[doc('Start local development server')]
[group('dev')]
dev:
    uvicorn app:main --reload

[doc('Run full test suite')]
[group('dev')]
test:
    pytest

[doc('Format and lint code')]
[group('dev')]
check:
    ruff format .
    ruff check --fix .

[doc('Show project status')]
default:
    @just --list
```

This root file has only 3 direct recipes plus a `default`,
with all other functionality organized into modules. Running
`just --list` shows a clean, grouped overview of the entire
project.
