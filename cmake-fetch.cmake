include_guard()

set(fetch_module_dir "${CMAKE_CURRENT_LIST_DIR}")

include(FetchContent)

function(fetch_package specifier)
  set(one_value_keywords
    SOURCE_DIR
    BINARY_DIR
  )

  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "" "${one_value_keywords}" ""
  )

  if(specifier MATCHES "^([A-Za-z0-9_]+):(@?[A-Za-z0-9_/-]+)(#[A-Z-a-z0-9_.-]+)?(@[0-9]+\.[0-9]+\.[0-9]+)?")
    set(protocol "${CMAKE_MATCH_1}")
    set(package "${CMAKE_MATCH_2}")
    set(ref "${CMAKE_MATCH_3}")
    set(version "${CMAKE_MATCH_4}")
  else()
    message(FATAL_ERROR "Invalid package specifier \"${specifier}\"")
  endif()

  string(REGEX REPLACE "/" "+" target "${protocol}+${package}")

  if(protocol MATCHES "github")
    if(version)
      string(REGEX REPLACE "@" "" tag "v${version}")
    elseif(ref)
      string(REGEX REPLACE "#" "" tag "${ref}")
    else()
      set(tag "main")
    endif()

    set(args
      GIT_REPOSITORY "https://github.com/${package}.git"
      GIT_TAG "${tag}"
      GIT_REMOTE_UPDATE_STRATEGY REBASE_CHECKOUT
    )
  else()
    message(FATAL_ERROR "Unknown package protocol \"${protocol}\"")
  endif()

  FetchContent_Declare(
    ${target}
    ${args}
    PATCH_COMMAND ${CMAKE_COMMAND} -P "${fetch_module_dir}/patch.cmake"
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
