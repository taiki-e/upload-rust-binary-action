# upload-rust-binary-action

[![build status](https://img.shields.io/github/workflow/status/taiki-e/upload-rust-binary-action/CI/main?style=flat-square&logo=github)](https://github.com/taiki-e/upload-rust-binary-action/actions)

GitHub Action for building and uploading Rust binary to GitHub Releases.

- [Usage](#usage)
  - [Inputs](#inputs)
  - [Example workflow: Basic usage](#example-workflow-basic-usage)
  - [Example workflow: Basic usage (multiple platforms)](#example-workflow-basic-usage-multiple-platforms)
  - [Example workflow: Customize archive name](#example-workflow-customize-archive-name)
  - [Example workflow: Build with different features on different platforms](#example-workflow-build-with-different-features-on-different-platforms)
  - [Example workflow: Cross-compilation](#example-workflow-cross-compilation)
  - [Other examples](#other-examples)
  - [Optimize Rust binary](#optimize-rust-binary)
- [Related Projects](#related-projects)
- [License](#license)

## Usage

This action builds and uploads Rust binary that specified by `bin` option to
GitHub Releases.

Currently, this action is basically intended to be used in combination with an action like [create-gh-release-action] that creates a GitHub release when a tag is pushed.

### Inputs

| Name       | Required | Description                                                                      | Type   | Default        |
|------------|:--------:|----------------------------------------------------------------------------------|--------|----------------|
| bin        | **true** | Binary name (non-extension portion of filename) to build and upload              | String |                |
| archive    | false    | Archive name (non-extension portion of filename) to be uploaded                  | String | `$bin-$target` |
| target     | false    | Target triple, default is host triple                                            | String | (host triple)  |
| features   | false    | Comma separated list of cargo build features to enable                           | String |                |
| tar        | false    | On which platform to distribute the `.tar.gz` file (all, unix, windows, or none) | String | `unix`         |
| zip        | false    | On which platform to distribute the `.zip` file (all, unix, windows, or none)    | String | `windows`      |
| build-tool | false    | Tool to build binary (cargo or cross, see [cross-compilation example](#example-workflow-cross-compilation) for more) | String |                |

### Example workflow: Basic usage

In this example, when a new tag is pushed, creating a new GitHub Release by
using [create-gh-release-action], then uploading Rust binary to the created
GitHub Release.

An archive file with a name like `$bin-$target.tar.gz` will be uploaded to
GitHub Release.

```yaml
name: Release

on:
  push:
    tags:
      - v[0-9]+.*

jobs:
  create-release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: taiki-e/create-gh-release-action@v1
        with:
          # (optional) Path to changelog.
          changelog: CHANGELOG.md
        env:
          # (required) GitHub token for creating GitHub Releases.
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  upload-assets:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: taiki-e/upload-rust-binary-action@v1
        with:
          # (required) Binary name (non-extension portion of filename) to build and upload.
          bin: ...
        env:
          # (required) GitHub token for uploading assets to GitHub Releases.
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Example workflow: Basic usage (multiple platforms)

This action supports Linux, macOS, and Windows as a host OS and supports
binaries for various targets.

```yaml
name: Release

on:
  push:
    tags:
      - v[0-9]+.*

jobs:
  create-release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: taiki-e/create-gh-release-action@v1
        with:
          # (optional)
          changelog: CHANGELOG.md
        env:
          # (required)
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  upload-assets:
    strategy:
      matrix:
        os:
          - ubuntu-latest
          - macos-latest
          - windows-latest
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v3
      - uses: taiki-e/upload-rust-binary-action@v1
        with:
          # (required)
          bin: ...
          # (optional) On which platform to distribute the `.tar.gz` file.
          # [default value: unix]
          # [possible values: all, unix, windows, none]
          tar: unix
          # (optional) On which platform to distribute the `.zip` file.
          # [default value: windows]
          # [possible values: all, unix, windows, none]
          zip: windows
        env:
          # (required)
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Example workflow: Customize archive name

By default, this action will upload an archive file with a name like
`$bin-$target.$extension`.

You can customize archive name by `archive` option.

```yaml
name: Release

on:
  push:
    tags:
      - v[0-9]+.*

jobs:
  create-release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: taiki-e/create-gh-release-action@v1
        with:
          # (optional)
          changelog: CHANGELOG.md
        env:
          # (required)
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  upload-assets:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: taiki-e/upload-rust-binary-action@v1
        with:
          bin: ...
          # (optional) Archive name (non-extension portion of filename) to be uploaded.
          # [default value: $bin-$target]
          # [possible values: the following variables and any string]
          #   variables:
          #     - $bin - Binary name (non-extension portion of filename).
          #     - $target - Target triple.
          #     - $tag - Tag of this release.
          archive: $bin-$tag-$target
        env:
          # (required)
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Example workflow: Build with different features on different platforms

This action enables the `systemd` and `io_uring` features for Linux, and leave macOS, and Windows with default set of features.

```yaml
name: Release

on:
  push:
    tags:
      - v[0-9]+.*

jobs:
  create-release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: taiki-e/create-gh-release-action@v1
        with:
          # (optional)
          changelog: CHANGELOG.md
        env:
          # (required)
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  upload-assets:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        include:
          - os: ubuntu-latest
            features: systemd,io_uring
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v3
      - uses: taiki-e/upload-rust-binary-action@v1
        with:
          # (required)
          bin: ...
          # (optional) On which platform to distribute the `.tar.gz` file.
          # [default value: unix]
          # [possible values: all, unix, windows, none]
          tar: unix
          # (optional) On which platform to distribute the `.zip` file.
          # [default value: windows]
          # [possible values: all, unix, windows, none]
          zip: windows
          # (optional) Build with the given set of features if any.
          features: ${{ matrix.features || '' }}
        env:
          # (required)
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Example workflow: Cross-compilation

By default, this action uses [cross] for cross-compilation (if cross supports that target). In the following example, only aarch64-unknown-linux-gnu uses cross, the rest use cargo.

```yaml
name: Release

on:
  push:
    tags:
      - v[0-9]+.*

jobs:
  create-release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: taiki-e/create-gh-release-action@v1
        with:
          # (optional)
          changelog: CHANGELOG.md
        env:
          # (required)
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  upload-assets:
    strategy:
      matrix:
        include:
          - target: aarch64-unknown-linux-gnu
            os: ubuntu-latest
          - target: aarch64-apple-darwin
            os: macos-latest
          - target: x86_64-unknown-linux-gnu
            os: ubuntu-latest
          - target: x86_64-apple-darwin
            os: macos-latest
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v3
      - uses: taiki-e/upload-rust-binary-action@v1
        with:
          # (required)
          bin: ...
          # (optional) Target triple, default is host triple.
          target: ${{ matrix.target }}
        env:
          # (required)
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

However, if the host has another cross-compilation setup, it will be respected.
The following is an example using [setup-cross-toolchain-action]. In this example, this action uses cargo for all targets.

```yaml
name: Release

on:
  push:
    tags:
      - v[0-9]+.*

jobs:
  create-release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: taiki-e/create-gh-release-action@v1
        with:
          # (optional)
          changelog: CHANGELOG.md
        env:
          # (required)
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  upload-assets:
    strategy:
      matrix:
        include:
          - target: aarch64-unknown-linux-gnu
            os: ubuntu-latest
          - target: aarch64-apple-darwin
            os: macos-latest
          - target: x86_64-unknown-linux-gnu
            os: ubuntu-latest
          - target: x86_64-apple-darwin
            os: macos-latest
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v3
      - name: Install cross-compilation tools
        uses: taiki-e/setup-cross-toolchain-action@v1
        with:
          target: ${{ matrix.target }}
        if: startsWith(matrix.os, 'ubuntu')
      - uses: taiki-e/upload-rust-binary-action@v1
        with:
          # (required)
          bin: ...
          # (optional) Target triple, default is host triple.
          target: ${{ matrix.target }}
        env:
          # (required)
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Other examples

- [cargo-hack/.github/workflows/release.yml](https://github.com/taiki-e/cargo-hack/blob/5d629a8e4b869215acbd55250f078eb211d2337b/.github/workflows/release.yml#L38-L66)
- [urdf-viz/.github/workflows/release.yml](https://github.com/openrr/urdf-viz/blob/d6f16cbdda66a54a55ac2f14ac0c69819127b2d4/.github/workflows/release.yml#L37-L58)

### Optimize Rust binary

You can optimize Rust binaries by passing the profile options.
The profile options can be specified by [`[profile]` table in `Cargo.toml`](https://doc.rust-lang.org/cargo/reference/profiles.html), [cargo config](https://doc.rust-lang.org/cargo/reference/config.html), [environment variables](https://doc.rust-lang.org/cargo/reference/environment-variables.html#configuration-environment-variables), etc.

The followings are examples of using environment variables to specify profile options:

- [lto](https://doc.rust-lang.org/cargo/reference/config.html#profilenamelto)

  ```yaml
  env:
    CARGO_PROFILE_RELEASE_LTO: true
  ```

- [codegen-units](https://doc.rust-lang.org/cargo/reference/config.html#profilenamecodegen-units)

  ```yaml
  env:
    CARGO_PROFILE_RELEASE_CODEGEN_UNITS: 1
  ```

**Note:** These options may increase the build time.

## Related Projects

- [create-gh-release-action]: GitHub Action for creating GitHub Releases based on changelog.

[create-gh-release-action]: https://github.com/taiki-e/create-gh-release-action
[cross]: https://github.com/cross-rs/cross
[setup-cross-toolchain-action]: https://github.com/taiki-e/setup-cross-toolchain-action

## License

Licensed under either of [Apache License, Version 2.0](LICENSE-APACHE) or
[MIT license](LICENSE-MIT) at your option.

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you, as defined in the Apache-2.0 license, shall
be dual licensed as above, without any additional terms or conditions.
