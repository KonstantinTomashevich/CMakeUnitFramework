# This file contains primary part of CMakeUnitFramework: unit registration and configuration routines.

define_property (TARGET PROPERTY UNIT_TARGET_TYPE
        BRIEF_DOCS "Type of the registered unit target."
        FULL_DOCS "Supported values: Abstract, Concrete, ConcreteInterface, Interface.")

define_property (TARGET PROPERTY INTERNAL_CONCRETE_SOURCES
        BRIEF_DOCS "Property for concrete units that holds list of sources."
        FULL_DOCS "Concrete units support preprocessing queues and therefore may change their sources several times "
        "during configuration phase. Then, final sources are extracted through generator expression using this "
        "property and passed to compiler.")

define_property (TARGET PROPERTY INTERNAL_CONCRETE_SOURCES_INITIAL
        BRIEF_DOCS "Property that contains value of INTERNAL_CONCRETE_SOURCES when preprocessing queue was initialized."
        FULL_DOCS "Used to provide source file names to preprocess step executors.")

define_property (TARGET PROPERTY INTERNAL_CONCRETE_GATHER_PRODUCTS
        BRIEF_DOCS "Property for concrete units that holds list of sources produced by preprocessing gather steps."
        FULL_DOCS "Some sources are produced as a result of gather steps and need to be added to sources separately.")

define_property (TARGET PROPERTY INTERNAL_CONCRETE_QUEUE_OUTPUT_INDEX
        BRIEF_DOCS "Next step index in preprocessing queue for steps that have output."
        FULL_DOCS "Steps that have output need to have their own directories and we use indices for naming them.")

# Defines which case framework uses for generating API macros. Support values:
# - Pascal
# - mixed_snake_case -- screaming case for macros and usual for files.
set (UNIT_FRAMEWORK_API_CASE "Pascal")

# Stub file for highlight-only targets for concrete units.
# In some cases, concrete unit sources are generated by external preprocessor tool. If this happens, most IDEs don't 
# know how to highlight real source file that is not preprocessed. To solve this issue, we provide special 
# highlight-only object libraries that should never be built, but are used to tell IDE how to highlight real sources.
set (UNIT_FRAMEWORK_HIGHLIGHT_STUB_SOURCE "${CMAKE_CURRENT_LIST_DIR}/highlight_stub.c")

# Populates values for UNIT_API_MACRO, UNIT_IMPLEMENTATION_MACRO and UNIT_API_FILE with appropriate values.
# UNIT_API_MACRO is a macro that is used to declare exported functions and symbols. UNIT_IMPLEMENTATION_MACRO is a macro
# that is only defined in targets with exported functions and symbols implementations. UNIT_API_FILE is a name of file
# with API macro (only file name, no path).
function (get_unit_api_variables API_UNIT_NAME)
    # We expect unit name to follow the same case.
    if (UNIT_FRAMEWORK_API_CASE STREQUAL "Pascal")
        set (UNIT_API_MACRO "${API_UNIT_NAME}Api" PARENT_SCOPE)
        set (UNIT_IMPLEMENTATION_MACRO "${API_UNIT_NAME}Implementation" PARENT_SCOPE)
        set (UNIT_API_FILE "${API_UNIT_NAME}Api.h" PARENT_SCOPE)

    elseif (UNIT_FRAMEWORK_API_CASE STREQUAL "mixed_snake_case")
        string (TOUPPER "${API_UNIT_NAME}" API_UNIT_NAME_UPPER)
        set (UNIT_API_MACRO "${API_UNIT_NAME_UPPER}_API" PARENT_SCOPE)
        set (UNIT_IMPLEMENTATION_MACRO "${API_UNIT_NAME_UPPER}_IMPLEMENTATION" PARENT_SCOPE)
        set (UNIT_API_FILE "${API_UNIT_NAME}_api.h" PARENT_SCOPE)

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
    target_sources ("${UNIT_NAME}" PRIVATE
            $<TARGET_PROPERTY:${UNIT_NAME},INTERNAL_CONCRETE_SOURCES>
            $<TARGET_PROPERTY:${UNIT_NAME},INTERNAL_CONCRETE_GATHER_PRODUCTS>)
    reflected_target_link_libraries (TARGET "${UNIT_NAME}" PUBLIC "${UNIT_NAME}Interface")

    add_library ("${UNIT_NAME}Highlight" OBJECT EXCLUDE_FROM_ALL "${UNIT_FRAMEWORK_HIGHLIGHT_STUB_SOURCE}")
    set_target_properties ("${UNIT_NAME}Highlight" PROPERTIES UNIT_TARGET_TYPE "Concrete")
    reflected_target_link_libraries (TARGET "${UNIT_NAME}Highlight" PUBLIC "${UNIT_NAME}Interface")

    # Generate API header for shared library support.
    set (GENERATED_DIRECTORY "${CMAKE_BINARY_DIR}/Generated/${UNIT_NAME}/")
    file (MAKE_DIRECTORY "${GENERATED_DIRECTORY}")
    get_unit_api_variables ("${UNIT_NAME}")

    generate_api_header (
            API_MACRO "${UNIT_API_MACRO}"
            EXPORT_MACRO "${UNIT_IMPLEMENTATION_MACRO}"
            OUTPUT_FILE "${GENERATED_DIRECTORY}/Include/${UNIT_API_FILE}")

    target_compile_definitions ("${UNIT_NAME}" PRIVATE "${UNIT_IMPLEMENTATION_MACRO}")
    target_include_directories ("${UNIT_NAME}Interface" INTERFACE "${GENERATED_DIRECTORY}/Include")
    set (UNIT_NAME "${UNIT_NAME}" PARENT_SCOPE)
