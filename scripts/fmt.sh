#!/bin/bash

# Format all scripts.
#
# Note: This script requires shfmt and clang-format.

set -euo pipefail
IFS=$'\n\t'

cd "$(cd "$(dirname "${0}")" && pwd)"/..

if [[ -n "${CI:-}" ]]; then
  shfmt -d ./*/*.sh ./*.sh
else
  shfmt -l -w ./*/*.sh ./*.sh
fi

clang-format -i ./*.js
if [[ -n "${CI:-}" ]]; then
  git diff --exit-code
fi
