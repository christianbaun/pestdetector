#!/bin/bash
#
# title:        pestdetector.sh
# description:  This script creates images and detects rats and other forms of 
#               pest
# author:       Dr. Christian Baun
# url:          none
# license:      GPLv3
# date:         December 5th 2021
# version:      0.02
# bash_version: testsed with 5.1.4(1)-release 
# requires:     raspistill from packet python3-picamera
# optional:     none
# notes:        This script has been developed on a Raspberry Pi 4 (4 GB RAM)
# example:      ./pestdetector.sh
# ----------------------------------------------------------------------------

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


# Check if the most_recent_image directory already exists
if [ -e ${DIRECTORY_MOST_RECENT_IMAGE} ] ; then
  # If the directory for the most_recent_image already exists
   echo -e "${YELLOW}[INFO] The directory ${DIRECTORY_MOST_RECENT_IMAGE} already exists in the local directory.${NC}"
else
  # If the directory for the most_recent_image does not already exist => create it
  if mkdir ${DIRECTORY_MOST_RECENT_IMAGE} ; then
    echo -e "${GREEN}[OK] The local directory ${DIRECTORY_MOST_RECENT_IMAGE} has been created.${NC}"
  else
    echo -e "${RED}[ERROR] Unable to create the local directory ${DIRECTORY_MOST_RECENT_IMAGE}.${NC}" && exit 1
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

# ----------------------------------------
# | Try to make a picture with the camera|
# ----------------------------------------

# Store timestamp of the date and time in a variable
DATE_AND_TIME_STAMP=$(date +%Y-%m-%d_%H-%M-%S)
IMAGE_FILENAME_AND_PATH="${DIRECTORY_MOST_RECENT_IMAGE}/${DATE_AND_TIME_STAMP}.jpg"

if raspistill -o ${IMAGE_FILENAME_AND_PATH} -n ; then
  echo -e "${GREEN}[OK] The picture ${IMAGE_FILENAME_AND_PATH} has been created.${NC}"
else
  echo -e "${RED}[ERROR] Unable to create the picture ${IMAGE_FILENAME_AND_PATH}.${NC}" && exit 1
fi

# -----------------------------------------
# | Object detection and logfile creation |
# -----------------------------------------

# Filename of the log file
LOG_FILENAME_AND_PATH="${DIRECTORY_MOST_RECENT_IMAGE}/${DATE_AND_TIME_STAMP}.txt"

if [[ -f "${IMAGE_FILENAME_AND_PATH}" ]] ; then
    python3 TFLite_detection_image_modified.py --modeldir=$MODEL --graph=detect_edgetpu.tflite --labels=$LABELS --edgetpu --image=${IMAGE_FILENAME_AND_PATH} 2>&1 | tee -a $LOG_FILENAME_AND_PATH
else
    echo "The image file ${IMAGE_FILENAME_AND_PATH} was not found."
    exit 
fi

# ----------------------------------------------------
# | Check of one or more objects have been detected. |
# | If there have been objects detected, move the    | 
# | picture and the log file to the images directory |
# ----------------------------------------------------

# Check in the log file of the picture what the output of TFLite_detection_image_modified.py is
# If one or more objects have been detected, there will be one or more lines like these:
# Detected Object: rat with 87 %
# The return code of grep is 0 when the search patern "Detected" is inside the log file at least one time.
if grep "Detected" ${LOG_FILENAME_AND_PATH} ; then
  echo -e "${GREEN}[OK] One or more objects have been deteted in the picture ${LOG_FILENAME_AND_PATH}.${NC}"
  # Move the picture file from the directory "most_recent_image" to the directory "images" 
  if mv ${IMAGE_FILENAME_AND_PATH} ${DIRECTORY_IMAGES} ; then
    echo -e "${GREEN}[OK] The picture ${IMAGE_FILENAME_AND_PATH} as been moved to the directory ${DIRECTORY_IMAGES}.${NC}"
  else
    echo -e "${RED}[ERROR] The attempt to move the picture ${IMAGE_FILENAME_AND_PATH} to the directory ${DIRECTORY_IMAGES} failed.${NC}"
    exit 1
  fi
  if mv ${LOG_FILENAME_AND_PATH} ${DIRECTORY_IMAGES} ; then
    # Move the log file from the directory "most_recent_image" to the directory "images" 
    echo -e "${GREEN}[OK] The logfile ${LOG_FILENAME_AND_PATH} as been moved to the directory ${DIRECTORY_IMAGES}.${NC}"
  else
    echo -e "${RED}[ERROR] The attempt to move the logfile ${LOG_FILENAME_AND_PATH} to the directory ${DIRECTORY_IMAGES} failed.${NC}"
    exit 1
  fi
