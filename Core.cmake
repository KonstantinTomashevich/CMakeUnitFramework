# This file contains quality-of-life improvements for CMake on top of which CMakeUnitFramework is built upon, including:
# - Easy to use search through target linking tree.
# - Function for setting up shared library copying to user targets.
# - Other minor improvements.

define_property (TARGET PROPERTY INTERFACE_LINKED_TARGETS
        BRIEF_DOCS "Targets linked in INTERFACE scope to this target using reflected_target_link_libraries."
        FULL_DOCS "We use reflected_target_link_libraries in order to make it easy to traverse linking hierarchy.")

define_property (TARGET PROPERTY PUBLIC_LINKED_TARGETS
        BRIEF_DOCS "Targets linked in PUBLIC scope to this target using reflected_target_link_libraries."
        FULL_DOCS "We use reflected_target_link_libraries in order to make it easy to traverse linking hierarchy.")

define_property (TARGET PROPERTY PRIVATE_LINKED_TARGETS
        BRIEF_DOCS "Targets linked in PRIVATE scope to this target using reflected_target_link_libraries."
        FULL_DOCS "We use reflected_target_link_libraries in order to make it easy to traverse linking hierarchy.")

# Adapter for target_link_libraries that keeps linked libraries accessible in appropriate target properties.
# Arguments:
# - TARGET: target to which we are linking.
# - INTERFACE: targets that are linked to it in INTERFACE scope.
# - PUBLIC: targets that are linked to it in PUBLIC scope.
# - PRIVATE: targets that are linked to it in PRIVATE scope.
function (reflected_target_link_libraries)
    cmake_parse_arguments (LINK "" "TARGET" "INTERFACE;PUBLIC;PRIVATE" ${ARGV})
    if (DEFINED LINK_UNPARSED_ARGUMENTS OR
            NOT DEFINED LINK_TARGET OR (
            NOT DEFINED LINK_INTERFACE AND
            NOT DEFINED LINK_PUBLIC AND
            NOT DEFINED LINK_PRIVATE))
        message (FATAL_ERROR "Incorrect function arguments!")
    endif ()

    foreach (SCOPE INTERFACE PUBLIC PRIVATE)
        if (DEFINED LINK_${SCOPE})

            target_link_libraries ("${LINK_TARGET}" "${SCOPE}" ${LINK_${SCOPE}})
            get_target_property (LINKED_TARGETS "${LINK_TARGET}" "${SCOPE}_LINKED_TARGETS")

            if (LINKED_TARGETS STREQUAL "LINKED_TARGETS-NOTFOUND")
                set (LINKED_TARGETS)
            endif ()

            list (APPEND LINKED_TARGETS ${LINK_${SCOPE}})
            set_target_properties ("${LINK_TARGET}" PROPERTIES "${SCOPE}_LINKED_TARGETS" "${LINKED_TARGETS}")

        endif ()
    endforeach ()

endfunction ()

# Recursively searches for linked targets of given target and outputs them to given variable.
# Arguments:
# - TARGET: root target to start the search.
# - OUTPUT: name of the output variable to store the found targets.
# - ARTEFACT_SCOPE: option, if passed, search will not exit artefact (shared library or executable) scope.
# - CHECK_VISIBILITY: option, if passed, only targets that are directly visible to root target will be added to list.
function (find_linked_targets_recursively)
    cmake_parse_arguments (SEARCH "ARTEFACT_SCOPE;CHECK_VISIBILITY" "TARGET;OUTPUT" "" ${ARGV})
    if (DEFINED SEARCH_UNPARSED_ARGUMENTS OR
            NOT DEFINED SEARCH_TARGET OR
            NOT DEFINED SEARCH_OUTPUT)
        message (FATAL_ERROR "Incorrect function arguments!")
    endif ()

    set (ALL_LINKED_TARGETS)
    set (SCAN_QUEUE)
    list (APPEND SCAN_QUEUE ${SEARCH_TARGET})
    list (LENGTH SCAN_QUEUE SCAN_QUEUE_LENGTH)

    while (SCAN_QUEUE_LENGTH GREATER 0)
        list (POP_BACK SCAN_QUEUE ITEM)
        if (TARGET ${ITEM})
            set (CHECK_SCOPES)
            list (APPEND CHECK_SCOPES INTERFACE PUBLIC)

            if (NOT SEARCH_CHECK_VISIBILITY OR ITEM STREQUAL SEARCH_TARGET)
                list (APPEND CHECK_SCOPES PRIVATE)
            endif ()

            foreach (SCOPE ${CHECK_SCOPES})
                get_target_property (LINKED_TARGETS ${ITEM} "${SCOPE}_LINKED_TARGETS")
                if (NOT "${LINKED_TARGETS}" STREQUAL "LINKED_TARGETS-NOTFOUND")
                    foreach (LINKED_TARGET ${LINKED_TARGETS})
                        if (TARGET ${LINKED_TARGET})

                            get_target_property (TARGET_TYPE "${LINKED_TARGET}" TYPE)
                            if (NOT SEARCH_ARTEFACT_SCOPE OR NOT TARGET_TYPE STREQUAL "SHARED_LIBRARY")
                                list (FIND ALL_LINKED_TARGETS "${LINKED_TARGET}" LINKED_TARGET_INDEX)
                                if (LINKED_TARGET_INDEX EQUAL -1)
                                    list (APPEND ALL_LINKED_TARGETS ${LINKED_TARGET})
                                    list (APPEND SCAN_QUEUE ${LINKED_TARGET})
                                endif ()
                            endif ()

                        # Do not print warnings for standard C++ library and standard math library.
                        elseif (NOT LINKED_TARGET STREQUAL "stdc++" AND NOT LINKED_TARGET STREQUAL "m")
                            message (WARNING "Unable to find linked target \"${LINKED_TARGET}\".")
                        endif ()
                    endforeach ()
                endif ()
            endforeach ()

        else ()
            message (WARNING "Unable to find linked target \"${ITEM}\".")
        endif ()

        list (LENGTH SCAN_QUEUE SCAN_QUEUE_LENGTH)
    endwhile ()

    set ("${SEARCH_OUTPUT}" "${ALL_LINKED_TARGETS}" PARENT_SCOPE)
