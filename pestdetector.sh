#!/bin/bash
#
# title:        pestdetector.sh
# description:  This script creates images and detects rats and other forms of 
#               pest like cockroaches
# author:       Dr. Christian Baun
# url:          https://github.com/christianbaun/pestdetector
# license:      GPLv3
# date:         December 7th 2021
# version:      0.10
# bash_version: tested with 5.1.4(1)-release
# requires:     The functions in functionlibrary.sh
#               raspistill command line tool from packet python3-picamera.
# optional:     none
# notes:        This script has been developed to run on a Raspberry Pi 4 
#               (4 GB RAM). A LCD 4x20 with a HD44780 controller, 
#               connected via the I2C interface is used to inform about the
#               work of the pest detector.
# example:      ./pestdetector.sh
# ----------------------------------------------------------------------------

# Function library with thse functions:
# make_a_picture()
# detect_objects()
# check_if_objects_have_been_deteted()
# print_result_on_LCD()
# prevent_directory_overflow()
. functionlibrary.sh

# Path of the directory for the most recent picture
DIRECTORY_MOST_RECENT_IMAGE="most_recent_image"
# Path of the directory for the picture
DIRECTORY_IMAGES="images"
#DIRECTORY_IMAGES_MAX_SIZE="1073741824"  # 1 GB max
DIRECTORY_IMAGES_MAX_SIZE="5000"  # 5 MB max for testing purposes
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

RED='\033[0;31m'          # Red color
NC='\033[0m'              # No color
GREEN='\033[0;32m'        # Green color
YELLOW='\033[0;33m'       # Yellow color
BLUE='\033[0;34m'         # Blue color
WHITE='\033[0;37m'        # White color

# At the very beginning, no objects have been detected
HIT=0

# Check if the required command line tools are available
if ! [ -x "$(command -v hostname)" ]; then
    echo -e "${RED}[ERROR] The command line tool hostname tool is missing.${NC}"
    exit 1
else
    HOSTNAME=$(hostname)
    # Store timestamp of the date in a variable
    DATE_TIME_STAMP=$(date +%Y-%m-%d)
    CLOCK_TIME_STAMP=$(date +%H-%M-%S)
    echo -e "${DATE_TIME_STAMP} ${CLOCK_TIME_STAMP} Welcome to pestdetector on host ${HOSTNAME}"
fi

# ------------------------------
# | Check the operating system |
# ------------------------------

if [[ "$OSTYPE" == "linux-gnu" || "$OSTYPE" == "linux-gnueabihf" ]]; then
    # Linux
    echo -e "${YELLOW}[INFO] The operating system is Linux: ${OSTYPE}${NC}"
elif [[ "$OSTYPE" == "freebsd"* ]]; then
    # FreeBSD
    echo -e "${YELLOW}[INFO] The operating system is FreeBSD: ${OSTYPE}${NC}"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # Mac OS X
    echo -e "${YELLOW}[INFO] The operating system is Mac OS X: ${OSTYPE}${NC}"
elif [[ "$OSTYPE" == "msys" ]]; then
    # Windows 
    echo -e "${YELLOW}[INFO] The operating system is Windows: ${OSTYPE}${NC}"
elif [[ "$OSTYPE" == "cygwin" ]]; then
    # POSIX compatibility layer for Windows
    echo -e "${YELLOW}[INFO] POSIX compatibility layer for Windows detected: ${OSTYPE}${NC}"
else
    # Unknown
    echo -e "${YELLOW}[INFO] The operating system is unknown: ${OSTYPE}${NC}"
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
    echo -e "${GREEN}[OK] This computer has a working internet connection.${NC}"
    # Skip entire rest of loop.
    break
  else
    echo -e "${YELLOW}[INFO] The internet connection is not working now. Will check again.${NC}"
    # Decrement variable
    LOOP_VARIABLE=$((LOOP_VARIABLE-1))
    if [ "$LOOP_VARIABLE" -eq 0 ] ; then
      echo -e "${RED}[INFO] This computer has no working internet connection.${NC}"
    fi
    # Wait a moment. 
    sleep 1
  fi
done

# ----------------------------------------------------------
# | Check if the required command line tools are available |
# ----------------------------------------------------------

# Check if the command line tool raspistill is available
if ! [ -x "$(command -v raspistill)" ]; then
  echo -e "${RED}[ERROR] pestdetector requires the command line tool raspistill from the packet python3-picamera. Please install it.${NC}" && exit 1
else
  echo -e "${GREEN}[OK] The tool raspistill has been found on this system.${NC}"
fi

# Check if the LCD "driver" (just a command line tool tool to print lines on the LCD) is available
if ! [ -f "${LCD_DRIVER1}" ]; then
   echo -e "${RED}[ERROR] The LCD command line tool ${LCD_DRIVER1} is missing.${NC}" && exit 1
