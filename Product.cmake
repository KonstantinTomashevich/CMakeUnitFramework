# This file contains function for generating products (executables and shared libraries) with CMakeUnitFramework.

# Starts configuration routine of shared library.
function (register_shared_library ARTEFACT_NAME)
    message (STATUS "Registering shared library \"${ARTEFACT_NAME}\"...")
    add_library ("${ARTEFACT_NAME}" SHARED)
    set (ARTEFACT_NAME "${ARTEFACT_NAME}" PARENT_SCOPE)

    # Force Windows-like behaviour on rpath-driven unix builds.
    if (UNIX)
        set_target_properties ("${ARTEFACT_NAME}" PROPERTIES BUILD_RPATH "\$ORIGIN")
    endif ()
endfunction ()

# Adds given units to current shared library content.
# Arguments:
# - SCOPE: Scope in which these units are being added, either PUBLIC or PRIVATE.
# - ABSTRACT: list of abstract units implementations that are being added to this library in format
#             "ABSTRACT_UNIT_NAME=IMPLEMENTATION_NAME".
# - CONCRETE: list of concrete units that are being added to this library.
function (shared_library_include)
    cmake_parse_arguments (INCLUDE "" "SCOPE" "ABSTRACT;CONCRETE" ${ARGV})
    if (DEFINED INCLUDE_UNPARSED_ARGUMENTS OR
            NOT DEFINED INCLUDE_SCOPE OR (
            NOT DEFINED INCLUDE_ABSTRACT AND
            NOT DEFINED INCLUDE_CONCRETE))
        message (FATAL_ERROR "Incorrect function arguments!")
    endif ()

    if (INCLUDE_SCOPE STREQUAL "PUBLIC")
        set (SCOPE_STRING "public")
    elseif (INCLUDE_SCOPE STREQUAL "PRIVATE")
        set (SCOPE_STRING "private")
    else ()
        message (FATAL_ERROR "Incorrect function arguments!")
    endif ()

    if (DEFINED INCLUDE_ABSTRACT)
        foreach (SELECTION ${INCLUDE_ABSTRACT})
            if (NOT SELECTION MATCHES "^([A-Za-z0-9_]+)=([A-Za-z0-9_]+)$")
                message (SEND_ERROR "Unable to parse abstract selection \"${SELECTION}\".")
            else ()

                set (ABSTRACT_NAME "${CMAKE_MATCH_1}")
                set (IMPLEMENTATION_NAME "${CMAKE_MATCH_2}")
                message (STATUS "    Add ${SCOPE_STRING} implementation \"${IMPLEMENTATION_NAME}\" of abstract \"${ABSTRACT_NAME}\".")

                set (IMPLEMENTATION_TARGET "${ABSTRACT_NAME}${IMPLEMENTATION_NAME}Marker")
                # Redirect to aliased implementation if it is an alias,
                # because it will be easier to verify library with aliases resolved.
                get_target_property (ALIASED_IMPLEMENTATION "${IMPLEMENTATION_TARGET}" ALIASED_TARGET)

                if (ALIASED_IMPLEMENTATION)
                    set (IMPLEMENTATION_TARGET "${ALIASED_IMPLEMENTATION}")
                endif ()

                if (TARGET "${IMPLEMENTATION_TARGET}")
                    get_target_property (REMAP "${IMPLEMENTATION_TARGET}" IMPLEMENTATION_REMAP)

                    if (REMAP STREQUAL "REMAP-NOTFOUND")
                        message (SEND_ERROR "Abstract \"${ABSTRACT_NAME}\" implementation \"${IMPLEMENTATION_NAME}\" is empty!")
                    else ()
                        reflected_target_link_libraries (
                                TARGET "${ARTEFACT_NAME}" ${INCLUDE_SCOPE} "${IMPLEMENTATION_TARGET}")

                        foreach (PART_NAME ${REMAP})
                            message (STATUS "        Include part \"${PART_NAME}\".")
                            reflected_target_link_libraries (TARGET "${ARTEFACT_NAME}" ${INCLUDE_SCOPE} "${PART_NAME}")
                        endforeach ()
                    endif ()

                else ()
                    message (SEND_ERROR "Abstract \"${ABSTRACT_NAME}\" implementation \"${IMPLEMENTATION_NAME}\" can only be included after it is registered!")
                endif ()

            endif ()
        endforeach ()
    endif ()

    if (DEFINED INCLUDE_CONCRETE)
        foreach (DEPENDENCY ${INCLUDE_CONCRETE})
            message (STATUS "    Add ${SCOPE_STRING} scope concrete \"${DEPENDENCY}\".")
            reflected_target_link_libraries (TARGET "${ARTEFACT_NAME}" ${INCLUDE_SCOPE} "${DEPENDENCY}")
        endforeach ()
    endif ()

endfunction ()

# Links other shared libraries to current shared library.
# Arguments:
# - PRIVATE: list of shared libraries to be linked in private scope.
# - PUBLIC: list of shared libraries to be linked in public scope.
function (shared_library_link_shared_library)
    cmake_parse_arguments (LINK "" "" "PRIVATE;PUBLIC" ${ARGV})
    if (DEFINED LINK_UNPARSED_ARGUMENTS OR
            NOT DEFINED LINK_PRIVATE AND
            NOT DEFINED LINK_PUBLIC)
        message (FATAL_ERROR "Incorrect function arguments!")
    endif ()

    foreach (LIBRARY_TARGET ${LINK_PRIVATE})
        message (STATUS "    Link shared library \"${LIBRARY_TARGET}\" in private scope.")
        reflected_target_link_libraries (TARGET "${ARTEFACT_NAME}" PRIVATE "${LIBRARY_TARGET}")
    endforeach ()

    foreach (LIBRARY_TARGET ${LINK_PUBLIC})
        message (STATUS "    Link shared library \"${LIBRARY_TARGET}\" in public scope.")
        reflected_target_link_libraries (TARGET "${ARTEFACT_NAME}" PUBLIC "${LIBRARY_TARGET}")
    endforeach ()
