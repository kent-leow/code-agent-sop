---
applyTo:: "**"
---

# Atomic Design & File Organization

Always follow atomic design principles and maintain small, focused files with clear separation of concerns.

## Core Rules

**First Rule: Atomic Design Extraction**
- Extract all reusable helpers, methods, functions, hooks into separate files.
- Each extracted file must have clear, single-purpose usability.
- Name files based on their specific function/responsibility.
- Group related utilities logically (e.g., `utils/`, `hooks/`, `helpers/`, `services/`).

**Second Rule: Keep Files Small**
- Limit file size to maintain readability and focus.
- Split large components into smaller, composable pieces.
- One primary export per file when possible.
- Prefer multiple small files over monolithic ones.

## Implementation Guidelines

**Component Structure**
- Break UI into atoms → molecules → organisms → templates → pages.
- Extract custom hooks to `hooks/` directory.
- Move business logic to `services/` or `lib/` directories.
- Place utility functions in `utils/` with clear naming.

**File Naming & Organization**
- Use descriptive, purpose-driven names.
- Group by feature/domain, not by file type.
- Keep related files close in directory structure.
- Maintain consistent naming conventions across project.

**Extraction Criteria**
- If code is used in 2+ places → extract to utility.
- If logic exceeds 10-15 lines → consider extraction.
- If component has multiple responsibilities → split.
- If file exceeds 200 lines → refactor into smaller modules.

**Best Practices**
- Each file should have a single, clear responsibility.
- Prefer composition over inheritance.
- Use barrel exports (`index.js`) for clean imports.
- Document complex utilities with JSDoc or inline comments.