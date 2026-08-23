# Development Workflow

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

