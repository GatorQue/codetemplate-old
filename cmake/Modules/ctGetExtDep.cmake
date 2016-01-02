# Include CMakeParseArguments macro for use below
include(CMakeParseArguments)

# Was a toolchain file provided? then use it for ExternalProject_Add
if(DEFINED CMAKE_TOOLCHAIN_FILE)
  set(USE_TOOLCHAIN_FILE CMAKE_CACHE_ARGS
      "-DCMAKE_TOOLCHAIN_FILE:Path=${CMAKE_TOOLCHAIN_FILE}")
endif()

# Define the __DOWNLOAD, __EXTRACT, __INSTALL, and __SOURCE variables for use below
set(__DOWNLOAD ${CMAKE_SOURCE_DIR}/third_party)
set(__EXTRACT ${CMAKE_SOURCE_DIR}/third_party)
if(CMAKE_BUILD_TYPE STREQUAL "")
  set(__INSTALL
      ${CMAKE_SOURCE_DIR}/third_party/${CMAKE_SYSTEM_PROCESSOR}/__default__)
else()
  set(__INSTALL
      ${CMAKE_SOURCE_DIR}/third_party/${CMAKE_SYSTEM_PROCESSOR}/${CMAKE_BUILD_TYPE})
endif()
set(__SOURCE ${CMAKE_BINARY_DIR}/third_party/src)
set(__PROJECT_SOURCE ${CMAKE_SOURCE_DIR}/third_party/src)

# ct_get_file will download the file specified to the directory provided.
# Usage:
# ct_get_file(_url _dir)
#   _url - URL and filename to download
#   _dir - Directory to put downloaded file (checks here first)
#   INACTIVITY_TIMEOUT [..] - Inactivity timeout value in seconds
#   MD5 [..] - MD5SUM value to use for verifying download
#   TIMEOUT [..] - Timeout for entire download to complete by in seconds
function(ct_get_file _url _dir)
  # Get filename component of URL provided
  get_filename_component(_filename ${_url} NAME)

  # Set options that have no arguments
  set(_options)
  # Set one value arguments
  set(_oneValueArgs INACTIVITY_TIMEOUT MD5 TIMEOUT)
  # Set multi value arguments
  set(_multiValueArgs)

  # Parse the arguments provided into categories
  cmake_parse_arguments(_ct "${_options}" "${_oneValueArgs}" "${_multiValueArgs}" ${ARGN})

  # If the file already exists verify the MD5 sum
  if(EXISTS ${_dir}/${_filename})
    file(MD5 ${_dir}/${_filename} _md5)
    if(_ct_MD5 AND _md5 STREQUAL _ct_MD5)
      # Download file verifies correct, skip download
      message(STATUS "Skipping download of '${_url}'")
      return()
    else()
      # Verify failed, remove the partial download file
      file(REMOVE ${_dir}/${_filename})
    endif()
  endif()

  # Create inactivity timeout argument
  if(_ct_INACTIVITY_TIMEOUT)
    set(_inactivity_args INACTIVITY_TIMEOUT ${_ct_INACTIVITY_TIMEOUT})
  endif()

  # Create download timeout argument
  if(_ct_TIMEOUT)
    set(_timeout_args TIMEOUT ${_ct_TIMEOUT})
  endif()

  # Create expected MD5 argument
  if(_ct_MD5)
    set(_timeout_args EXPECTED_MD5 ${_ct_MD5})
  endif()

  # Tell CMake to download the file
  message(STATUS "Downloading from '${_url}'")
  file(DOWNLOAD "${_url}" ${_dir}/${_filename}
      ${_inactivity_args}
      ${_timeout_args}
      ${_md5_args}
      STATUS _status
      LOG log)

  # Extract code and string result from _status
  list(GET _status 0 _result_code)
  list(GET _status 1 _result_string)

  # Check the result code
  if(NOT _result_code EQUAL 0)
    message(FATAL_ERROR "Bad download of '${_url}' (${_result_code}:${_result_string})")
  endif()

  # Inform the user that the download was successful
  message(STATUS "Download to '${_dir}/${_filename}' done")
