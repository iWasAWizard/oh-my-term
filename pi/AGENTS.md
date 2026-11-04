# Global instructions for coding agents

These apply to every project. A project's own AGENTS.md can add to them or
override them. Edit freely, this is a starting point.

## Code style

- Indent with spaces, never tabs.
- When asked for code, give complete files, with no truncation and no placeholder comments.
- Use the latest stable Python unless the project pins a version.
- Match the existing style of the project before applying your own.

## Working method

- Say so when you are unsure or assuming something. Do not guess at flags, paths, or APIs, check them.
- Make small, reviewable changes, and run the project's tests or linters after editing.
- Do not add a dependency that downloads things at runtime unless asked. Some machines have no internet.
- Never put secrets, hostnames, or credentials in files that get committed.
