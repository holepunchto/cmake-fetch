# cmake-fetch

Minimal package manager for CMake based on [`FetchContent`](https://cmake.org/cmake/help/latest/module/FetchContent.html).

```
npm i cmake-fetch
```

```cmake
find_package(cmake-fetch REQUIRED PATHS node_modules/cmake-fetch)
```

## API

#### `fetch_package(<specifier> [SOURCE_DIR <var>] [BINARY_DIR <var>])`

## License

Apache-2.0
