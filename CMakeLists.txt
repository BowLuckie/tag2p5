cmake_minimum_required(VERSION 3.16)

project(boxt VERSION 1.0 LANGUAGES C)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)

find_package(box2d REQUIRED)

add_executable(${PROJECT_NAME} main.c)

target_link_libraries(${PROJECT_NAME} PRIVATE box2d::box2d m)
