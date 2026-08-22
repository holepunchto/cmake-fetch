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

  if(EXISTS "package-lock.json")
    set(install clean-install)
  else()
    set(install install)
  endif()

  execute_process(
    COMMAND ${npm} ${install} --ignore-scripts --foreground-scripts --allow-git=none
    OUTPUT_QUIET
    RESULT_VARIABLE result
    ERROR_VARIABLE error
  )

  if(NOT result EQUAL 0)
    if(NOT sfw MATCHES "NOTFOUND")
      message(
        FATAL_ERROR
        "Dependencies could not be installed (via Socket Firewall): ${error}"
      )
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

foreach(patch IN LISTS patches)
  get_filename_component(patch "${patch}" REALPATH)

  # Only apply patches that still apply cleanly. A patch that no longer applies
  # is assumed to be applied already, which keeps patching idempotent across
  # reconfigures without reverting local modifications to the checkout. This is
  # also robust when several patches modify overlapping context, where
  # detecting an applied patch by reverse application is unreliable.
  execute_process(
    COMMAND ${git} apply --ignore-whitespace --check "${patch}"
    OUTPUT_QUIET
    ERROR_QUIET
    RESULT_VARIABLE result
  )

  if(result EQUAL 0)
    execute_process(
      COMMAND ${git} apply --ignore-whitespace "${patch}"
      OUTPUT_QUIET
      RESULT_VARIABLE result
      ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
      message(FATAL_ERROR "Patch ${patch} was not applied: ${error}")
    endif()
  endif()
endforeach()