endfunction()

# ct_extract_file will extract the file specified to the directory provided.
# Usage:
# ct_extract_file(_file _dir)
#   _file - Filename to extract
#   _dir - Directory to extract file to (removed if it already exists)
function(ct_extract_file _file _dir)
  # Make file name and directory absolute
  get_filename_component(_filename ${_file} ABSOLUTE)
  get_filename_component(_dir_abs ${_dir} ABSOLUTE)
  get_filename_component(_name ${_file} NAME_WE)

  if(NOT EXISTS ${_filename})
    message(FATAL_ERROR "Bad '${_file}' doesn't exist")
  endif()

  if(EXISTS ${_dir})
    message(STATUS "Extract to '${_dir}' skipped, already exists")
    return()
  endif()

  # See if filename ends in .bz2, .tar.gz, .tgz, or .zip
  if(_filename MATCHES "(\\.|=)(bz2|tar\\.gz|tgz|zip)$")
    set(_tar_args xfz)
  endif()

  # See if filename ends in .tar
  if(_filename MATCHES "(\\.|=)tar$")
    set(_tar_args xf)
  endif()

  if(_tar_args STREQUAL "")
    message(FATAL_ERROR "Bad '${_file}' type (not .bz2, .tar, .tar.gz, .tgz, or .zip)")
  endif()

  # Create extract dir if it doesn't yet exist
  if(NOT EXISTS ${__EXTRACT})
    file(MAKE_DIRECTORY ${__EXTRACT})
  endif()

  # Prepare a directory for extracting:
  set(i 1234)
  while(EXISTS "${__EXTRACT}/ex-${_name}${i}")
    math(EXPR i "${i} + 1")
  endwhile()
  set(_tmp_dir "${__EXTRACT}/ex-${_name}${i}")
  file(MAKE_DIRECTORY ${_tmp_dir})

  # Extract it:
  message(STATUS "Extracting from '${_file}'")
  execute_process(COMMAND ${CMAKE_COMMAND} -E tar ${_tar_args} ${_filename}
      WORKING_DIRECTORY ${_tmp_dir}
      RESULT_VARIABLE _result_code)

  if(NOT _result_code EQUAL 0)
    file(REMOVE_RECURSE "${_tmp_dir}")
    message(FATAL_ERROR "Bad extraction failed for '${_file}'")
  endif()

  # Analyze what came out of the tar file
  file(GLOB _files "${_tmp_dir}/*")
  list(LENGTH _files _count)
  if(NOT _count EQUAL 1 OR NOT IS_DIRECTORY ${_files})
    set(_files ${_tmp_dir})
  endif()

  # Move "the one" directory to the final directory:
  file(REMOVE_RECURSE ${_dir_abs})
  get_filename_component(_files ${_files} ABSOLUTE)
  file(RENAME ${_files} ${_dir_abs})

  # Clean up:
  file(REMOVE_RECURSE ${_tmp_dir})

  # Done:
  message(STATUS "Extract to '${_dir}' done")
endfunction()

