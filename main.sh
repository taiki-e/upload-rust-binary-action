#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

error() {
    echo "::error::$*"
}

warn() {
    echo "::warning::$*"
}

if [[ "${GITHUB_REF:?}" != "refs/tags/"* ]]; then
    error "GITHUB_REF should start with 'refs/tags/'"
    exit 1
fi
tag="${GITHUB_REF#refs/tags/}"

features=${INPUT_FEATURES}

archive="${INPUT_ARCHIVE:?}"
package=${INPUT_BIN:?}
if [[ ! "${INPUT_TAR}" =~ ^(all|unix|windows|none)$ ]]; then
    error "invalid input 'tar': ${INPUT_TAR}"
    exit 1
elif [[ ! "${INPUT_ZIP}" =~ ^(all|unix|windows|none)$ ]]; then
    error "invalid input 'zip': ${INPUT_ZIP}"
    exit 1
elif [[ "${INPUT_TAR}" == "none" ]] && [[ "${INPUT_ZIP}" == "none" ]]; then
    error "at least one of INPUT_TAR or INPUT_ZIP must be a value other than 'none'"
    exit 1
fi

host=$(rustc -Vv | grep host | sed 's/host: //')
target="${INPUT_TARGET:-"${host}"}"
cargo="cargo"
if [[ "${host}" != "${target}" ]]; then
    rustup target add "${target}"
    case "${target}" in
        # https://github.com/rust-embedded/cross#supported-targets
        *windows-msvc | *windows-gnu | *darwin | *fuchsia | *redox) ;;
        *)
            cargo="cross"
            cargo install cross
            ;;
    esac
fi

case "${OSTYPE}" in
    linux*)
        platform="unix"
        ;;
    darwin*)
        platform="unix"
        # Work around https://github.com/actions/cache/issues/403 by using GNU tar
        # instead of BSD tar.
        brew install gnu-tar &>/dev/null
        export PATH=${PATH}:/usr/local/opt/gnu-tar/libexec/gnubin
        ;;
    cygwin* | msys*)
        platform="windows"
        exe=".exe"
        ;;
    *)
        error "unrecognized OSTYPE: ${OSTYPE}"
        exit 1
        ;;
esac

strip=""
case "${target}" in
    *-pc-windows-msvc) ;;
    x86_64-* | i686-*)
        strip="strip"
        ;;
    arm*-linux-*eabi)
        strip="arm-linux-gnueabi-strip"
        ;;
    arm*-linux-*eabihf | thumb*-linux-*eabihf)
        strip="arm-linux-gnueabihf-strip"
        ;;
    arm*-none-eabi | thumb*-none-eabi)
        strip="arm-none-eabi-strip"
        ;;
    aarch64*-linux-*)
        strip="aarch64-linux-gnu-strip"
        ;;
    *) ;;
esac
if [[ -n "${strip:-}" ]]; then
    # shellcheck disable=SC2230 # https://github.com/koalaman/shellcheck/issues/1162
    if ! which "$strip" &>/dev/null; then
        warn "$strip not found, skip stripping"
        strip=""
    fi
fi

bin="${package}${exe:-}"

build_options=("--bin" "${package}" "--release" "--target" "${target}")
if [[ -n "${features}" ]]; then
    build_options+=("--features" "${features}")
fi

$cargo build "${build_options[@]}"

cd target/"${target}"/release
archive="${archive/\$bin/${package}}"
archive="${archive/\$target/${target}}"
archive="${archive/\$tag/${tag}}"
assets=()
if [[ -n "${strip:-}" ]]; then
    $strip "${bin}"
fi
if [[ "${INPUT_TAR/all/${platform}}" == "${platform}" ]]; then
    assets+=("${archive}.tar.gz")
    tar acf ../../../"${assets[0]}" "${bin}"
fi
if [[ "${INPUT_ZIP/all/${platform}}" == "${platform}" ]]; then
    assets+=("${archive}.zip")
    if [[ "${platform}" == "unix" ]]; then
        zip ../../../"${archive}.zip" "${bin}"
    else
        7z a ../../../"${archive}.zip" "${bin}"
    fi
fi
cd ../../..

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    error "GITHUB_TOKEN not set, skipping deploy"
    exit 1
else
    # https://cli.github.com/manual/gh_release_upload
    gh release upload "${tag}" "${assets[@]}" --clobber
fi
