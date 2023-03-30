#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
cd "$(dirname "$0")"/..

# shellcheck disable=SC2154
trap 's=$?; echo >&2 "$0: Error on line "${LINENO}": ${BASH_COMMAND}"; exit ${s}' ERR

bail() {
    echo >&2 "error: $*"
    exit 1
}

if [[ -z "${CI:-}" ]]; then
    bail "this script is intended to call from release workflow on CI"
fi
ref="${GITHUB_REF:-}"
if [[ "${ref}" != "refs/tags/"* ]]; then
    bail "tag ref should start with 'refs/tags/'"
fi
tag="${ref#refs/tags/}"

git config user.name "Taiki Endo"
git config user.email "te316e89@gmail.com"

version="${tag}"
version="${version#v}"

set -x

major_version_tag="v${version%%.*}"
git checkout -b "${major_version_tag}"
git push origin refs/heads/"${major_version_tag}"
if git --no-pager tag | grep -Eq "^${major_version_tag}$"; then
    git tag -d "${major_version_tag}"
    git push --delete origin refs/tags/"${major_version_tag}"
fi
git tag "${major_version_tag}"
git checkout main
git branch -d "${major_version_tag}"

git push origin --tags
