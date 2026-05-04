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

- Before creating a git commit for substantive code changes, prefer the `Test And Docs` agent for focused test execution, regression-test creation, and documentation follow-through.
- When a change affects documented combat or gameplay behavior, use `Test And Docs` before commit to verify the behavior and update the nearest docs.
- Do not require `Test And Docs` as an automatic post-edit step during normal implementation flow; reserve that handoff for commit-time verification and documentation checks.
- If a commit is requested for code changes without relevant tests or docs being checked, treat the commit as incomplete when a focused verification path exists.