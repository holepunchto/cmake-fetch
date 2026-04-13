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

  if(sfw MATCHES "NOTFOUND")
    set(npm "${npm}")
  else()
    set(npm "${sfw}" "${npm}")
  endif()

  if(EXISTS "package-lock.json")
    set(install clean-install)
  else()
    set(install install)
  endif()

  execute_process(
    COMMAND ${npm} ${install} --ignore-scripts --foreground-scripts --allow-git=none
    RESULT_VARIABLE result
    ERROR_VARIABLE error
    OUTPUT_QUIET
  )

  if(NOT result EQUAL 0)
    message(FATAL_ERROR "Dependencies could not be installed: ${error}")
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

  execute_process(
    COMMAND ${git} apply --ignore-whitespace "${patch}"
    RESULT_VARIABLE result
    ERROR_VARIABLE error
    OUTPUT_QUIET
  )

  if(NOT result EQUAL 0)
    execute_process(
      COMMAND ${git} apply --ignore-whitespace --check --reverse "${patch}"
      RESULT_VARIABLE result
      ERROR_VARIABLE error
      OUTPUT_QUIET
    )

    if(NOT result EQUAL 0)
      message(FATAL_ERROR "Patch ${patch} was not applied: ${error}")
    endif()
  endif()
endforeach()
