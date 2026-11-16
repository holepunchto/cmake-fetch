cmake_minimum_required(VERSION 3.25)

find_package(cmake-fetch REQUIRED PATHS node_modules/cmake-fetch)

project(specifiers NONE)

function(expect_name specifier expected)
  parse_fetch_specifier("${specifier}" name args)

  if(NOT name STREQUAL expected)
    message(SEND_ERROR "${specifier}\n  expected name ${expected}\n  actual   name ${name}")
  endif()
endfunction()

function(expect_arg specifier key expected)
  parse_fetch_specifier("${specifier}" name args)

  list(FIND args "${key}" i)

  if(i EQUAL -1)
    message(SEND_ERROR "${specifier}\n  expected ${key} in args, got: ${args}")
    return()
  endif()

  math(EXPR i "${i} + 1")
  list(GET args ${i} actual)

  if(NOT actual STREQUAL expected)
    message(SEND_ERROR "${specifier}\n  expected ${key} ${expected}\n  actual   ${key} ${actual}")
  endif()
endfunction()

# ExternalProject repeats the name three levels deep, and Windows rejects paths
# over 260 characters by default, so the name has to stay bounded whatever the
# URL looks like.
function(expect_name_shorter_than specifier limit)
  parse_fetch_specifier("${specifier}" name args)

  string(LENGTH "${name}" length)

  if(NOT length LESS ${limit})
    message(SEND_ERROR "${specifier}\n  expected a name shorter than ${limit}, got ${length}: ${name}")
  endif()
endfunction()

expect_name("github:acme/widget" "github+acme+widget")
expect_arg("github:acme/widget" GIT_REPOSITORY "https://github.com/acme/widget.git")
expect_arg("github:acme/widget" GIT_TAG "main")
expect_arg("github:acme/widget#next" GIT_TAG "next")
expect_arg("github:acme/widget@1.2.3" GIT_TAG "v1.2.3")

# A commit cannot be fetched shallowly by name, so hashes turn shallow off.
expect_arg("github:acme/widget#v1.2.3" GIT_SHALLOW ON)
expect_arg("github:acme/widget#4f2a9c1" GIT_SHALLOW OFF)

expect_name("gitlab:acme/widget" "gitlab+acme+widget")
expect_arg("gitlab:acme/widget" GIT_REPOSITORY "https://gitlab.com/acme/widget.git")

expect_name("git:example.com/acme/widget" "git+example.com+acme+widget")
expect_arg("git:example.com/acme/widget" GIT_REPOSITORY "https://example.com/acme/widget.git")

expect_name("git:/path/to/widget.bundle" "git+bundle+widget")
expect_arg("git:/path/to/widget.bundle@1.2.3" GIT_TAG "v1.2.3")

expect_arg(
  "https://github.com/acme/widget/releases/download/v2.4.1/prebuilds.zip"
  URL
  "https://github.com/acme/widget/releases/download/v2.4.1/prebuilds.zip"
)

# The digest exists to make names deterministic and unique, so check both.
expect_name("https://example.com/pkg/prebuilds.zip" "https+prebuilds+a4ec4b51")

parse_fetch_specifier("https://example.com/pkg/v1/prebuilds.zip" one args)
parse_fetch_specifier("https://example.com/pkg/v2/prebuilds.zip" two args)

if(one STREQUAL two)
  message(SEND_ERROR "expected distinct names for distinct URLs, both gave ${one}")
endif()

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