else
  if ! python3 ${LCD_DRIVER1} "Welcome to" "pestdetector" "on host" "${HOSTNAME}" ; then
    echo -e "${RED}[ERROR] The LCD command line tool ${LCD_DRIVER1} does not operate properly.${NC}" && exit 1
  fi
fi

# --------------------------------------------------
# | Check if the required directories/folders exit |
# --------------------------------------------------

# Check if the images directory already exists
if [ -e ${DIRECTORY_IMAGES} ] ; then
  # If the directory for the images already exists
   echo -e "${GREEN}[OK] The directory ${DIRECTORY_IMAGES} already exists in the directory.${NC}"
else
  # If the directory for the images does not already exist => create it
  if mkdir ${DIRECTORY_IMAGES} ; then
    echo -e "${GREEN}[OK] The directory ${DIRECTORY_IMAGES} has been created.${NC}"
  else
    echo -e "${RED}[ERROR] Unable to create the directory ${DIRECTORY_IMAGES}.${NC}" && exit 1
  fi
fi


# Check if the most_recent_image directory already exists
if [ -e ${DIRECTORY_MOST_RECENT_IMAGE} ] ; then
  # If the directory for the most_recent_image already exists
   echo -e "${GREEN}[OK] The directory ${DIRECTORY_MOST_RECENT_IMAGE} already exists in the directory.${NC}"
else
  # If the directory for the most_recent_image does not already exist => create it
  if mkdir ${DIRECTORY_MOST_RECENT_IMAGE} ; then
    echo -e "${GREEN}[OK] The directory ${DIRECTORY_MOST_RECENT_IMAGE} has been created.${NC}"
  else
    echo -e "${RED}[ERROR] Unable to create the directory ${DIRECTORY_MOST_RECENT_IMAGE}.${NC}" && exit 1
  fi
fi

# Check if the most_recent_image directory is empty. If it is not, erase all content
if [[ -z "$(ls -A ${DIRECTORY_MOST_RECENT_IMAGE})" ]] ; then
  # -z string => True (0) if the string is null (an empty string).
  # In other words, it is Talse (1) if there are files in most_recent_image
  # -A means list all except . and ..
  echo -e "${GREEN}[OK] The directory ${DIRECTORY_MOST_RECENT_IMAGE} is empty.${NC}"
else
  # Erase the content of the directory most_recent_image.
  # It sould be empty at the very beginning of the script.
  # If it was not empty, maybe something went wrong with the inite loop during the last run.
  if rm ${DIRECTORY_MOST_RECENT_IMAGE}/* ; then
    echo -e "${GREEN}[OK] The directory ${DIRECTORY_MOST_RECENT_IMAGE} is now empty.${NC}"
  else
    echo -e "${RED}[ERROR] Unable to erase the content of the directory ${DIRECTORY_MOST_RECENT_IMAGE}.${NC}" && exit 1
  fi
fi

# Check if the logs directory already exists
if [ -e ${DIRECTORY_LOGS} ] ; then
  # If the directory for the logs already exists
   echo -e "${GREEN}[OK] The directory ${DIRECTORY_LOGS} already exists in the local directory.${NC}"
else
  # If the directory for the logs does not already exist => create it
  if mkdir ${DIRECTORY_LOGS} ; then
    echo -e "${GREEN}[OK] The local directory ${DIRECTORY_LOGS} has been created.${NC}"
  else
    echo -e "${RED}[ERROR] Unable to create the local directory ${DIRECTORY_LOGS}.${NC}" && exit 1
  fi
fi

NUMBER_OF_RUNS=0

# Inifinite loop
while true ; do
  # Increment the number of program runs + 1 by using the command line tool bc
  NUMBER_OF_RUNS=$(echo "${NUMBER_OF_RUNS} + 1" | bc)
  TIMESTAMP=$(date +%Y-%m-%d\ %H:%M:%S)
  echo -e "${TIMESTAMP} ${GREEN}[OK] ===> Start of program run ${NUMBER_OF_RUNS} <=== ${NC}"
 
  # -----------------------------------------
  # | Try to make a picture with the camera |
  # -----------------------------------------

  make_a_picture

  # -----------------------------------------
  # | Object detection and logfile creation |
  # -----------------------------------------

  detect_objects

  # ----------------------------------------------------
  # | Check of one or more objects have been detected. |
  # | If there have been objects detected, move the    | 
  # | picture and the log file to the images directory |
  # ----------------------------------------------------

  check_if_objects_have_been_deteted

  # ----------------------------------------------------
  # | If one or more objects have been detected, print |
  # | the results on the LCD screen                    |
  # ----------------------------------------------------

  if [ "$HIT" -eq 1 ] ; then
    print_result_on_LCD 
  fi

  # ----------------------------------------------
  # | Prevent the images directory from overflow |
  # ----------------------------------------------

  prevent_directory_overflow    

done

exit 0