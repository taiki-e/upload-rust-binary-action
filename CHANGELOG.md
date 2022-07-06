# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org).

<!--
Note: In this file, do not use the hard wrap in the middle of a sentence for compatibility with GitHub comment style markdown rendering.
-->

## [Unreleased]

- Fix unbound variable error on macOS.

## [1.6.0] - 2022-07-05

- Support building and uploading multiple binaries at the same step. ([#18](https://github.com/taiki-e/upload-rust-binary-action/pull/18))

- Add `checksum` input option to upload checksum. ([#21](https://github.com/taiki-e/upload-rust-binary-action/pull/21))

- Add `build_tool` input option to specify the tool to build binaries. ([#20](https://github.com/taiki-e/upload-rust-binary-action/pull/20))

## [1.5.0] - 2022-07-05

- Add `include` input option to include additional files. ([#17](https://github.com/taiki-e/upload-rust-binary-action/pull/17))

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

[Unreleased]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.6.0...HEAD
[1.6.0]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.0.2...v1.1.0
[1.0.2]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/taiki-e/upload-rust-binary-action/releases/tag/v1.0.0