# ct_get_git will clone a GIT repository to the directory specified.
# Usage:
# ct_get_git(_url _dir)
#   _url - URL of the repository to clone
#   _dir - Directory to clone repository to (checks here first)
#   REF  - Reference (tag/commit hash) to checkout
function(ct_get_git _url _dir)
  # Make directory absolute
  get_filename_component(_dir_abs ${_dir} ABSOLUTE)

  # Set options that have no arguments
  set(_options)
  # Set one value arguments
  set(_oneValueArgs REF)
  # Set multi value arguments
  set(_multiValueArgs)

  # Parse the arguments provided into categories
  cmake_parse_arguments(_ct "${_options}" "${_oneValueArgs}" "${_multiValueArgs}" ${ARGN})

  # Now find GIT executable
  find_package(Git QUIET)
  if(NOT GIT_EXECUTABLE)
    message(FATAL_ERROR "Bad git executable missing")
  else()
    # Verify the GIT version is > 1.6.5
    execute_process(
        COMMAND "${GIT_EXECUTABLE}" --version
        OUTPUT_VARIABLE _version
        OUTPUT_STRIP_TRAILING_WHITESPACE)
    string(REGEX REPLACE "^git version (.+)$" "\\1" GIT_VERSION "${_version}")
    if(GIT_VERSION VERSION_LESS 1.6.5)
      message(FATAL_ERROR "Bad git version '${GIT_VERSION}' (requires 1.6.5)")
    endif()
  endif()

  # Setup GIT repository information
  #set(module "")
  #configure_file(
  #    "${CMAKE_ROOT}/Modules/RepositoryInfo.txt.in"
  #    "${PROJECT_BINARY_DIR}/RepositoryInfo.txt"
  #    @ONLY)

  # If the clone directory doesn't exist, create it and perform the clone
  if(NOT EXISTS ${_dir_abs})
    message(STATUS "Cloning from '${_url}' to '${_dir}'")
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E make_directory ${_dir_abs}
        COMMAND ${GIT_EXECUTABLE} clone ${_url} ${_dir_abs}
        WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
        RESULT_VARIABLE _result_code)
    if(NOT _result_code EQUAL 0)
      message(FATAL_ERROR "Bad '${_url}' repository")
    endif()
  else()
    message(STATUS "Updating clone in '${_dir}'")
  endif()

  # Checkout reference specified
  if(_ct_REF)
    message(STATUS "Checking out '${_ct_REF}'")
    execute_process(
        COMMAND ${GIT_EXECUTABLE} checkout ${_ct_REF}
        WORKING_DIRECTORY ${_dir_abs}
        RESULT_VARIABLE _result_code)
    if(NOT _result_code EQUAL 0)
      message(FATAL_ERROR "Bad reference '${_ct_REF}'")
    endif()
  endif()

  # Perform update, submodule init, and submodule update steps
  execute_process(
      COMMAND ${GIT_EXECUTABLE} pull
      COMMAND ${GIT_EXECUTABLE} submodule init
      COMMAND ${GIT_EXECUTABLE} submodule update --recursive
      WORKING_DIRECTORY ${_dir_abs}
      RESULT_VARIABLE _result_code)
  if(NOT _result_code EQUAL 0)
    message(WARNING "Bad update in '${_dir_abs}'")
  endif()
endfunction()

# ct_get_hg will clone a Mercurial repository to the directory specified.
# Usage:
# ct_get_hg(_url _dir)
#   _url - URL of the repository to clone
#   _dir - Directory to clone repository to (checks here first)
#   REF  - Reference (tag/commit hash) to checkout
function(ct_get_hg _url _dir)
  # Make directory absolute
  get_filename_component(_dir_abs ${_dir} ABSOLUTE)

  # Set options that have no arguments
  set(_options)
  # Set one value arguments
  set(_oneValueArgs REF)
  # Set multi value arguments
  set(_multiValueArgs)

  # Parse the arguments provided into categories
  cmake_parse_arguments(_ct "${_options}" "${_oneValueArgs}" "${_multiValueArgs}" ${ARGN})

  # Find the mercurial executable
  find_package(Mercurial QUIET)
  if(NOT MERCURIAL_EXECUTABLE)
    message(FATAL_ERROR "Bad hg executable missing")
  endif()

  # Setup Mecurial repository information
  #set(module "")
  #configure_file(
  #    "${CMAKE_ROOT}/Modules/RepositoryInfo.txt.in"
  #    "${PROJECT_BINARY_DIR}/RepositoryInfo.txt"
  #    @ONLY)

  # If the clone directory doesn't exist, create it and perform the clone
  if(NOT EXISTS ${_dir_abs})
    message(STATUS "Cloning from '${_url}' to '${_dir}'")
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E make_directory ${_dir_abs}
        COMMAND ${MERCURIAL_EXECUTABLE} clone -U ${_url} ${_dir_abs}
        WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
        RESULT_VARIABLE _result_code)
    if(NOT _result_code EQUAL 0)
      message(FATAL_ERROR "Bad '${_url}' repository")
    endif()
  else()
    message(STATUS "Updating clone in '${_dir}'")
  endif()

  # Checkout reference specified
  if(_ct_REF)
    message(STATUS "Checking out '${_ct_REF}'")
    execute_process(
        COMMAND ${MERCURIAL_EXECUTABLE} update -r ${_ct_REF}
        WORKING_DIRECTORY ${_dir_abs}
        RESULT_VARIABLE _result_code)
    if(NOT _result_code EQUAL 0)
      message(FATAL_ERROR "Bad reference '${_ct_REF}'")
    endif()
  endif()

  # Perform update, submodule init, and submodule update steps
  execute_process(
      COMMAND ${MERCURIAL_EXECUTABLE} update -c
      WORKING_DIRECTORY ${_dir_abs}
      RESULT_VARIABLE _result_code)
  if(NOT _result_code EQUAL 0)
    message(WARNING "Bad update in '${_dir_abs}'")
  endif()
