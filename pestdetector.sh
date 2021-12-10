#!/bin/bash
#
# title:        pestdetector.sh
# description:  This script creates images and detects rats and other forms of 
#               pest like cockroaches
# author:       Dr. Christian Baun
# url:          https://github.com/christianbaun/pestdetector
# license:      GPLv3
# date:         December 10th 2021
# version:      0.15
# bash_version: tested with 5.1.4(1)-release
# requires:     The functions in functionlibrary.sh
#               libcamera-still command line tool that uses the libcamera open 
#               source camera stack. As alternative, the legacy raspistill
#               command line tool can be used.
# optional:     none
# notes:        This script has been developed to run on a Raspberry Pi 4 
#               (4 GB RAM). Two LCD 4x20 displays with HD44780 controllers, 
#               connected via the I2C interface are used to inform about the
#               work of the pest detector.
# example:      ./pestdetector.sh
# ----------------------------------------------------------------------------

# Function library with thse functions:
# make_a_picture()
# detect_objects()
# check_if_objects_have_been_deteted()
# print_result_on_LCD()
# print_no_object_detected_on_LCD()
# prevent_directory_overflow()
. functionlibrary.sh

# Path of the directory for the most recent picture
DIRECTORY_MOST_RECENT_IMAGE="/dev/shm/most_recent_image"
# Path of the directory for the picture
DIRECTORY_IMAGES="images"
#DIRECTORY_IMAGES_MAX_SIZE="1073741824"  # 1 GB max
DIRECTORY_IMAGES_MAX_SIZE="50000"  # 50 MB max for testing purposes
DIRECTORY_LOGS="logs"
DIRECTORY_LOGS_MAX_SIZE="1048576" # 1 MB max

STANDARDMODELL=model_2021_07_08_rat_bug_hedgehog

if [ -z "$1" ]; then
  # No model provided as parameter => mode default model: $STANDARDMODELL
  MODELLNAME=$STANDARDMODELL
fi

MODEL="/home/pi/$MODELLNAME"
LABELS="/home/pi/$MODELLNAME/labelmap.txt"

LCD_DRIVER1="lcd_output_display1.py"
LCD_DRIVER2="lcd_output_display2.py"

RED='\033[0;31m'          # Red color
NC='\033[0m'              # No color
GREEN='\033[0;32m'        # Green color
YELLOW='\033[0;33m'       # Yellow color
BLUE='\033[0;34m'         # Blue color
WHITE='\033[0;37m'        # White color

# At the very beginning, no objects have been detected
HIT=0

# Check if the logs directory already exists
if [ -e ${DIRECTORY_LOGS} ] ; then
  # If the directory for the logs already exists
   echo -e "${GREEN}[OK] The directory ${DIRECTORY_LOGS} already exists in the local directory.${NC}" | ${TEE_PROGRAM_LOG}
else
  # If the directory for the logs does not already exist => create it
  if mkdir ${DIRECTORY_LOGS} ; then
    echo -e "${GREEN}[OK] The local directory ${DIRECTORY_LOGS} has been created.${NC}" | ${TEE_PROGRAM_LOG}
  else
    echo -e "${RED}[ERROR] Unable to create the local directory ${DIRECTORY_LOGS}.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
  fi
fi

# Check if the required command line tools are available
if ! [ -x "$(command -v hostname)" ]; then
    echo -e "${RED}[ERROR] The command line tool hostname tool is missing.${NC}" | ${TEE_PROGRAM_LOG} 
    exit 1
else
    HOSTNAME=$(hostname)
    # Store timestamp of the date in a variable
    DATE_TIME_STAMP=$(date +%Y-%m-%d)
    CLOCK_TIME_STAMP=$(date +%H-%M-%S)
    echo -e "${DATE_TIME_STAMP} ${CLOCK_TIME_STAMP} Welcome to pestdetector on host ${HOSTNAME}" | ${TEE_PROGRAM_LOG} 
