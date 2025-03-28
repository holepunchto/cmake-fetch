include_guard()

# Ensure that package search paths aren't rerooted when a toolchain defines a
# system root, such as when cross compiling for iOS and Android.
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)

set(fetch_module_dir "${CMAKE_CURRENT_LIST_DIR}")

include(FetchContent)

function(parse_fetch_specifier specifier target args)
  if(specifier MATCHES "^([A-Za-z0-9_]+):")
    set(protocol "${CMAKE_MATCH_1}")
  else()
    message(FATAL_ERROR "Invalid package specifier \"${specifier}\"")
  endif()

  if(protocol MATCHES "github")
    if(specifier MATCHES "^github:(@?[A-Za-z0-9_/-]+)(#[A-Z-a-z0-9_.-]+)?(@[0-9]+\.[0-9]+\.[0-9]+)?")
      set(package "${CMAKE_MATCH_1}")
      set(ref "${CMAKE_MATCH_2}")
      set(version "${CMAKE_MATCH_3}")
    else()
      message(FATAL_ERROR "Invalid package specifier \"${specifier}\"")
    endif()

    string(REGEX REPLACE "/" "+" escaped "${protocol}+${package}")

    set(${target} ${escaped} PARENT_SCOPE)

    if(version)
      string(REGEX REPLACE "@" "" tag "v${version}")
    elseif(ref)
      string(REGEX REPLACE "#" "" tag "${ref}")
    else()
      set(tag "main")
    endif()

    set(${args}
      GIT_REPOSITORY "https://github.com/${package}.git"
      GIT_TAG "${tag}"
      GIT_PROGRESS ON
      GIT_REMOTE_UPDATE_STRATEGY REBASE_CHECKOUT
      PARENT_SCOPE
    )
  elseif(protocol MATCHES "git")
    if(specifier MATCHES "^git:([^/]+)/([A-Za-z0-9_/-]+)(#[A-Z-a-z0-9_.-]+)?(@[0-9]+\.[0-9]+\.[0-9]+)?")
      set(host "${CMAKE_MATCH_1}")
      set(repo "${CMAKE_MATCH_2}")
      set(ref "${CMAKE_MATCH_3}")
      set(version "${CMAKE_MATCH_4}")
    else()
      message(FATAL_ERROR "Invalid package specifier \"${specifier}\"")
    endif()

    if(version)
      string(REGEX REPLACE "@" "" tag "v${version}")
    elseif(ref)
      string(REGEX REPLACE "#" "" tag "${ref}")
    else()
      set(tag "main")
    endif()

    string(REGEX REPLACE "/" "+" escaped "${protocol}+${host}+${repo}")

    set(${target} ${escaped} PARENT_SCOPE)

    set(${args}
      GIT_REPOSITORY "https://${host}/${repo}.git"
      GIT_TAG "${tag}"
      GIT_PROGRESS ON
      GIT_REMOTE_UPDATE_STRATEGY REBASE_CHECKOUT
      PARENT_SCOPE
    )
  elseif(protocol MATCHES "https?")
    if(specifier MATCHES "^https?://(.+)")
      set(resource "${CMAKE_MATCH_1}")
    else()
      message(FATAL_ERROR "Invalid package specifier \"${specifier}\"")
    endif()

    string(REGEX REPLACE "/" "+" escaped "${protocol}+${resource}")

    set(${target} ${escaped} PARENT_SCOPE)

    set(${args}
      URL "${specifier}"
      TLS_VERSION 1.2
      TLS_VERIFY ON
      PARENT_SCOPE
    )
  else()
    message(FATAL_ERROR "Unknown package protocol \"${protocol}\"")
  endif()
endfunction()

function(fetch_package specifier)
  set(one_value_keywords
    SOURCE_DIR
    BINARY_DIR
  )

  set(multi_value_keywords
    PATCHES
  )

  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "" "${one_value_keywords}" "${multi_value_keywords}"
  )

  list(TRANSFORM ARGV_PATCHES PREPEND "${CMAKE_CURRENT_LIST_DIR}/")

  list(JOIN ARGV_PATCHES "$<SEMICOLON>" patches)

  parse_fetch_specifier(${specifier} target args)

  FetchContent_Declare(
    ${target}
    ${args}
    PATCH_COMMAND ${CMAKE_COMMAND} -DPATCHES=${patches} -P "${fetch_module_dir}/patch.cmake"
    EXCLUDE_FROM_ALL ON
    OVERRIDE_FIND_PACKAGE
  )

  FetchContent_MakeAvailable(${target})

  FetchContent_GetProperties(
    ${target}
    SOURCE_DIR ${target}_SOURCE_DIR
    BINARY_DIR ${target}_BINARY_DIR
  )

  if(DEFINED ARGV_SOURCE_DIR)
    set(${ARGV_SOURCE_DIR} ${${target}_SOURCE_DIR})
  endif()

  if(DEFINED ARGV_BINARY_DIR)
    set(${ARGV_BINARY_DIR} ${${target}_BINARY_DIR})
  endif()

  return(PROPAGATE ${ARGV_SOURCE_DIR} ${ARGV_BINARY_DIR})
endfunction()
