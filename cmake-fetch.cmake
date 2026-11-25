include_guard()

# Ensure that package search paths aren't rerooted when a toolchain defines a
# system root, such as when cross compiling for iOS and Android.
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)

set(fetch_module_dir "${CMAKE_CURRENT_LIST_DIR}")

include(FetchContent)

function(parse_fetch_specifier specifier target args)
  set(one_value_keywords
    ASSET
    VERSION
  )

  cmake_parse_arguments(
    PARSE_ARGV 3 ARGV "" "${one_value_keywords}" ""
  )

  cmake_language(GET_MESSAGE_LOG_LEVEL log_level)

  if(log_level MATCHES "STATUS|VERBOSE|DEBUG|TRACE")
    set(progress ON)
  else()
    set(progress OFF)
  endif()

  if(specifier MATCHES "^([A-Za-z0-9_]+):")
    set(protocol "${CMAKE_MATCH_1}")
  else()
    message(FATAL_ERROR "Invalid package specifier \"${specifier}\"")
  endif()

  if(protocol MATCHES "git(hub|lab)")
    if(specifier MATCHES "^git(hub|lab):(@?[A-Za-z0-9_./-]+)(#[A-Za-z0-9_./-]+)?(@[0-9]+(\.[0-9]+)*)?")
      set(package "${CMAKE_MATCH_2}")
      set(ref "${CMAKE_MATCH_3}")
      set(version "${CMAKE_MATCH_4}")
    else()
      message(FATAL_ERROR "Invalid package specifier \"${specifier}\"")
    endif()

    if(DEFINED ARGV_ASSET)
      if(NOT protocol STREQUAL "github" OR NOT version OR ref)
        message(FATAL_ERROR "Assets can only be fetched with a github: specifier that has a version, not \"${specifier}\"")
      endif()

      string(REGEX REPLACE "@" "" tag "v${version}")

      parse_fetch_specifier("https://github.com/${package}/releases/download/${tag}/${ARGV_ASSET}" asset_target asset_args)

      set(${target} ${asset_target} PARENT_SCOPE)
      set(${args} ${asset_args} PARENT_SCOPE)

      if(DEFINED ARGV_VERSION)
        string(REGEX REPLACE "@" "" ${ARGV_VERSION} "${version}")

        return(PROPAGATE ${ARGV_VERSION})
      endif()

      return()
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

    if(tag MATCHES "^[0-9a-f]+$")
      set(shallow OFF)
    else()
      set(shallow ON)
    endif()

    set(${args}
      GIT_REPOSITORY "https://${protocol}.com/${package}.git"
      GIT_TAG "${tag}"
      GIT_SHALLOW ${shallow}
      GIT_PROGRESS ${progress}
      GIT_REMOTE_UPDATE_STRATEGY REBASE_CHECKOUT
      PARENT_SCOPE
    )
  elseif(protocol MATCHES "git")
    if(specifier MATCHES "^git:(.+\\.bundle)(#[A-Za-z0-9_./-]+)?(@[0-9]+(\\.[0-9]+)*)?$")
      set(path "${CMAKE_MATCH_1}")
      set(ref "${CMAKE_MATCH_2}")
      set(version "${CMAKE_MATCH_3}")

      cmake_path(ABSOLUTE_PATH path BASE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" NORMALIZE)

      cmake_path(GET path STEM stem)

      string(REGEX REPLACE "/" "+" escaped "git+bundle+${stem}")

      set(${target} ${escaped} PARENT_SCOPE)

      if(version)
        string(REGEX REPLACE "@" "" tag "v${version}")
      elseif(ref)
        string(REGEX REPLACE "#" "" tag "${ref}")
      else()
        set(tag "main")
      endif()

      set(${args}
        GIT_REPOSITORY "${path}"
        GIT_TAG "${tag}"
        GIT_PROGRESS ${progress}
        GIT_CONFIG submodule.active=none
        PARENT_SCOPE
      )
    elseif(specifier MATCHES "^git:([^/]+)/([A-Za-z0-9_./-]+)(#[A-Za-z0-9_./-]+)?(@[0-9]+(\.[0-9]+)*)?")
      set(host "${CMAKE_MATCH_1}")
      set(repo "${CMAKE_MATCH_2}")
      set(ref "${CMAKE_MATCH_3}")
      set(version "${CMAKE_MATCH_4}")

      if(version)
        string(REGEX REPLACE "@" "" tag "v${version}")
      elseif(ref)
        string(REGEX REPLACE "#" "" tag "${ref}")
      else()
        set(tag "main")
      endif()

      if(tag MATCHES "^[0-9a-f]+$")
        set(shallow OFF)
      else()
        set(shallow ON)
      endif()

      string(REGEX REPLACE "/" "+" escaped "${protocol}+${host}+${repo}")

      set(${target} ${escaped} PARENT_SCOPE)

      set(${args}
        GIT_REPOSITORY "https://${host}/${repo}.git"
        GIT_TAG "${tag}"
        GIT_SHALLOW ${shallow}
        GIT_PROGRESS ${progress}
        GIT_REMOTE_UPDATE_STRATEGY REBASE_CHECKOUT
        PARENT_SCOPE
      )
    else()
      message(FATAL_ERROR "Invalid package specifier \"${specifier}\"")
    endif()
  elseif(protocol MATCHES "https?")
    if(specifier MATCHES "^https?://(.+)")
      set(resource "${CMAKE_MATCH_1}")
    else()
      message(FATAL_ERROR "Invalid package specifier \"${specifier}\"")
    endif()

    # Name the package after the resource's file stem plus a digest of the URL,
    # rather than escaping the whole URL. ExternalProject repeats this name three
    # levels deep, so a long one pushes paths past the 260 character limit on
    # Windows and the populate step never completes.
    string(REGEX REPLACE "[?#].*$" "" resource "${resource}")

    cmake_path(GET resource STEM LAST_ONLY stem)

    string(REGEX REPLACE "[^A-Za-z0-9_.-]" "-" stem "${stem}")

    if(stem STREQUAL "")
      set(stem "archive")
    endif()

    # Bound the stem too, or a long filename just moves the problem.
    string(SUBSTRING "${stem}" 0 24 stem)

    string(SHA256 digest "${specifier}")

    string(SUBSTRING "${digest}" 0 8 digest)

    set(${target} "${protocol}+${stem}+${digest}" PARENT_SCOPE)

    if(progress)
      set(no_progress OFF)
    else()
      set(no_progress ON)
    endif()

    set(${args}
      URL "${specifier}"
      TLS_VERSION 1.2
      TLS_VERIFY ON
      DOWNLOAD_NO_PROGRESS ${no_progress}
      PARENT_SCOPE
    )
  else()
    message(FATAL_ERROR "Unknown package protocol \"${protocol}\"")
  endif()

  if(DEFINED ARGV_VERSION)
    string(REGEX REPLACE "@" "" ${ARGV_VERSION} "${version}")

    return(PROPAGATE ${ARGV_VERSION})
  endif()
endfunction()

function(fetch_package specifier)
  set(one_value_keywords
    SOURCE_SUBDIR
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

  set(args)

  parse_fetch_specifier(${specifier} target args)

  if(DEFINED ARGV_SOURCE_SUBDIR)
    list(APPEND args SOURCE_SUBDIR "${ARGV_SOURCE_SUBDIR}")
  endif()

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

function(_fetch_platform result)
  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "HOST" "" ""
  )

  if(ARGV_HOST)
    set(platform ${CMAKE_HOST_SYSTEM_NAME})
  else()
    set(platform ${CMAKE_SYSTEM_NAME})

    if(NOT platform)
      set(platform ${CMAKE_HOST_SYSTEM_NAME})
    endif()
  endif()

  string(TOLOWER "${platform}" platform)

  if(platform MATCHES "darwin|ios|watchos|linux|android|wasi|freertos")
    set(${result} ${platform})
  elseif(platform MATCHES "windows")
    set(${result} "win32")
  else()
    set(${result} "unknown")
  endif()

  return(PROPAGATE ${result})
endfunction()

function(_fetch_arch result)
  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "HOST" "" ""
  )

  if(ARGV_HOST)
    set(arch ${CMAKE_HOST_SYSTEM_PROCESSOR})
  else()
    if(APPLE AND CMAKE_OSX_ARCHITECTURES)
      set(arch ${CMAKE_OSX_ARCHITECTURES})
    elseif(MSVC AND CMAKE_GENERATOR_PLATFORM)
      set(arch ${CMAKE_GENERATOR_PLATFORM})
    elseif(ANDROID AND CMAKE_ANDROID_ARCH_ABI)
      set(arch ${CMAKE_ANDROID_ARCH_ABI})
    else()
      set(arch ${CMAKE_SYSTEM_PROCESSOR})
    endif()

    if(NOT arch AND NOT CMAKE_CROSSCOMPILING)
      set(arch ${CMAKE_HOST_SYSTEM_PROCESSOR})
    endif()
  endif()

  list(LENGTH arch length)

  string(TOLOWER "${arch}" arch)

  if(length GREATER 1)
    set(${result} "universal")
  elseif(arch MATCHES "arm64_32")
    set(${result} "arm64-32")
  elseif(arch MATCHES "arm64|aarch64")
    set(${result} "arm64")
  elseif(arch MATCHES "armv8m")
    set(${result} "armv8m")
  elseif(arch MATCHES "armv7-a|armeabi-v7a")
    set(${result} "arm")
  elseif(arch MATCHES "x64|x86_64|amd64")
    set(${result} "x64")
  elseif(arch MATCHES "x86|i386|i486|i586|i686")
    set(${result} "ia32")
  elseif(arch MATCHES "riscv64")
    set(${result} "riscv64")
  elseif(arch MATCHES "riscv32")
    set(${result} "riscv32")
  elseif(arch MATCHES "mipsel")
    set(${result} "mipsel")
  elseif(arch MATCHES "mips(eb)?")
    set(${result} "mips")
  elseif(arch MATCHES "wasm32")
    set(${result} "wasm32")
  else()
    set(${result} "unknown")
  endif()

  return(PROPAGATE ${result})