endfunction ()

# For internal use inside this file only.
# Helper for adding source to current concrete unit targets.
function (internal_concrete_add_sources)
    get_target_property (QUEUE_STARTED "${UNIT_NAME}" INTERNAL_CONCRETE_SOURCES_INITIAL)
    if (QUEUE_STARTED)
        message (FATAL_ERROR "        Caught attempt to add sources after preprocess queue configuration started.")
    endif ()

    get_target_property (TARGET_SOURCES "${UNIT_NAME}" INTERNAL_CONCRETE_SOURCES)
    if (NOT TARGET_SOURCES)
        set (TARGET_SOURCES)
    endif ()

    foreach (SOURCE ${ARGV})
        cmake_path (ABSOLUTE_PATH SOURCE NORMALIZE)
        list (APPEND TARGET_SOURCES "${SOURCE}")
    endforeach ()

    set_target_properties ("${UNIT_NAME}" PROPERTIES INTERNAL_CONCRETE_SOURCES "${TARGET_SOURCES}")
    target_sources ("${UNIT_NAME}Highlight" PRIVATE ${ARGV})
endfunction ()

# Adds sources that match given glob recurse patterns to current concrete unit.
function (concrete_sources)
    foreach (PATTERN ${ARGV})
        message (STATUS "    Add sources with recurse pattern \"${PATTERN}\".")
        file (GLOB_RECURSE SOURCES "${PATTERN}")
        internal_concrete_add_sources (${SOURCES})
    endforeach ()
endfunction ()

# Directly adds given sources without globbing and checking for existence.
function (concrete_sources_direct)
    message (STATUS "    Add sources directly \"${ARGV}\".")
    internal_concrete_add_sources (${ARGV})
endfunction ()

# Adds given sources that match given glob recurse patterns to highlight target of current concrete target.
function (concrete_highlight)
    foreach (PATTERN ${ARGV})
        file (GLOB_RECURSE SOURCES "${PATTERN}")
        target_sources ("${UNIT_NAME}Highlight" PRIVATE ${SOURCES})
    endforeach ()
endfunction ()

