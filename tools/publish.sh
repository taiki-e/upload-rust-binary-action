#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Publish a new release.
#
# USAGE:
#    ./tools/publish.sh <VERSION>
#
# NOTE:
# - This script requires parse-changelog <https://github.com/taiki-e/parse-changelog>

cd "$(cd "$(dirname "$0")" && pwd)"/..

bail() {
    echo >&2 "error: $*"
    exit 1
}

version="${1:?}"
version="${version#v}"
tag="v${version}"
if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z\.-]+)?(\+[0-9A-Za-z\.-]+)?$ ]]; then
    bail "invalid version format '${version}'"
fi
if [[ $# -gt 1 ]]; then
    bail "invalid argument '$2'"
fi

# Make sure there is no uncommitted change.
git diff --exit-code
git diff --exit-code --staged

# Make sure that a valid release note for this version exists.
# https://github.com/taiki-e/parse-changelog
echo "============== CHANGELOG =============="
parse-changelog CHANGELOG.md "${version}"
echo "======================================="

if ! grep <CHANGELOG.md -E "^\\[${version//./\\.}\\]: " >/dev/null; then
    bail "not found link to [${version}] in CHANGELOG.md"
fi

# Make sure the same release has not been created in the past.
if gh release view "${tag}" &>/dev/null; then
    bail "tag '${tag}' has already been created and pushed"
fi

set -x

git push origin main
git tag "${tag}"
git push origin --tags
sleep 10

version_tag="v${version%%.*}"
git checkout -b "${version_tag}"
git push origin refs/heads/"${version_tag}"
if git --no-pager tag | grep -E "^${version_tag}$" &>/dev/null; then
    git tag -d "${version_tag}"
    git push --delete origin refs/tags/"${version_tag}"
fi
git tag "${version_tag}"
git checkout main
git branch -d "${version_tag}"

git push origin --tags
