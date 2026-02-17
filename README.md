# skills

A collection of skills for Claude Code.

Reference: [Anthropic Official Documentation on Skills](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview)

## Installation

### Quick install (no clone needed)

```sh
curl -fsSL mhbxyz.github.io/skills/install.sh | sh -s -- <skill-name>
```

### Options

```sh
sh -s -- <skill-name>          # local (current project)
sh -s -- -g <skill-name>       # global (~/.claude/skills/)
sh -s -- -l                    # list available skills
sh -s -- -u <skill-name>       # uninstall
```

## elite-coder

Enforces elite coding standards every time Claude writes, refactors, or reviews code. Python-focused with universal principles.

### What it does

- Applies strict hard limits: 80 chars/line, 20 lines/function, 5 functions/file
- Enforces naming conventions, guard clauses, and single-responsibility functions
- Runs a self-review checklist before finalizing code
- Provides detailed refactoring patterns, API design, and architecture guidance in `references/`

### Installation

Copy or symlink the `elite-coder/` folder to one of:

- **Global**: `~/.claude/skills/elite-coder/`
- **Per-project**: `.claude/skills/elite-coder/` in your repo root

### Usage

**Automatic**: The skill triggers whenever you ask Claude to write, refactor, or review code.

**Manual**: Type `/elite-coder` to explicitly activate the standards.

### Standards applied

| Rule | Limit |
|------|-------|
| Line length | 80 characters max |
| Function length | 20 lines max |
| Functions per file | 5 max |
| Function parameters | 3 max |
| Priority order | Correctness > Clarity > Simplicity > Robustness > Performance |

### Structure

```
elite-coder/
  SKILL.md                          # Core standards (~160 lines)
  references/
    detailed-guidelines.md          # Patterns, anti-patterns, examples (~250 lines)
```

## License

MIT