# Directly adds given sources to highlight target without globbing and checking for existence.
function (concrete_highlight_direct)
    target_sources ("${UNIT_NAME}Highlight" PRIVATE ${ARGV})
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
            target_include_directories ("${UNIT_NAME}Highlight" PRIVATE ${INCLUDE_DIR})
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
                reflected_target_link_libraries (TARGET "${UNIT_NAME}Highlight" PRIVATE "${DEPENDENCY}")
            endforeach ()
        endif ()

        if (DEFINED REQUIRE_CONCRETE_INTERFACE)
            foreach (DEPENDENCY ${REQUIRE_CONCRETE_INTERFACE})
                message (STATUS "    Require private scope interface of concrete \"${DEPENDENCY}\".")
                reflected_target_link_libraries (TARGET "${UNIT_NAME}" PRIVATE "${DEPENDENCY}Interface")
                reflected_target_link_libraries (TARGET "${UNIT_NAME}Highlight" PRIVATE "${DEPENDENCY}Interface")
            endforeach ()
        endif ()

        if (DEFINED REQUIRE_ABSTRACT)
            foreach (DEPENDENCY ${REQUIRE_ABSTRACT})
                message (STATUS "    Require private scope abstract \"${DEPENDENCY}\".")
                reflected_target_link_libraries (TARGET "${UNIT_NAME}" PRIVATE "${DEPENDENCY}")
                reflected_target_link_libraries (TARGET "${UNIT_NAME}Highlight" PRIVATE "${DEPENDENCY}")
            endforeach ()
        endif ()

        if (DEFINED REQUIRE_THIRD_PARTY)
            foreach (DEPENDENCY ${REQUIRE_THIRD_PARTY})
                message (STATUS "    Require private scope third party \"${DEPENDENCY}\".")
                reflected_target_link_libraries (TARGET "${UNIT_NAME}" PRIVATE "${DEPENDENCY}")
                reflected_target_link_libraries (TARGET "${UNIT_NAME}Highlight" PRIVATE "${DEPENDENCY}")
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
        target_compile_options ("${UNIT_NAME}Highlight" PRIVATE ${OPTIONS_PRIVATE})
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
        target_compile_definitions ("${UNIT_NAME}Highlight" PRIVATE ${DEFINITIONS_PRIVATE})
    endif ()
endfunction ()

# Informs build system that this concrete unit implements given abstract unit.
# Needed to pass correct compile definitions to concrete unit objects.
function (concrete_implements_abstract ABSTRACT_NAME)
    message (STATUS "    Implement abstract unit \"${ABSTRACT_NAME}\".")
    reflected_target_link_libraries (TARGET "${UNIT_NAME}" PRIVATE "${ABSTRACT_NAME}")
    get_unit_api_variables ("${ABSTRACT_NAME}")
    target_compile_definitions ("${UNIT_NAME}" PRIVATE "${UNIT_IMPLEMENTATION_MACRO}")
endfunction ()

# For internal use inside this file only.
# Starts preprocessing queue configurations if it is not yet started,
function (internal_concrete_preprocessing_queue_ensure_initialized)
    get_target_property (QUEUE_STARTED "${UNIT_NAME}" INTERNAL_CONCRETE_SOURCES_INITIAL)
    if (NOT QUEUE_STARTED)
        get_target_property (TARGET_SOURCES "${UNIT_NAME}" INTERNAL_CONCRETE_SOURCES)
        if (NOT TARGET_SOURCES)
            message (FATAL_ERROR "        Cannot start preprocessing queue when there is no sources!")
        endif ()

        set_target_properties ("${UNIT_NAME}" PROPERTIES INTERNAL_CONCRETE_SOURCES_INITIAL "${TARGET_SOURCES}")
    endif ()
endfunction ()

