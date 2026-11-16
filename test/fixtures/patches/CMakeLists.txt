cmake_minimum_required(VERSION 3.25)

find_package(cmake-fetch REQUIRED PATHS node_modules/cmake-fetch)

include("${CMAKE_CURRENT_LIST_DIR}/../bundle.cmake")

project(patches C)

create_bundle("${CMAKE_CURRENT_LIST_DIR}/dep" "${CMAKE_CURRENT_BINARY_DIR}/dep.bundle")

fetch_package(
  "git:${CMAKE_CURRENT_BINARY_DIR}/dep.bundle@1.0.0"
  PATCHES
    patches/add-dep-patched.patch
)

add_executable(app)

target_sources(
  app
  PRIVATE
    main.c
)

target_link_libraries(
  app
  PRIVATE
    dep
)
