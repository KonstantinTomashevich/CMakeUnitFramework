# CMake script that converts /sourceDependencies output from VS2022 MSVC in C mode to CMake DEPFILE format.
# Arguments:
# - SOURCE: Absolute path to the source file to be added as dependency.
# - TARGET: Absolute path to the target file.
# - VS_DEPFILE: Absolute path to VS2022 dependencies json file.
# - DEPFILE_OUTPUT: Absolute path to store generated depfile at.

file (READ ${VS_DEPFILE} VS_JSON)
string (JSON INCLUDES_JSON GET "${VS_JSON}" Data Includes)
string (REPLACE "[" "" INCLUDES "${INCLUDES_JSON}")
string (REPLACE "]" "" INCLUDES "${INCLUDES}")
string (REPLACE "\"" "" INCLUDES "${INCLUDES}")
string (REPLACE "," ";" INCLUDES "${INCLUDES}")

cmake_path (RELATIVE_PATH TARGET BASE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}")
set (CONTENT "${TARGET}:\\\n${SOURCE}")

foreach (INCLUDE ${INCLUDES})
    string (STRIP "${INCLUDE}" INCLUDE)
    cmake_path (CONVERT "${INCLUDE}" TO_CMAKE_PATH_LIST INCLUDE NORMALIZE)
    string (REPLACE " " "\\ " INCLUDE "${INCLUDE}")
    string (APPEND CONTENT "\\\n${INCLUDE}")
endforeach ()

file (WRITE ${DEPFILE_OUTPUT} "${CONTENT}")
