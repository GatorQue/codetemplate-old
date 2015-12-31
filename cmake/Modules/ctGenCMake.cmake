# Include the add dir CMake module
include(ctAddDir)

# ct_get_headers retrieves a list of C/C++ header (.h,.hh,.hpp,.hxx) files in
# the directory specified.
# Usage:
# ct_get_headers(_headers _dir)
#   _headers - List variable to store header files (.h,.hh,.hpp,.hxx) found in _dir
#   _dir     - Directory to search for header files in
#   _rdir    - Relative directory to retrieve header file path from
macro(ct_get_headers _headers _dir _rdir)
  file(GLOB _h RELATIVE ${_rdir} ${_dir}/*.h)
  file(GLOB _hh RELATIVE ${_rdir} ${_dir}/*.hh)
  file(GLOB _hpp RELATIVE ${_rdir} ${_dir}/*.hpp)
  file(GLOB _hxx RELATIVE ${_rdir} ${_dir}/*.hxx)
  list(APPEND ${_headers} ${_h} ${_hh} ${_hpp} ${_hxx})
endmacro()

# ct_get_headers_tree recursively retrieves a list of C/C++ source files in
# the directory specified.
# Usage:
# ct_get_headers_tree(_headers _dir)
#   _headers - List variable to store header files (.h,.hh,.hpp,.hxx) found in _dir
#   _dir     - Directory to search for header files in
#   _rdir    - Relative directory to retrieve header file path from
macro(ct_get_headers_tree _headers _dir _rdir)
  ct_get_headers(${_headers} ${_dir} ${_rdir})
  ct_get_subdirs(_subdirs ${_dir} ${_rdir})
  foreach(_subdir ${_subdirs})
    ct_get_headers(${_headers} ${_rdir}/${_dir}/${_subdir} ${_rdir})
  endforeach()
endmacro()

# ct_get_sources retrieves a list of C/C++ source (.c,.cc,.cpp,.cxx) files in
# the directory specified.
# Usage:
# ct_get_sources(_sources _dir)
#   _sources - List variable to store source files (.c,.cc,.cpp,.cxx) found in _dir
#   _dir     - Directory to search for source files in
#   _rdir    - Relative directory to retrieve source file path from
macro(ct_get_sources _sources _dir _rdir)
  file(GLOB _c RELATIVE ${_rdir} ${_dir}/*.c)
  file(GLOB _cc RELATIVE ${_rdir} ${_dir}/*.cc)
  file(GLOB _cpp RELATIVE ${_rdir} ${_dir}/*.cpp)
  file(GLOB _cxx RELATIVE ${_rdir} ${_dir}/*.cxx)
  list(APPEND ${_sources} ${_c} ${_cc} ${_cpp} ${_cxx})
endmacro()

# ct_get_sources_tree recursively retrieves a list of C/C++ source files in
# the directory specified.
# Usage:
# ct_get_sources_tree(_sources _dir)
#   _sources - List variable to store source files (.c,.cc,.cpp,.cxx) found in _dir
#   _dir     - Directory to recursively search for source files in
#   _rdir    - Relative directory to retrieve source file path from
macro(ct_get_sources_tree _sources _dir _rdir)
  ct_get_sources(${_sources} ${_dir} ${_rdir})
  ct_get_subdirs(_subdirs ${_dir} ${_rdir})
  foreach(_subdir ${_subdirs})
    ct_get_sources(${_sources} ${_rdir}/${_dir}/${_subdir} ${_rdir})
  endforeach()
endmacro()

# ct_filter_sources filters a list of C/C++ source files into libraries,
# applications (_main or main), and test executable (_test) sources according
# to the filenames used. The caller provides three variables that will be
# populated with the filtered files.
# Usage:
# ct_filter_sources(_libs _apps _tests _sources)
#   _libs    - List variable to store library C/C++ source files
#   _apps    - List variable to store application C/C++ source files (*_main or main)
#   _tests   - List variable to store test C/C++ source files (*_test or test)
#   _sources - C/C++ sources to filter into variables above
macro(ct_filter_sources _libs _apps _tests _sources)
  set(_lib_list)
  set(_app_list)
  set(_test_list)
  foreach(_source ${_sources})
    get_filename_component(_name ${_source} NAME_WE)
    if((_name MATCHES "^.*_main$") OR (_name STREQUAL "main"))
      list(APPEND _app_list ${_source})
    elseif((_name MATCHES "^.*_test$") OR (_name STREQUAL "test"))
      list(APPEND _test_list ${_source})
    else()
      list(APPEND _lib_list ${_source})
    endif()
  endforeach()
  set(${_libs} ${_lib_list})
  set(${_apps} ${_app_list})
  set(${_tests} ${_test_list})
endmacro()

# ct_gen_autotgt will generate a AutoTarget.cmake file in the binary directory
# provided and a CMakeLists.txt file in the source directory provided if it
# contains source files in the src or test subdirectories.
# Usage:
# ct_gen_autotgt(_sdir _bdir _target)
#   _sdir   - Root source directory to obtain source files from
#   _bdir   - Root binary directory to store AutoTarget.cmake file to
#   _target - Target to give library or application target created
macro(ct_gen_autotgt _sdir _bdir _target)
  include_directories(${_sdir}/include)
  # Clear headers and sources
  set(_headers)
  set(_sources)
  # Get public headers with include path
  ct_get_headers_tree(_headers ${_sdir}/include ${_sdir})
  # Get private headers in src subdirectory
  ct_get_headers_tree(_sources ${_sdir}/src ${_sdir})
  # Get source files in src subdirectory
  ct_get_sources_tree(_sources ${_sdir}/src ${_sdir})
  # Get source files in test subdirectory
  ct_get_sources_tree(_sources ${_sdir}/test ${_sdir})
  # Get private header files in current directory
  ct_get_headers(_sources ${_sdir} ${_sdir})
  # Get source files in current directory
  ct_get_sources(_sources ${_sdir} ${_sdir})

  # Categorize sources into a list of libraries, applications, and test
  # executables.
  set(_libs)
  set(_apps)
  set(_tests)
  ct_filter_sources(_libs _apps _tests "${_sources}")

  # Library sources found? then add library target to master list
  if(_libs)
    # Add library target to master list
    list(APPEND ALL_LIBS ${_target})

    # Define the directory to find include files for this target
    set(${_target}_AUTO_INCLUDE_DIR ${_sdir}/include)

    # Define the auto dependency as a link to ourselves
    set(${_target}_AUTO_DEPS ${_target})
  endif()

  # If source files were found then create AutoTargets.cmake and CMakeLists.txt
  if(_sources)
    set(_auto_target ${_target})
    # If the AutoTargets.cmake file doesn't exist then create one now
    message(STATUS "Creating '${_bdir}/Auto${_target}.cmake'")
    configure_file(${PROJECT_SOURCE_DIR}/cmake/AutoTarget.cmake.in
      ${_bdir}/Auto${_target}.cmake
      @ONLY)

    # If the CMakeLists.txt file doesn't exist then create one now
    if(NOT EXISTS ${_sdir}/CMakeLists.txt)
      message(STATUS "Creating '${_sdir}/CMakeLists.txt'")
      configure_file(${PROJECT_SOURCE_DIR}/cmake/CMakeLists.txt.in
        ${_sdir}/CMakeLists.txt
        @ONLY)
    endif()
  endif()
endmacro()

# ct_gen_autotgt_tree will generate a CMakeLists.txt file in every subdirectory
# of the directory specified that contains source files and any of their
# corresponding subdirectories as well. Essentially this is a recursive version
# of the ct_gen_autotgt method.
# Usage:
# ct_gen_autotgt_tree(_sdir _bdir _filter _target)
#   _sdir   - Source directory to obtain subdirectories from
#   _bdir   - Binary directory to obtain subdirectories from
#   _filter - List of subdirectories to skip over
#   _target - Target to give library or application target created
macro(ct_gen_autotgt_tree _sdir _bdir _filter _target)
  ct_gen_autotgt(${_sdir} ${_bdir} ${_target})
  ct_get_subdirs(_subdirs ${_sdir} ${_sdir})
  if(_subdirs)
    # Remove subdirs in filter list provided
    foreach(_subdir ${_filter})
      list(REMOVE_ITEM _subdirs ${_subdir})
    endforeach()
    # Recursively generate AutoTarget.cmake and CMakeLists.txt files for each subdir
    foreach(_subdir ${_subdirs})
      ct_gen_autotgt_tree(${_sdir}/${_subdir} ${_bdir} ${_filter} ${_subdir})
    endforeach()
  endif()
endmacro()

# ct_get_lib_deps retrieves a list of library dependencies for the C/C++ source
# file provided by looking for include paths and files that match those found
# within the project directory structure.
# Usage:
# ct_get_lib_deps(_lib_deps _source)
#   _lib_deps - Dependencies found in _source that should be linked
#   _source   - Source file to scan for dependencies
macro(ct_get_lib_deps _lib_deps _source)
  set(_lib_dep_list "")
  file(READ ${_source} _content)
  string(REGEX MATCHALL "#[ \t]*include[ \t]+[\"<][a-zA-Z0-9/.-]+[\">]" _includes ${_content})
  foreach(_include ${_includes})
    string(REGEX REPLACE "#[ \t]*include[ \t]+.([a-zA-Z0-9/.-]+)." "\\1" _include_file ${_include})
    # Check each target in all libs for include file
    foreach(_target ${ALL_LIBS})
      #message(STATUS "Searching for ${_include_file} to add ${_target}")
      if(EXISTS ${${_target}_AUTO_INCLUDE_DIR}/${_include_file})
        #message(STATUS "found")
        # Recursively check for dependencies in _include_file
        ct_get_lib_deps(${_lib_deps} ${${_target}_AUTO_INCLUDE_DIR}/${_include_file})
        # Add this libraries dependencies
        if(${_target}_AUTO_DEPS)
          list(APPEND _lib_dep_list ${${_target}_AUTO_DEPS})
        endif()
      endif()
    endforeach()
  endforeach()
  list(APPEND ${_lib_deps} ${_lib_dep_list})
endmacro()

# ct_gen_autodeps will generate a AutoDeps.cmake file in every subdirectory of
# the directory specified if it contains source files.
# Usage:
# ct_gen_autodeps(_sdir _bdir _target)
#   _sdir   - Root source directory to obtain source files from
#   _bdir   - Root binary directory to store AutoTarget.cmake file to
#   _target - Target to give library or application target created
macro(ct_gen_autodeps _sdir _bdir _target)
  # Clear sources
  set(_sources)
  # Get source files in src subdirectory
  ct_get_sources_tree(_sources ${_sdir}/src ${_sdir})
  # Get source files in test subdirectory
  ct_get_sources_tree(_sources ${_sdir}/test ${_sdir})
  # Get source files in current directory
  ct_get_sources(_sources ${_sdir} ${_sdir})

  # Categorize sources into a list of libraries, applications, and test
  # executables.
  set(_libs)
  set(_apps)
  set(_tests)
  ct_filter_sources(_libs _apps _tests "${_sources}")

  # Find the application library dependencies
  set(_apps_libs)
  foreach(_app ${_apps})
    get_filename_component(_name ${_app} NAME_WE)
    set(_lib_deps)
    ct_get_lib_deps(_lib_deps ${_sdir}/${_app})
    list(REMOVE_DUPLICATES _lib_deps)
    if(_lib_deps)
      list(APPEND _apps_libs "set(${_name}_LIBS ${_lib_deps})")
    endif()
  endforeach()

  # Find the test executable dependencies
  set(_tests_libs)
  foreach(_test ${_tests})
    get_filename_component(_name ${_test} NAME_WE)
    set(_lib_deps)
    ct_get_lib_deps(_lib_deps ${_sdir}/${_test})
    list(REMOVE_DUPLICATES _lib_deps)
    if(_lib_deps)
      list(APPEND _tests_libs "set(${_name}_LIBS ${_lib_deps})")
    endif()
  endforeach()

  # If source files were found then create AutoDeps.cmake
  if(_sources)
    # If the AutoDeps.cmake file doesn't exist then create one now
    message(STATUS "Creating '${_bdir}/Auto${_target}Deps.cmake'")
    configure_file(${PROJECT_SOURCE_DIR}/cmake/AutoTargetDeps.cmake.in
      ${_bdir}/Auto${_target}Deps.cmake
      @ONLY)
  endif()
endmacro()

# ct_gen_autodeps_tree will generate a AutoTargetDeps.cmake file in every
# subdirectory of the directory specified that contains source files and any of
# their corresponding subdirectories as well. Essentially this is a recursive
# version of the ct_gen_autodeps method.
# Usage:
# ct_gen_autodeps_tree(_sdir _bdir _filter _target)
#   _sdir   - Source directory to obtain subdirectories from
#   _bdir   - Binary directory to obtain subdirectories from
#   _filter - List of subdirectories to skip over
#   _target - Target to give library or application target created
macro(ct_gen_autodeps_tree _sdir _bdir _filter _target)
  ct_gen_autodeps(${_sdir} ${_bdir} ${_target})
  ct_get_subdirs(_subdirs ${_sdir} ${_sdir})
  if(_subdirs)
    # Remove subdirs in filter list provided
    foreach(_subdir ${_filter})
      list(REMOVE_ITEM _subdirs ${_subdir})
    endforeach()
    # Recursively generate AutoTargetDeps.cmake files for each subdir
    foreach(_subdir ${_subdirs})
      ct_gen_autodeps_tree(${_sdir}/${_subdir} ${_bdir} ${_filter} ${_subdir})
    endforeach()
  endif()
endmacro()

# ct_gen_cmake will generate the AutoTarget.cmake, AutoTargetDeps.cmake, and
# CMakeLists.txt files in every subdirectory of the directory specified that
# contains source files and any of their corresponding subdirectories as well.
# After generating these files, they will be added automatically to the
# project.
# Usage:
# ct_gen_cmake(_sdir)
#   _sdir   - Source directory to generate cmake files in/from
macro(ct_gen_cmake _sdir)
  # Specify a list of subdirectories to skip over during generation process
  set(_filter include inc src test)

  # Generate AutoTarget.cmake in project binary directory and CMakeLists.txt
  # file in sources directory (and its subdirectories) if it doesn't yet exist
  ct_gen_autotgt_tree(${_sdir} ${PROJECT_BINARY_DIR} ${_filter} ${PROJECT_NAME})

  # Generate AutoTargetDeps.cmake in project binary directory
  ct_gen_autodeps_tree(${_sdir} ${PROJECT_BINARY_DIR} ${_filter} ${PROJECT_NAME})

  # Add every subdirectory that contains a CMakeLists.txt file
  ct_add_subdirs(${_sdir})
endmacro()

# EOF
