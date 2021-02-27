#!/bin/bash

# Format all scripts.
#
# Note: This script requires shfmt and prettier.

set -euo pipefail
IFS=$'\n\t'

cd "$(cd "$(dirname "${0}")" && pwd)"/..

if [[ -z "${CI:-}" ]]; then
    (
        set -x
        shfmt -l -w ./*/*.sh ./*.sh
        prettier -w ./*.js
    )
else
    (
        set -x
        shfmt -d ./*/*.sh ./*.sh
        prettier -c ./*.js
    )
fi