fi

# Definition of the logfile specification.
# This can be attached with a pipe to echo commands
TEE_PROGRAM_LOG=" tee -a ${DIRECTORY_LOGS}/${DATE_TIME_STAMP}-pestdetector_log.txt"
TEE_OBJECTS_DETECTED=" tee -a ${DIRECTORY_LOGS}/${DATE_TIME_STAMP}-detected_objects.txt"

# ------------------------------
# | Check the operating system |
# ------------------------------

if [[ "$OSTYPE" == "linux-gnu" || "$OSTYPE" == "linux-gnueabihf" ]]; then
    # Linux
    echo -e "${YELLOW}[INFO] The operating system is Linux: ${OSTYPE}${NC}" | ${TEE_PROGRAM_LOG} 
elif [[ "$OSTYPE" == "freebsd"* ]]; then
    # FreeBSD
    echo -e "${YELLOW}[INFO] The operating system is FreeBSD: ${OSTYPE}${NC}" | ${TEE_PROGRAM_LOG} 
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # Mac OS X
    echo -e "${YELLOW}[INFO] The operating system is Mac OS X: ${OSTYPE}${NC}" | ${TEE_PROGRAM_LOG} 
elif [[ "$OSTYPE" == "msys" ]]; then
    # Windows 
    echo -e "${YELLOW}[INFO] The operating system is Windows: ${OSTYPE}${NC}" | ${TEE_PROGRAM_LOG} 
elif [[ "$OSTYPE" == "cygwin" ]]; then
    # POSIX compatibility layer for Windows
    echo -e "${YELLOW}[INFO] POSIX compatibility layer for Windows detected: ${OSTYPE}${NC}" | ${TEE_PROGRAM_LOG} 
else
    # Unknown
    echo -e "${YELLOW}[INFO] The operating system is unknown: ${OSTYPE}${NC}" | ${TEE_PROGRAM_LOG} 
fi

# ----------------------------------------------------
# | Check that we have a working internet connection |
# ----------------------------------------------------

# We shall check at least 5 times
LOOP_VARIABLE=5  
#until LOOP_VARIABLE is greater than 0 
while [ $LOOP_VARIABLE -gt "0" ]; do 
  # Check if we have a working network connection by sending a ping to 8.8.8.8
  if ping -q -c 1 -W 1 8.8.8.8 >/dev/null ; then
    echo -e "${GREEN}[OK] This computer has a working internet connection.${NC}" | ${TEE_PROGRAM_LOG} 
    # Skip entire rest of loop.
    break
  else
    echo -e "${YELLOW}[INFO] The internet connection is not working now. Will check again.${NC}" | ${TEE_PROGRAM_LOG} 
    # Decrement variable
    LOOP_VARIABLE=$((LOOP_VARIABLE-1))
    if [ "$LOOP_VARIABLE" -eq 0 ] ; then
      echo -e "${RED}[INFO] This computer has no working internet connection.${NC}" | ${TEE_PROGRAM_LOG} 
    fi
    # Wait a moment. 
    sleep 1
  fi
done

# ----------------------------------------------------------
# | Check if the required command line tools are available |
# ----------------------------------------------------------

# If libcamera-still will not work, we will try raspistill later, but for the moment we hope it will work
TRY_LEGACY_RASPISTILL=0

# Check if the command line tool libcamera-still is available
if [ -x "$(command -v libcamera-still)" ]; then
  echo -e "${GREEN}[OK] The tool libcamera-still has been found on this system.${NC}" | ${TEE_PROGRAM_LOG} 
  libcamera-still &> /dev/null
  if [ $? -eq 0 ] ; then
    echo -e "${GREEN}[OK] The tool libcamera-still appears to work well.${NC}" | ${TEE_PROGRAM_LOG} 
  else
    echo -e "${YELLOW}[INFO] The tool libcamera-still fails. I try the legacy raspistill instead.${NC}" | ${TEE_PROGRAM_LOG} 
    # We need to try raspistill...
    TRY_LEGACY_RASPISTILL=1
  fi
