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

features="${INPUT_FEATURES:-}"
archive="${INPUT_ARCHIVE:?}"
if [[ ! "${INPUT_TAR}" =~ ^(all|unix|windows|none)$ ]]; then
    bail "invalid input 'tar': ${INPUT_TAR}"
elif [[ ! "${INPUT_ZIP}" =~ ^(all|unix|windows|none)$ ]]; then
    bail "invalid input 'zip': ${INPUT_ZIP}"
elif [[ "${INPUT_TAR}" == "none" ]] && [[ "${INPUT_ZIP}" == "none" ]]; then
    bail "at least one of 'tar' or 'zip' must be a value other than 'none'"
fi

leading_dir="${INPUT_LEADING_DIR:-}"
case "${leading_dir}" in
    true) leading_dir="1" ;;
    false) leading_dir="" ;;
    *) bail "'leading_dir' input option must be 'true' or 'false': '${leading_dir}'" ;;
esac

bin_name="${INPUT_BIN:?}"
bin_names=()
if [[ -n "${bin_name}" ]]; then
    # We can expand a glob by expanding a variable without quote, but that way
    # has a security issue of shell injection.
    if [[ "${bin_name}" == *"?"* ]] || [[ "${bin_name}" == *"*"* ]] || [[ "${bin_name}" == *"["* ]]; then
        # This check is not for security but for diagnostic purposes.
        # We quote the filename, so without this uses get an error like
        # "cp: cannot stat 'app-*': No such file or directory".
        bail "glob pattern in 'bin' input option is not supported yet"
    fi
    while read -rd,; do bin_names+=("${REPLY}"); done <<<"${bin_name},"
fi
if [[ ${#bin_names[@]} -gt 1 ]] && [[ "${archive}" == *"\$bin"* ]]; then
    bail "when multiple binary names are specified, default archive name or '\$bin' variable cannot be used in 'archive' option"
fi

include="${INPUT_INCLUDE:-}"
includes=()
if [[ -n "${include}" ]]; then
    # We can expand a glob by expanding a variable without quote, but that way
    # has a security issue of shell injection.
    if [[ "${include}" == *"?"* ]] || [[ "${include}" == *"*"* ]] || [[ "${include}" == *"["* ]]; then
        # This check is not for security but for diagnostic purposes.
        # We quote the filename, so without this uses get an error like
        # "cp: cannot stat 'LICENSE-*': No such file or directory".
        bail "glob pattern in 'include' input option is not supported yet"
    fi
    while read -rd,; do includes+=("${REPLY}"); done <<<"${include},"
fi

checksum="${INPUT_CHECKSUM:-}"
checksums=()
if [[ -n "${checksum}" ]]; then
    while read -rd,; do
        checksums+=("${REPLY}")
        case "${REPLY}" in
            sha256 | sha512 | sha1 | md5) ;;
            *) bail "'checksum' input option must be 'sha256', 'sha512', 'sha1', or 'md5': '${REPLY}'" ;;
        esac
    done <<<"${checksum},"
fi

host=$(rustc -Vv | grep host | sed 's/host: //')
target="${INPUT_TARGET:-"${host}"}"
target_lower="${target//-/_}"
target_lower="${target_lower//./_}"
target_upper="$(tr '[:lower:]' '[:upper:]' <<<"${target_lower}")"
build_tool="${INPUT_BUILD_TOOL:-}"
if [[ -z "${build_tool}" ]]; then
    build_tool="cargo"
    if [[ "${host}" != "${target}" ]]; then
        rustup target add "${target}"
        case "${target}" in
            # https://github.com/cross-rs/cross#supported-targets
            *windows-msvc | *windows-gnu | *darwin | *fuchsia | *redox) ;;
            *)
                # If any of these are set, it is obvious that the user has set up a cross-compilation environment on the host.
                if [[ -z "$(eval "echo \${CARGO_TARGET_${target_upper}_LINKER:-}")" ]] && [[ -z "$(eval "echo \${CARGO_TARGET_${target_upper}_RUNNER:-}")" ]]; then
                    build_tool="cross"
                fi
                ;;
        esac
    fi
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

build_options=("--release" "--target" "${target}")
bins=()
for bin_name in "${bin_names[@]}"; do
    bins+=("${bin_name}${exe:-}")
    build_options+=("--bin" "${bin_name}")
done
if [[ -n "${features}" ]]; then
    build_options+=("--features" "${features}")
fi

case "${build_tool}" in
    cargo) cargo build "${build_options[@]}" ;;
    cross)
        if ! type -P cross &>/dev/null; then
            cargo install cross
        fi
        cross build "${build_options[@]}"
        ;;
    *) bail "unrecognized build tool '${build_tool}'" ;;
esac

if [[ -n "${strip:-}" ]]; then
    for bin_exe in "${bins[@]}"; do
        "${strip}" target/"${target}"/release/"${bin_exe}"
    done
fi

archive="${archive/\$bin/${bin_names[0]}}"
archive="${archive/\$target/${target}}"
archive="${archive/\$tag/${tag}}"
assets=()
cwd=$(pwd)
mkdir /tmp/"${archive}"
filenames=("${bins[@]}")
for bin_exe in "${bins[@]}"; do
    cp target/"${target}"/release/"${bin_exe}" /tmp/"${archive}"/
done
for include in "${includes[@]}"; do
    cp -r "${include}" /tmp/"${archive}"/
    filenames+=("$(basename "${include}")")
done
pushd /tmp >/dev/null
if [[ -n "${leading_dir}" ]]; then
    # with leading directory
    #
    # /${archive}
    # /${archive}/${bins}
    # /${archive}/${includes}
    if [[ "${INPUT_TAR/all/${platform}}" == "${platform}" ]]; then
        assets+=("${archive}.tar.gz")
        tar acf "${cwd}/${archive}.tar.gz" "${archive}"
    fi
    if [[ "${INPUT_ZIP/all/${platform}}" == "${platform}" ]]; then
        assets+=("${archive}.zip")
        if [[ "${platform}" == "unix" ]]; then
            zip -r "${cwd}/${archive}.zip" "${archive}"
        else
            7z a "${cwd}/${archive}.zip" "${archive}"
        fi
    fi
else
    # without leading directory
    #
    # /${bins}
    # /${includes}
    pushd "${archive}" >/dev/null
    if [[ "${INPUT_TAR/all/${platform}}" == "${platform}" ]]; then
        assets+=("${archive}.tar.gz")
        tar acf "${cwd}/${archive}.tar.gz" "${filenames[@]}"
    fi
    if [[ "${INPUT_ZIP/all/${platform}}" == "${platform}" ]]; then
        assets+=("${archive}.zip")
        if [[ "${platform}" == "unix" ]]; then
            zip -r "${cwd}/${archive}.zip" "${filenames[@]}"
        else
            7z a "${cwd}/${archive}.zip" "${filenames[@]}"
        fi
    fi
    popd >/dev/null
fi
popd >/dev/null
rm -rf /tmp/"${archive}"

final_assets=("${assets[@]}")
for checksum in "${checksums[@]}"; do
    "${checksum}sum" "${assets[@]}" >"${archive}.${checksum}"
    final_assets+=("${archive}.${checksum}")
done

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    bail "GITHUB_TOKEN not set, skipping deploy"
else
    # https://cli.github.com/manual/gh_release_upload
    gh release upload "${tag}" "${final_assets[@]}" --clobber
fi
