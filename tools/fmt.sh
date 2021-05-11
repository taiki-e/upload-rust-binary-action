#!/bin/bash

# Format all code.
#
# Usage:
#    ./tools/fmt.sh
#
# Note: This script requires shfmt and prettier.

set -euo pipefail
IFS=$'\n\t'

cd "$(cd "$(dirname "${0}")" && pwd)"/..

# shellcheck disable=SC2046
if [[ -z "${CI:-}" ]]; then
    shfmt -l -w $(git ls-files '*.sh')
    prettier -l -w $(git ls-files '*.yml')
    prettier -l -w $(git ls-files '*.js')
else
    shfmt -d $(git ls-files '*.sh')
    prettier -c $(git ls-files '*.yml')
    prettier -c $(git ls-files '*.js')
fi
