# Murrmobile

## Commit message format

All commits must follow Conventional Commits so cocogitto can bump versions
and generate the changelog.

- Use one of these types: `feat`, `fix`, `chore`, `ci`, `docs`, `refactor`,
  `style`, `test`, `perf`, `revert`, `build`, `misc`.
- The type and colon are in English; the description can be in Chinese.
- Keep the first line short: `<type>: <description>`.
- Only use `feat` for new features and `fix` for bug fixes. They trigger
  version bumps (`feat` -> minor, `fix`/`perf`/`revert` -> patch).
- For anything else use `chore`, `ci`, `docs`, `test`, or `misc`. These do
  not trigger a version bump.

Install the commit message hook so non-conventional subjects are
automatically prefixed with `misc:`:

```bash
git config core.hooksPath .githooks
```

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