# For internal use inside this file only.
# Generates next write step output directory and outputs source and output directories to provided variables.
function (internal_concrete_preprocessing_queue_setup_output_step)
    cmake_parse_arguments (ARG "" "OUTPUT_SOURCE_DIR;OUTPUT_TARGET_DIR" "" ${ARGV})
    if (DEFINED ARG_UNPARSED_ARGUMENTS OR
            NOT DEFINED ARG_OUTPUT_SOURCE_DIR OR
            NOT DEFINED ARG_OUTPUT_TARGET_DIR)
        message (FATAL_ERROR "Incorrect function arguments!")
    endif ()

    set (GENERATED_DIRECTORY "${CMAKE_BINARY_DIR}/Generated/${UNIT_NAME}")
    get_target_property (INDEX "${UNIT_NAME}" INTERNAL_CONCRETE_QUEUE_OUTPUT_INDEX)

    if (INDEX)
        math (EXPR PREVIOUS_INDEX "${INDEX} - 1")
        set ("${ARG_OUTPUT_SOURCE_DIR}" "${GENERATED_DIRECTORY}/PPQ${PREVIOUS_INDEX}" PARENT_SCOPE)
    else ()
        set (INDEX 0)
        set ("${ARG_OUTPUT_SOURCE_DIR}" "${CMAKE_CURRENT_SOURCE_DIR}" PARENT_SCOPE)
        get_target_property (INITIAL_SOURCES "${UNIT_NAME}" INTERNAL_CONCRETE_SOURCES_INITIAL)

        foreach (INITIAL_SOURCE ${INITIAL_SOURCES})
            if (NOT INITIAL_SOURCE MATCHES "^${CMAKE_CURRENT_SOURCE_DIR}")
                message (FATAL_ERROR
                        "Preprocessing input file \"${INITIAL_SOURCE}\" must be "
                        "under current source dir \"${CMAKE_CURRENT_SOURCE_DIR}\".")
            endif ()
        endforeach ()
    endif ()

    file (MAKE_DIRECTORY "${GENERATED_DIRECTORY}/PPQ${INDEX}")
    set ("${ARG_OUTPUT_TARGET_DIR}" "${GENERATED_DIRECTORY}/PPQ${INDEX}" PARENT_SCOPE)

    math (EXPR NEXT_INDEX "${INDEX} + 1")
    set_target_properties ("${UNIT_NAME}" PROPERTIES INTERNAL_CONCRETE_QUEUE_OUTPUT_INDEX "${NEXT_INDEX}")
endfunction ()

# Preprocessing queue write step that runs compiler default preprocessing step and saves it as text files.
# Only preprocessing is executed and its results are copied back to preprocessing queue directories.
# Keep in mind that preprocessing will always be executed by compiler in the end of queue even if it was executed
# inside queue, because it is difficult to ensure that preprocessing will be omitted when using CMake.
# Also, this step can be used only once per concrete unit preprocessing queue!
# It has no arguments as preprocessing is fully dependant on compiler configuration.
function (concrete_preprocessing_queue_step_preprocess)
    internal_concrete_preprocessing_queue_ensure_initialized ()
    internal_concrete_preprocessing_queue_setup_output_step (
            OUTPUT_SOURCE_DIR PPQ_SOURCE_DIR
            OUTPUT_TARGET_DIR PPQ_TARGET_DIR)

    get_target_property (STEP_SOURCES "${UNIT_NAME}" INTERNAL_CONCRETE_SOURCES)
    set (STEP_OUTPUTS)

    add_library ("${UNIT_NAME}Preprocessed" OBJECT)
    target_sources ("${UNIT_NAME}Preprocessed" PRIVATE ${STEP_SOURCES})
    target_include_directories ("${UNIT_NAME}Preprocessed" PRIVATE $<TARGET_PROPERTY:${UNIT_NAME},INCLUDE_DIRECTORIES>)
    target_compile_definitions ("${UNIT_NAME}Preprocessed" PRIVATE $<TARGET_PROPERTY:${UNIT_NAME},COMPILE_DEFINITIONS>)
    target_compile_options ("${UNIT_NAME}Preprocessed" PRIVATE $<TARGET_PROPERTY:${UNIT_NAME},COMPILE_OPTIONS>)

    if (MSVC)
        target_compile_options ("${UNIT_NAME}Preprocessed" PRIVATE "/P")
    else ()
        target_compile_options ("${UNIT_NAME}Preprocessed" PRIVATE "-E")
    endif ()

    set (SOURCE_INDEX 0)
    foreach (STEP_SOURCE ${STEP_SOURCES})
        set (SOURCE_RELATIVE "${STEP_SOURCE}")
        cmake_path (RELATIVE_PATH SOURCE_RELATIVE BASE_DIRECTORY "${PPQ_SOURCE_DIR}")
        set (STEP_OUTPUT "${PPQ_TARGET_DIR}/${SOURCE_RELATIVE}")

        add_custom_command (
                OUTPUT "${STEP_OUTPUT}"
                COMMENT "Copying ${STEP_OUTPUT}."
                DEPENDS $<LIST:GET,$<TARGET_OBJECTS:${UNIT_NAME}Preprocessed>,${SOURCE_INDEX}>
                COMMAND
                ${CMAKE_COMMAND}
                -E copy_if_different
                "$<LIST:GET,$<TARGET_OBJECTS:${UNIT_NAME}Preprocessed>,${SOURCE_INDEX}>"
                "${STEP_OUTPUT}"
                VERBATIM)

        math (EXPR SOURCE_INDEX "${SOURCE_INDEX} + 1")
        list (APPEND STEP_OUTPUTS "${STEP_OUTPUT}")
    endforeach ()

    set_target_properties ("${UNIT_NAME}" PROPERTIES INTERNAL_CONCRETE_SOURCES "${STEP_OUTPUTS}")
