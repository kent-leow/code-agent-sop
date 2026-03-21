---
applyTo:: "**"
---

# Stack-Aware Structure & Architecture

Always implement using the standard folder structure and architecture for the detected stack, framework, and technologies.

- Detect the main stack, frameworks, and tech from context, requirements, or codebase.
- Use official or community-recommended folder structures for each stack (e.g., Next.js, Django, FastAPI, React, Node.js, etc.).
- Place code, configs, and assets in canonical locations (e.g., `src/`, `app/`, `pages/`, `api/`, `models/`, `services/`, `controllers/`, `routes/`, `middlewares/`, `repositories/`, `lib/`, `utils/`, `types/`, `hooks/`, `components/`, `styles/`, `public/`, `tests/`, `config/`, `scripts/`, `docs/`).
- Follow best practices for modularity, separation of concerns, and scalability.
- If multiple stacks are present, keep boundaries clear and structure each according to its conventions.
- Document any deviations and the rationale.
- When in doubt, cite the official docs or a widely-accepted open-source reference.

**Never improvise structure—always align with the stack's standards.**

Common canonical folders (non‑exhaustive)
- Node/Express/Nest: `src/controllers/`, `src/services/`, `src/routes/`, `src/middlewares/`, `src/models/`, `src/repositories/`, `src/config/`, `src/utils/`, `tests/`
- React/Vite/Next: `app/` or `pages/`, `src/components/`, `src/hooks/`, `src/context/`, `src/lib/`, `src/services/`, `src/types/`, `src/styles/`, `public/`, `tests/`
- Python (Django): project `settings/`, app `models.py`, `views.py`, `urls.py`, `templates/`, `static/`, `migrations/`, `tests/`
- Python (FastAPI): `app/main.py`, `app/api/routers.py`, `app/schemas/`, `app/models/`, `app/services/`, `app/core/config.py`, `tests/`
- Java (Spring): `src/main/java/.../controller`, `service`, `repository`, `config`, `domain`, `dto`; `src/main/resources/`; `src/test/java/`
- Go: `cmd/`, `internal/`, `pkg/`, `api/`, `configs/`, `deploy/`, `scripts/`
- Infra/CI: `infra/` (Terraform/Pulumi), `k8s/`, `docker/`, `.github/workflows/`, `scripts/`
