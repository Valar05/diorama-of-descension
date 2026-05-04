# Copilot Instructions

## Repo Orientation Routing

- For questions about repository architecture, file ownership, gameplay-system summaries, implementation location, project structure, or "how this repo works", prefer the `Repo Knowledge` agent first.
- Start those answers from existing documentation before searching broad code surfaces.
- Treat `README.md` and `docs/COMBAT.md` as the primary orientation sources.
- Use nearby code only when the docs do not fully answer the question or when ownership needs confirmation.
- If a real documentation gap is discovered while answering a repo-orientation question, prefer handing off to `Test And Docs` rather than editing docs directly from a coding-oriented flow.

## Scope Boundary

- Do not use `Repo Knowledge` for direct implementation tasks, code fixes, or broad refactors.
- For code-change requests, use the normal coding workflow and consult `Repo Knowledge` only when repository context is genuinely needed.

## Verification Routing

- After substantive code changes, prefer the `Test And Docs` agent for focused test execution, regression-test creation, and documentation follow-through.
- When a change affects documented combat or gameplay behavior, use `Test And Docs` to verify the behavior and update the nearest docs.
- If a coding task finishes without running the relevant tests or checking affected docs, treat that as incomplete when a focused verification path exists.
- Keep the default coding flow for implementation, but hand off the verification and documentation phase to `Test And Docs` whenever practical.