endfunction ()

# Preprocessing queue write step that runs arbitrary executable with given arguments on filtered sources.
# This step takes sources from previous write step (or initial sources if there is no previous write step) and
# adds custom commands that execute given command on these sources (separately for every source) in order to provide
# new generation of files. Filter is used to selectively update files, filtered out files will be just copied to the
# new generation.
#
# Arguments:
# - COMMAND: Name of the executable or executable target that is being executed.
# - FILTER: Filter expression in format compatible with CMake MATCHES operation. Optional.
# - ARGUMENTS: List of arguments that are passed to command.
#              `$$INPUT` items are replaced with source file name from previous generation.
#              `$$INITIAL_INPUT` items are replaced with initial source file name.
#              `$$OUTPUT` items are replaced with output file name in new generation.
function (concrete_preprocessing_queue_step_apply)
    cmake_parse_arguments (ARG "" "COMMAND;FILTER" "ARGUMENTS" ${ARGV})
    if (DEFINED ARG_UNPARSED_ARGUMENTS OR
            NOT DEFINED ARG_COMMAND OR
            NOT DEFINED ARG_ARGUMENTS)
        message (FATAL_ERROR "Incorrect function arguments!")
    endif ()

    internal_concrete_preprocessing_queue_ensure_initialized ()
    internal_concrete_preprocessing_queue_setup_output_step (
            OUTPUT_SOURCE_DIR PPQ_SOURCE_DIR
            OUTPUT_TARGET_DIR PPQ_TARGET_DIR)

    get_target_property (STEP_SOURCES "${UNIT_NAME}" INTERNAL_CONCRETE_SOURCES)
    get_target_property (INITIAL_SOURCES "${UNIT_NAME}" INTERNAL_CONCRETE_SOURCES_INITIAL)
    set (STEP_OUTPUTS)

    foreach (STEP_SOURCE INITIAL_SOURCE IN ZIP_LISTS STEP_SOURCES INITIAL_SOURCES)
        set (SOURCE_RELATIVE "${STEP_SOURCE}")
        cmake_path (RELATIVE_PATH SOURCE_RELATIVE BASE_DIRECTORY "${PPQ_SOURCE_DIR}")
        set (STEP_OUTPUT "${PPQ_TARGET_DIR}/${SOURCE_RELATIVE}")

        if (NOT ARG_FILTER OR "${INITIAL_SOURCE}" MATCHES "${ARG_FILTER}")
            set (COMMAND_ARGUMENTS)
            foreach (ARGUMENT ${ARG_ARGUMENTS})
                if ("${ARGUMENT}" STREQUAL "$$INPUT")
                    list (APPEND COMMAND_ARGUMENTS "${STEP_SOURCE}")
                elseif ("${ARGUMENT}" STREQUAL "$$INITIAL_INPUT")
                    list (APPEND COMMAND_ARGUMENTS "${INITIAL_SOURCE}")
                elseif ("${ARGUMENT}" STREQUAL "$$OUTPUT")
                    list (APPEND COMMAND_ARGUMENTS "${STEP_OUTPUT}")
                else ()
                    list (APPEND COMMAND_ARGUMENTS "${ARGUMENT}")
                endif ()
            endforeach ()

            add_custom_command (
                    OUTPUT "${STEP_OUTPUT}"
                    COMMENT "Processing ${STEP_INPUT} with ${ARG_COMMAND}."
                    DEPENDS "${STEP_INPUT}"
                    COMMAND ${ARG_COMMAND} ${COMMAND_ARGUMENTS}
                    COMMAND_EXPAND_LISTS
                    VERBATIM)

            list (APPEND STEP_OUTPUTS "${STEP_OUTPUT}")
        else ()
            add_custom_command (
                    OUTPUT "${STEP_OUTPUT}"
                    COMMENT "Copying ${STEP_SOURCE}."
                    DEPENDS "${STEP_SOURCE}"
                    COMMAND ${CMAKE_COMMAND} -E copy_if_different "${STEP_SOURCE}" "${STEP_OUTPUT}"
                    VERBATIM)

            list (APPEND STEP_OUTPUTS "${STEP_OUTPUT}")
        endif ()
    endforeach ()

    set_target_properties ("${UNIT_NAME}" PROPERTIES INTERNAL_CONCRETE_SOURCES "${STEP_OUTPUTS}")
