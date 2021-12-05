#!/bin/bash
#
# title:        pestdetector.sh
# description:  This script creates images and detects rats and other forms of 
#               pest
# author:       Dr. Christian Baun
# url:          none
# license:      GPLv3
# date:         December 4th 2021
# version:      0.01
# bash_version: 5.1.4(1)-release 
# requires:     raspistill from packet python3-picamera
# optional:     none
# notes:        none
# example:      ./pestdetector.sh
# ----------------------------------------------------------------------------

# Path of the directory for the images
DIRECTORY="images"

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

# Check if the required command line tools are available
if ! [ -x "$(command -v raspistill)" ]; then
    echo -e "${RED}[ERROR] pestdetector requires the command line tool raspistill from the packet python3-picamera. Please install it.${NC}"
    exit 1
else
    echo -e "${YELLOW}[INFO] The tool pestdetector has been found on this system.${NC}"
fi

# Store timestamp of the date and time in a variable
DATE_AND_TIME_STAMP=$(date +%Y-%m-%d_%H-%M-%S)

# Store timestamp of the date in a variable
DATE_TIME_STAMP=$(date +%Y-%m-%d)

# Filename of the log file
LOG_FILENAME="${DATE_TIME_STAMP}_results.txt"

echo "${LOG_FILENAME}"


echo "$DATE_AND_TIME_STAMP"

exit 0

#raspistill -o image.jpg -n