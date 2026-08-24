# Development Workflow

## Change approval policy

- Do not modify repository files or project functionality without the project owner's explicit prior approval.
- Treat approval as limited to the specific changes and scope described by the project owner.
- Read-only inspection, review, diagnosis, and planning do not authorize subsequent file modifications.

## Branch policy

- Create a dedicated branch for every development activity.
- Use the `codex/` prefix for branches created by Codex unless the project owner requests a different name.
- Never implement development work directly on `main`.
- Keep each branch focused on one coherent activity.

## Review and merge policy

- Complete the implementation and appropriate verification on the activity branch.
- Stop before merging into `main`.
- Ask the project owner to verify the changes and wait for explicit acceptance.
- Merge into `main` only after the project owner has accepted the changes.
- Do not treat silence or a request for more changes as acceptance.

## Repository safety

- Preserve pre-existing local modifications and untracked files unless the project owner explicitly asks to change or remove them.
- Do not mix unrelated pre-existing work into commits created for a new activity.
- The canonical `origin` for this repository is `https://github.com/KojiKBD/volt26.git`.
