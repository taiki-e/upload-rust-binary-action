#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

bail() {
    echo "::error::$*"
    exit 1
}
warn() {
    echo "::warning::$*"
}

if [[ $# -gt 0 ]]; then
    bail "invalid argument '$1'"
fi

if [[ "${GITHUB_REF:?}" != "refs/tags/"* ]]; then
    bail "GITHUB_REF should start with 'refs/tags/'"
fi
tag="${GITHUB_REF#refs/tags/}"

features=${INPUT_FEATURES}

archive="${INPUT_ARCHIVE:?}"
package=${INPUT_BIN:?}
if [[ ! "${INPUT_TAR}" =~ ^(all|unix|windows|none)$ ]]; then
    bail "invalid input 'tar': ${INPUT_TAR}"
elif [[ ! "${INPUT_ZIP}" =~ ^(all|unix|windows|none)$ ]]; then
    bail "invalid input 'zip': ${INPUT_ZIP}"
elif [[ "${INPUT_TAR}" == "none" ]] && [[ "${INPUT_ZIP}" == "none" ]]; then
    bail "at least one of INPUT_TAR or INPUT_ZIP must be a value other than 'none'"
fi

host=$(rustc -Vv | grep host | sed 's/host: //')
target="${INPUT_TARGET:-"${host}"}"
target_lower="${target//-/_}"
target_lower="${target_lower//./_}"
target_upper="$(tr '[:lower:]' '[:upper:]' <<<"${target_lower}")"
cargo="cargo"
if [[ "${host}" != "${target}" ]]; then
    rustup target add "${target}"
    case "${target}" in
        # https://github.com/cross-rs/cross#supported-targets
        *windows-msvc | *windows-gnu | *darwin | *fuchsia | *redox) ;;
        *)
            # If any of these are set, it is obvious that the user has set up a cross-compilation environment on the host.
            if [[ -z "$(eval "echo \${CARGO_TARGET_${target_upper}_LINKER:-}")" ]] && [[ -z "$(eval "echo \${CARGO_TARGET_${target_upper}_RUNNER:-}")" ]]; then
                cargo="cross"
                if ! type -P cross &>/dev/null; then
                    cargo install cross
                fi
            fi
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
        export PATH="${PATH}:/usr/local/opt/gnu-tar/libexec/gnubin"
        ;;
    cygwin* | msys*)
        platform="windows"
        exe=".exe"
        ;;
    *) bail "unrecognized OSTYPE '${OSTYPE}'" ;;
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
    if ! type -P "${strip}" &>/dev/null; then
        warn "${strip} not found, skip stripping"
        strip=""
    fi
fi

bin="${package}${exe:-}"

build_options=("--bin" "${package}" "--release" "--target" "${target}")
if [[ -n "${features}" ]]; then
    build_options+=("--features" "${features}")
fi

"${cargo}" build "${build_options[@]}"

pushd target/"${target}"/release >/dev/null
archive="${archive/\$bin/${package}}"
archive="${archive/\$target/${target}}"
archive="${archive/\$tag/${tag}}"
assets=()
if [[ -n "${strip:-}" ]]; then
    "${strip}" "${bin}"
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
popd >/dev/null

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    bail "GITHUB_TOKEN not set, skipping deploy"
else
    # https://cli.github.com/manual/gh_release_upload
    gh release upload "${tag}" "${assets[@]}" --clobber
fi
