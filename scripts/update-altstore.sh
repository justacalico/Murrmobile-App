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
    if [ -z "$ipa_url" ]; then
      echo "Warning: $tag has no $IPA_ASSET link, skipping" >&2
      continue
    fi

    pkg_id=$(glab api "projects/$PROJECT_ID/packages?package_name=$PKG_NAME&package_version=$tag" |
      jq -r '.[0].id // empty')
    size=""
    if [ -n "$pkg_id" ]; then
      size=$(glab api "projects/$PROJECT_ID/packages/$pkg_id/package_files?per_page=100" |
        jq -r --arg n "$IPA_ASSET" '[.[] | select(.file_name == $n)][0].size // empty')
    fi
    if [ -z "$size" ]; then
      # Fall back to the download URL's content-length.
      size=$(curl -fsSIL "$ipa_url" 2>/dev/null | grep -i '^content-length' | tail -n1 | tr -dc '0-9')
    fi
    if [ -z "$size" ]; then
      echo "Warning: could not determine ipa size for $tag, skipping" >&2
      continue
    fi

    # Use the tagged commit's date: the release record is recreated on
    # every sync, so released_at changes each run and would spam commits.
    date=$(glab api "projects/$PROJECT_ID/repository/commits/$tag" |
      jq -r '.committed_date // empty' || true)
    [ -z "$date" ] && date=$(jq -r '.released_at // .created_at' <<<"$rel")

    versions=$(jq --arg v "$ver" --arg d "$date" --arg u "$ipa_url" \
      --arg min "$MIN_OS" --argjson s "$size" \
      '. + [{version: $v, date: $d, downloadURL: $u, size: $s, minOSVersion: $min}]' <<<"$versions")

    if [ "$count" -lt 5 ]; then
      news=$(jq --arg id "release-$tag" --arg t "Murrmobile $ver" \
        --arg c "Version $ver is now available." --arg d "$date" \
        --arg u "https://gitlab.com/$PROJECT_PATH/-/releases/$tag" --arg app "$BUNDLE_ID" \
        '. + [{identifier: $id, title: $t, caption: $c, date: $d, url: $u, appID: $app}]' <<<"$news")
    fi
    count=$((count + 1))
  done < <(jq -c '.[]' <<<"$releases")

  if [ "$count" -eq 0 ]; then
    echo "Warning: no releases with an ipa asset found, leaving apps.json untouched" >&2
    return 0
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
      apps: [{
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
      }],
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
# ci.skip so the commit does not start another pipeline. Retry the whole
# thing when a concurrent pusher (auto-release, merges) moves main.
mkdir -p altstore

if [ -n "${GITLAB_TOKEN:-}" ]; then
  git remote add altstore-push "https://oauth2:${GITLAB_TOKEN}@${CI_SERVER_HOST:-gitlab.com}/${PROJECT_PATH}.git" 2>/dev/null || true
elif [ -n "${GITLAB_RELEASE_SSH_KEY:-}" ]; then
  git remote add altstore-push "git@${CI_SERVER_HOST:-gitlab.com}:${PROJECT_PATH}.git" 2>/dev/null || true
else
  echo "ERROR: set GITLAB_TOKEN or GITLAB_RELEASE_SSH_KEY so the job can push to main" >&2
  exit 1
fi

git config user.name "GitLab CI"
git config user.email "ci@gitlab.com"

for attempt in 1 2 3; do
  git fetch --depth 1 altstore-push main
  git checkout -B main FETCH_HEAD
  write_apps_json
  git add altstore/apps.json
  if git diff --cached --quiet; then
    echo "AltStore source already up to date"
    exit 0
  fi
  git commit -q -m "chore: 更新 AltStore 源"
  if git push -o ci.skip altstore-push HEAD:main; then
    echo "Pushed updated AltStore source to main"
    exit 0
  fi
  echo "Push rejected, main moved; retrying (attempt $attempt)"
done

echo "Failed to push AltStore update after 3 attempts" >&2
exit 1
