#!/usr/bin/env bash
# Releases the theme: bumps Version in readme.txt, tags the commit, pushes both,
# and opens the pull request that lists the new version in OpenPanel's theme list.
#
#   ./release.sh 1.3.2            release 1.3.2
#   ./release.sh 1.3.2 --dry-run  check everything and show the changes, push nothing
#
# Needs git and the GitHub CLI (gh), signed in to the account that owns this repo.
set -euo pipefail

CATALOG_REPO="${CATALOG_REPO:-stefanpejcic/openpanel-configuration}"
CATALOG_FILE="openpanel/templates/themes.yml"
THEME_FOLDER="modern"
THEME_NAME="Modern"

die() { echo "release: $*" >&2; exit 1; }

new="${1:-}"
dry=""
[ "${2:-}" = "--dry-run" ] && dry=1
[[ "$new" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "usage: ./release.sh <version like 1.3.2> [--dry-run]"
tag="v$new"

command -v gh >/dev/null || die "the GitHub CLI (gh) is not installed"
cd "$(git rev-parse --show-toplevel)"
[ -f readme.txt ] || die "readme.txt not found, run this from the theme repo"

# the release is cut from what's on origin/main, nothing more and nothing less
git fetch --quiet --tags origin main
[ -z "$(git status --porcelain --untracked-files=no)" ] || die "there are uncommitted changes, commit or stash them first"
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || die "HEAD is not origin/main, check out main and pull (or push) first"
git rev-parse -q --verify "refs/tags/$tag" >/dev/null && die "tag $tag already exists"

current="$(sed -n 's/^Version:[[:space:]]*//p' readme.txt | tr -d '\r' | head -n1)"
[ -n "$current" ] || die "readme.txt has no Version: line"
if [ "$current" != "$new" ]; then
    [ "$(printf '%s\n%s\n' "$current" "$new" | sort -V | tail -n1)" = "$new" ] || die "$new is older than the current version $current"
fi

repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
me="$(gh api user --jq .login)"
fork="$me/${CATALOG_REPO#*/}"
download="https://github.com/$repo/archive/refs/tags/$tag.tar.gz"

# what changed since the last release, for the pull request text
last="$(git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null || true)"
changes="$(git log --no-merges --format='%s' ${last:+"$last"..HEAD} | grep -vE '^v?[0-9]+\.[0-9]+\.[0-9]+$' || true)"

# the theme list with the new version and download link
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
gh api "repos/$CATALOG_REPO/contents/$CATALOG_FILE" --jq .content | base64 -d > "$work/old.yml"
awk -v folder="$THEME_FOLDER" -v ver="$new" -v url="$download" '
    /^  - folder:/ { mine = ($3 == folder) }
    mine && /^    version:/  { print "    version: " ver;  next }
    mine && /^    download:/ { print "    download: " url; next }
    { print }
' "$work/old.yml" > "$work/new.yml"
grep -qxF "    version: $new" "$work/new.yml" && grep -qxF "    download: $download" "$work/new.yml" \
    || die "could not find the $THEME_FOLDER entry in $CATALOG_FILE"
cmp -s "$work/old.yml" "$work/new.yml" && die "$CATALOG_FILE already lists $new with this download link"

{
    echo "Bumps $THEME_NAME to $new${changes:+:}"
    [ -n "$changes" ] && printf '%s\n' "$changes" | sed 's/^/- /'
    echo
    echo "The download link points at the \`$tag\` tag, so what gets installed is the version listed here."
} > "$work/body.md"

echo "Version:    $current -> $new"
echo "Tag:        $tag on $repo"
echo "Theme list: $CATALOG_REPO, branch catalog/$THEME_FOLDER-$new on $fork"
echo
diff -u "$work/old.yml" "$work/new.yml" | tail -n +3 || true
echo
echo "Pull request text:"
sed 's/^/  /' "$work/body.md"

open_prs="$(gh pr list --repo "$CATALOG_REPO" --author "$me" --state open --search "themes.yml: $THEME_NAME in:title" --json number,title --jq '.[] | "  #\(.number) \(.title)"')"
if [ -n "$open_prs" ]; then
    echo
    echo "Still open, the new pull request replaces them, close them once it's up:"
    echo "$open_prs"
fi

if [ -n "$dry" ]; then
    echo
    echo "Dry run, nothing was changed."
    exit 0
fi

# 1. version bump (skipped when readme.txt already says $new), tag, push
if [ "$current" != "$new" ]; then
    sed -i "s/^Version:.*/Version: $new/" readme.txt
    git commit --quiet -m "$new" readme.txt
fi
git tag "$tag"
git push --quiet origin HEAD:main "$tag"
echo
echo "Pushed $tag."

# 2. theme list pull request, from a branch on the fork that starts at the upstream main
gh repo view "$fork" >/dev/null 2>&1 || gh repo fork "$CATALOG_REPO" --clone=false >/dev/null
gh repo sync "$fork" --branch main >/dev/null
branch="catalog/$THEME_FOLDER-$new"
base_sha="$(gh api "repos/$fork/git/ref/heads/main" --jq .object.sha)"
gh api -X POST "repos/$fork/git/refs" -f ref="refs/heads/$branch" -f sha="$base_sha" >/dev/null
file_sha="$(gh api "repos/$fork/contents/$CATALOG_FILE?ref=$branch" --jq .sha)"
base64 -w0 "$work/new.yml" > "$work/new.b64"
gh api -X PUT "repos/$fork/contents/$CATALOG_FILE" \
    -f message="themes.yml: $THEME_NAME $new" -f branch="$branch" -f sha="$file_sha" \
    -F content=@"$work/new.b64" >/dev/null
gh pr create --repo "$CATALOG_REPO" --head "$me:$branch" --base main \
    --title "themes.yml: $THEME_NAME $new" --body-file "$work/body.md"
