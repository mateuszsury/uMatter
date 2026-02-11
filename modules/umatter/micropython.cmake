add_library(usermod_umatter INTERFACE)

target_sources(usermod_umatter INTERFACE
    ${CMAKE_CURRENT_LIST_DIR}/src/mod_umatter.c
    ${CMAKE_CURRENT_LIST_DIR}/src/mod_umatter_core.c
    ${CMAKE_CURRENT_LIST_DIR}/src/umatter_core_runtime.c
)

target_include_directories(usermod_umatter INTERFACE
    ${CMAKE_CURRENT_LIST_DIR}/include
)

target_link_libraries(usermod INTERFACE usermod_umatter)
