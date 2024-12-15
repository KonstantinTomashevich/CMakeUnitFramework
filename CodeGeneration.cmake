# This file contains functions used by CMakeUnitFramework to generate code.

# If set, added as prefix to export API macros. Useful for injection of custom pragma statements.
set (UNIT_FRAMEWORK_API_MACRO_EXPORT_PREFIX "")

# Writes given content to given file unless it already contains the same content.
function (file_write_if_not_equal TARGET_FILE CONTENT)
    set (CURRENT_CONTENT)

    if (EXISTS "${TARGET_FILE}")
        file (READ "${TARGET_FILE}" CURRENT_CONTENT)
    endif ()

    if (NOT CONTENT STREQUAL CURRENT_CONTENT)
        file (WRITE "${TARGET_FILE}" "${CONTENT}")
    endif ()
endfunction ()

# Generic utility function for generating API headers for Windows dllexport/dllimport support.
# Arguments:
# - API_MACRO: name of the macro that will be used as API declaration macro.
# - EXPORT_MACRO: name of the macro that is only added to targets that export definitions of declared API.
# - OUTPUT_FILE: path to the output file.
function (generate_api_header)
    cmake_parse_arguments (GENERATE "" "API_MACRO;EXPORT_MACRO;OUTPUT_FILE" "" ${ARGV})
    if (DEFINED GENERATE_UNPARSED_ARGUMENTS OR
            NOT DEFINED GENERATE_API_MACRO OR
            NOT DEFINED GENERATE_EXPORT_MACRO OR
            NOT DEFINED GENERATE_OUTPUT_FILE)
        message (FATAL_ERROR "Incorrect function arguments!")
    endif ()

    set (CONTENT)
    string (APPEND CONTENT "// AUTOGENERATED BY BUILD SYSTEM, DO NOT MODIFY.\n\n")
    string (APPEND CONTENT "#pragma once\n\n")
    string (APPEND CONTENT "#if defined(_WIN32)\n")
    string (APPEND CONTENT "#    if defined(${GENERATE_EXPORT_MACRO})\n")
    string (APPEND CONTENT "// NOLINTNEXTLINE(readability-identifier-naming): API macro is named the same way as target for better readability.\n")
    string (APPEND CONTENT "#        define ${GENERATE_API_MACRO} ${UNIT_FRAMEWORK_API_MACRO_EXPORT_PREFIX} __declspec(dllexport)\n")
    string (APPEND CONTENT "#    else\n")
    string (APPEND CONTENT "// NOLINTNEXTLINE(readability-identifier-naming): API macro is named the same way as target for better readability.\n")
    string (APPEND CONTENT "#        define ${GENERATE_API_MACRO} __declspec(dllimport)\n")
    string (APPEND CONTENT "#    endif\n")
    string (APPEND CONTENT "#else\n")
    string (APPEND CONTENT "#    if defined(${GENERATE_EXPORT_MACRO})\n")
    string (APPEND CONTENT "// NOLINTNEXTLINE(readability-identifier-naming): API macro is named the same way as target for better readability.\n")
    string (APPEND CONTENT "#        define ${GENERATE_API_MACRO} ${UNIT_FRAMEWORK_API_MACRO_EXPORT_PREFIX}\n")
    string (APPEND CONTENT "#    else\n")
    string (APPEND CONTENT "// NOLINTNEXTLINE(readability-identifier-naming): API macro is named the same way as target for better readability.\n")
    string (APPEND CONTENT "#        define ${GENERATE_API_MACRO}\n")
    string (APPEND CONTENT "#    endif\n")
    string (APPEND CONTENT "#endif\n")

    file_write_if_not_equal ("${GENERATE_OUTPUT_FILE}" "${CONTENT}")
endfunction ()
