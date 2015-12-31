# Define the default goal as all
.DEFAULT_GOAL := all

# Create a list of Makefile options.mk files to include
OPTION_FILES?=$(wildcard options.mk)

# Eclipse Project Name (defaults to parent directory name if not provided)
EPROJ_NAME?=$(lastword $(subst /, ,$(CURDIR)))

# Use Eclipse Config Name (if provided) to define the CMake build type to use
ifneq (,$(findstring Rel,$(ECONFIG_NAME)))
  ifneq (,$(findstring RelWithDebInfo,$(ECONFIG_NAME)))
    CMAKE_BUILD_TYPE:=RelWithDebInfo
  else
    ifneq (,$(findstring MinSizeRel,$(ECONFIG_NAME)))
      CMAKE_BUILD_TYPE:=MinSizeRel
    else
      CMAKE_BUILD_TYPE:=Release
    endif
  endif
else
  CMAKE_BUILD_TYPE:=Debug
endif

# Use Eclipse Config Name (if provided) to define the target type (e.g. Host or
# Target) to build and the build directory to use
ifneq (,$(findstring Target,$(ECONFIG_NAME)))
TARGET_TYPE:=Target
CMAKE_TOOLCHAIN_FILE=-DCMAKE_TOOLCHAIN_FILE=cmake/toolchain/$(TARGET_TOOLCHAIN).cmake
else
TARGET_TYPE:=Host
endif

# Were option files found above? then include them now
ifneq ("$(OPTION_FILES)","")
include $(OPTION_FILES)
endif

# Set BUILD_DIR according to build type and target type
BUILD_DIR:=$(CMAKE_BUILD_TYPE)-$(TARGET_TYPE)

# List of internal targets to filter out of MAKECMDGOALS
INTERNAL_TARGETS:=\
	all \
	clean \
	distclean \
	printvars

# If targets were specified filter out internal targets handled
ifdef MAKECMDGOALS
# Filter out internal targets we use from any provided externally
MAKE_TARGETS:=$(filter-out $(INTERNAL_TARGETS),$(MAKECMDGOALS))
endif

# Define the default target and pass through filtered make targets passed to
# the command line by the caller (this allows for defining unique targets in
# the CMakeLists.txt files and running them from here)
all $(MAKE_TARGETS): $(BUILD_DIR)/Options | $(BUILD_DIR)/Makefile
	@$(MAKE) -C $(BUILD_DIR) --no-print-directory $@

# Always run make all target before make test target
test: coverage

# Create a special target for rebuilding the $(BUILD_DIR)/Makefile if
# it doesn't yet exist.
$(BUILD_DIR)/Makefile:
	@mkdir -p $(BUILD_DIR)
	@echo "Creating '$(BUILD_DIR)/Makefile'"
	@cmake -E chdir $(BUILD_DIR) cmake -G "Unix Makefiles" ../ \
		-DCMAKE_BUILD_TYPE:String=$(CMAKE_BUILD_TYPE) \
		-DEPROJ_NAME:String=$(EPROJ_NAME) \
		$(CMAKE_TOOLCHAIN_FILE)

# Create a special build type file to detect build type or option changes and
# remove the build directory and force a rebuild
$(BUILD_DIR)/Options: $(OPTION_FILES)
	@rm -rf $(BUILD_DIR)
	@mkdir -p $(BUILD_DIR)
	@if [ ! -z "$(strip $(OPTION_FILES))" ]; then \
		cat $(OPTION_FILES) > $@;\
	else \
		touch $@;\
	fi

# Provide an explicit clean target definition
clean:
	-@if [ -e $(BUILD_DIR)/Makefile ]; then \
		$(MAKE) -C $(BUILD_DIR) --no-print-directory clean;\
	fi
	@rm -rf $(BUILD_DIR)

# Provide an explicit distclean target definition
distclean: clean
	@rm -rf Debug*
	@rm -rf Release*
	@rm -rf coverage
	@rm -rf reference
	@rm -rf third_party

# Prints the specified variable:
# make print-VARIABLE
print-%:
	@echo $(origin $*): $* = $($*)

# Prints all variables:
printvars:
	@$(foreach v,$(.VARIABLES),$(warning $(origin $v): $v=$($v) ($(value $v))))

# Define all our phony targets: both internal and command line targets
.PHONY: $(INTERNAL_TARGETS) $(MAKE_TARGETS) print-% printvars