fi

# If libcamera-still is not present or does not work properly, we need to try legacy raspistill as fallback solution
if [[ ${TRY_LEGACY_RASPISTILL} -eq 1 ]]; then 
  # Check if the legacy command line tool raspistill is available
  if [ -x "$(command -v raspistill)" ] ; then
    echo -e "${GREEN}[OK] The tool raspistill has been found on this system.${NC}" | ${TEE_PROGRAM_LOG} 
    echo -e "${YELLOW}[INFO] But it is a good idea to install libcamera-still from the libcamera tools because the legacy raspistill tool will stop working in the future.${NC}" | ${TEE_PROGRAM_LOG}   
  else
    echo -e "${RED}[ERROR] pestdetector requires either the command line tool libcamera-still or raspistill.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
  fi
fi

# Check if the LCD "driver" for LCD display 1 (just a command line tool tool to print lines on the LCD) is available
if ! [ -f "${LCD_DRIVER1}" ] ; then
   echo -e "${RED}[ERROR] The LCD command line tool ${LCD_DRIVER1} is missing.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
else
  if ! python3 ${LCD_DRIVER1} "Welcome to" "pestdetector" "on host" "${HOSTNAME}" ; then
    echo -e "${RED}[ERROR] The LCD command line tool ${LCD_DRIVER1} does not operate properly.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
  fi
fi

# Check if the LCD "driver" for LCD display 2 (just a command line tool tool to print lines on the LCD) is available
if ! [ -f "${LCD_DRIVER1}" ]; then
   echo -e "${RED}[ERROR] The LCD command line tool ${LCD_DRIVER2} is missing.${NC}" && exit 1
else
  if ! python3 ${LCD_DRIVER2} "This display informs" "about the state of" "the pestdetector" "software" ; then
    echo -e "${RED}[ERROR] The LCD command line tool ${LCD_DRIVER2} does not operate properly.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
  fi
fi

# --------------------------------------------------
# | Check if the required directories/folders exit |
# --------------------------------------------------

# Check if the images directory already exists
if [ -e ${DIRECTORY_IMAGES} ] ; then
  # If the directory for the images already exists
   echo -e "${GREEN}[OK] The directory ${DIRECTORY_IMAGES} already exists in the directory.${NC}" | ${TEE_PROGRAM_LOG}
else
  # If the directory for the images does not already exist => create it
  if mkdir ${DIRECTORY_IMAGES} ; then
    echo -e "${GREEN}[OK] The directory ${DIRECTORY_IMAGES} has been created.${NC}" | ${TEE_PROGRAM_LOG}
  else
    echo -e "${RED}[ERROR] Unable to create the directory ${DIRECTORY_IMAGES}.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
  fi
fi

# Check if the most_recent_image directory already exists
if [ -e ${DIRECTORY_MOST_RECENT_IMAGE} ] ; then
  # If the directory for the most_recent_image already exists
   echo -e "${GREEN}[OK] The directory ${DIRECTORY_MOST_RECENT_IMAGE} already exists in the directory.${NC}" | ${TEE_PROGRAM_LOG}
else
  # If the directory for the most_recent_image does not already exist => create it
  if mkdir ${DIRECTORY_MOST_RECENT_IMAGE} ; then
    echo -e "${GREEN}[OK] The directory ${DIRECTORY_MOST_RECENT_IMAGE} has been created.${NC}" | ${TEE_PROGRAM_LOG}
  else
    echo -e "${RED}[ERROR] Unable to create the directory ${DIRECTORY_MOST_RECENT_IMAGE}.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
  fi
fi

