# ct_get_subdirs retrieves a list of subdirectories of the directory specified
# and stores the list in the result variable specified. The list provided are
# relative to the _rdir directory specified
# Usage:
# ct_get_subdirs(_result _dir _rdir)
#   _result - Variable to store list of subdirectories in
#   _dir    - Directory to obtain subdirectories from
#   _rdir   - Directory to make results relative to
macro(ct_get_subdirs _result _dir _rdir)
  file(GLOB _children RELATIVE ${_rdir} ${_dir}/*)
  set(_dirlist "")
  foreach(_child ${_children})
    if(IS_DIRECTORY ${_rdir}/${_child})
      list(APPEND _dirlist ${_child})
    endif()
  endforeach()
  list(REVERSE _dirlist)
  set(${_result} ${_dirlist})
endmacro()

# ct_get_tree retrieves a recursive list of subdirectories of the directory
# specified and stores the list in the result variable specified. The list
# provided are relative to the directory specified
# Usage:
# ct_get_tree(_result _dir _rdir)
#   _result - Variable to store list of subdirectories in
#   _dir    - Directory to obtain subdirectories from
#   _rdir   - Directory to make results relative to
macro(ct_get_tree _result _dir _rdir)
  ct_get_subdirs(_subdirs ${_dir} ${_rdir})
  foreach(_subdir ${_subdirs})
    list(APPEND ${_result} ${_rdir}/${_subdir})
    ct_get_tree(${_result} ${_rdir}/${_subdir} ${_rdir})
  endforeach()
endmacro()

# ct_add_subdirs recursively adds every subdirectory of the directory specified
# that contains a CMakeLists.txt file.
# Usage:
# ct_add_subdirs(_dir)
#   _dir    - Directory to obtain subdirectories from
macro(ct_add_subdirs _dir)
  # Add _dir if it contains a CMakeLists.txt file
  if(EXISTS ${_dir}/CMakeLists.txt)
    add_subdirectory(${_dir})
  endif()
  # Now check remaining subdirs for CMakeLists.txt files
  ct_get_subdirs(_subdirs ${_dir} ${_dir})
  foreach(_subdir ${_subdirs})
    ct_add_subdirs(${_dir}/${_subdir})
  endforeach()
endmacro()

# EOF
