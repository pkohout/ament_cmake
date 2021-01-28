# Copyright 2014 Open Source Robotics Foundation, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# Install a Python package (and its recursive subpackages) as a flat Python .egg
#
# :param package_name: the Python package name
# :type package_name: string
# :param PACKAGE_DIR: the path to the Python package directory (default:
#   <package_name> folder relative to the CMAKE_CURRENT_LIST_DIR)
# :type PACKAGE_DIR: string
# :param VERSION: the Python package version (default: package.xml version)
# :param VERSION: string
# :param SETUP_CFG: the path to a setup.cfg file, if provided
# :param SETUP_CFG: string
# :param SKIP_COMPILE: if set do not byte-compile the installed package
# :type SKIP_COMPILE: option
#
macro(ament_python_install_package)
  _ament_cmake_python_register_environment_hook()
  _ament_cmake_python_install_package(${ARGN})
endmacro()

function(_ament_cmake_python_install_package package_name)
  cmake_parse_arguments(ARG "SKIP_COMPILE" "PACKAGE_DIR;VERSION;SETUP_CFG" "" ${ARGN})
  if(ARG_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "ament_python_install_package() called with unused "
      "arguments: ${ARG_UNPARSED_ARGUMENTS}")
  endif()

  if(NOT ARG_PACKAGE_DIR)
    set(ARG_PACKAGE_DIR "${CMAKE_CURRENT_LIST_DIR}/${package_name}")
  endif()
  if(NOT IS_ABSOLUTE "${ARG_PACKAGE_DIR}")
    set(ARG_PACKAGE_DIR "${CMAKE_CURRENT_LIST_DIR}/${ARG_PACKAGE_DIR}")
  endif()

  if(NOT ARG_VERSION)
    # Use package.xml version
    if(NOT _AMENT_PACKAGE_NAME)
      ament_package_xml()
    endif()
    set(ARG_VERSION "${${PROJECT_NAME}_VERSION}")
  endif()

  if(NOT EXISTS "${ARG_PACKAGE_DIR}/__init__.py")
    message(FATAL_ERROR "ament_python_install_package() the Python package "
      "folder '${ARG_PACKAGE_DIR}' doesn't contain an '__init__.py' file")
  endif()

  set(build_dir "${CMAKE_CURRENT_BINARY_DIR}/ament_cmake_python/${package_name}")

  string(CONFIGURE "\
from setuptools import setup

setup(
  name='${package_name}',
  version='${ARG_VERSION}',
  packages=['${package_name}'],
  package_dir={'${package_name}': '${ARG_PACKAGE_DIR}'},
)
" setup_py_content)

  file(GENERATE
    OUTPUT "${build_dir}/setup.py"
    CONTENT "${setup_py_content}"
  )

  if(ARG_SETUP_CFG)
    if(NOT IS_ABSOLUTE ${ARG_SETUP_CFG})
      set(ARG_SETUP_CFG "${CMAKE_CURRENT_LIST_DIR}/${ARG_SETUP_CFG}")
    endif()
    add_custom_command(
      OUTPUT "${build_dir}/setup.cfg"
      COMMAND ${CMAKE_COMMAND} -E copy ${ARG_SETUP_CFG} ${build_dir}/setup.cfg
      MAIN_DEPENDENCY ${ARG_SETUP_CFG}
    )
  endif()

  if(NOT ARG_SKIP_COMPILE)
    set(extra_install_args "--compile")
  else()
    set(extra_install_args "--no-compile")
  endif()

  # Install as flat Python .egg to mimic https://github.com/colcon/colcon-core
  # handling of pure Python packages.

  # NOTE(hidmic): Allow setup.py install to build, as there is no way to
  # determine the Python package's source dependencies for proper build
  # invalidation.
  install(CODE
    "message(STATUS \"Installing: ${package_name} as flat Python .egg \"
                    \"to ${CMAKE_INSTALL_PREFIX}/${PYTHON_INSTALL_DIR}\")
     execute_process(
        COMMAND
        \"${PYTHON_EXECUTABLE}\" setup.py install
           --single-version-externally-managed
           --prefix ${CMAKE_INSTALL_PREFIX}
           --record install.log
           ${extra_install_args}
        WORKING_DIRECTORY \"${build_dir}\"
        OUTPUT_QUIET
     )"
  )

  if(package_name IN_LIST AMENT_CMAKE_PYTHON_INSTALL_INSTALLED_NAMES)
    message(FATAL_ERROR
      "ament_python_install_package() a Python module file or package with "
      "the same name '${package_name}' has been installed before")
  endif()
  list(APPEND AMENT_CMAKE_PYTHON_INSTALL_INSTALLED_NAMES "${package_name}")
  set(AMENT_CMAKE_PYTHON_INSTALL_INSTALLED_NAMES
    "${AMENT_CMAKE_PYTHON_INSTALL_INSTALLED_NAMES}" PARENT_SCOPE)
endfunction()
