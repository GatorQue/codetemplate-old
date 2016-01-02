@ECHO OFF

REM Set default values
SET ECONFIG_NAME=HostDebug
SET EPROJ_NAME=codetemplate
SET MAKE_TARGET=all
SET CURDIR=%~dp0

IF "%~1"=="" GOTO SKIP_MAKE_TARGET
IF "%~2"=="" GOTO SKIP_ARGUMENTS
IF NOT "%~3"=="" GOTO USAGE

REM Load ConfigName (argument 2) over default
SET ECONFIG_NAME=%2

:SKIP_ARGUMENTS

REM Load MakeTarget (argument 1) over default
SET MAKE_TARGET=%1

:SKIP_MAKE_TARGET

REM Determine the correct TARGET_TYPE based on ECONFIG_NAME value
IF NOT x%ECONFIG_NAME:Target=%==x%ECONFIG_NAME% (
SET TARGET_TYPE=Target
) ELSE (
SET TARGET_TYPE=Host
)

REM Determine the correct BUILD_TYPE based on ECONFIG_NAME value
IF NOT x%ECONFIG_NAME:Rel=%==x%ECONFIG_NAME% (
  IF NOT x%ECONFIG_NAME:Release=%==x%ECONFIG_NAME% (
    SET BUILD_TYPE=Release
  ) ELSE (
    IF NOT x%ECONFIG_NAME:MinSizeRel=%==x%ECONFIG_NAME% (
      SET BUILD_TYPE=MinSizeRel
    ) ELSE (
      SET BUILD_TYPE=Release
    )
  )
) ELSE (
  SET BUILD_TYPE=Debug
)

REM Determine the correct MAKE_PROJECT to build based on MAKE_TARGET value
IF NOT x%MAKE_TARGET:test=%==x%MAKE_TARGET% (
  SET MAKE_PROJECT=RUN_TESTS.vcxproj
) ELSE (
  IF NOT x%MAKE_TARGET:coverage=%==x%MAKE_TARGET% (
    SET MAKE_PROJECT=coverage.vcxproj
  ) ELSE (
    IF NOT x%MAKE_TARGET:install=%==x%MAKE_TARGET% (
      SET MAKE_PROJECT=INSTALL.vcxproj
    ) ELSE (
      IF NOT x%MAKE_TARGET:doc=%==x%MAKE_TARGET% (
        SET MAKE_PROJECT=DOC.vcxproj
      ) ELSE (
        SET MAKE_PROJECT=ALL_BUILD.vcxproj
      )
    )
  )
)

REM Create CMake build directories
IF NOT EXIST %BUILD_TYPE%-%TARGET_TYPE%\NUL (
  mkdir %BUILD_TYPE%-%TARGET_TYPE%
)
pushd %BUILD_TYPE%-%TARGET_TYPE%
cmake .. -DCMAKE_BUILD_TYPE=%BUILD_TYPE%
popd

REM Build the directory
pushd %BUILD_TYPE%-%TARGET_TYPE%
msbuild %MAKE_PROJECT%
popd

REM Skip usage
GOTO END

:USAGE
ECHO "Usage: %0 [Target] [ConfigName]"
ECHO "Where:"
ECHO "  Target is all (default), coverage, doc, test, or install"
ECHO "  ConfigName is HostDebug (default), HostRelease, TargetDebug, or TargetRelease"
EXIT /B 1

:END