endfunction()

# ct_get_svn will clone a Subversion repository to the directory specified.
# Usage:
# ct_get_svn(_url _dir)
#   _url - URL of the repository to clone
#   _dir - Directory to clone repository to (checks here first)
#   REF  - Reference (tag/commit hash) to checkout
function(ct_get_svn _url _dir)
  # Make directory absolute
  get_filename_component(_dir_abs ${_dir} ABSOLUTE)

  # Set options that have no arguments
  set(_options)
  # Set one value arguments
  set(_oneValueArgs REF)
  # Set multi value arguments
  set(_multiValueArgs)

  # Parse the arguments provided into categories
  cmake_parse_arguments(_ct "${_options}" "${_oneValueArgs}" "${_multiValueArgs}" ${ARGN})

  # Use SVN reference/revision specified
  if(_ct_REF)
    set(_rev_args "--revision ${_ct_REF}")
  endif()

  # Look for Subversion executable
  find_package(Subversion QUIET)
  if(NOT Subversion_SVN_EXECUTABLE)
    message(FATAL_ERROR "Bad svn executable missing")
  endif()

  # Setup Subversion repository information
  #set(module "")
  #configure_file(
  #    "${CMAKE_ROOT}/Modules/RepositoryInfo.txt.in"
  #    "${PROJECT_BINARY_DIR}/RepositoryInfo.txt"
  #    @ONLY)

  # If the clone directory doesn't exist, create it and perform the clone
  if(NOT EXISTS ${_dir_abs})
    message(STATUS "Cloning from '${_url}' to '${_dir}'")
    execute_process(
        COMMAND ${Subversion_SVN_EXECUTABLE} co ${_url} ${_rev_args} --non-interactive ${_dir_abs}
        WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
        RESULT_VARIABLE _result_code)
    if(NOT _result_code EQUAL 0)
      message(FATAL_ERROR "Bad '${_url}' repository")
    endif()
  else()
    message(STATUS "Updating clone in '${_dir}'")
    execute_process(
        COMMAND ${Subversion_SVN_EXECUTABLE} update ${_rev_args}
        WORKING_DIRECTORY ${_dir_abs}
        RESULT_VARIABLE _result_code)
    if(NOT _result_code EQUAL 0)
      message(WARNING "Bad update in '${_dir_abs}'")
    endif()
  endif()
endfunction()

