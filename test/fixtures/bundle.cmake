# Commits the contents of a directory to a fresh repository on `main`, tags it
# `v1.0.0`, and writes it to a Git bundle, so fixtures can fetch packages
# without touching the network. The commit dates are fixed to keep the commit
# hash, and with it the fetched checkout, stable across runs.
function(create_bundle source bundle)
  set(repo "${CMAKE_CURRENT_BINARY_DIR}/bundle")

  file(REMOVE_RECURSE "${repo}")
  file(COPY "${source}/" DESTINATION "${repo}")

  set(git
    ${CMAKE_COMMAND} -E env
      GIT_AUTHOR_DATE=2000-01-01T00:00:00Z
      GIT_COMMITTER_DATE=2000-01-01T00:00:00Z
    git
      -C "${repo}"
      -c user.name=cmake-fetch
      -c user.email=cmake-fetch@example.com
      -c commit.gpgsign=false
      -c tag.gpgsign=false
      -c core.autocrlf=false
  )

  execute_process(COMMAND ${git} init --quiet --initial-branch=main COMMAND_ERROR_IS_FATAL ANY)
  execute_process(COMMAND ${git} add . COMMAND_ERROR_IS_FATAL ANY)
  execute_process(COMMAND ${git} commit --quiet --message "Initial commit" COMMAND_ERROR_IS_FATAL ANY)
  execute_process(COMMAND ${git} tag v1.0.0 COMMAND_ERROR_IS_FATAL ANY)
  execute_process(COMMAND ${git} bundle create "${bundle}" --all ERROR_QUIET COMMAND_ERROR_IS_FATAL ANY)
endfunction()
