# Murrmobile

- Read README.md, AGENTS.md, and CLAUDE.md before proposing or making any changes.
- Use subagents to review code harshly for bugs, issues, and correctness before any merge.
- Do not create god files; keep modules focused and small.
- Do not blindly merge. Verify behavior by running the test suite locally. Do not finish until `flutter test` passes. Do not push commits or check GitLab pipeline status as a substitute for local verification.
- Add new tests for everything new. Every piece of new code must be testable in Dart (Flutter).
- Do a final harsh subagent review of all changes before finishing.
- Do not squash merge requests. Use a regular merge commit so each conventional commit is preserved for the changelog and history.

## Local verification

Run the test suite locally and confirm it is green before considering any task complete. Do not finish, open a merge request, or push commits just to trigger CI while tests are failing.

```bash
flutter test
```

Do not rely on GitLab pipeline status or `git push` output instead of running this command locally. The suite must pass before finishing.

## Commit message format

All commits must follow Conventional Commits so cocogitto can bump versions
and generate the changelog.

- Use one of these types: `feat`, `fix`, `chore`, `ci`, `docs`, `refactor`,
  `style`, `test`, `perf`, `revert`, `build`, `misc`.
- The type and colon are in English; the description can be in Chinese.
- Keep the first line short: `<type>: <description>`.
- Use the imperative mood and do not add a period at the end.
- Only use `feat` for new features and `fix` for bug fixes. They trigger
  version bumps (`feat` -> minor, `fix`/`perf`/`revert` -> patch).
- For anything else use `chore`, `ci`, `docs`, `test`, or `misc`. These do
  not trigger a version bump.

Install the commit message hook so non-conventional subjects are
automatically prefixed with `misc:`:

```bash
git config core.hooksPath .githooks
```

The hook is a safety net. Still try to write proper conventional commits
when possible.

## Releases

Versioning is fully automated by cocogitto. Every push to `main` runs the
`auto-release` GitLab job: if the commits since the latest tag contain a
`feat`, `fix`, `perf` or `revert`, cog bumps `pubspec.yaml`, updates
`CHANGELOG.md`, tags `vX.Y.Z` and pushes it. The tag pipeline mirrors the
tag to GitHub, where the release build runs and the GitHub release is
created. Never edit `version:` in `pubspec.yaml` or create version tags by
hand.

The `auto-release` job pushes the bump commit and tag back to the repo, so
it needs a `GITLAB_TOKEN` (or `GITLAB_RELEASE_SSH_KEY` deploy key) CI
variable with permission to push to `main` and create `v*` tags.

To cut a release manually from a local checkout:

```bash
cog bump --auto
```

This runs the default hook profile in `cog.toml`, which updates the version
files and pushes the bump commit and tag.
