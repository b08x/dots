# Environment Variable Management — pydantic-settings

Standard for every python-dev skill that reads configuration. Use `pydantic-settings` (`BaseSettings`). Read `.env` files through its `env_file` setting. Do not call `os.environ` directly in project code.

**Rule:** never hardcode secrets, API keys, or environment-specific configuration in code.

## Setup

### 1. Add the dependency

```bash
uv add pydantic-settings
```

Only load `.env` in development and test. Production uses real environment variables.

### 2. Create `.env` (never commit)

```bash
# .env (NEVER COMMIT THIS FILE)
OPENAI_API_KEY=sk-proj-...
GEMINI_API_KEY=AIzaSy...
DATABASE_URL=postgresql+psycopg://localhost/myapp_dev
REDIS_URL=redis://localhost:6379/0
```

### 3. Ignore it

```gitignore
.env
.env.local
.env.*.local
```

### 4. Commit a template

```bash
# .env.example (COMMIT THIS FILE)
# OpenAI API key — get from https://platform.openai.com/api-keys
OPENAI_API_KEY=

# Database connection string
DATABASE_URL=postgresql+psycopg://localhost/myapp_dev
```

## Standard pattern

```python
from __future__ import annotations

from functools import lru_cache
from typing import Annotated

from pydantic import Field, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Process configuration. Values come from the environment, then `.env`."""

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="forbid", frozen=True)

    openai_api_key: SecretStr
    database_url: str
    log_level: str = "info"
    port: Annotated[int, Field(ge=1, le=65535)] = 8080
    debug: bool = False


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Load settings once. Missing required variables raise `ValidationError` at startup."""
    return Settings()
```

Enable the pydantic mypy plugin (`[tool.mypy] plugins = ["pydantic.mypy"]`) so that mypy checks `Settings()` against the required fields. Do not suppress a settings error with `# type: ignore`. Trigger 2 stops any run that adds one.

## Rules

- Required variables are declared without defaults. A missing one fails at startup, not on first use.
- Secrets use `SecretStr`. Read them with `.get_secret_value()` only at the call site that needs them.
- `extra="forbid"` rejects unknown keys in `.env`, which catches typos.
- Read settings through one `get_settings()` accessor. Tests override it through the dishka container or `get_settings.cache_clear()`.
- Do not fall back to a silent default for a credential. `os.environ.get("OPENAI_API_KEY")` returning `None` is the failure this rule prevents.

## Environment-specific files

Layer files with pydantic-settings' `env_file` tuple. Later entries override earlier ones:

```python
model_config = SettingsConfigDict(env_file=(".env", ".env.local", ".env.development", ".env.development.local"))
```

Use the environment name from an `APP_ENV` variable to pick the file. Do not branch on the environment name inside business logic.

## Deployment

- Production sets variables in the process environment: systemd `Environment=`, container `environment:`, or a Kubernetes `secretRef`.
- The Docker image never contains `.env`. Add `.env*` to `.dockerignore`.

## Common variables

```bash
# LLM providers
OPENAI_API_KEY=sk-proj-...
GEMINI_API_KEY=AIzaSy...
OLLAMA_HOST=http://localhost:11434

# Data stores
DATABASE_URL=postgresql+psycopg://user:pass@localhost/myapp_dev
REDIS_URL=redis://localhost:6379/0

# Application
APP_ENV=development
LOG_LEVEL=info
PORT=8080
DEBUG=false
```

## Checklist

- [ ] `pydantic-settings` declared in `pyproject.toml`
- [ ] `.env` listed in `.gitignore`; `.env.example` committed
- [ ] Required fields have no default
- [ ] Credentials typed as `SecretStr`
- [ ] No `os.environ` reads outside the settings module
- [ ] No `# type: ignore` or `# noqa` added to silence a settings error
