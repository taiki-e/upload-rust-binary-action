#!/bin/bash

# Publish a new release.
#
# Usage:
#    ./tools/publish.sh <version>
#
# Note:
# - This script requires parse-changelog <https://github.com/taiki-e/parse-changelog>

set -euo pipefail
IFS=$'\n\t'

cd "$(cd "$(dirname "$0")" && pwd)"/..

error() {
    echo "error: $*" >&2
}

# Parse arguments.
version="${1:?}"
tag="v${version}"
if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z\.-]+)?(\+[0-9A-Za-z\.-]+)?$ ]]; then
    error "invalid version format: '${version}'"
    exit 1
fi
if [[ "${2:-}" == "--dry-run" ]]; then
    dry_run="--dry-run"
    shift
fi
if [[ -n "${2:-}" ]]; then
    error "invalid argument: '$2'"
    exit 1
fi

if [[ -z "${dry_run:-}" ]]; then
    git diff --exit-code
    git diff --exit-code --staged
fi

# Make sure that a valid release note for this version exists.
# https://github.com/taiki-e/parse-changelog
echo "============== CHANGELOG =============="
parse-changelog CHANGELOG.md "${version}"
echo
echo "======================================="

# Make sure the same release has not been created in the past.
if gh release view "${tag}" &>/dev/null; then
    error "tag '${tag}' has already been created and pushed"
    exit 1
fi

# Exit if dry run.
if [[ -n "${dry_run:-}" ]]; then
    echo "warning: skip creating a new tag '${tag}' due to dry run"
    exit 0
fi

echo "info: creating and pushing a new tag '${tag}'"

set -x

git push origin main
git checkout v1
git merge main
git push origin refs/heads/v1

if git --no-pager tag | grep -E "^v1$" &>/dev/null; then
    git tag -d v1
    git push --delete origin refs/tags/v1
fi

git tag v1
git tag "${tag}"
git push origin --tags
git checkout main
