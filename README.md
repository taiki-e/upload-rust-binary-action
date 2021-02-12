# upload-rust-binary-action

GitHub Action for building and uploading Rust binary to GitHub Releases.

## Usage

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
      - uses: actions/checkout@v2
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
      - uses: actions/checkout@v2
      - uses: taiki-e/upload-rust-binary-action@v1
        with:
          # (required) Binary name (non-extension portion of filename) to build and upload.
          bin: ...
        env:
          # (required) GitHub token for uploading assets to GitHub Releases.
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          # (optional) Optimize the compiled binary.
          CARGO_PROFILE_RELEASE_LTO: true
```

### Example workflow: Basic usage (multiple platforms)

This action supports Linux, macOS, and Windows as a host OS and supports binaries for various targets.

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
      - uses: actions/checkout@v2
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
      - uses: actions/checkout@v2
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
          # (optional)
          CARGO_PROFILE_RELEASE_LTO: true
```

### Example workflow: Customize archive name

By default, this action will upload an archive file with a name like
`$bin-$target.$extension`.

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
      - uses: actions/checkout@v2
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
      - uses: actions/checkout@v2
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
          # (optional)
          CARGO_PROFILE_RELEASE_LTO: true
```

### Other examples

- [cargo-hack/.github/workflows/release.yml](https://github.com/taiki-e/cargo-hack/blob/5d629a8e4b869215acbd55250f078eb211d2337b/.github/workflows/release.yml#L38-L66)
- [parse-changelog/.github/workflows/release.yml](https://github.com/taiki-e/parse-changelog/blob/2440e0cf0ea09b2736bb02a6b39b1fa797cee99a/.github/workflows/release.yml#L38-L66)

## Configuration

| Input   | Required | Description                                                                      | Type   | Default        |
|---------|:--------:|----------------------------------------------------------------------------------|--------|----------------|
| bin     | **true** | Binary name (non-extension portion of filename) to build and upload              | String |                |
| archive | false    | Archive name (non-extension portion of filename) to be uploaded                  | String | `$bin-$target` |
| target  | false    | Target triple, default is host triple                                            | String | (host triple)  |
| tar     | false    | On which platform to distribute the `.tar.gz` file (all, unix, windows, or none) | String | `unix`         |
| zip     | false    | On which platform to distribute the `.zip` file (all, unix, windows, or none)    | String | `windows`      |

See [action.yml](action.yml) for more details.

[create-gh-release-action]: https://github.com/taiki-e/create-gh-release-action

## Related Projects

- [create-gh-release-action]: GitHub Action for creating GitHub Releases based on changelog.

## License

Licensed under either of [Apache License, Version 2.0](LICENSE-APACHE) or
[MIT license](LICENSE-MIT) at your option.

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you, as defined in the Apache-2.0 license, shall
be dual licensed as above, without any additional terms or conditions.
