# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org).

<!--
Note: In this file, do not use the hard wrap in the middle of a sentence for compatibility with GitHub comment style markdown rendering.
-->

## [Unreleased]

## [1.16.0] - 2023-08-06

- Support [cargo-zigbuild](https://github.com/rust-cross/cargo-zigbuild) as build tool. ([#50](https://github.com/taiki-e/upload-rust-binary-action/pull/50))

## [1.15.0] - 2023-06-26

- Use [multi-target builds](https://blog.rust-lang.org/2022/09/22/Rust-1.64.0.html#cargo-improvements-workspace-inheritance-and-multi-target-builds) for `universal-apple-darwin` (universal macOS binary) on Rust 1.64+. This could make `universal-apple-darwin` builds up to about 2x faster.

## [1.14.0] - 2023-05-13

- Add `profile` input option to allow specifying custom profiles. ([#44](https://github.com/taiki-e/upload-rust-binary-action/pull/44), thanks @afnanenayet)

## [1.13.0] - 2023-03-22

- Switch to composite action ([#42](https://github.com/taiki-e/upload-rust-binary-action/pull/42))

## [1.12.1] - 2023-03-19

- Diagnostics improvements.

## [1.12.0] - 2023-01-10

- Support universal macOS binary as `target: universal-apple-darwin`. ([#38](https://github.com/taiki-e/upload-rust-binary-action/pull/38))

## [1.11.1] - 2022-12-28

- Fix installation of cross.

- Improve support for stripping.

## [1.11.0] - 2022-12-03

- Skip stripping by this action if cargo's [`strip` profile option](https://doc.rust-lang.org/cargo/reference/profiles.html#strip) is set.

- Diagnostics improvements.

## [1.10.0] - 2022-10-28

- Add `manifest_path` input option. ([#32](https://github.com/taiki-e/upload-rust-binary-action/pull/32), thanks @GeorgeHahn)

## [1.9.1] - 2022-09-16

- Fix "command not found" error when `checksum` input option is passed on macOS. ([#30](https://github.com/taiki-e/upload-rust-binary-action/pull/30))

## [1.9.0] - 2022-09-08

- Add `token` input option to use the specified token instead of `GITHUB_TOKEN` environment variable.

- Add `ref` input option to use the specified tag ref instead of `GITHUB_REF` environment variable.

## [1.8.0] - 2022-08-28

- Add `no_default_features` input option. ([#28](https://github.com/taiki-e/upload-rust-binary-action/pull/28), thanks @samtay)

## [1.7.2] - 2022-07-08

- Fix regression introduced in 1.7.0.

## [1.7.1] - 2022-07-08

- Fix "no such file" error when `target` input option is passed.

## [1.7.0] - 2022-07-07

- Add `asset` input option to upload additional files separately. ([#23](https://github.com/taiki-e/upload-rust-binary-action/pull/23))

- `--target` flag no longer passed to cargo when `target` input option is not specified.

## [1.6.1] - 2022-07-06

- Fix unbound variable error on macOS.

## [1.6.0] - 2022-07-05

- Support building and uploading multiple binaries at the same step. ([#18](https://github.com/taiki-e/upload-rust-binary-action/pull/18))

- Add `checksum` input option to upload checksum. ([#21](https://github.com/taiki-e/upload-rust-binary-action/pull/21))

- Add `build_tool` input option to specify the tool to build binaries. ([#20](https://github.com/taiki-e/upload-rust-binary-action/pull/20))

## [1.5.0] - 2022-07-05

- Add `include` input option to include additional files to the archive. ([#17](https://github.com/taiki-e/upload-rust-binary-action/pull/17))

## [1.4.0] - 2022-06-08

- Respect host cross-compilation setup. ([#16](https://github.com/taiki-e/upload-rust-binary-action/pull/16))

## [1.3.0] - 2022-05-01

- Update default runtime to node16.

## [1.2.0] - 2021-12-30

- Skip the installation of `cross` if it is already installed.

  Previously, on Linux, if the target is different from the host and `cross` supports the target, `cross` was always installed.

## [1.1.0] - 2021-09-29

- Add `features` input option. ([#7](https://github.com/taiki-e/upload-rust-binary-action/pull/7), thanks @ririsoft)

- Fix strip error on non-x86 targets. ([#9](https://github.com/taiki-e/upload-rust-binary-action/pull/9))

## [1.0.2] - 2021-02-28

- Documentation improvements.

## [1.0.1] - 2021-02-12

- Pass `--noprofile` and `--norc` options to bash.

## [1.0.0] - 2021-02-03

Initial release

[Unreleased]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.16.0...HEAD
[1.16.0]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.15.0...v1.16.0
[1.15.0]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.14.0...v1.15.0
[1.14.0]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.13.0...v1.14.0
[1.13.0]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.12.1...v1.13.0
[1.12.1]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.12.0...v1.12.1
[1.12.0]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.11.1...v1.12.0
[1.11.1]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.11.0...v1.11.1
[1.11.0]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.10.0...v1.11.0
[1.10.0]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.9.1...v1.10.0
[1.9.1]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.9.0...v1.9.1
[1.9.0]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.8.0...v1.9.0
[1.8.0]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.7.2...v1.8.0
[1.7.2]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.7.1...v1.7.2
[1.7.1]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.7.0...v1.7.1
[1.7.0]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.6.1...v1.7.0
[1.6.1]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.6.0...v1.6.1
[1.6.0]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.0.2...v1.1.0
[1.0.2]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/taiki-e/upload-rust-binary-action/releases/tag/v1.0.0
