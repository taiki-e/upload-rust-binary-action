# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org).

<!--
Note: In this file, do not use the hard wrap in the middle of a sentence for compatibility with GitHub comment style markdown rendering.
-->

## [Unreleased]

## [1.2.0] - 2021-12-30

- Skip the installation of `cross` if it is already installed.

  Previously, on Linux, if the target is different from the host and `cross` supports the target, `cross` was always installed.

## [1.1.0] - 2021-09-29

- [Add `features` input option.](https://github.com/taiki-e/upload-rust-binary-action/pull/7)

- [Fix strip error on non-x86 targets.](https://github.com/taiki-e/upload-rust-binary-action/pull/9)

## [1.0.2] - 2021-02-28

- Documentation improvements.

## [1.0.1] - 2021-02-12

- Pass `--noprofile` and `--norc` options to bash.

## [1.0.0] - 2021-02-03

Initial release

[Unreleased]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.0.2...v1.1.0
[1.0.2]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/taiki-e/upload-rust-binary-action/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/taiki-e/upload-rust-binary-action/releases/tag/v1.0.0
