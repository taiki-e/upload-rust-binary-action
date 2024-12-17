#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -CeEuo pipefail
IFS=$'\n\t'

x() {
    (
        set -x
        "$@"
    )
}
retry() {
    for i in {1..10}; do
        if "$@"; then
            return 0
        else
            sleep "${i}"
        fi
    done
    "$@"
}
bail() {
    printf '::error::%s\n' "$*"
    exit 1
}
warn() {
    printf '::warning::%s\n' "$*"
}
info() {
    printf >&2 'info: %s\n' "$*"
}

export CARGO_NET_RETRY=10
export RUSTUP_MAX_RETRIES=10

if [[ $# -gt 0 ]]; then
    bail "invalid argument '$1'"
fi

dry_run="${INPUT_DRY_RUN:-}"
case "${dry_run}" in
    true) dry_run=1 ;;
    false) dry_run='' ;;
    *) bail "'dry-run' input option must be 'true' or 'false': '${dry_run}'" ;;
esac

token="${INPUT_TOKEN:-"${GITHUB_TOKEN:-}"}"
ref="${INPUT_REF:-"${GITHUB_REF:-}"}"

if [[ -z "${token}" ]]; then
    if [[ -n "${dry_run}" ]]; then
        # TODO: The warnings are somewhat noisy if we have a lot of build matrix:
        # https://github.com/taiki-e/upload-rust-binary-action/pull/55#discussion_r1349880455
        warn "neither GITHUB_TOKEN environment variable nor 'token' input option is set (downgraded error to info because action is running in dry-run mode)"
    else
        bail "neither GITHUB_TOKEN environment variable nor 'token' input option is set"
    fi
fi

if [[ "${ref}" != "refs/tags/"* ]]; then
    if [[ -n "${dry_run}" ]]; then
        # TODO: The warnings are somewhat noisy if we have a lot of build matrix:
        # https://github.com/taiki-e/upload-rust-binary-action/pull/55#discussion_r1349880455
        warn "tag ref should start with 'refs/tags/': '${ref}'; this action only supports events from tag or release by default; see <https://github.com/taiki-e/create-gh-release-action#supported-events> for more (downgraded error to info because action is running in dry-run mode)"
        ref='refs/tags/dry-run'
    else
        bail "tag ref should start with 'refs/tags/': '${ref}'; this action only supports events from tag or release by default; see <https://github.com/taiki-e/create-gh-release-action#supported-events> for more"
    fi
fi
tag="${ref#refs/tags/}"

features="${INPUT_FEATURES:-}"
archive="${INPUT_ARCHIVE:?}"

if [[ ! "${INPUT_TAR}" =~ ^(all|unix|windows|none)$ ]]; then
    bail "invalid input 'tar': ${INPUT_TAR}"
elif [[ ! "${INPUT_ZIP}" =~ ^(all|unix|windows|none)$ ]]; then
    bail "invalid input 'zip': ${INPUT_ZIP}"
fi

leading_dir="${INPUT_LEADING_DIR:-}"
case "${leading_dir}" in
    true) leading_dir=1 ;;
    false) leading_dir='' ;;
    *) bail "'leading-dir' input option must be 'true' or 'false': '${leading_dir}'" ;;
esac

bin_leading_dir="${INPUT_BIN_LEADING_DIR:-}"

no_default_features="${INPUT_NO_DEFAULT_FEATURES:-}"
case "${no_default_features}" in
    true) no_default_features=1 ;;
    false) no_default_features='' ;;
    *) bail "'no-default-features' input option must be 'true' or 'false': '${no_default_features}'" ;;
esac

build_locked="${INPUT_LOCKED:-}"
case "${build_locked}" in
    true) build_locked=1 ;;
    false) build_locked='' ;;
    *) bail "'locked' input option must be 'true' or 'false': '${build_locked}'" ;;
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

asset="${INPUT_ASSET:-}"
assets=()
if [[ -n "${asset}" ]]; then
    # We can expand a glob by expanding a variable without quote, but that way
    # has a security issue of shell injection.
    if [[ "${asset}" == *"?"* ]] || [[ "${asset}" == *"*"* ]] || [[ "${asset}" == *"["* ]]; then
        # This check is not for security but for diagnostic purposes.
        # We quote the filename, so without this uses get an error like
        # "cp: cannot stat 'LICENSE-*': No such file or directory".
        bail "glob pattern in 'asset' input option is not supported yet"
    fi
    while read -rd,; do assets+=("${REPLY}"); done <<<"${asset},"
