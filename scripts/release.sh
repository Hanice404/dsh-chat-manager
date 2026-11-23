#!/bin/sh
# Package the plugin, tag it, push the fork, and (optionally) create the GitHub
# Release with the tarball. POSIX counterpart of scripts/publish-fork-release.ps1.
#
# Usage:
#   scripts/release.sh <tag> [token-file]
#
#   tag         annotated tag to publish, for example v2.1.0; must match package.json
#   token-file  optional file holding a GitHub token with repo write access.
#               Read from disk only, never from the command line, and never printed.
#               Without it the script stops after pushing the tag.
#
# Environment:
#   HTTPS_PROXY   when github.com is unreachable directly, point git and curl at a
#                 local proxy, for example HTTPS_PROXY=http://127.0.0.1:7890
#   DRY=1         print the plan and create the tarball only
#   OWNER/REPO  defaults to Hanice404/dsh-chat-manager
set -eu

tag=${1:-}
token_file=${2:-}
owner=${OWNER:-Hanice404}
repo=${REPO:-dsh-chat-manager}
repo_root=$(cd -- "$(dirname -- "$0")/.." && pwd)

fail() { printf 'release: %s\n' "$1" >&2; exit 1; }
info() { printf '==> %s\n' "$1"; }

[ -n "$tag" ] || fail 'usage: scripts/release.sh <tag> [token-file]'
[ -f "$repo_root/package.json" ] || fail "no package.json under $repo_root"

cd "$repo_root"

version=$(node -p "require('./package.json').version")
[ "$tag" = "v$version" ] || fail "tag $tag does not match package.json version $version"

[ -z "$(git status --porcelain)" ] || fail 'working tree is not clean; commit or stash first'
git rev-parse -q --verify "refs/tags/$tag" >/dev/null && fail "tag $tag already exists locally"

branch=$(git rev-parse --abbrev-ref HEAD)
info "packing dsh-chat-manager-$version.tgz"
pnpm pack --pack-destination . >/dev/null
tarball="dsh-chat-manager-$version.tgz"
[ -f "$tarball" ] || fail "pack did not produce $tarball"

if [ "${DRY:-0}" = "1" ]; then
  info "dry run: would tag $tag on $branch, push, and release $tarball"
  exit 0
fi

info "tagging $tag"
git tag -a "$tag" -m "dsh-chat-manager $version"

info "pushing $branch and $tag to $owner/$repo"
git push origin "$branch"
git push origin "$tag"

[ -n "$token_file" ] || { info 'no token file: tag pushed, skipping the GitHub Release'; exit 0; }
[ -f "$token_file" ] || fail "token file not found: $token_file"
token=$(tr -d '[:space:]' < "$token_file")
[ -n "$token" ] || fail 'token file is empty'

notes_file="RELEASE-NOTES-$tag.md"
[ -f "$notes_file" ] || fail "missing release notes: $notes_file"

info "creating GitHub Release $tag"
body=$(node -e 'const fs=require("node:fs");const t=process.argv[1];process.stdout.write(JSON.stringify({tag_name:t,name:"dsh-chat-manager "+t,body:fs.readFileSync(process.argv[2],"utf8"),prerelease:t.indexOf("-")!==-1}))' "$tag" "$notes_file")

release_url=$(curl -sS -X POST \
  -H "Authorization: Bearer $token" \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "https://api.github.com/repos/$owner/$repo/releases" \
  -d "$body" | node -e 'let raw="";process.stdin.on("data",c=>{raw+=c});process.stdin.on("end",()=>{const p=JSON.parse(raw);if(!p.upload_url){process.stderr.write(JSON.stringify(p)+"\n");process.exit(1)}process.stdout.write(p.upload_url.replace(/\{\?.*$/,""))})')

info "uploading $tarball"
curl -sS -X POST \
  -H "Authorization: Bearer $token" \
  -H 'Content-Type: application/gzip' \
  --data-binary "@$tarball" \
  "$release_url?name=$tarball" >/dev/null

info "released $tag with $tarball"