# ct_get_ext_dep will download and install an external dependency needed for a project.
# Usage:
# ct_get_ext_dep(_target)
#   _target - Target name for the external dependency being added
#   PACKAGE [..] - Find package name to attempt to use first
#   COMPONENTS [..] - Package components to attempt to find
#   ROOT_HINT_VAR [..] - Package root hint variable to use for find package if available
#   FOUND_VAR [..] - Package found variable to identify find package success
#   INCLUDE_DIR_VAR [..] - Package include dir variable
#   LIBS [.. ..] - One or more libraries provided by package
#   -- Download step options --
#   URL [..] - Download URL to filename
#   URL_MD5 [..] - Download MD5 sum to compare filename to
#   DOWNLOAD_DIR [..] - Download directory to download filename to
#   GIT_REPOSITORY [..] - URL to git repository to clone
#   GIT_TAG [..] - Git reference/commit hash/tag to checkout
#   HG_REPOSITORY [..] - URL to mercurial repository to clone
#   HG_TAG [..] - Mercurial branch name/commit id/tag to checkout
#   SVN_REPOSITORY [..] - URL to svn repository to checkout
#   SVN_REVISION [..] - SVN revision to checkout
#   -- Configure step options --
#   SOURCE_DIR [..] - Source dir to extract download to or clone to
#   BIN_DIR [..] - Binary dir to use for configure and build steps
#   CONFIGURE_COMMANDS [..] - Configure commands to perform configure step
#   -- Build step options --
#   BUILD_COMMANDS [..] - Build commands to perform build
#   -- Install step options --
#   INSTALL_DIR [..] - Install directory to install results into
#   INSTALL_COMMANDS [..] - Install commands to perform
macro(ct_get_ext_dep _target)
  # Set options that have no arguments
  set(_options)
  # Set one value arguments
  set(_oneValueArgs PACKAGE ROOT_HINT_VAR FOUND_VAR INCLUDE_DIR_VAR
      URL URL_MD5 DOWNLOAD_DIR GIT_REPOSITORY GIT_TAG HG_REPOSITORY HG_TAG
      SVN_REPOSITORY SVN_REVISION SOURCE_DIR BIN_DIR INSTALL_DIR)
  # Set multi value arguments
  set(_multiValueArgs COMPONENTS CONFIGURE_COMMANDS BUILD_COMMANDS INSTALL_COMMANDS LIBS)

  # Parse the arguments provided into categories
  cmake_parse_arguments(_ct "${_options}" "${_oneValueArgs}" "${_multiValueArgs}" ${ARGN})

  # Check for missing PACKAGE value
  if(NOT DEFINED _ct_PACKAGE)
    message(FATAL_ERROR "Bad PACKAGE value")
  endif()

  # Check for missing or invalid FOUND_VAR value
  if(NOT DEFINED _ct_FOUND_VAR)
    message(FATAL_ERROR "Bad FOUND_VAR value")
  endif()

  # DOWNLOAD_DIR not provided? then set it as __DOWNLOAD
  if(NOT DEFINED _ct_DOWNLOAD_DIR)
    set(_ct_DOWNLOAD_DIR ${__DOWNLOAD})
  endif()

  # SOURCE_DIR not provided? then set it as __SOURCE/_target
  if(NOT DEFINED _ct_SOURCE_DIR)
    set(_ct_SOURCE_DIR ${__SOURCE}/${_target})
  endif()

  # INSTALL_DIR not provided? then set it as __INSTALL/_target
  if(NOT DEFINED _ct_INSTALL_DIR)
    set(_ct_INSTALL_DIR ${__INSTALL}/${_target})
  endif()

  # Root hint variable provided? set to third_party install directory
  if(_ct_ROOT_HINT_VAR)
    set(${_ct_ROOT_HINT_VAR} ${_ct_INSTALL_DIR})
  endif()

  # Set _FIND_PACKAGE_ARGS value
  set(_FIND_PACKAGE_ARGS ${_ct_PACKAGE})
  if(_ct_COMPONENTS)
    set(_FIND_PACKAGE_ARGS ${_FIND_PACKAGE_ARGS} COMPONENTS ${_ct_COMPONENTS})
  endif()

  # Workaround Start
  ###########################################################################
  # Generate CMake script to call find_package to work around CMake bug
  # #15293 which isn't fixed until CMake 3.2.

  # Create and execute TestFind<Package>.cmake script
  configure_file(${PROJECT_CMAKE_DIR}/TestFindPackage.cmake
      ${PROJECT_BINARY_DIR}/TestFind${_ct_PACKAGE}.cmake
      @ONLY)
  execute_process(
      COMMAND ${CMAKE_COMMAND} -P ${PROJECT_BINARY_DIR}/TestFind${_ct_PACKAGE}.cmake
      WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
      RESULT_VARIABLE _result_code
      OUTPUT_FILE TestFind${_ct_PACKAGE}.log
      ERROR_FILE TestFind${_ct_PACKAGE}-error.log)
  ###########################################################################
  # Workaround End

  # Package not found? then attempt to retrieve it now
  if(NOT _result_code EQUAL 0)
    # Set variables used for string(CONFIGURE) of commands below
    set(DOWNLOAD_DIR ${_ct_DOWNLOAD_DIR})
    set(SOURCE_DIR ${_ct_SOURCE_DIR})
    set(INSTALL_DIR ${_ct_INSTALL_DIR})

    # Download URL options provided?
    if(_ct_URL)
      get_filename_component(_filename ${_ct_URL} NAME)
      set(DOWNLOAD_FILE ${DOWNLOAD_DIR}/${_filename})

      # Download the file to DOWNLOAD_DIR
      ct_get_file(${_ct_URL} ${_ct_DOWNLOAD_DIR} MD5 ${_ct_URL_MD5})

      # Extract the file to SOURCE_DIR (which we create now)
      if(NOT EXISTS ${_ct_SOURCE_DIR})
        file(MAKE_DIRECTORY ${_ct_SOURCE_DIR})
        ct_extract_file(${_ct_DOWNLOAD_DIR}/${_filename} ${_ct_SOURCE_DIR})
      endif()
    endif()

    # Git options provided?
    if(_ct_GIT_REPOSITORY)
      # Clone/update the repository
      ct_get_git(${_ct_GIT_REPOSITORY} ${_ct_SOURCE_DIR} REF ${_ct_GIT_TAG})
    endif()

    # Mercurial options provided?
    if(_ct_HG_REPOSITORY)
      # Clone/update the repository
      ct_get_hg(${_ct_HG_REPOSITORY} ${_ct_SOURCE_DIR} REF ${_ct_HG_TAG})
    endif()

    # SVN options provided?
    if(_ct_SVN_REPOSITORY)
      # Clone/update the repository
      ct_get_svn(${_ct_SVN_REPOSITORY} ${_ct_SOURCE_DIR} REF ${_ct_SVN_REVISION})
    endif()

    # Add CMake configure step if source dir includes CMakeLists.txt file
    if(EXISTS ${_ct_SOURCE_DIR}/CMakeLists.txt AND NOT _ct_CONFIGURE_COMMANDS)
      set(_ct_CONFIGURE_COMMANDS
          COMMAND ${CMAKE_COMMAND} "-GUnix Makefiles" \@SOURCE_DIR\@)
    elseif(EXISTS ${_ct_SOURCE_DIR}/configure AND NOT _ct_CONFIGURE_COMMANDS)
      set(_ct_CONFIGURE_COMMANDS COMMAND configure)
      set(_ct_BIN_DIR ${__SOURCE}/${_target})
    elseif(EXISTS ${_ct_SOURCE_DIR}/Makefile AND NOT _ct_CONFIGURE_COMMANDS)
      set(_ct_BIN_DIR ${__SOURCE}/${_target})
    endif()

    # BIN_DIR not provided? then set it as __SOURCE/_target-build
    if(NOT DEFINED _ct_BIN_DIR)
      set(_ct_BIN_DIR ${__SOURCE}/${_target}-build)
    endif()

    # Set BIN_DIR as ${_ct_BIN_DIR} defined above
    set(BIN_DIR ${_ct_BIN_DIR})

    # Configure commands provided? then perform them now
    if(_ct_CONFIGURE_COMMANDS)
      # TODO: Add check to see if build is already done
      # Configure _ct_CONFIGURE_COMMANDS variable
      string(CONFIGURE "${_ct_CONFIGURE_COMMANDS}" _CONFIGURE_COMMANDS @ONLY ESCAPE_QUOTES)

      # Create build directory and execute build steps
      file(MAKE_DIRECTORY ${_ct_BIN_DIR})
      execute_process(
          ${_CONFIGURE_COMMANDS}
          WORKING_DIRECTORY ${_ct_BIN_DIR}
          OUTPUT_FILE configure.log
          ERROR_FILE configure-error.log)
    endif()

    # Create build command if missing
    if(EXISTS ${_ct_BIN_DIR}/Makefile AND NOT _ct_BUILD_COMMANDS)
      set(_ct_BUILD_COMMANDS COMMAND make)
    endif()

    # Build commands provided? then perform them now
    if(_ct_BUILD_COMMANDS)
      # TODO: Add check to see if build is already done
      # Configure _ct_BUILD_COMMANDS variable
      string(CONFIGURE "${_ct_BUILD_COMMANDS}" _BUILD_COMMANDS @ONLY ESCAPE_QUOTES)

      # Create build directory and execute build steps
      file(MAKE_DIRECTORY ${_ct_BIN_DIR})
      execute_process(
          ${_BUILD_COMMANDS}
          WORKING_DIRECTORY ${_ct_BIN_DIR}
          OUTPUT_FILE build.log
          ERROR_FILE build-error.log)
    endif()

    # Create install command if missing
    if(EXISTS ${_ct_BIN_DIR}/Makefile AND NOT _ct_INSTALL_COMMANDS)
      set(_ct_INSTALL_COMMANDS COMMAND make DESTDIR=${_ct_INSTALL_DIR} install)
    endif()

    # Install commands provided? then perform them now
    if(_ct_INSTALL_COMMANDS)
      # TODO: Add check to see if install is already done
      # Configure _ct_INSTALL_COMMANDS variable
      string(CONFIGURE "${_ct_INSTALL_COMMANDS}" _INSTALL_COMMANDS @ONLY ESCAPE_QUOTES)

      # Create install directory and execute install steps from either the
      # build or source directory.
      file(MAKE_DIRECTORY ${_ct_INSTALL_DIR})
      if(_ct_BUILD_COMMANDS)
        execute_process(
            ${_INSTALL_COMMANDS}
            WORKING_DIRECTORY ${_ct_BIN_DIR}
            OUTPUT_FILE install.log
            ERROR_FILE install-error.log)
      else()
        execute_process(
            ${_INSTALL_COMMANDS}
            WORKING_DIRECTORY ${_ct_SOURCE_DIR}
            OUTPUT_FILE install.log
            ERROR_FILE install-error.log)
      endif()
    endif()
  endif()

  # Use package provided to find external dependency
  find_package(${_FIND_PACKAGE_ARGS})

  if(${_ct_FOUND_VAR})
    # Add the GTest include file directory
    include_directories(${${_ct_INCLUDE_DIR_VAR}})
  else()
    message(FATAL_ERROR "Bad external dependency '${_target}'")
  endif()

  # Add all libraries provided by this package to auto dependency list
  set(ALL_LIBS ${ALL_LIBS} ${_ct_LIBS})

  # Add auto include directory for each library added
  foreach(_lib ${_ct_LIBS})
    set(${_lib}_AUTO_INCLUDE_DIR ${${_ct_INCLUDE_DIR_VAR}})
  endforeach()

  # Cleanup variables set above
  foreach(_var ${_options})
    unset(${_var})
  endforeach()
  foreach(_var ${_oneValueArgs})
    unset(${_var})
  endforeach()
  foreach(_var ${_multiValueArgs})
    unset(${_var})
  endforeach()
