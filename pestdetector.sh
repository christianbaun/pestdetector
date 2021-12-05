#!/bin/bash
#
# title:        pestdetector.sh
# description:  This script creates images and detects rats and other forms of 
#               pest
# author:       Dr. Christian Baun
# url:          none
# license:      GPLv3
# date:         December 5th 2021
# version:      0.01
# bash_version: 5.1.4(1)-release 
# requires:     raspistill from packet python3-picamera
# optional:     none
# notes:        none
# example:      ./pestdetector.sh
# ----------------------------------------------------------------------------

# Path of the directory for the images
DIRECTORY_IMAGES="images"
DIRECTORY_LOGS="logs"

RED='\033[0;31m'          # Red color
NC='\033[0m'              # No color
GREEN='\033[0;32m'        # Green color
YELLOW='\033[0;33m'       # Yellow color
BLUE='\033[0;34m'         # Blue color
WHITE='\033[0;37m'        # White color

# Check if the required command line tools are available
if ! [ -x "$(command -v hostname)" ]; then
    echo -e "${RED}[ERROR] The command line tool hostname tool is missing.${NC}"
    exit 1
else
    HOSTNAME=$(hostname)
    echo -e "Welcome to pestdetector on host ${HOSTNAME}"
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
    echo -e "${RED}[ERROR] pestdetector requires the command line tool raspistill from the packet python3-picamera. Please install it.${NC}"
    exit 1
else
    echo -e "${GREEN}[OK] The tool raspistill has been found on this system.${NC}"
fi

# --------------------------------------------------
# | Check if the required directories/folders exit |
# --------------------------------------------------

# Check if the images directory already exists
if [ -e ${DIRECTORY_IMAGES} ] ; then
  # If the directory for the images already exists
   echo -e "${YELLOW}[INFO] The directory ${DIRECTORY_IMAGES} already exists in the local directory.${NC}"
else
  # If the directory for the images does not already exist => create it
  if mkdir ${DIRECTORY_IMAGES} ; then
    echo -e "${GREEN}[OK] The local directory ${DIRECTORY_IMAGES} has been created.${NC}"
  else
    echo -e "${RED}[ERROR] Unable to create the local directory ${DIRECTORY_IMAGES}.${NC}" && exit 1
  fi
fi

# Check if the logs directory already exists
if [ -e ${DIRECTORY_LOGS} ] ; then
  # If the directory for the logs already exists
   echo -e "${YELLOW}[INFO] The directory ${DIRECTORY_LOGS} already exists in the local directory.${NC}"
else
  # If the directory for the logs does not already exist => create it
  if mkdir ${DIRECTORY_LOGS} ; then
    echo -e "${GREEN}[OK] The local directory ${DIRECTORY_LOGS} has been created.${NC}"
  else
    echo -e "${RED}[ERROR] Unable to create the local directory ${DIRECTORY_LOGS}.${NC}" && exit 1
  fi
fi




# Store timestamp of the date and time in a variable
DATE_AND_TIME_STAMP=$(date +%Y-%m-%d_%H-%M-%S)

# Store timestamp of the date in a variable
DATE_TIME_STAMP=$(date +%Y-%m-%d)

# Filename of the log file
LOG_FILENAME="${DATE_TIME_STAMP}_results.txt"

echo "${LOG_FILENAME}"


echo "$DATE_AND_TIME_STAMP"



#raspistill -o image.jpg -n




exit 0