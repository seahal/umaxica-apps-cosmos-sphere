# ADR: Explicit Importmap/Propshaft and Vite Rails stacks

- Status: accepted for history; active frontend scope amended on 2026-11-10
- Date: 2026-09-07

`config/frontend_stacks.yml` records current template ownership. Retained pages render ERB. Edit
uses Importmap for Turbo; Vite builds CSS for content roots and Edit. Bun provides the formatting,
lint, type-check, dead-code, and OpenAPI scripts. This current description supersedes the historical
React/Inertia and Vitest/Playwright stack below.

## Surface hard-reset amendment (2026-11-10)

The owner-approved surface hard reset removed the Inertia pages, browser tests, and frontend
dependencies. `config/frontend_stacks.yml` records the current template ownership.
