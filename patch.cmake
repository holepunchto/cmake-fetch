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

  execute_process(
    COMMAND "${npm}" install
    COMMAND_ERROR_IS_FATAL ANY
  )
endif()