endmacro()

# ct_get_cmake will retrieve and include an external CMake project
# (e.g. googlemock) for use by the project.
# Usage:
# ct_get_ext_dep(_dir_name)
#   _dir_name - Directory name for the external CMake project being added
#   -- Retrieve step options --
#   URL [..] - Download URL to filename
#   URL_MD5 [..] - Download MD5 sum to compare filename to
#   DOWNLOAD_DIR [..] - Download directory to download filename to
#   GIT_REPOSITORY [..] - URL to git repository to clone
#   GIT_TAG [..] - Git reference/commit hash/tag to checkout
#   HG_REPOSITORY [..] - URL to mercurial repository to clone
#   HG_TAG [..] - Mercurial branch name/commit id/tag to checkout
#   SVN_REPOSITORY [..] - URL to svn repository to checkout
#   SVN_REVISION [..] - SVN revision to checkout
#   SOURCE_DIR [..] - Source dir to extract download to or clone to
#   INCLUDE_DIRS [..] - Include directories relative to SOURCE_DIR to add
macro(ct_get_cmake _dir_name)
  # Set options that have no arguments
  set(_options)
  # Set one value arguments
  set(_oneValueArgs URL URL_MD5 DOWNLOAD_DIR GIT_REPOSITORY GIT_TAG HG_REPOSITORY HG_TAG
      SVN_REPOSITORY SVN_REVISION SOURCE_DIR)
  # Set multi value arguments
  set(_multiValueArgs INCLUDE_DIRS)

  # Parse the arguments provided into categories
  cmake_parse_arguments(_ct "${_options}" "${_oneValueArgs}" "${_multiValueArgs}" ${ARGN})

  # DOWNLOAD_DIR not provided? then set it as __DOWNLOAD
  if(NOT DEFINED _ct_DOWNLOAD_DIR)
    set(_ct_DOWNLOAD_DIR ${__DOWNLOAD})
  endif()

  # SOURCE_DIR not provided? then set it as __PROJECT_SOURCE/_dir_name
  if(NOT DEFINED _ct_SOURCE_DIR)
    if(NOT EXISTS ${__PROJECT_SOURCE})
      file(MAKE_DIRECTORY ${__PROJECT_SOURCE})
    endif()
    set(_ct_SOURCE_DIR ${__PROJECT_SOURCE}/${_dir_name})
  endif()

  # Download URL options provided?
  if(_ct_URL)
    get_filename_component(_filename ${_ct_URL} NAME)

    # Download the file to DOWNLOAD_DIR
    ct_get_file(${_ct_URL} ${_ct_DOWNLOAD_DIR} MD5 ${_ct_URL_MD5})

    # Extract the file to SOURCE_DIR (which we create now)
    ct_extract_file(${_ct_DOWNLOAD_DIR}/${_filename} ${_ct_SOURCE_DIR})
  endif()

  # Git options provided?
  if(_ct_GIT_REPOSITORY)
    # Clone/update the repository
    ct_get_git(${_ct_GIT_REPOSITORY} ${_ct_SOURCE_DIR} REF ${_ct_GIT_TAG})
  endif()

  # Mercurial options provided?
  if(_ct_HG_REPOSITORY)
    # Clone/update the repository
    ct_get_hg(${_ct_HG_REPOSITORY} ${_ct_SOURCE_DIR} REF ${_ct_HG_TAG})
  endif()

  # SVN options provided?
  if(_ct_SVN_REPOSITORY)
    # Clone/update the repository
    ct_get_svn(${_ct_SVN_REPOSITORY} ${_ct_SOURCE_DIR} REF ${_ct_SVN_REVISION})
  endif()

  # Add additional include directories if provided
  if(_ct_INCLUDE_DIRS)
    foreach(include_dir ${_ct_INCLUDE_DIRS})
      include_directories(${_ct_SOURCE_DIR}/${include_dir})
    endforeach()
  endif()

  # Add CMake project directory we just retrieved
  add_subdirectory(${_ct_SOURCE_DIR})

  # Cleanup variables set above
  foreach(_var ${_options})
    unset(${_var})
  endforeach()
  foreach(_var ${_oneValueArgs})
    unset(${_var})
  endforeach()
  foreach(_var ${_multiValueArgs})
    unset(${_var})
  endforeach()
endmacro()

# EOF
