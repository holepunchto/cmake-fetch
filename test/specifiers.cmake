# Asserts what `parse_fetch_specifier` derives from each specifier form: the
# package name, which becomes directory names under `_deps` and the
# OVERRIDE_FIND_PACKAGE name, and the FetchContent arguments.
#
# Nothing here touches the network. Run with `cmake -P test/specifiers.cmake`.

cmake_minimum_required(VERSION 3.25)

include("${CMAKE_CURRENT_LIST_DIR}/../cmake-fetch.cmake")

set(failures 0)

function(expect_name specifier expected)
  parse_fetch_specifier("${specifier}" name args)

  if(NOT name STREQUAL expected)
    message(SEND_ERROR "${specifier}\n  expected name ${expected}\n  actual   name ${name}")
    math(EXPR failures "${failures} + 1")
    set(failures ${failures} PARENT_SCOPE)
  endif()
endfunction()

function(expect_arg specifier key expected)
  parse_fetch_specifier("${specifier}" name args)

  list(FIND args "${key}" i)

  if(i EQUAL -1)
    message(SEND_ERROR "${specifier}\n  expected ${key} in args, got: ${args}")
    math(EXPR failures "${failures} + 1")
    set(failures ${failures} PARENT_SCOPE)
    return()
  endif()

  math(EXPR i "${i} + 1")
  list(GET args ${i} actual)

  if(NOT actual STREQUAL expected)
    message(SEND_ERROR "${specifier}\n  expected ${key} ${expected}\n  actual   ${key} ${actual}")
    math(EXPR failures "${failures} + 1")
    set(failures ${failures} PARENT_SCOPE)
  endif()
endfunction()

# Names must stay short: ExternalProject repeats them three levels deep, and
# Windows rejects paths over 260 characters by default.
function(expect_name_shorter_than specifier limit)
  parse_fetch_specifier("${specifier}" name args)

  string(LENGTH "${name}" length)

  if(NOT length LESS ${limit})
    message(SEND_ERROR "${specifier}\n  expected a name shorter than ${limit}, got ${length}: ${name}")
    math(EXPR failures "${failures} + 1")
    set(failures ${failures} PARENT_SCOPE)
  endif()
endfunction()

# github / gitlab

expect_name("github:holepunchto/bare@1.31.1" "github+holepunchto+bare")
expect_arg("github:holepunchto/bare@1.31.1" GIT_REPOSITORY "https://github.com/holepunchto/bare.git")
expect_arg("github:holepunchto/bare@1.31.1" GIT_TAG "v1.31.1")
expect_arg("github:holepunchto/bare@1.31.1" GIT_SHALLOW ON)

expect_name("github:holepunchto/bare" "github+holepunchto+bare")
expect_arg("github:holepunchto/bare" GIT_TAG "main")

expect_arg("github:holepunchto/librpc#38deb71" GIT_TAG "38deb71")

# A hex ref cannot be fetched shallowly.
expect_arg("github:holepunchto/librpc#38deb71" GIT_SHALLOW OFF)
expect_arg("github:holepunchto/bare-kit#some-branch" GIT_SHALLOW ON)

expect_name("gitlab:group/project@2.0.0" "gitlab+group+project")
expect_arg("gitlab:group/project@2.0.0" GIT_REPOSITORY "https://gitlab.com/group/project.git")

expect_name("git:example.com/group/project@1.0.0" "git+example.com+group+project")
expect_arg("git:example.com/group/project@1.0.0" GIT_REPOSITORY "https://example.com/group/project.git")

# URLs

expect_arg(
  "https://github.com/holepunchto/bare-kit/releases/download/v2.4.1/prebuilds.zip"
  URL
  "https://github.com/holepunchto/bare-kit/releases/download/v2.4.1/prebuilds.zip"
)

expect_name("https://example.com/pkg/prebuilds.zip" "https+prebuilds+a4ec4b51")

# Same specifier, same name; different version, different name.
expect_name("https://example.com/pkg/prebuilds.zip" "https+prebuilds+a4ec4b51")

parse_fetch_specifier("https://example.com/pkg/v1/prebuilds.zip" one args)
parse_fetch_specifier("https://example.com/pkg/v2/prebuilds.zip" two args)

if(one STREQUAL two)
  message(SEND_ERROR "expected distinct names for distinct URLs, both gave ${one}")
  math(EXPR failures "${failures} + 1")
endif()

# The stem keeps the full version rather than stopping at the first dot.
expect_name_shorter_than("https://example.com/pkg/bare-kit-2.4.1.tar.gz" 40)
expect_name("https://example.com/pkg/bare-kit-2.4.1.tar.gz" "https+bare-kit-2.4.1.tar+8495d151")

# A query string belongs to neither the stem nor the name.
expect_name(
  "https://example.com/artifacts/download?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAEXAMPLE"
  "https+download+f25758d1"
)

# No last path segment to name it after.
expect_name("https://example.com/some/path/" "https+archive+5982a827")

# A long filename is clamped rather than passed through.
expect_name_shorter_than(
  "https://example.com/a/really-quite-long-artifact-filename-that-goes-on-and-on-forever.zip"
  48
)

if(failures GREATER 0)
  message(FATAL_ERROR "${failures} assertion(s) failed")
endif()

message(STATUS "specifiers: ok")
