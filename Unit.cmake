# This file contains primary part of CMakeUnitFramework: unit registration and configuration routines.

define_property (TARGET PROPERTY UNIT_TARGET_TYPE
        BRIEF_DOCS "Type of the registered unit target."
        FULL_DOCS "Supported values: Abstract, Concrete, ConcreteInterface, Interface.")

# Defines which case framework uses for generating API macros. Support values:
# - Pascal
# - mixed_snake_case -- screaming case for macros and usual for files.
set (UNIT_FRAMEWORK_API_CASE "Pascal")

# Private utility function for unit configuration.
# Populates values for UNIT_API_MACRO, UNIT_IMPLEMENTATION_MACRO and UNIT_API_FILE.
function (private_generate_unit_api_variables API_UNIT_NAME)
    # We expect unit name to follow the same case.
    if (UNIT_FRAMEWORK_API_CASE STREQUAL "Pascal")
        set (UNIT_API_MACRO "${API_UNIT_NAME}Api"  PARENT_SCOPE)
        set (UNIT_IMPLEMENTATION_MACRO "${API_UNIT_NAME}Implementation"  PARENT_SCOPE)
        set (UNIT_API_FILE "${API_UNIT_NAME}Api.h"  PARENT_SCOPE)

    elseif (UNIT_FRAMEWORK_API_CASE STREQUAL "mixed_snake_case")
        string (TOUPPER "${API_UNIT_NAME}" API_UNIT_NAME_UPPER)
        set (UNIT_API_MACRO "${API_UNIT_NAME_UPPER}_API"  PARENT_SCOPE)
        set (UNIT_IMPLEMENTATION_MACRO "${API_UNIT_NAME_UPPER}_IMPLEMENTATION" PARENT_SCOPE)
        set (UNIT_API_FILE "${API_UNIT_NAME}_api.h"  PARENT_SCOPE)

    else ()
        message (FATAL_ERROR "Unknown API case value \"${UNIT_FRAMEWORK_API_CASE}\".")
    endif ()
endfunction ()

# Starts configuration routine of interface unit: header-only library.
function (register_interface UNIT_NAME)
    message (STATUS "Registering interface \"${UNIT_NAME}\"...")
    add_library ("${UNIT_NAME}" INTERFACE)
    set_target_properties ("${UNIT_NAME}" PROPERTIES UNIT_TARGET_TYPE "Interface")
    set (UNIT_NAME "${UNIT_NAME}" PARENT_SCOPE)
endfunction ()

# Adds given directories to interface include list of current interface unit.
function (interface_include)
    foreach (INCLUDE_DIR ${ARGV})
        message (STATUS "    Add include \"${INCLUDE_DIR}\".")
        target_include_directories ("${UNIT_NAME}" INTERFACE ${INCLUDE_DIR})
    endforeach ()
endfunction ()

# Registers requirements of current interface unit.
# Arguments:
# - ABSTRACT: list of required abstract units.
# - CONCRETE_INTERFACE: list of required interfaces of concrete units.
# - INTERFACE: list of required interface units.
# - THIRD_PARTY: list of required third party targets.
function (interface_require)
    cmake_parse_arguments (REQUIRE "" "" "ABSTRACT;CONCRETE_INTERFACE;INTERFACE;THIRD_PARTY" ${ARGV})
    if (DEFINED REQUIRE_UNPARSED_ARGUMENTS OR (
            NOT DEFINED REQUIRE_ABSTRACT AND
            NOT DEFINED REQUIRE_CONCRETE_INTERFACE AND
            NOT DEFINED REQUIRE_INTERFACE AND
            NOT DEFINED REQUIRE_THIRD_PARTY))
        message (FATAL_ERROR "Incorrect function arguments!")
    endif ()

    if (DEFINED REQUIRE_ABSTRACT)
        foreach (DEPENDENCY ${REQUIRE_ABSTRACT})
            message (STATUS "    Require abstract \"${DEPENDENCY}\".")
            reflected_target_link_libraries (TARGET "${UNIT_NAME}" INTERFACE "${DEPENDENCY}")
        endforeach ()
    endif ()

    if (DEFINED REQUIRE_CONCRETE_INTERFACE)
        foreach (DEPENDENCY ${REQUIRE_CONCRETE_INTERFACE})
            message (STATUS "    Require concrete interface \"${DEPENDENCY}\".")
            reflected_target_link_libraries (TARGET "${UNIT_NAME}" INTERFACE "${DEPENDENCY}Interface")
        endforeach ()
    endif ()

    if (DEFINED REQUIRE_INTERFACE)
        foreach (DEPENDENCY ${REQUIRE_INTERFACE})
            message (STATUS "    Require interface \"${DEPENDENCY}\".")
            reflected_target_link_libraries (TARGET "${UNIT_NAME}" INTERFACE "${DEPENDENCY}")
        endforeach ()
    endif ()

    if (DEFINED REQUIRE_THIRD_PARTY)
        foreach (DEPENDENCY ${REQUIRE_THIRD_PARTY})
            message (STATUS "    Require third party \"${DEPENDENCY}\".")
            reflected_target_link_libraries (TARGET "${UNIT_NAME}" INTERFACE "${DEPENDENCY}")
        endforeach ()
    endif ()