endfunction ()

# Verifies that there is no missing abstract unit implementations or concrete units in current shared library.
function (shared_library_verify)
    message (STATUS "    Verifying...")
    find_linked_targets_recursively (TARGET "${ARTEFACT_NAME}" OUTPUT ALL_LOCAL_TARGETS ARTEFACT_SCOPE)
    find_linked_targets_recursively (TARGET "${ARTEFACT_NAME}" OUTPUT ALL_VISIBLE_TARGETS CHECK_VISIBILITY)

    foreach (LOCAL_TARGET ${ALL_LOCAL_TARGETS})
        get_target_property (TARGET_TYPE "${LOCAL_TARGET}" UNIT_TARGET_TYPE)
        if (TARGET_TYPE STREQUAL "ConcreteInterface")

            get_target_property (CONCRETE_REQUIREMENT "${LOCAL_TARGET}" REQUIRED_CONCRETE_UNIT)
            list (FIND ALL_VISIBLE_TARGETS "${CONCRETE_REQUIREMENT}" REQUIREMENT_INDEX)

            if (REQUIREMENT_INDEX EQUAL -1)
                message (SEND_ERROR "Target \"${ARTEFACT_NAME}\": Missing \"${CONCRETE_REQUIREMENT}\". Found interface, but no implementation.")
            endif ()

        elseif (TARGET_TYPE STREQUAL "Abstract")

            get_target_property (IMPLEMENTATIONS "${LOCAL_TARGET}" IMPLEMENTATIONS)
            set (FOUND_IMPLEMENTATION OFF)

            foreach (IMPLEMENTATION ${IMPLEMENTATIONS})
                list (FIND ALL_VISIBLE_TARGETS "${LOCAL_TARGET}${IMPLEMENTATION}Marker" IMPLEMENTATION_INDEX)
                if (NOT IMPLEMENTATION_INDEX EQUAL -1)
                    if (FOUND_IMPLEMENTATION)
                        message (SEND_ERROR "Target \"${ARTEFACT_NAME}\": Found multiple implementations of abstract \"${LOCAL_TARGET}\".")
                    else ()
                        set (FOUND_IMPLEMENTATION ON)
                    endif ()
                endif ()
            endforeach ()

            if (NOT FOUND_IMPLEMENTATION)
                message (SEND_ERROR "Target \"${ARTEFACT_NAME}\": Missing abstract \"${LOCAL_TARGET}\" implementation.")
            endif ()

        endif ()
    endforeach ()
endfunction ()

# Adds build commands for copying required linked artefacts to current shared library output location.
function (shared_library_copy_linked_artefacts)
    find_linked_shared_libraries (TARGET "${ARTEFACT_NAME}" OUTPUT REQUIRED_LIBRARIES)
    foreach (LIBRARY_TARGET ${REQUIRED_LIBRARIES})
        setup_shared_library_copy (
                LIBRARY "${LIBRARY_TARGET}"
                USER "${ARTEFACT_NAME}"
                OUTPUT "$<TARGET_FILE_DIR:${ARTEFACT_NAME}>")
    endforeach ()
endfunction ()

# Starts configuration routine of executable.
function (register_executable ARTEFACT_NAME)
    message (STATUS "Registering executable \"${ARTEFACT_NAME}\"...")
    add_executable ("${ARTEFACT_NAME}")
    set (ARTEFACT_NAME "${ARTEFACT_NAME}" PARENT_SCOPE)

    # Force Windows-like behaviour on rpath-driven unix builds.
    if (UNIX)
        set_target_properties ("${ARTEFACT_NAME}" PROPERTIES BUILD_RPATH "\$ORIGIN")
    endif ()
endfunction ()

# Adds given units to current executable content.
# Arguments:
# - ABSTRACT: list of abstract units implementations that are being added to this executable in format
#             "ABSTRACT_UNIT_NAME=IMPLEMENTATION_NAME".
# - CONCRETE: list of concrete units that are being added to this executable.
function (executable_include)
    # Technically, we're doing the same thing except for the scope, so it is ok to call shared library function.
    shared_library_include (SCOPE PRIVATE ${ARGV})
endfunction ()

# Links given shared libraries to current executable.
function (executable_link_shared_libraries)
    foreach (LIBRARY_TARGET ${ARGV})
        message (STATUS "    Link shared library \"${LIBRARY_TARGET}\".")
        reflected_target_link_libraries (TARGET "${ARTEFACT_NAME}" PRIVATE "${LIBRARY_TARGET}")
    endforeach ()
endfunction ()

# Verifies that there is no missing abstract unit implementations or concrete units in current executable.
function (executable_verify)
    # Technically, we're doing the same thing except for the scope, so it is ok to call shared library function.
    shared_library_verify ()
endfunction ()

# Adds build commands for copying required linked artefacts to current executable.
function (executable_copy_linked_artefacts)
    shared_library_copy_linked_artefacts ()
endfunction ()