endfunction ()

# Recursively searches for linked shared libraries that are needed for given target.
# Arguments:
# - TARGET: target for which we're searching.
# - OUTPUT: name of the output variable to store the found shared libraries.
function (find_linked_shared_libraries)
    cmake_parse_arguments (SEARCH "" "TARGET;OUTPUT" "" ${ARGV})
    if (DEFINED SEARCH_UNPARSED_ARGUMENTS OR
            NOT DEFINED SEARCH_TARGET OR
            NOT DEFINED SEARCH_OUTPUT)
        message (FATAL_ERROR "Incorrect function arguments!")
    endif ()

    set (LIBRARIES)
    find_linked_targets_recursively (TARGET "${SEARCH_TARGET}" OUTPUT ALL_LINKED_TARGETS)

    foreach (LINKED_TARGET ${ALL_LINKED_TARGETS})
        get_target_property (TARGET_TYPE "${LINKED_TARGET}" TYPE)
        if (TARGET_TYPE STREQUAL "SHARED_LIBRARY")
            list (APPEND LIBRARIES "${LINKED_TARGET}")
        endif ()
    endforeach ()

    set ("${SEARCH_OUTPUT}" "${LIBRARIES}" PARENT_SCOPE)
endfunction ()

# Setups custom target for copying shared library to target directory for specified user.
# Arguments:
# - LIBRARY: shared library to copy.
# - USER: user target to which we add copy target as dependency.
# - OUTPUT: output directory to which shared library should be copied.
# - DEPENDENCIES: optional list of additional dependencies for copy target, for example directory creation targets.
function (setup_shared_library_copy)
    cmake_parse_arguments (COPY "" "LIBRARY;USER;OUTPUT" "DEPENDENCIES" ${ARGV})
    if (DEFINED SEARCH_UNPARSED_ARGUMENTS OR
            NOT DEFINED COPY_LIBRARY OR
            NOT DEFINED COPY_USER OR
            NOT DEFINED COPY_OUTPUT)
        message (FATAL_ERROR "Incorrect function arguments!")
    endif ()

    set (CUSTOM_TARGET_NAME "Copy${COPY_LIBRARY}For${COPY_USER}")
    string (REPLACE "::" "_" CUSTOM_TARGET_NAME "${CUSTOM_TARGET_NAME}")

    if (UNIX)
        add_custom_target ("${CUSTOM_TARGET_NAME}"
                COMMAND ${CMAKE_COMMAND} -E copy
                $<TARGET_SONAME_FILE:${COPY_LIBRARY}> "${COPY_OUTPUT}/$<TARGET_SONAME_FILE_NAME:${COPY_LIBRARY}>"
                COMMENT "Copying \"${COPY_LIBRARY}\" for \"${COPY_USER}\"."
                COMMAND_EXPAND_LISTS VERBATIM)
    else ()
        add_custom_target ("${CUSTOM_TARGET_NAME}"
                COMMAND ${CMAKE_COMMAND} -E copy
                $<TARGET_FILE:${COPY_LIBRARY}> "${COPY_OUTPUT}/$<TARGET_FILE_NAME:${COPY_LIBRARY}>"
                COMMENT "Copying \"${COPY_LIBRARY}\" for \"${COPY_USER}\"."
                COMMAND_EXPAND_LISTS VERBATIM)
    endif ()

    add_dependencies ("${CUSTOM_TARGET_NAME}" "${COPY_LIBRARY}" ${COPY_DEPENDENCIES})
    add_dependencies ("${COPY_USER}" "${CUSTOM_TARGET_NAME}")
endfunction ()

# Utility function that adds all child directories of current directory as subdirectories.
# Useful for flat directory structure where it is better to just add everything than list lots entries by hand.
function (add_all_subdirectories)
    file (GLOB RELATIVES "*")
    foreach (RELATIVE ${RELATIVES})
        if (IS_DIRECTORY "${RELATIVE}")
            add_subdirectory ("${RELATIVE}")
        endif ()
    endforeach ()
endfunction ()
