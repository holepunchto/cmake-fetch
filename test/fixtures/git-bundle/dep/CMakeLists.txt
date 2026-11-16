cmake_minimum_required(VERSION 3.25)

project(dep C)

add_library(dep STATIC)

target_sources(
  dep
  PRIVATE
    dep.c
)

target_include_directories(
  dep
  PUBLIC
    .
)
