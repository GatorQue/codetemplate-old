cmake_minimum_required(VERSION 2.8)

if(EPROJ_NAME)
  project(${EPROJ_NAME})
else()
  project(Project)
endif()
set(PROJECT_VERSION_MAJOR 1)
set(PROJECT_VERSION_MINOR 0)
set(PROJECT_VERSION_PATCH 0)
set(PROJECT_VERSION_TWEAK 0)
set(PROJECT_VERSION
  ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}.${PROJECT_VERSION_PATCH}.${PROJECT_VERSION_TWEAK})

# Add cmake/modules directory if it exists
if(EXISTS ${PROJECT_SOURCE_DIR}/cmake/Modules)
  set(CMAKE_MODULE_PATH ${PROJECT_SOURCE_DIR}/cmake/Modules ${CMAKE_MODULE_PATH})
endif()

# Now include CodeTemplate cmake module from CMAKE_MODULE_PATH
include(CodeTemplate)

# Generate CMakeLists.txt files in each source folder and add them to the
# CMake build process through a add_subdirectory call.
ct_gen_cmake(${PROJECT_SOURCE_DIR}/sources)

# Add overall coverage report target after adding all test targets
ct_add_coverage()