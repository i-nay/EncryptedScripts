#!/bin/bash
#================================================================
# HEADER
#================================================================
#+ USAGE:
#+    ./${SCRIPT_NAME} [OPTIONS] args ...
#+
#+ OPTIONS:
#+    -a, --api                     Run Test Api
#+    -h, --help                    Print this help
#+    -v, --version                 Print script information
#+
#================================================================
#- VERSION:
#-    Last revised: 2023/03/12
#-
#================================================================
#  HISTORY:
#     2022/10/25 : Script creation
#     2023/03/12 : Use chatgpt to refactor the code
#================================================================
# END_OF_HEADER
#================================================================
# Use the `trap` command to perform cleanup operations when the script exits
# Delete temporary files and directories indicated by variables `$TMP_DIR` and `$TMP_FILENAME`
trap 'rm -rf "$TMP_DIR" "$TMP_FILENAME"' EXIT
# Create function
# Define a function called `scriptinfo`
scriptinfo() {
  # Specify line filters to extract different types of comments in the script head
  headFilter="^#-" # information lines
  [[ "$1" = "usg" ]] && headFilter="^#+"
  [[ "$1" = "ver" ]] && headFilter="^#-"
  # Use `head` and `grep` commands to extract comments from the script header,
  # limited to the number of lines set by the `SCRIPT_HEADSIZE` environment variable
  # Use the `sed` command to delete the comment filter pattern and substitute `SCRIPT_NAME` variable with actual script name
  head -"${SCRIPT_HEADSIZE:-99}" "${0}" | grep -e "${headFilter}" | sed -e "s/${headFilter}//g" -e "s/\${SCRIPT_NAME}/${SCRIPT_NAME}/g"
}
# Define a function called `extract`
extract() {
  # Check if the first argument is provided, print an error message and exit if not
  # Assign the first argument to a variable `FILE`
  [[ -z "$1" ]] && echo "no option" && exit 1 || FILE=$1
  # Assign a default output directory to the second argument if it is not provided
  # Otherwise, use the second argument as the output directory
  [[ -z "$2" ]] && OUT_DIR=$TMP_DIR || OUT_DIR=$2
  # Use `tar` command to extract the contents of the archive file to the specified output directory
  tar -zxf "$FILE" -C "$OUT_DIR"
}
# Define a function called `decrypt`
decrypt() {
  # Check if the first argument is provided, print an error message and exit if not
  # Assign the first argument to a variable `FILE`
  [[ -z "$1" ]] && echo "no option" && exit 1 || FILE=$1
  # Assign a default output filename to the second argument if it is not provided
  # Otherwise, use the second argument as the output filename
  [[ -z "$2" ]] && OUT_FILE=$TMP_FILENAME || OUT_FILE=$2
  # Use `gpg` command to decrypt the input file using a passphrase stored in an environment variable,
  # write the output to the specified output file
  gpg --quiet --batch --yes --decrypt --passphrase="$LARGE_SECRET_PASSPHRASE" -o "$OUT_FILE" -d "$FILE"
}
# Create variable
# Create a temporary directory and filename for later cleanup
TMP_DIR=$(mktemp -d) || exit 1
TMP_FILENAME=$(mktemp) || exit 1
# Get the file name of the current script
SCRIPT_NAME="$(basename "${0}")"
# Find the line number of the first line that starts with "# END_OF_HEADER" in the script file
SCRIPT_HEADSIZE=$(grep -sn "^# END_OF_HEADER" "${0}" | head -1 | cut -f1 -d:)
# Define short options, where "a:" means the option "a" requires an argument
SHORT_OPTIONS="a:,h,v"
# Define long options, where "api:" means the option "api" requires an argument
LONG_OPTIONS="api:,help,version"
# Parse the command line parameters into short options, long options, and their arguments, and assign to the variable "ARGS"
# -a: Stop parsing options at the first non-option argument and allows options after non-option arguments
# -o: Define short options
# -l: Define long options
# --: signal the end of options and treat all further arguments as non-option arguments
ARGS=$(getopt -a -o $SHORT_OPTIONS -l $LONG_OPTIONS -- "$@")
# Check the exit status of the previous command, and if it's not 0, print an error message and exit the script
# $? is a special variable that contains the exit status of the previous command
# -ne is a comparison command that means "not equal to"
# The && operator only executes the echo command if the previous command exits with status 0 ("true")
# ${SCRIPT_NAME} is the name of your shell script, obtained via the $0 variable
[ $? -ne 0 ] && {
  echo "Try ./${SCRIPT_NAME} --help for more information." >&2
  exit 1
}
# Use eval to set the positional parameters ($1, $2, etc.) to the values of the command line arguments
# $ARGS contains the command line arguments, passed in from getopt
# The double quotes around $ARGS ensure that any arguments with spaces are treated as a single argument
# The eval command evaluates the resulting string as a shell command, setting positional parameters to the argument values
# The set command sets the positional parameters to the new values
# The "--" option is used to signal the end of options, and treat all remaining arguments as positional parameters
eval set -- "$ARGS"
# Start an infinite loop
while true; do
  # Start a switch/case control structure to determine the value of the first parameter $1
  case "$1" in
    -a | --api) # This option handles API testing
      echo "Decrypt the file"
      decrypt api && extract "$TMP_FILENAME"
      DIR="${TMP_DIR}/api"
      case "$2" in
        1) # This option tests Api.Read function
          echo "Test Api [Api.Read]"
          decrypt "${DIR}/read.gpg" run.py
          python run.py
          shift 2
          ;;
        2) # This option tests Api.Write function
          echo "Test Api [Api.Write]"
          decrypt "${DIR}/write.gpg" run.py
          python run.py
          shift 2
          ;;
        3) # This option tests Api.Token function
          echo "Test Api [Api.Token]"
          decrypt "${DIR}/token.gpg" run.py
          python run.py
          shift 2
          ;;
        *) # This option handles invalid arguments for API testing
          echo "bad option: $2"
          shift 2
          ;;
      esac
      ;;
    -h | --help) # This option displays usage information for this script
      scriptinfo usg
      shift
      ;;
    -v | --version) # This option displays version information for this script
      scriptinfo ver
      shift
      ;;
    --) # This option ends argument parsing
      shift
      break
      ;;
    *) # This option handles internal errors
      echo "Internal error!"
      exit 1
      ;;
  esac
done