endfunction ()

# Processing queue gather step that runs arbitrary command on subset of files in order to produce one product file.
# Gather steps are used to extract data from filtered subsets of files from previous write step (or initial sources
# if there is no previous write step) and save it as generated product source file, for example it can be reflection
# for the whole unit. Product does not participates in preprocess generations. Command is executed for all files at
# once and must always have one product file. As gather steps do not modify generation files, it can be executed
# simultaneously with other steps or compilation.
#
# Arguments:
# - COMMAND: Name of the executable or executable target that is being executed.
# - PRODUCT: Relative name of product file. Will be created in generation directory.
# - FILTER: Filter expression in format compatible with CMake MATCHES operation. Optional.
# - ARGUMENTS: List of arguments that are passed to command.
#              `$$INPUT` items are replaced with list of filtered source files at current generation.
#              `$$PRODUCT` items are replaced with absolute product file name.
function (concrete_preprocessing_queue_step_gather)
    cmake_parse_arguments (ARG "" "COMMAND;PRODUCT;FILTER" "ARGUMENTS" ${ARGV})
    if (DEFINED ARG_UNPARSED_ARGUMENTS OR
            NOT DEFINED ARG_COMMAND OR
            NOT DEFINED ARG_PRODUCT OR
            NOT DEFINED ARG_ARGUMENTS)
        message (FATAL_ERROR "Incorrect function arguments!")
    endif ()

    internal_concrete_preprocessing_queue_ensure_initialized ()
    set (GENERATED_DIRECTORY "${CMAKE_BINARY_DIR}/Generated/${UNIT_NAME}")
    get_target_property (INDEX "${UNIT_NAME}" INTERNAL_CONCRETE_QUEUE_OUTPUT_INDEX)

    if (INDEX)
        math (EXPR PREVIOUS_INDEX "${INDEX} - 1")
        set (PPQ_SOURCE_DIR "${GENERATED_DIRECTORY}/PPQ${PREVIOUS_INDEX}")
    else ()
        set (PPQ_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
    endif ()

    get_target_property (STEP_SOURCES "${UNIT_NAME}" INTERNAL_CONCRETE_SOURCES)
    get_target_property (INITIAL_SOURCES "${UNIT_NAME}" INTERNAL_CONCRETE_SOURCES_INITIAL)
    set (PRODUCT_ABSOLUTE "${GENERATED_DIRECTORY}/${ARG_PRODUCT}")

    set (COMMAND_ARGUMENTS)
    foreach (ARGUMENT ${ARG_ARGUMENTS})
        if ("${ARGUMENT}" STREQUAL "$$INPUT")
            foreach (STEP_SOURCE INITIAL_SOURCE IN ZIP_LISTS STEP_SOURCES INITIAL_SOURCES)
                if (NOT ARG_FILTER OR "${INITIAL_SOURCE}" MATCHES "${ARG_FILTER}")
                    list (APPEND COMMAND_ARGUMENTS ${STEP_SOURCE})
                endif ()
            endforeach ()

        elseif ("${ARGUMENT}" STREQUAL "$$PRODUCT")
            list (APPEND COMMAND_ARGUMENTS "${PRODUCT_ABSOLUTE}")
        else ()
            list (APPEND COMMAND_ARGUMENTS "${ARGUMENT}")
        endif ()
    endforeach ()

    add_custom_command (
            OUTPUT "${PRODUCT_ABSOLUTE}"
            COMMENT "Gathering preprocessed data using ${ARG_COMMAND} for target \"${UNIT_NAME}\"."
            DEPENDS ${STEP_SOURCES}
            COMMAND ${ARG_COMMAND} ${COMMAND_ARGUMENTS}
            COMMAND_EXPAND_LISTS
            VERBATIM)

    get_target_property (PRODUCTS "${UNIT_NAME}" INTERNAL_CONCRETE_GATHER_PRODUCTS)
    if (NOT PRODUCTS)
        set (PRODUCTS)
    endif ()

    list (APPEND PRODUCTS "${PRODUCT_ABSOLUTE}")
    set_target_properties ("${UNIT_NAME}" PROPERTIES INTERNAL_CONCRETE_GATHER_PRODUCTS "${PRODUCTS}")
endfunction ()

# Starts configuration routine of abstract unit: headers that might have multiple implementations.
function (register_abstract UNIT_NAME)
    message (STATUS "Registering abstract \"${UNIT_NAME}\"...")
    add_library ("${UNIT_NAME}" INTERFACE)
    set_target_properties ("${UNIT_NAME}" PROPERTIES UNIT_TARGET_TYPE "Abstract")

    # Generate API header for shared library support.
    set (GENERATED_DIRECTORY "${CMAKE_BINARY_DIR}/Generated/${UNIT_NAME}/")
    file (MAKE_DIRECTORY "${GENERATED_DIRECTORY}")
    get_unit_api_variables ("${UNIT_NAME}")

    generate_api_header (
            API_MACRO "${UNIT_API_MACRO}"
            EXPORT_MACRO "${UNIT_IMPLEMENTATION_MACRO}"
            OUTPUT_FILE "${GENERATED_DIRECTORY}/${UNIT_API_FILE}")

    target_include_directories ("${UNIT_NAME}" INTERFACE "${GENERATED_DIRECTORY}")
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

# Registers alias to an already registered implementation.
# Arguments:
# - ALIAS: name of the alias implementation.
# - SOURCE: name of the source implementation.
function (abstract_alias_implementation)
    cmake_parse_arguments (IMPLEMENTATION "" "ALIAS;SOURCE" "" ${ARGN})
    if (DEFINED IMPLEMENTATION_UNPARSED_ARGUMENTS OR
            NOT DEFINED IMPLEMENTATION_ALIAS OR
            NOT DEFINED IMPLEMENTATION_SOURCE)
        message (FATAL_ERROR "Incorrect function arguments!")
    endif ()

    message (STATUS "    Add implementation alias \"${IMPLEMENTATION_ALIAS}\" to \"${IMPLEMENTATION_SOURCE}\".")
    add_library ("${UNIT_NAME}${IMPLEMENTATION_ALIAS}Marker" ALIAS "${UNIT_NAME}${IMPLEMENTATION_SOURCE}Marker")
endfunction ()

# Outputs list of all implementations of requested abstract unit. Omits aliases.
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
