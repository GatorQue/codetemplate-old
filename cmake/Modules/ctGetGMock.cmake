# Use ctGetExtDep module to download GMock
include(ctGetExtDep)

# Call ct_get_cmake to download,extract and include googlemock CMake project
ct_get_cmake(googlemock
    URL http://googlemock.googlecode.com/files/gmock-1.7.0.zip
    URL_MD5 073b984d8798ea1594f5e44d85b20d66
    INCLUDE_DIRS gtest/include)

# Add gtest/gmock libraries to list of all auto dependency library list
set(ALL_LIBS ${ALL_LIBS} gtest gmock)

# Set gtest/gmock include directory and auto library dependencies
set(gtest_AUTO_INCLUDE_DIR ${__PROJECT_SOURCE}/googlemock/gtest/include)
set(gtest_AUTO_DEPS gmock gmock_main)
set(gmock_AUTO_INCLUDE_DIR ${__PROJECT_SOURCE}/googlemock/include)
set(gmock_AUTO_DEPS gmock gmock_main)

# EOF
