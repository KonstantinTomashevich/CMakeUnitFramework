# CMake script that copies source file and prepends line directive that points to the actual source.
# Needed for the cases when we plainly copy files from source directory to binary directory and need to preserve
# line information properly for the compilation and debug.
#
# Arguments:
# - INPUT: Path to input file that needs to be copied.
# - OUTPUT: Output path to which data will be written.
file (READ "${INPUT}" INPUT_CONTENT)
file (WRITE "${OUTPUT}" "#line 1 \"${INPUT}\"\n${INPUT_CONTENT}")