# Check if the most_recent_image directory is empty. If it is not, erase all content
if [[ -z "$(ls -A ${DIRECTORY_MOST_RECENT_IMAGE})" ]] ; then
  # -z string => True (0) if the string is null (an empty string).
  # In other words, it is Talse (1) if there are files in most_recent_image
  # -A means list all except . and ..
  echo -e "${GREEN}[OK] The directory ${DIRECTORY_MOST_RECENT_IMAGE} is empty.${NC}" | ${TEE_PROGRAM_LOG}
else
  # Erase the content of the directory most_recent_image.
  # It sould be empty at the very beginning of the script.
  # If it was not empty, maybe something went wrong with the inite loop during the last run.
  if rm ${DIRECTORY_MOST_RECENT_IMAGE}/* ; then
    echo -e "${GREEN}[OK] The directory ${DIRECTORY_MOST_RECENT_IMAGE} is now empty.${NC}" | ${TEE_PROGRAM_LOG}
  else
    echo -e "${RED}[ERROR] Unable to erase the content of the directory ${DIRECTORY_MOST_RECENT_IMAGE}.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
  fi
fi

NUMBER_OF_RUNS=0

# Inifinite loop
while true ; do
  # Increment the number of program runs + 1 by using the command line tool bc
  NUMBER_OF_RUNS=$(echo "${NUMBER_OF_RUNS} + 1" | bc)
  TIMESTAMP_OUTPUT_STYLE=$(date +%Y-%m-%d\ %H:%M:%S)
  echo -e "${GREEN}[OK] ${TIMESTAMP_OUTPUT_STYLE} ==> Start of program run ${NUMBER_OF_RUNS} <=== ${NC}" | ${TEE_PROGRAM_LOG}
 
  # -----------------------------------------
  # | Try to make a picture with the camera |
  # -----------------------------------------

  # Print some information on LCD display 2
  if ! python3 ${LCD_DRIVER2} "Make a picture" "" "" "" ; then
    echo -e "${RED}[ERROR] The LCD command line tool ${LCD_DRIVER2} does not operate properly.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
  fi

  make_a_picture

  # -----------------------------------------
  # | Object detection and logfile creation |
  # -----------------------------------------

  # Print some information on LCD display 2
  if ! python3 ${LCD_DRIVER2} "Make a picture" "Detect objects" "" "" ; then
    echo -e "${RED}[ERROR] The LCD command line tool ${LCD_DRIVER2} does not operate properly.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
  fi

  detect_objects

  # ----------------------------------------------------
  # | Check of one or more objects have been detected. |
  # | If there have been objects detected, move the    | 
  # | picture and the log file to the images directory |
  # ----------------------------------------------------

  # Print some information on LCD display 2
  if ! python3 ${LCD_DRIVER2} "Make a picture" "Detect objects" "Analyze results" "" ; then
    echo -e "${RED}[ERROR] The LCD command line tool ${LCD_DRIVER2} does not operate properly.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
  fi

  check_if_objects_have_been_deteted

  # ----------------------------------------------------------
  # | If one or more objects have been detected, print       |
  # | the results on the LCD screen => print_result_on_LCD() |
  # |                                                        |
  # | If no objects have been detected, print the result on  | 
  # | the LCD screen => print_no_object_detected_on_LCD()    |
  # ----------------------------------------------------------

  if [ "$HIT" -eq 1 ] ; then
    # If one or more objects have been detected...
    print_result_on_LCD 
  else
    # If no object has been detected...
    print_no_object_detected_on_LCD
  fi

  # ----------------------------------------------
  # | Prevent the images directory from overflow |
  # ----------------------------------------------

  # Print some information on LCD display 2
  if ! python3 ${LCD_DRIVER2} "Make a picture" "Detect objects" "Analyze results" "Organize folders" ; then
    echo -e "${RED}[ERROR] The LCD command line tool ${LCD_DRIVER2} does not operate properly.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
  fi

  prevent_directory_overflow    

done

exit 0