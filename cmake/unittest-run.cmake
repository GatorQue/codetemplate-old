# This file causes the unit test for an test executable to be executed and
# checks its results and fails the build with a fatal error if the test fails.
# The test will only be run if the test executable (or its dependencies)
# changes. If the test fails the executable will be deleted which will force
# the unit test executable to be rebuilt and rerun again next time. This was
# based on the notes from the following cmake mailing list email:
# https://cmake.org/pipermail/cmake/2011-September/046218.html

# Check for coverage programs on our path that will be used in creating the
# unit test coverage reports.
find_program(GCOV_COMMAND gcov)
find_program(LCOV_COMMAND lcov)
find_program(GENHTML_COMMAND genhtml)

# Check that either gcov or lcov and genhtml commands are available
if(GCOV_COMMAND-NOTFOUND OR LCOV_COMMAND-NOTFOUND AND GENHTML_COMMAND-NOTFOUND)
  message(WARNING "Test coverage reports disabled, missing gcov or lcov and genthml")
  set(UT_COVERAGE OFF)
endif()

# Execute the test target using the ctest command
execute_process(
  COMMAND ${CMAKE_CTEST_COMMAND} -R ${TEST} --output-on-failure
  RESULT_VARIABLE TEST_RESULT
  )

# Check the test results
if(TEST_RESULT EQUAL 0)
  if(UT_COVERAGE AND LCOV_COMMAND AND GENHTML_COMMAND)
    message(STATUS "Creating coverage report")
    execute_process(
      COMMAND ${LCOV_COMMAND} -q -c -d ${PROJECT_BINARY_DIR} -o ${TEST}.info.full)
    execute_process(
      COMMAND ${LCOV_COMMAND} -q -r ${TEST}.info.full /usr/include/* /usr/lib/* third_party/* -o ${TEST}.info)
    execute_process(
      COMMAND ${GENHTML_COMMAND} -o ${UT_COVERAGE_DIR} ${TEST}.info)
    execute_process(
      COMMAND ${CMAKE_COMMAND} -E remove ${TEST}.info.full ${TEST}.info)
  endif()
else()
  if(UT_FAIL_COMPILE)
    # Delete the test executable on failures which will force it to be built
    # again on the next time make is called
    file(REMOVE ${TARGET})
    # Fail the CMake build due to the test failing
    message(FATAL_ERROR "Test ${TEST} [${TARGET}] failed.")
  endif()
endif()