endfunction ()

# Adds interface compile options to current interface unit.
function (interface_compile_options)
    message (STATUS "    Add compile options \"${ARGV}\".")
    target_compile_options ("${UNIT_NAME}" INTERFACE ${ARGV})
endfunction ()

# Adds interface compile definitions to current interface unit.
function (interface_compile_definitions)
    message (STATUS "    Add compile definitions \"${ARGV}\".")
    target_compile_definitions ("${UNIT_NAME}" INTERFACE ${ARGV})
endfunction ()

define_property (TARGET PROPERTY REQUIRED_CONCRETE_UNIT
        BRIEF_DOCS "Name of concrete unit for this concrete unit interface."
        FULL_DOCS "Concrete units consist of two targets: interface with only headers and implementation objects.")

# Starts configuration routine of concrete unit: headers with one concrete implementation.
function (register_concrete UNIT_NAME)
    message (STATUS "Registering concrete \"${UNIT_NAME}\"...")

    add_library ("${UNIT_NAME}Interface" INTERFACE)
    set_target_properties ("${UNIT_NAME}Interface" PROPERTIES
            UNIT_TARGET_TYPE "ConcreteInterface"
            REQUIRED_CONCRETE_UNIT "${UNIT_NAME}")

    add_library ("${UNIT_NAME}" OBJECT)
    set_target_properties ("${UNIT_NAME}" PROPERTIES UNIT_TARGET_TYPE "Concrete")
    reflected_target_link_libraries (TARGET "${UNIT_NAME}" PUBLIC "${UNIT_NAME}Interface")

    # Generate API header for shared library support.
    file (MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/Generated")
    private_generate_unit_api_variables ("${UNIT_NAME}")
    
    generate_api_header (
            API_MACRO "${UNIT_API_MACRO}"
            EXPORT_MACRO "${UNIT_IMPLEMENTATION_MACRO}"
            OUTPUT_FILE "${CMAKE_CURRENT_BINARY_DIR}/Generated/${UNIT_API_FILE}")

    target_compile_definitions ("${UNIT_NAME}" PRIVATE "${UNIT_IMPLEMENTATION_MACRO}")
    target_include_directories ("${UNIT_NAME}Interface" INTERFACE "${CMAKE_CURRENT_BINARY_DIR}/Generated")
    set (UNIT_NAME "${UNIT_NAME}" PARENT_SCOPE)
endfunction ()

# Adds sources that match given glob recurse patterns to current concrete unit.
function (concrete_sources)
    foreach (PATTERN ${ARGV})
        message (STATUS "    Add sources with recurse pattern \"${PATTERN}\".")
        file (GLOB_RECURSE SOURCES "${PATTERN}")
        target_sources ("${UNIT_NAME}" PRIVATE ${SOURCES})
    endforeach ()
endfunction ()

# Adds include directories to current concrete unit.
# Arguments:
# - PUBLIC: directories that are meant to be publicly linked.
# - PRIVATE: directories that are meant to be privately linked.
function (concrete_include)
    cmake_parse_arguments (INCLUDE "" "" "PUBLIC;PRIVATE" ${ARGV})
    if (DEFINED INCLUDE_UNPARSED_ARGUMENTS OR (
            NOT DEFINED INCLUDE_PUBLIC AND
            NOT DEFINED INCLUDE_PRIVATE))
        message (FATAL_ERROR "Incorrect function arguments!")
    endif ()

    if (DEFINED INCLUDE_PUBLIC)
        foreach (INCLUDE_DIR ${INCLUDE_PUBLIC})
            message (STATUS "    Add public scope include \"${INCLUDE_DIR}\".")
            target_include_directories ("${UNIT_NAME}Interface" INTERFACE ${INCLUDE_DIR})
        endforeach ()
    endif ()

    if (DEFINED INCLUDE_PRIVATE)
        foreach (INCLUDE_DIR ${INCLUDE_PRIVATE})
            message (STATUS "    Add private scope include \"${INCLUDE_DIR}\".")
            target_include_directories ("${UNIT_NAME}" PRIVATE ${INCLUDE_DIR})
        endforeach ()
    endif ()
endfunction ()

# Registers requirements of current concrete unit.
# Arguments:
# - SCOPE: scope for these requirements, either PUBLIC or PRIVATE.
# - ABSTRACT: list of required abstract units.
# - CONCRETE_INTERFACE: list of required interfaces of concrete units.
# - INTERFACE: list of required interface units.
# - THIRD_PARTY: list of required third party targets.
function (concrete_require)
    cmake_parse_arguments (REQUIRE "" "SCOPE" "INTERFACE;CONCRETE_INTERFACE;ABSTRACT;THIRD_PARTY" ${ARGV})
    if (DEFINED REQUIRE_UNPARSED_ARGUMENTS OR
            NOT DEFINED REQUIRE_SCOPE OR (
            NOT DEFINED REQUIRE_INTERFACE AND
            NOT DEFINED REQUIRE_CONCRETE_INTERFACE AND
            NOT DEFINED REQUIRE_ABSTRACT AND
            NOT DEFINED REQUIRE_THIRD_PARTY))
        message (FATAL_ERROR "Incorrect function arguments!")
    endif ()

    if (REQUIRE_SCOPE STREQUAL "PUBLIC")

        if (DEFINED REQUIRE_INTERFACE)
            foreach (DEPENDENCY ${REQUIRE_INTERFACE})
                message (STATUS "    Require public scope interface \"${DEPENDENCY}\".")
                reflected_target_link_libraries (TARGET "${UNIT_NAME}Interface" INTERFACE "${DEPENDENCY}")
            endforeach ()
        endif ()

        if (DEFINED REQUIRE_CONCRETE_INTERFACE)
            foreach (DEPENDENCY ${REQUIRE_CONCRETE_INTERFACE})
                message (STATUS "    Require public scope interface of concrete \"${DEPENDENCY}\".")
                reflected_target_link_libraries (TARGET "${UNIT_NAME}Interface" INTERFACE "${DEPENDENCY}Interface")
            endforeach ()
        endif ()

        if (DEFINED REQUIRE_ABSTRACT)
            foreach (DEPENDENCY ${REQUIRE_ABSTRACT})
                message (STATUS "    Require public scope abstract \"${DEPENDENCY}\".")
                reflected_target_link_libraries (TARGET "${UNIT_NAME}Interface" INTERFACE "${DEPENDENCY}")
            endforeach ()
        endif ()

        if (DEFINED REQUIRE_THIRD_PARTY)
            foreach (DEPENDENCY ${REQUIRE_THIRD_PARTY})
                message (STATUS "    Require public scope third party \"${DEPENDENCY}\".")
                reflected_target_link_libraries (TARGET "${UNIT_NAME}Interface" INTERFACE "${DEPENDENCY}")
            endforeach ()
        endif ()

    elseif (REQUIRE_SCOPE STREQUAL "PRIVATE")

        if (DEFINED REQUIRE_INTERFACE)
            foreach (DEPENDENCY ${REQUIRE_INTERFACE})
                message (STATUS "    Require private scope interface \"${DEPENDENCY}\".")
                reflected_target_link_libraries (TARGET "${UNIT_NAME}" PRIVATE "${DEPENDENCY}")
            endforeach ()
        endif ()

        if (DEFINED REQUIRE_CONCRETE_INTERFACE)
            foreach (DEPENDENCY ${REQUIRE_CONCRETE_INTERFACE})
                message (STATUS "    Require private scope interface of concrete \"${DEPENDENCY}\".")
                reflected_target_link_libraries (TARGET "${UNIT_NAME}" PRIVATE "${DEPENDENCY}Interface")
            endforeach ()
        endif ()

        if (DEFINED REQUIRE_ABSTRACT)
            foreach (DEPENDENCY ${REQUIRE_ABSTRACT})
                message (STATUS "    Require private scope abstract \"${DEPENDENCY}\".")
                reflected_target_link_libraries (TARGET "${UNIT_NAME}" PRIVATE "${DEPENDENCY}")
            endforeach ()
        endif ()

        if (DEFINED REQUIRE_THIRD_PARTY)
            foreach (DEPENDENCY ${REQUIRE_THIRD_PARTY})
                message (STATUS "    Require private scope third party \"${DEPENDENCY}\".")
                reflected_target_link_libraries (TARGET "${UNIT_NAME}" PRIVATE "${DEPENDENCY}")
            endforeach ()
        endif ()

    else ()
        message (FATAL_ERROR "Incorrect function arguments!")
    endif ()
endfunction ()

# Adds compile options to current concrete unit.
# Arguments:
# - PUBLIC: compile options that are added to public scope.
# - PRIVATE: compile options that are added to private scope.
function (concrete_compile_options)
    cmake_parse_arguments (OPTIONS "" "" "PUBLIC;PRIVATE" ${ARGV})
    if (DEFINED OPTIONS_UNPARSED_ARGUMENTS OR (
            NOT DEFINED OPTIONS_PUBLIC AND
            NOT DEFINED OPTIONS_PRIVATE))
        message (FATAL_ERROR "Incorrect function arguments!")
    endif ()

    if (DEFINED OPTIONS_PUBLIC)
        message (STATUS "    Add public compile options \"${OPTIONS_PUBLIC}\".")
        target_compile_options ("${UNIT_NAME}Interface" INTERFACE ${OPTIONS_PUBLIC})
    endif ()

    if (DEFINED OPTIONS_PRIVATE)
        message (STATUS "    Add private compile options \"${OPTIONS_PRIVATE}\".")
        target_compile_options ("${UNIT_NAME}" PRIVATE ${OPTIONS_PRIVATE})
    endif ()
endfunction ()

# Adds compile definitions to current concrete unit.
# Arguments:
# - PUBLIC: compile definitions that are added to public scope.
# - PRIVATE: compile definitions that are added to private scope.
function (concrete_compile_definitions)
    cmake_parse_arguments (DEFINITIONS "" "" "PUBLIC;PRIVATE" ${ARGV})
    if (DEFINED DEFINITIONS_UNPARSED_ARGUMENTS OR (
            NOT DEFINED DEFINITIONS_PUBLIC AND
            NOT DEFINED DEFINITIONS_PRIVATE))
        message (FATAL_ERROR "Incorrect function arguments!")
    endif ()

    if (DEFINED DEFINITIONS_PUBLIC)
        message (STATUS "    Add public compile definitions \"${DEFINITIONS_PUBLIC}\".")
        target_compile_definitions ("${UNIT_NAME}Interface" INTERFACE ${DEFINITIONS_PUBLIC})
    endif ()

    if (DEFINED DEFINITIONS_PRIVATE)
        message (STATUS "    Add private compile definitions \"${DEFINITIONS_PRIVATE}\".")
        target_compile_definitions ("${UNIT_NAME}" PRIVATE ${DEFINITIONS_PRIVATE})
    endif ()
endfunction ()

# Informs build system that this concrete unit implements given abstract unit.
# Needed to pass correct compile definitions to concrete unit objects.
function (concrete_implements_abstract ABSTRACT_NAME)
    message (STATUS "    Implement abstract unit \"${ABSTRACT_NAME}\".")
    reflected_target_link_libraries (TARGET "${UNIT_NAME}" PRIVATE "${ABSTRACT_NAME}")
    private_generate_unit_api_variables ("${ABSTRACT_NAME}")
    target_compile_definitions ("${UNIT_NAME}" PRIVATE "${UNIT_IMPLEMENTATION_MACRO}")
endfunction ()

# Starts configuration routine of abstract unit: headers that might have multiple implementations.
function (register_abstract UNIT_NAME)
    message (STATUS "Registering abstract \"${UNIT_NAME}\"...")
    add_library ("${UNIT_NAME}" INTERFACE)
    set_target_properties ("${UNIT_NAME}" PROPERTIES UNIT_TARGET_TYPE "Abstract")

    # Generate API header for shared library support.
    file (MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/Generated")
    private_generate_unit_api_variables ("${UNIT_NAME}")
    
    generate_api_header (
            API_MACRO "${UNIT_API_MACRO}"
            EXPORT_MACRO "${UNIT_IMPLEMENTATION_MACRO}"
            OUTPUT_FILE "${CMAKE_CURRENT_BINARY_DIR}/Generated/${UNIT_API_FILE}")

    target_include_directories ("${UNIT_NAME}" INTERFACE "${CMAKE_CURRENT_BINARY_DIR}/Generated")
    set (UNIT_NAME "${UNIT_NAME}" PARENT_SCOPE)
endfunction ()

# Adds given directories to interface include list of current abstract unit.
function (abstract_include INCLUDE_DIR)
    # Technically, abstract is an advanced interface. Therefore we're using some of the interface functions.
    interface_include (${ARGV})
endfunction ()

# Registers requirements of current abstract unit.
# Arguments:
# - ABSTRACT: list of required abstract units.
# - CONCRETE_INTERFACE: list of required interfaces of concrete units.
# - INTERFACE: list of required interface units.
# - THIRD_PARTY: list of required third party targets.
function (abstract_require)
    # Technically, abstract is an advanced interface. Therefore we're using some of the interface functions.
    interface_require (${ARGV})
endfunction ()

# Adds interface compile options to current abstract unit.
function (abstract_compile_definitions)
    interface_compile_definitions (${ARGV})
endfunction ()

define_property (TARGET PROPERTY IMPLEMENTATIONS
        BRIEF_DOCS "List of implementations of the abstract unit."
        FULL_DOCS "Saving list of implementations makes it easy to add custom logic to build system.")

define_property (TARGET PROPERTY IMPLEMENTATION_REMAP
        BRIEF_DOCS "List of concrete units that form implementation of associated abstract unit."
        FULL_DOCS "Added to special implementation marker target.")

# Registers new implementation for current abstract unit.
# Arguments:
# - NAME: name of the implementation.
# - PARTS: list of concrete units that form implementation of this abstract unit.
function (abstract_register_implementation)
    cmake_parse_arguments (IMPLEMENTATION "" "NAME" "PARTS" ${ARGN})
    if (DEFINED IMPLEMENTATION_UNPARSED_ARGUMENTS OR
            NOT DEFINED IMPLEMENTATION_NAME OR
            NOT DEFINED IMPLEMENTATION_PARTS)
        message (FATAL_ERROR "Incorrect function arguments!")
    endif ()

    message (STATUS "    Add implementation \"${IMPLEMENTATION_NAME}\".")
    add_library ("${UNIT_NAME}${IMPLEMENTATION_NAME}Marker" INTERFACE)

    foreach (PART_NAME ${IMPLEMENTATION_PARTS})
        message (STATUS "        Add part \"${PART_NAME}\".")
    endforeach ()

    set_target_properties ("${UNIT_NAME}${IMPLEMENTATION_NAME}Marker" PROPERTIES
            UNIT_TARGET_TYPE "AbstractImplementation"
            IMPLEMENTATION_REMAP "${IMPLEMENTATION_PARTS}")

    get_target_property (IMPLEMENTATIONS "${UNIT_NAME}" IMPLEMENTATIONS)
    if (IMPLEMENTATIONS STREQUAL "IMPLEMENTATIONS-NOTFOUND")
        set (IMPLEMENTATIONS)
    endif ()

    list (APPEND IMPLEMENTATIONS "${IMPLEMENTATION_NAME}")
    set_target_properties ("${UNIT_NAME}" PROPERTIES IMPLEMENTATIONS "${IMPLEMENTATIONS}")
endfunction ()

# Outputs list of all implementations of request abstract unit.
# Arguments:
# - ABSTRACT: name of the abstract unit.
# - OUTPUT: name of the output variable.
function (abstract_get_implementations)
    cmake_parse_arguments (SEARCH "" "ABSTRACT;OUTPUT" "" ${ARGV})
    if (DEFINED SEARCH_UNPARSED_ARGUMENTS OR
            NOT DEFINED SEARCH_ABSTRACT OR
            NOT DEFINED SEARCH_OUTPUT)
        message (FATAL_ERROR "Incorrect function arguments!")
    endif ()

    get_target_property (IMPLEMENTATIONS "${SEARCH_ABSTRACT}" IMPLEMENTATIONS)
    if (IMPLEMENTATIONS STREQUAL "IMPLEMENTATIONS-NOTFOUND")
        set ("${SEARCH_OUTPUT}" "" PARENT_SCOPE)
    else ()
        set ("${SEARCH_OUTPUT}" "${IMPLEMENTATIONS}" PARENT_SCOPE)
    endif ()
endfunction ()