fi

checksum="${INPUT_CHECKSUM:-}"
checksums=()
if [[ -n "${checksum}" ]]; then
    while read -rd,; do
        checksums+=("${REPLY}")
        case "${REPLY}" in
            b2 | sha256 | sha512 | sha1 | md5) ;;
            *) bail "'checksum' input option must be 'b2', 'sha256', 'sha512', 'sha1', or 'md5': '${REPLY}'" ;;
        esac
    done <<<"${checksum},"
fi

host=$(rustc -vV | grep -E '^host:' | cut -d' ' -f2)
rustc_version=$(rustc -vV | grep -E '^release:' | cut -d' ' -f2)
rustc_minor_version="${rustc_version#*.}"
rustc_minor_version="${rustc_minor_version%%.*}"
target="${INPUT_TARGET:-"${host}"}"
zigbuild_target=''
build_tool="${INPUT_BUILD_TOOL:-}"
if [[ "${build_tool}" == "cargo-zigbuild" ]]; then
    # cargo-zigbuild supports .<glibc_version> suffix
    zigbuild_target="${target}"
    target="${target%%.*}"
fi
case "${target}" in
    wasm*) exe=.wasm ;;
    *-windows*) exe=.exe ;;
    *) exe='' ;;
esac
target_lower="${target//-/_}"
target_lower="${target_lower//./_}"
target_upper=$(tr '[:lower:]' '[:upper:]' <<<"${target_lower}")

case "$(uname -s)" in
    Linux)
        platform=unix
        host_os=linux
        ;;
    Darwin)
        platform=unix
        host_os=macos
        # Work around https://github.com/actions/cache/issues/403 by using GNU tar
        # instead of BSD tar.
        if ! type -P gtar >/dev/null; then
            brew install gnu-tar &>/dev/null
        fi
        tar() { gtar "$@"; }
        if [[ -z "${INPUT_TARGET:-}" ]]; then
            warn "GitHub Actions changed default architecture of macos-latest since macos-14; consider passing 'target' input option to clarify which target you are building for"
        fi
        ;;
    MINGW* | MSYS* | CYGWIN* | Windows_NT)
        platform=windows
        host_os=windows
        ;;
    *) bail "unrecognized OS type '$(uname -s)'" ;;
esac

if [[ -z "${build_tool}" ]]; then
    build_tool=cargo
    if [[ "${host}" != "${target}" ]]; then
        # If any of these are set, it is obvious that the user has set up a cross-compilation environment on the host.
        if [[ -z "$(eval "printf '%s\n' \${CARGO_TARGET_${target_upper}_LINKER:-}")" ]] && [[ -z "$(eval "printf '%s\n' \${CARGO_TARGET_${target_upper}_RUNNER:-}")" ]]; then
            case "${target}" in
                # https://github.com/cross-rs/cross#supported-targets
                *-windows*)
                    case "${host_os}" in
                        windows) ;;
                        *) build_tool=cross ;;
                    esac
                    ;;
                *-apple-*)
                    case "${host_os}" in
                        macos) ;;
                        *) build_tool=cross ;;
                    esac
                    ;;
                *-fuchsia* | *-redox*) ;;
                *) build_tool=cross ;;
            esac
        fi
    fi
fi

if [[ "${build_tool}" == "cargo" ]]; then
    case "${target}" in
        universal-apple-darwin) retry rustup target add aarch64-apple-darwin x86_64-apple-darwin ;;
        *) retry rustup target add "${target}" ;;
    esac
fi

archive="${archive/\$bin/${bin_names[0]}}"
archive="${archive/\$target/${target}}"
archive="${archive/\$tag/${tag}}"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf 'archive=%s\n' "${archive}" >>"${GITHUB_OUTPUT}"
else
    warn "GITHUB_OUTPUT is not set; skip setting the 'archive' output"
    printf 'archive: %s\n' "${archive}"
fi

input_profile=${INPUT_PROFILE:-release}
case "${input_profile}" in
    release) build_options=(--release) ;;
    *) build_options=(--profile "${input_profile}") ;;
esac

