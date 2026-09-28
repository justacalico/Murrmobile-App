#!/usr/bin/env bash
# Regenerates altstore/apps.json from the GitLab releases and, in CI,
# commits it back to main with ci.skip. Run with --no-push to only
# rewrite the file (used to seed the initial version).
set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"

PROJECT_DIR="${CI_PROJECT_DIR:-$PWD}"
PROJECT_PATH="${CI_PROJECT_PATH:-HttpAnimations/Murrmobile-App}"
PROJECT_ENC="${PROJECT_PATH//\//%2F}"
IPA_ASSET="murrmobile-ios-arm64-unsigned.ipa"
PKG_NAME="release-assets"
BUNDLE_ID="gitlab.httpanimations.murrmobile"
ICON_URL="https://gitlab.com/${PROJECT_PATH}/-/raw/main/assets/icon.png"
MIN_OS="13.0"

cd "$PROJECT_DIR"

if [ -n "${CI_PROJECT_ID:-}" ]; then
  PROJECT_ID="$CI_PROJECT_ID"
else
  PROJECT_ID=$(glab api "projects/$PROJECT_ENC" | jq -r .id)
fi

write_apps_json() {
  # All semver releases, newest first. Nightly is excluded since AltStore
  # version entries need real version numbers.
  local releases
  releases=$(glab api "projects/$PROJECT_ID/releases?per_page=100" |
    jq -c 'sort_by(.released_at) | reverse | [.[] | select(.tag_name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))]')

  local versions="[]" news="[]"
  local count=0
  while IFS= read -r rel; do
    local tag ver ipa_url pkg_id size date
    tag=$(jq -r '.tag_name' <<<"$rel")
    ver="${tag#v}"
    ipa_url=$(jq -r --arg n "$IPA_ASSET" \
      '[.assets.links[]? | select(.name == $n)][0] | .direct_asset_url // .url // empty' <<<"$rel")
    [ -z "$ipa_url" ] && continue

    pkg_id=$(glab api "projects/$PROJECT_ID/packages?package_name=$PKG_NAME&package_version=$tag" |
      jq -r '.[0].id // empty')
    size=""
    if [ -n "$pkg_id" ]; then
      size=$(glab api "projects/$PROJECT_ID/packages/$pkg_id/package_files?per_page=100" |
        jq -r --arg n "$IPA_ASSET" '[.[] | select(.file_name == $n)][0].size // empty')
    fi
    date=$(jq -r '.released_at // .created_at' <<<"$rel")

    versions=$(jq --arg v "$ver" --arg d "$date" --arg u "$ipa_url" --arg min "$MIN_OS" \
      --argjson s "${size:-null}" \
      '. + [({version: $v, date: $d, downloadURL: $u, minOSVersion: $min}
             + (if $s then {size: $s} else {} end))]' <<<"$versions")

    if [ "$count" -lt 5 ]; then
      news=$(jq --arg id "release-$tag" --arg t "Murrmobile $ver" \
        --arg c "Version $ver is now available." --arg d "$date" \
        --arg u "https://gitlab.com/$PROJECT_PATH/-/releases/$tag" --arg app "$BUNDLE_ID" \
        '. + [{identifier: $id, title: $t, caption: $c, date: $d, url: $u, appID: $app}]' <<<"$news")
    fi
    count=$((count + 1))
  done < <(jq -c '.[]' <<<"$releases")

  if [ "$count" -eq 0 ]; then
    echo "No releases with an ipa asset found, leaving apps.json untouched" >&2
    return 1
  fi

  jq -n \
    --arg src_name "Murrmobile" \
    --arg src_id "gitlab.httpanimations.murrmobile.source" \
    --arg icon "$ICON_URL" \
    --arg website "https://gitlab.com/$PROJECT_PATH" \
    --arg app_name "Murrmobile" \
    --arg bundle "$BUNDLE_ID" \
    --arg dev "HttpAnimations" \
    --arg sub "Unofficial murrtube.net client" \
    --arg desc "A native Flutter client for murrtube.net. Browse, watch, upload, and comment on videos." \
    --arg cat "entertainment" \
    --argjson versions "$versions" \
    --argjson news "$news" \
    '{
      name: $src_name,
      identifier: $src_id,
      iconURL: $icon,
      website: $website,
      apps: [({
        name: $app_name,
        bundleIdentifier: $bundle,
        developerName: $dev,
        subtitle: $sub,
        localizedDescription: $desc,
        iconURL: $icon,
        category: $cat,
        version: $versions[0].version,
        versionDate: $versions[0].date,
        downloadURL: $versions[0].downloadURL,
        size: $versions[0].size,
        versions: $versions
      } | with_entries(select(.value != null)))],
      news: $news
    }' > altstore/apps.json

  echo "Wrote altstore/apps.json with $count version(s)"
}

if [ "${1:-}" = "--no-push" ]; then
  mkdir -p altstore
  write_apps_json
  exit 0
fi

# In CI: base the update on the latest remote main, commit and push with
# ci.skip so the commit does not start another pipeline.
mkdir -p altstore

if [ -n "${GITLAB_TOKEN:-}" ]; then
  git remote add altstore-push "https://oauth2:${GITLAB_TOKEN}@${CI_SERVER_HOST}/${PROJECT_PATH}.git" 2>/dev/null || true
elif [ -n "${GITLAB_RELEASE_SSH_KEY:-}" ]; then
  git remote add altstore-push "git@${CI_SERVER_HOST:-gitlab.com}:${PROJECT_PATH}.git" 2>/dev/null || true
else
  echo "ERROR: set GITLAB_TOKEN or GITLAB_RELEASE_SSH_KEY so the job can push to main" >&2
  exit 1
fi

git fetch altstore-push main
git checkout -B main FETCH_HEAD

write_apps_json

git config user.name "GitLab CI"
git config user.email "ci@gitlab.com"
git add altstore/apps.json
if git diff --cached --quiet; then
  echo "AltStore source already up to date"
  exit 0
fi
git commit -m "chore: 更新 AltStore 源"
git push -o ci.skip altstore-push HEAD:main
echo "Pushed updated AltStore source to main"
