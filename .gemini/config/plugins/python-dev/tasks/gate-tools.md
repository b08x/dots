# Gate Tools: Install and Check

Installs the pinned Python gate tools into the project and checks the binary tools. Run it before the baseline in Standard mode.

## Source of truth

`references/gate-tools.toml`. The `[dev]` table holds exact versions for the PyPI tools. The `[binaries.gitleaks]` table holds a binary that is not on PyPI. Do not use any other version.

## 1. Read the pins

```bash
uv run python -c "import tomllib, pathlib; d = tomllib.loads(pathlib.Path('../references/gate-tools.toml').read_text()); print(' '.join(f'{k}=={v}' for k, v in d['dev'].items()))"
```

## 2. Install the PyPI tools

Run `uv add --dev` with the pins, from the project root. Pass every pin in one call so uv resolves them together:

```bash
uv add --dev <name==version> <name==version> ...
```

If the project already pins one of these tools, the exact pin from `gate-tools.toml` replaces it. Report each replacement in the run notes, because the change is part of the baseline.

## 3. Check the binaries

```bash
command -v gitleaks && gitleaks version
```

If `gitleaks` is missing, do not install it. Record `not run: gitleaks unavailable`, and show the install hint from `gate-tools.toml`. The `implementer:gitleaks` check reports the same thing at gate time.

## 4. Confirm

```bash
uv lock --check
```

If the lock is stale after the install, run `uv lock` and report it.

## Rules

- Install only the pins listed. Do not add unrelated tools.
- Never install a system binary.
- Lite mode does not run this task. Lite installs nothing into the project.