# There are some special profiles that correspond to different target directory
# names. If we don't hit one of those conditionals then we just use the profile
# name.
# See: https://doc.rust-lang.org/nightly/cargo/reference/profiles.html#custom-profiles
case "${input_profile}" in
    bench) profile_directory=release ;;
    dev | test) profile_directory=debug ;;
    *) profile_directory=${input_profile} ;;
esac

bins=()
for bin_name in "${bin_names[@]}"; do
    bins+=("${bin_name}${exe}")
    build_options+=(--bin "${bin_name}")
done
if [[ -n "${features}" ]]; then
    build_options+=(--features "${features}")
fi
if [[ -n "${no_default_features}" ]]; then
    build_options+=(--no-default-features)
fi
if [[ -n "${build_locked}" ]]; then
    build_options+=(--locked)
fi
metadata_options=(--format-version=1 --no-deps)
manifest_path="${INPUT_MANIFEST_PATH:-}"
if [[ -n "${manifest_path}" ]]; then
    build_options+=(--manifest-path "${manifest_path}")
    metadata_options+=(--manifest-path "${manifest_path}")
fi
eval "$(cargo metadata "${metadata_options[@]}" | jq -r '@sh "target_dir=\(.target_directory) WORKSPACE_ROOT=\(.workspace_root)"')"

# Skip setting the strip option (requires Cargo 1.59) if it is unavailable or already set.
# TODO: This check is somewhat rough as it does not look at the type of profile.
if [[ "${rustc_minor_version}" -ge 59 ]] && [[ -z "${CARGO_PROFILE_RELEASE_STRIP:-}" ]] && ! grep -Eq '^\s*strip\s*=' "${WORKSPACE_ROOT}/Cargo.toml"; then
    if [[ "${rustc_minor_version}" -lt 79 ]]; then
        # On pre-1.77, align to Cargo 1.77+'s default: https://github.com/rust-lang/cargo/pull/13257
        # However, set environment variable on pre-1.79 because it is 1.79+ that actually works correctly due to https://github.com/rust-lang/cargo/issues/13617.
        case "${target}" in
            # Do not strip debuginfo on MSVC https://github.com/rust-lang/cargo/pull/13630
            # This is the same behavior as pre-1.19.0 upload-rust-binary-action.
            *-windows-msvc) strip_default=none ;;
            *) strip_default=debuginfo ;;
        esac
        export CARGO_PROFILE_RELEASE_STRIP="${strip_default}"
    fi
    # Do not strip debuginfo on these targets in cross-compilation (including docker via cross).
    # https://github.com/nextest-rs/nextest/commit/d4f982b3184f07ff5c40cc90c52d3fc6567be0b9#commitcomment-140325483
    # https://github.com/rust-lang/rust/issues/123151#issuecomment-2024743520
    # https://github.com/rust-lang/rust/blob/1.80.0/compiler/rustc_codegen_ssa/src/back/link.rs#L1055-L1100
    # TODO: Add `if [[ "${rustc_minor_version}" -lt patched_version ]]; ..` once upstream bug fixed.
    case "${target}" in
        *-apple-*)
            case "${host_os}" in
                macos) ;; # apple to apple cross-compilation is okay
                *) export CARGO_PROFILE_RELEASE_STRIP=none ;;
            esac
            ;;
        # illumos/AIX host is not supported on GitHub Actions.
        *-illumos* | *-aix*) export CARGO_PROFILE_RELEASE_STRIP=none ;;
    esac
fi

build() {
    case "${build_tool}" in
        cargo) x cargo build "${build_options[@]}" "$@" ;;
        cross)
            if ! type -P cross >/dev/null; then
                x cargo install cross --locked
            fi
            x cross build "${build_options[@]}" "$@"
            ;;
        cargo-zigbuild)
            if ! type -P cargo-zigbuild >/dev/null; then
                x pip3 install cargo-zigbuild
            fi
            case "${INPUT_TARGET:-}" in
                '') ;;
                universal2-apple-darwin) retry rustup target add aarch64-apple-darwin x86_64-apple-darwin ;;
                *) retry rustup target add "${target}" ;;
            esac
            x cargo zigbuild "${build_options[@]}" "$@"
            ;;
        *) bail "unrecognized build tool '${build_tool}'" ;;
    esac
}

