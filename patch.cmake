if(EXISTS "package.json")
  if(CMAKE_HOST_WIN32)
    find_program(
      npm
      NAMES npm.cmd npm
      REQUIRED
    )
  else()
    find_program(
      npm
      NAMES npm
      REQUIRED
    )
  endif()

  set(npm "${npm}")

  if(CMAKE_HOST_WIN32)
    find_program(
      sfw
      NAMES sfw.cmd sfw
    )
  else()
    find_program(
      sfw
      NAMES sfw
    )
  endif()

  if(NOT sfw MATCHES "NOTFOUND")
    set(npm "${sfw}" ${npm})
  endif()

  # Only a lockfile that ships with the package is trusted, so don't write one
  # that a later update of the package would disagree with.
  if(EXISTS "package-lock.json")
    set(install clean-install)
  else()
    set(install install --no-package-lock)
  endif()

  execute_process(
    COMMAND ${npm} ${install} --ignore-scripts --foreground-scripts --allow-git=none
    OUTPUT_QUIET
    RESULT_VARIABLE result
    ERROR_VARIABLE error
  )

  if(NOT result EQUAL 0)
    if(NOT sfw MATCHES "NOTFOUND")
      message(FATAL_ERROR "Dependencies could not be installed (via Socket Firewall): ${error}")
    else()
      message(FATAL_ERROR "Dependencies could not be installed: ${error}")
    endif()
  endif()
endif()

if(CMAKE_HOST_WIN32)
  find_program(
    git
    NAMES git.cmd git
    REQUIRED
  )
else()
  find_program(
    git
    NAMES git
    REQUIRED
  )
endif()

string(REPLACE "$<SEMICOLON>" ";" patches "${PATCHES}")

set(resolved)

foreach(patch IN LISTS patches)
  get_filename_component(patch "${patch}" REALPATH)

  list(APPEND resolved "${patch}")
endforeach()

set(patches ${resolved})

execute_process(
  COMMAND ${git} rev-parse --absolute-git-dir
  OUTPUT_VARIABLE git_dir
  OUTPUT_STRIP_TRAILING_WHITESPACE
  COMMAND_ERROR_IS_FATAL ANY
)

execute_process(
  COMMAND ${git} rev-parse HEAD
  OUTPUT_VARIABLE head
  OUTPUT_STRIP_TRAILING_WHITESPACE
  COMMAND_ERROR_IS_FATAL ANY
)

execute_process(
  COMMAND ${git} status --porcelain
  OUTPUT_VARIABLE changes
  COMMAND_ERROR_IS_FATAL ANY
)

# Applied patches are recorded in the Git directory along with the commit they
# were applied on top of. Diffing the record against the requested patches
# determines exactly which patches to revert and which to apply, rather than
# guessing from whether a patch happens to apply, which silently skips patches
# that no longer match the source.
set(state "${git_dir}/cmake-fetch/patches")

if(EXISTS "${state}/HEAD")
  file(READ "${state}/HEAD" base)
else()
  set(base "")
endif()

if(NOT base STREQUAL head OR changes STREQUAL "")
  file(REMOVE_RECURSE "${state}")
  file(MAKE_DIRECTORY "${state}")
  file(WRITE "${state}/HEAD" "${head}")
endif()

set(applied 0)

while(EXISTS "${state}/${applied}.patch")
  math(EXPR applied "${applied} + 1")
endwhile()

set(kept 0)

foreach(patch IN LISTS patches)
  if(kept EQUAL applied)
    break()
  endif()

  file(SHA256 "${patch}" expected)
  file(SHA256 "${state}/${kept}.patch" actual)

  if(NOT expected STREQUAL actual)
    break()
  endif()

  math(EXPR kept "${kept} + 1")
endforeach()

# Patches are reverted in the reverse order of application, which reliably
# undoes them even when several patches modify overlapping context.
while(applied GREATER kept)
  math(EXPR applied "${applied} - 1")

  execute_process(
    COMMAND ${git} apply --ignore-whitespace --reverse "${state}/${applied}.patch"
    OUTPUT_QUIET
    RESULT_VARIABLE result
    ERROR_VARIABLE error
  )

  if(NOT result EQUAL 0)
    message(FATAL_ERROR "Previously applied patch ${applied} could not be reverted: ${error}")
  endif()

  file(REMOVE "${state}/${applied}.patch")
endwhile()

foreach(patch IN LISTS patches)
  if(kept GREATER 0)
    math(EXPR kept "${kept} - 1")
    continue()
  endif()

  execute_process(
    COMMAND ${git} apply --ignore-whitespace "${patch}"
    OUTPUT_QUIET
    RESULT_VARIABLE result
    ERROR_VARIABLE error
  )

  if(NOT result EQUAL 0)
    message(FATAL_ERROR "Patch ${patch} was not applied: ${error}")
  endif()

  file(COPY_FILE "${patch}" "${state}/${applied}.patch")

  math(EXPR applied "${applied} + 1")
endforeach()
