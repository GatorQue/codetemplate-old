# Create a variable for the cmake directory
set(PROJECT_CMAKE_DIR ${PROJECT_SOURCE_DIR}/cmake)

# Add various CMake CodeTemplate ct_add_* functions and macros
include(ctAddDir)
include(ctAddExe)
include(ctAddLib)
include(ctAddOption)
include(ctAddTest)
include(ctGenCMake)
include(ctGetExtDep)
include(ctGetGMock)

# EOF