do_codesign() {
    if [[ -n "${INPUT_CODESIGN:-}" ]]; then
        local codesign_options=(--sign "${INPUT_CODESIGN}")
        if [[ -n "${INPUT_CODESIGN_PREFIX:-}" ]]; then
            codesign_options+=(--prefix "${INPUT_CODESIGN_PREFIX}")
        fi
        if [[ -n "${INPUT_CODESIGN_OPTIONS:-}" ]]; then
            codesign_options+=(--options "${INPUT_CODESIGN_OPTIONS}")
        fi

        for bin_exe in "${bins[@]}"; do
            x codesign "${codesign_options[@]}" "${target_dir}/${bin_exe}"
        done
    fi
}

case "${INPUT_TARGET:-}" in
    '')
        build
        target_dir="${target_dir}/${profile_directory}"
        ;;
    universal-apple-darwin)
        # Refs: https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary
        # multi-target builds requires 1.64
        if [[ "${rustc_minor_version}" -ge 64 ]]; then
            build --target aarch64-apple-darwin --target x86_64-apple-darwin
        else
            build --target aarch64-apple-darwin
            build --target x86_64-apple-darwin
        fi
        aarch64_target_dir="${target_dir}/aarch64-apple-darwin/${profile_directory}"
        x86_64_target_dir="${target_dir}/x86_64-apple-darwin/${profile_directory}"
        target_dir="${target_dir}/${target}/${profile_directory}"
        mkdir -p -- "${target_dir}"
        for bin_exe in "${bins[@]}"; do
            x lipo -create -output "${target_dir}/${bin_exe}" "${aarch64_target_dir}/${bin_exe}" "${x86_64_target_dir}/${bin_exe}"
        done
        ;;
    *)
        build --target "${zigbuild_target:-"${target}"}"
        target_dir="${target_dir}/${target}/${profile_directory}"
        ;;
esac

# Compress binaries with UPX
if [[ "${INPUT_UPX:-}" = "true" ]]; then
    compress_binaries() {
        for bin_exe in "${bins[@]}"; do
            x upx --best "${target_dir}/${bin_exe}"
        done
    }

    case "${host_os}" in
        windows)
            if ! type -P upx >/dev/null; then
                choco install upx -y
            fi
            compress_binaries
            ;;
        linux)
            if ! type -P upx >/dev/null; then
                sudo apt-get install -y upx-ucl
            fi
            compress_binaries
            ;;
        macos)
            # macOS is not currently supported by UPX
            ;;
        *)
            warn "UPX is not available on ${host_os}"
            ;;
    esac
fi

case "${host_os}" in
    macos)
        if type -P codesign >/dev/null; then
            do_codesign
        fi
        ;;
esac