else
  echo -e "${YELLOW}[INFO] No objects have been detected in the picture ${LOG_FILENAME_AND_PATH}.${NC}"
fi

# ----------------------------------------------
# | Prevent the images directory from overflow |
# ----------------------------------------------

# Get the sum of the bytes in the images directory and keep only the first column of the output with awk
DIRECTORY_IMAGES_ACTUAL_SIZE=$(du -s ${DIRECTORY_IMAGES} | awk '{ print $1 }')

# Get the number of files in the images directory
# But first, check if the images directory is not empty and contains a least a single jpg file
if [[ -f images/*.jpg ]] ; then
  # -U causes ls to not sort the entries => less memory consumption
  # -b prints C-style escapes for nongraphic characters, => newlines are printed as \n
  # -a prints out all files, even hidden files 
  # -d prints out directories without attempting to list the contents of the directory
  # -1 makes sure that it's on one column 
  DIRECTORY_IMAGES_NUMBER_OF_FILES=$(ls -Ubad1 ${DIRECTORY_IMAGES}/*.jpg | wc -l)
 
  # Get the sum of the bytes in the images directory and keep only the first column of the output with awk
  DIRECTORY_IMAGES_ACTUAL_SIZE=$(du -s ${DIRECTORY_IMAGES} | awk '{ print $1 }')

  echo -e "${YELLOW}[INFO] Files in ${DIRECTORY_IMAGES}: ${DIRECTORY_IMAGES_NUMBER_OF_FILES}${NC}"
  echo -e "${YELLOW}[INFO] Used Bytes in ${DIRECTORY_IMAGES}: ${DIRECTORY_IMAGES_ACTUAL_SIZE}${NC}"   

else
  echo -e "${YELLOW}[INFO] The directory ${DIRECTORY_IMAGES} is still empty${NC}"
fi
  
if [[ "${DIRECTORY_IMAGES_ACTUAL_SIZE}" -lt "${DIRECTORY_IMAGES_MAX_SIZE}" ]] ; then
  echo -e "${GREEN}[OK] There is enough free storage capacity in the directory ${DIRECTORY_IMAGES}${NC}"
else
  echo -e "${YELLOW}[INFO] Attention: The directory ${DIRECTORY_IMAGES} consumes ${DIRECTORY_IMAGES_ACTUAL_SIZE} Bytes which is more than the permitted maximum ${DIRECTORY_IMAGES_MAX_SIZE} Bytes !${NC}"  
  while [ "${DIRECTORY_IMAGES_ACTUAL_SIZE}" -gt "${DIRECTORY_IMAGES_MAX_SIZE}" ]; do 
    DIRECTORY_IMAGES_OLDEST_FILE=$(ls -t ${DIRECTORY_IMAGES} | tail -1)
    if rm ${DIRECTORY_IMAGES}/${DIRECTORY_IMAGES_OLDEST_FILE}; then
      echo -e "${YELLOW}[INFO] Erased the file ${DIRECTORY_IMAGES_OLDEST_FILE} from ${DIRECTORY_IMAGES}${NC}"
      # Fetch the new sum of the bytes in the images directory and keep only the first column of the output with awk
      DIRECTORY_IMAGES_ACTUAL_SIZE=$(du -s ${DIRECTORY_IMAGES} | awk '{ print $1 }')
    else 
      echo -e "${RED}[INFO] Attention: Unable to erase ${DIRECTORY_IMAGES_OLDEST_FILE} from directory ${DIRECTORY_IMAGES}!${NC}"      
      exit 1
    fi
  done
  echo -e "${YELLOW}[INFO] Now, the directory ${DIRECTORY_IMAGES} consumes ${DIRECTORY_IMAGES_ACTUAL_SIZE} Bytes which is less than the permitted maximum ${DIRECTORY_IMAGES_MAX_SIZE} Bytes !${NC}" 
fi




# Store timestamp of the date in a variable
DATE_TIME_STAMP=$(date +%Y-%m-%d)







exit 0