endfunction()

function(_fetch_environment result)
  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "HOST" "" ""
  )

  set(environment "")

  if(NOT ARGV_HOST)
    if(APPLE AND CMAKE_OSX_SYSROOT MATCHES "iPhoneSimulator|WatchSimulator")
      set(environment "simulator")
    elseif(LINUX AND CMAKE_C_COMPILER_TARGET MATCHES "-linux-(musl(sf)?)")
      set(environment "${CMAKE_MATCH_1}")
    endif()
  endif()

  set(${result} ${environment})

  return(PROPAGATE ${result})
endfunction()

function(_fetch_target result)
  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "HOST" "" ""
  )

  if(ARGV_HOST)
    set(host HOST)
  else()
    set(host)
  endif()

  _fetch_platform(platform ${host})
  _fetch_arch(arch ${host})
  _fetch_environment(environment ${host})

  set(target ${platform}-${arch})

  if(environment)
    set(target ${target}-${environment})
  endif()

  set(${result} ${target})

  return(PROPAGATE ${result})
endfunction()

function(fetch_prebuilds specifier)
  set(one_value_keywords
    CHECKSUMS
    VERSION
  )

  set(multi_value_keywords
    PACKAGES
  )

  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "INSTALL" "${one_value_keywords}" "${multi_value_keywords}"
  )

  if(NOT ARGV_CHECKSUMS)
    message(FATAL_ERROR "fetch_prebuilds() requires CHECKSUMS")
  endif()

  if(NOT ARGV_PACKAGES)
    message(FATAL_ERROR "fetch_prebuilds() requires PACKAGES")
  endif()

  _fetch_target(target)

  parse_fetch_specifier(${specifier} name args ASSET ${target}.tar.xz VERSION version)

  cmake_parse_arguments(fetch "" "URL" "" ${args})

  if(NOT fetch_URL)
    message(FATAL_ERROR "Prebuilds must be fetched from a URL, not \"${specifier}\"")
  endif()

  if(NOT version)
    set(version ${ARGV_VERSION})
  endif()

  set(missing)

  foreach(package IN LISTS ARGV_PACKAGES)
    # A package found in an earlier fetch must not count as found already, or
    # the archive would never be fetched or installed again.
    if(${package}_DIR)
      cmake_path(IS_PREFIX FETCHCONTENT_BASE_DIR "${${package}_DIR}" NORMALIZE fetched)

      if(fetched)
        unset(${package}_DIR CACHE)
      endif()
    endif()

    if(NOT FETCHCONTENT_TRY_FIND_PACKAGE_MODE STREQUAL "NEVER")
      find_package(${package} ${version} CONFIG QUIET)
    endif()

    if(NOT ${package}_FOUND)
      list(APPEND missing ${package})
    endif()
  endforeach()

  if(NOT missing)
    return()
  endif()

  set(checksums "${ARGV_CHECKSUMS}")

  cmake_path(ABSOLUTE_PATH checksums BASE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" NORMALIZE)

  set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${checksums}")

  string(REGEX REPLACE "[?#].*$" "" file "${fetch_URL}")

  cmake_path(GET file FILENAME file)

  file(STRINGS "${checksums}" lines)

  set(hash)

  foreach(line IN LISTS lines)
    if(line MATCHES "^([0-9a-fA-F]+) [ *](.+)$" AND CMAKE_MATCH_2 STREQUAL file)
      string(LENGTH "${CMAKE_MATCH_1}" length)

      if(length EQUAL 64)
        set(hash ${CMAKE_MATCH_1})
      endif()
    endif()
  endforeach()

  if(NOT hash)
    message(FATAL_ERROR "There is no checksum for ${file} in ${checksums}")
  endif()

  FetchContent_Declare(
    ${name}
    ${args}
    URL_HASH SHA256=${hash}
  )

  FetchContent_MakeAvailable(${name})

  FetchContent_GetProperties(${name} SOURCE_DIR prefix)

  foreach(package IN LISTS missing)
    find_package(${package} ${version} CONFIG REQUIRED PATHS "${prefix}" NO_DEFAULT_PATH)
  endforeach()

  if(ARGV_INSTALL)
    install(DIRECTORY "${prefix}/" DESTINATION . USE_SOURCE_PERMISSIONS)
  endif()
endfunction()