if [[ "${INPUT_TAR/all/${platform}}" == "${platform}" ]] || [[ "${INPUT_ZIP/all/${platform}}" == "${platform}" ]]; then
    cwd=$(pwd)
    tmpdir=$(mktemp -d)
    mkdir -- "${tmpdir:?}/${archive}"
    if [[ -n "${bin_leading_dir}" ]]; then
        mkdir -p -- "${tmpdir}/${archive}/${bin_leading_dir}"/
        # TODO: %%/* is wrong if bin_leading_dir starts with /
        filenames=("${bin_leading_dir%%/*}")
    else
        filenames=("${bins[@]}")
    fi
    for bin_exe in "${bins[@]}"; do
        if [[ -n "${bin_leading_dir}" ]]; then
            x cp -- "${target_dir}/${bin_exe}" "${tmpdir}/${archive}/${bin_leading_dir}"/
        else
            x cp -- "${target_dir}/${bin_exe}" "${tmpdir}/${archive}"/
        fi
    done
    for include in ${includes[@]+"${includes[@]}"}; do
        x cp -r -- "${include}" "${tmpdir}/${archive}"/
        filenames+=("$(basename -- "${include}")")
    done
    pushd -- "${tmpdir}" >/dev/null
    if [[ -n "${leading_dir}" ]]; then
        # with leading directory
        #
        # /${archive}
        # /${archive}/${bins}
        # /${archive}/${includes}
        if [[ "${INPUT_TAR/all/${platform}}" == "${platform}" ]]; then
            assets+=("${archive}.tar.gz")

            if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
                printf 'tar=%s.tar.gz\n' "${archive}" >>"${GITHUB_OUTPUT}"
            else
                warn "GITHUB_OUTPUT is not set; skip setting the 'tar' output"
                printf 'tar: %s.tar.gz\n' "${archive}"
            fi

            x tar acf "${cwd}/${archive}.tar.gz" "${archive}"
        fi
        if [[ "${INPUT_ZIP/all/${platform}}" == "${platform}" ]]; then
            assets+=("${archive}.zip")

            if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
                printf 'zip=%s.zip\n' "${archive}" >>"${GITHUB_OUTPUT}"
            else
                warn "GITHUB_OUTPUT is not set; skip setting the 'zip' output"
                printf 'zip: %s.zip\n' "${archive}"
            fi

            if [[ "${platform}" == "unix" ]]; then
                x zip -r "${cwd}/${archive}.zip" "${archive}"
            else
                x 7z a "${cwd}/${archive}.zip" "${archive}"
            fi
        fi
    else
        # without leading directory
        #
        # /${bins}
        # /${includes}
        pushd -- "${archive}" >/dev/null
        if [[ "${INPUT_TAR/all/${platform}}" == "${platform}" ]]; then
            assets+=("${archive}.tar.gz")

            if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
                printf 'tar=%s.tar.gz\n' "${archive}" >>"${GITHUB_OUTPUT}"
            else
                warn "GITHUB_OUTPUT is not set; skip setting the 'tar' output"
                printf 'tar: %s.tar.gz\n' "${archive}"
            fi

            x tar acf "${cwd}/${archive}.tar.gz" "${filenames[@]}"
        fi
        if [[ "${INPUT_ZIP/all/${platform}}" == "${platform}" ]]; then
            assets+=("${archive}.zip")

            if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
                printf 'zip=%s.zip\n' "${archive}" >>"${GITHUB_OUTPUT}"
            else
                warn "GITHUB_OUTPUT is not set; skip setting the 'zip' output"
                printf 'zip: %s.zip\n' "${archive}"
            fi

            if [[ "${platform}" == "unix" ]]; then
                x zip -r "${cwd}/${archive}.zip" "${filenames[@]}"
            else
                x 7z a "${cwd}/${archive}.zip" "${filenames[@]}"
            fi
        fi
        popd >/dev/null
    fi
    popd >/dev/null
    rm -rf -- "${tmpdir:?}/${archive}"
fi

# Checksum of all assets except for .<checksum> files.
final_assets=("${assets[@]}")
for checksum in ${checksums[@]+"${checksums[@]}"}; do
    # TODO: Should we allow customizing the name of checksum files?
    if type -P "${checksum}sum" >/dev/null; then
        "${checksum}sum" "${assets[@]}" >"${archive}.${checksum}"
    else
        # GitHub-hosted macOS runner does not install GNU Coreutils by default.
        # https://github.com/actions/runner-images/issues/90
        case "${checksum}" in
            b2)
                bail "checksum for '${checksum}' requires '${checksum}sum' command; consider installing it"
                ;;
            sha*)
                if type -P shasum >/dev/null; then
                    shasum -a "${checksum#sha}" "${assets[@]}" >"${archive}.${checksum}"
                else
                    bail "checksum for '${checksum}' requires '${checksum}sum' or 'shasum' command; consider installing one of them"
                fi
                ;;
            md5)
                if type -P md5 >/dev/null; then
                    md5 "${assets[@]}" >"${archive}.${checksum}"
                else
                    bail "checksum for '${checksum}' requires '${checksum}sum' or 'md5' command; consider installing one of them"
                fi
                ;;
            *) bail "unrecognized 'checksum' input option '${checksum}'" ;;
        esac
    fi
    x cat -- "${archive}.${checksum}"

    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        printf '%s=%s.%s\n' "${checksum}" "${archive}" "${checksum}" >>"${GITHUB_OUTPUT}"
    else
        warn "GITHUB_OUTPUT is not set; skip setting the '${checksum}' output"
        printf '%s: %s.%s\n' "${checksum}" "${archive}" "${checksum}"
    fi

    final_assets+=("${archive}.${checksum}")
done

if [[ -n "${dry_run}" ]]; then
    info "skipped upload because action is running in dry-run mode"
    printf "tag: %s ('dry-run' if tag ref is not start with 'refs/tags/')\n" "${tag}"
    IFS=','
    printf 'assets: %s\n' "${final_assets[*]}"
    IFS=$'\n\t'
else
    # https://cli.github.com/manual/gh_release_upload
    GITHUB_TOKEN="${token}" retry gh release upload "${tag}" "${final_assets[@]}" --clobber
fi
