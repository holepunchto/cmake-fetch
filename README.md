# cmake-fetch

Minimal package manager for CMake based on [`FetchContent`](https://cmake.org/cmake/help/latest/module/FetchContent.html).

```
npm i cmake-fetch
```

```cmake
find_package(cmake-fetch REQUIRED PATHS node_modules/cmake-fetch)
```

## API

#### `parse_fetch_specifier(<specifier> <target> <args> [ASSET <name>] [VERSION <var>])`

Parse `<specifier>` into a `FetchContent` name, written to the `<target>` variable, and the arguments to declare it with, written to the `<args>` variable. See `fetch_package()` for the forms a specifier can take. `VERSION` writes the version of the specifier to `<var>`, or an empty string if it has none. `ASSET` fetches the release asset `<name>` instead of the repository for a `github:` specifier with a version, such as `<target>.tar.xz` from the `v<version>` release. Specifiers that are a URL ignore it.

#### `fetch_package(<specifier> [PACKAGE <name>] [SOURCE_SUBDIR <path>] [SOURCE_DIR <var>] [BINARY_DIR <var>] [PATCHES <path...>] [INSTALL])`

Fetch the package named by `<specifier>` and add it to the build with `FetchContent`. The specifier takes one of these forms:

- `github:<owner>/<repo>`, which clones the repository from GitHub.
- `gitlab:<owner>/<repo>`, which clones the repository from GitLab.
- `git:<host>/<path>`, which clones the repository at `https://<host>/<path>.git`.
- `git:<path>.bundle`, which clones a Git bundle. A relative path is resolved against the current source directory. Submodules aren't fetched.
- `https://<url>` or `http://<url>`, which downloads and extracts an archive.

A Git specifier may end with `#<ref>` to check out a branch, tag, or commit, or with `@<version>` to check out the `v<version>` tag. Versions may have any number of components, such as `@1.2.3` or `@1.2.3.4`. Without either, the `main` branch is checked out. Only the history needed for the checkout is fetched, except for a commit, which needs the full history.

```cmake
fetch_package("github:example/foo@1.2.3")
fetch_package("github:example/bar#next")
fetch_package("https://example.com/baz.tar.gz")
```

The package is added with `add_subdirectory()`, but excluded from `all`, so its targets are only built when something links them and aren't installed with the project. Pass `INSTALL` to build all of its targets and install it with the project instead, such as when an installed package of the project depends on it and should ship with it. The packages that it fetches itself are still excluded, unless it passes `INSTALL` too. A package is only added once, so the first call to fetch it decides. Pass `SOURCE_SUBDIR` if its `CMakeLists.txt` isn't at the root. `SOURCE_DIR` and `BINARY_DIR` write the source and build directories of the package to the given variables.

`PACKAGE` lets `find_package(<name>)` find the package in the build tree, such as when an installed package that depends on it is found later, for example with `fetch_prebuilds()`. It accepts the version of the specifier and later versions with the same major version, or any version if the specifier has none. The package must then also provide the targets that the installed package links, under the names its own installed package gives them. Packages that use `cmake-prelude` do all of this themselves, so `PACKAGE` is only needed for other packages.

`PATCHES` lists patches to apply to the package with `git apply`, in order, relative to the directory of the current list file. The applied patches are recorded, so when the list changes, only the patches that differ are reverted and applied again.

If the package has a `package.json`, its npm dependencies are installed before the patches are applied, without running install scripts. A `package-lock.json` that ships with the package is installed exactly, and no lockfile is written otherwise. When [Socket Firewall](https://socket.dev) is available as `sfw`, npm is run through it.

#### `fetch_prebuilds(<specifier> CHECKSUMS <path> PACKAGES <name...> [VERSION <version>] [INSTALL])`

Find the CMake packages in `PACKAGES`, and fetch an archive of prebuilds for the ones that aren't found. The archive must hold one or more install prefixes that `find_package()` can search, such as `<name>/lib/cmake/<name>/` or `lib/cmake/<name>/` at its root.

The specifier is either `github:<owner>/<repo>@<version>`, which fetches `<target>.tar.xz` from the `v<version>` release of the repository, or the URL of the archive. Packages are found with the version of a `github:` specifier, or with `VERSION` for a URL. The target is named the same way as by `bare_target()` from `cmake-bare`, such as `darwin-arm64` or `ios-arm64-simulator`, and is `<platform>-universal` when `CMAKE_OSX_ARCHITECTURES` lists several architectures.

`CHECKSUMS` is a file of SHA-256 checksums in the format written by `sha256sum`, such as a copy of the `SHA256SUMS` of a release. The archive is verified against the checksum of its file name, and configuration fails if there is none. To update the file, download it from the release, for example with `gh release download v<version> -R <owner>/<repo> -p SHA256SUMS -O <path>`.

Like `FetchContent`, the packages are first looked for with `find_package()`, so a package can be provided with `CMAKE_PREFIX_PATH` or `<name>_DIR` instead. Set `FETCHCONTENT_TRY_FIND_PACKAGE_MODE` to `NEVER` to always fetch the archive. Packages that aren't found are only looked for in the archive, and the dependencies they find are looked for there first.

Pass `INSTALL` to install the archive along with the project when it's fetched, which a package exported by the project needs to find its dependencies.

```cmake
fetch_prebuilds(
  "github:example/prebuilds@1.2.3"
  CHECKSUMS cmake/prebuilds.sha256
  PACKAGES foo bar
  INSTALL
)
```

## License

Apache-2.0
