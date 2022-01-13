#!/bin/bash
#
# title:        pestdetector.sh
# description:  This script creates images and detects rats and other forms of 
#               pest like cockroaches
# author:       Dr. Christian Baun
# url:          https://github.com/christianbaun/pestdetector
# license:      GPLv3
# date:         January 13th 2022
# version:      1.2
# bash_version: tested with 5.1.4(1)-release
# requires:     The functions in functionlibrary.sh
#               libcamera-still command line tool that uses the libcamera open 
#               source camera stack. 
#               Tested with the libcamera-apps packet version 2a38ae93f143
#               As alternative, the raspistill command line tool can be used.
#               curl command line tool for interaction with the Telegram Bot
#               Tested with curl 7.74.0
#               hostname command line tool. Tested with 3.21
#               ping command line tool. Tested with iputils-s20180629
#               python3 for the LCD driver when using the LCD 4x20 displays
# optional:     none
# notes:        This script has been developed to run on a Raspberry Pi 4 
#               (4 GB RAM). Two LCD 4x20 displays with HD44780 controllers, 
#               connected via the I2C interface are used to inform about the
#               work of the pest detector.
# example:      ./pestdetector.sh
# ----------------------------------------------------------------------------

# Function library with thse functions:
# clear_lcd_displays()
# make_a_picture()
# detect_objects()
# check_if_objects_have_been_deteted()
# print_result_on_LCD()
# print_no_object_detected_on_LCD()
# inform_telegram_bot()
# prevent_directory_overflow()
. functionlibrary.sh

function usage
{
echo "$SCRIPT [-h] [-m <modelname>] [-l <labelmap>] [-i <directory>] [-s <size>] [-j <directory>] [-t] [-d <number>] [-c]

Arguments:
-h : show this message on screen
-m : the name of the model used for object detection. The name must match the 
     directory name in the home directory
-l : the file name of the labelmap used for object detection
-i : the directory to store the images that contain detected objects
-s : the maximum size [kB] of the directory to store the images with detected objects.
     Minimum value is 10000 (= 10 MB)
-j : the directory to store the log files of pest detector
-t : use telegram bot notifications. If this flag is set, telegram notifications
     are send when the pest detector starts and when objects are detected.  
     The bot token url and the chat ID must be specified as variables \$TELEGRAM_TOKEN
     and \$TELEGRAM_CHAT_ID in the file /home/pi/pest_detect_telegram_credentials.sh
-d : use 0, 1 or 2 LCD displays (4x20)
-c : use Coral Accelerator TPU coprocessor 
"

exit 0
}

# Script name
SCRIPT=${0##*/}   
# This is the detault model that is used when no model name is 
# specified with the command line parameter -m <modelname>
STANDARDMODELL=model_2021_07_08_rat_bug_hedgehog
STANDARDLABELMAP=labelmap.txt
MODELLNAME_PARAMETER=0
LABELMAP_PARAMETER=0
# Path of the directory for the most recent picture
DIRECTORY_MOST_RECENT_IMAGE="/dev/shm/most_recent_image"
DIRECTORY_IMAGES_PARAMETER=0
# Path of the directory for the picture
DIRECTORY_IMAGES=""
STANDARD_DIRECTORY_IMAGES="images"
DIRECTORY_IMAGES_MAX_SIZE_PARAMETER=0
DIRECTORY_IMAGES_MAX_SIZE="" 
STANDARD_DIRECTORY_IMAGES_MAX_SIZE="50000"  # 50 MB max for testing purposes
DIRECTORY_LOGS_PARAMETER=0
DIRECTORY_LOGS=""
STANDARD_DIRECTORY_LOGS="logs"
DIRECTORY_LOGS_MAX_SIZE="100000" # 100 MB max
# Do not use the telegram bot notification per default
USE_TELEGRAM_BOT=0
# Do not use LCDdisplays 4x20 per default
NUM_LCD_DISPLAYS=0
USE_CORAL_TPU_COPROCESSOR=0
LCD_LINE_1_1=""
LCD_LINE_1_2=""
LCD_LINE_1_3=""
LCD_LINE_1_4=""
LCD_LINE_2_1=""
LCD_LINE_2_2=""
LCD_LINE_2_3=""
LCD_LINE_2_4=""

CLEAR_LCD_DRIVER1="lcd_display1_clear.py"
CLEAR_LCD_DRIVER2="lcd_display2_clear.py"
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
DETECTED_OBJECTS_OF_LAST_RUN=""

while getopts "hm:l:i:s:j:td:c" ARG ; do
  case $ARG in
    h) usage ;;
    m) MODELLNAME_PARAMETER=1
       MODELLNAME=${OPTARG} ;;
    l) LABELMAP_PARAMETER=1
       LABELMAP=${OPTARG} ;;
    i) DIRECTORY_IMAGES_PARAMETER=1
       DIRECTORY_IMAGES=${OPTARG} ;;
    s) DIRECTORY_IMAGES_MAX_SIZE_PARAMETER=1
       DIRECTORY_IMAGES_MAX_SIZE=${OPTARG} ;;
    j) DIRECTORY_LOGS_PARAMETER=1
       DIRECTORY_LOGS=${OPTARG} ;;
    t) USE_TELEGRAM_BOT=1 ;;
    d) NUM_LCD_DISPLAYS=${OPTARG} ;;
    c) USE_CORAL_TPU_COPROCESSOR=1 ;;
    *) echo -e "${RED}[ERROR] Invalid option! ${OPTARG} ${NC}" 
       exit 1
       ;;
  esac
done

# If the user did not want to specify the model name name with the parameter -m <modelname>, 
# the pest detector will use the default model name
if [ "$MODELLNAME_PARAMETER" -eq 0 ] ; then
  # No model provided as parameter => default model: $STANDARDMODELL
  MODELLNAME=${STANDARDMODELL}
fi

# If the user did not want to specify the file name of the labelmap with the parameter -l <labelmap>, 
# the pest detector will use the default labelmap file name
if [ "$LABELMAP_PARAMETER" -eq 0 ] ; then
  # No labelmap file name provided as parameter => label map file name: $STANDARDLABELMAP
  LABELMAP=${STANDARDLABELMAP}
fi

MODEL="/home/pi/${MODELLNAME}"
LABELS="/home/pi/${MODELLNAME}/${LABELMAP}"

# If the user did not want to specify the directory for the image files with detected objects 
# with the parameter -i <directory>, the pest detector will use the default image files directory
if [ "$DIRECTORY_IMAGES_PARAMETER" -eq 0 ] ; then
  # No image directory provided as parameter => default image directory: $STANDARD_DIRECTORY_IMAGES
  DIRECTORY_IMAGES=${STANDARD_DIRECTORY_IMAGES}
fi

# If the user did not want to specify the maximum size of the directory that stores the image files
# with detected objects with the parameter -s <size>, the pest detector will use the default size
if [ "$DIRECTORY_IMAGES_MAX_SIZE_PARAMETER" -eq 0 ] ; then
  # No maximum size for the directory provided as parameter => default size: $STANDARD_DIRECTORY_IMAGES_MAX_SIZE
  DIRECTORY_IMAGES_MAX_SIZE=${STANDARD_DIRECTORY_IMAGES_MAX_SIZE}
fi

# It makes no sense to specify a maximum size of less than 10 MB for the 
# directory that stores the image files with detected objects
if [ "$DIRECTORY_IMAGES_MAX_SIZE" -lt 10000 ] ; then
  echo -e "${RED}[ERROR] It makes no sense to specify a maximum size of less than 10 MB for the directory that stores the image files with detected objects.${NC}" 
  usage
  exit 1
fi

# If the user did not want to specify the directory for the log files 
# with the parameter -j <directory>, the pest detector will use the default log files directory
if [ "$DIRECTORY_LOGS_PARAMETER" -eq 0 ] ; then
  # No image directory provided as parameter => default image directory: $STANDARD_DIRECTORY_LOGS
  DIRECTORY_LOGS=${STANDARD_DIRECTORY_LOGS}
fi

# Check if the required command line tools are available
if ! [ -x "$(command -v hostname)" ]; then
  echo -e "${RED}[ERROR] The command line tool hostname is missing.${NC}" 
  exit 1
else
  HOSTNAME=$(hostname)
fi

# Store timestamp of the date in a variable
DATE_TIME_STAMP=$(date +%Y-%m-%d)
CLOCK_TIME_STAMP=$(date +%H-%M-%S)

echo -e "${DATE_TIME_STAMP} ${CLOCK_TIME_STAMP} Welcome to pestdetector on host ${HOSTNAME}"

# Check if the logs directory already exists
if [ -e ${DIRECTORY_LOGS} ] ; then
  # If the directory for the logs already exists
   echo -e "${GREEN}[OK] The directory ${DIRECTORY_LOGS} already exists in the local directory.${NC}" 
else
  # If the directory for the logs does not already exist => create it
  if mkdir ${DIRECTORY_LOGS} ; then
    echo -e "${GREEN}[OK] The directory ${DIRECTORY_LOGS} has been created.${NC}" 
  else
    echo -e "${RED}[ERROR] Unable to create the local directory ${DIRECTORY_LOGS}.${NC}" 
    exit 1
  fi
fi

# Definition of the logfile specification.
# This can be attached with a pipe to echo commands
TEE_PROGRAM_LOG=" tee -a ${DIRECTORY_LOGS}/${DATE_TIME_STAMP}-pestdetector_log.txt"
LOGFILE_OBJECTS_DETECTED="${DIRECTORY_LOGS}/${DATE_TIME_STAMP}-detected_objects.txt"

# Only if the command line parameter -t is set, the Telegram Bot notifications
# shall be send when the pest detector is started and when objects are detected
# and only in this case, the curl command line tool is required.
if [ "$USE_TELEGRAM_BOT" -eq 1 ] ; then
  if ! [ -x "$(command -v curl)" ]; then
      echo -e "${RED}[ERROR] The command line tool curl is missing.${NC}" | ${TEE_PROGRAM_LOG} 
      exit 1
  fi
fi

# Validate that the number of 4x20 LCD displays used is 0, 1 or 2
if [ "$NUM_LCD_DISPLAYS" -eq 0 ] ; then
  echo -e "${GREEN}[OK] ${NUM_LCD_DISPLAYS} 4x20 LCD display are used.${NC}" 
elif [ "$NUM_LCD_DISPLAYS" -eq 1 ] ; then
  echo -e "${GREEN}[OK] ${NUM_LCD_DISPLAYS} 4x20 LCD display is used.${NC}" 
elif [ "$NUM_LCD_DISPLAYS" -eq 2 ] ; then
  echo -e "${GREEN}[OK] ${NUM_LCD_DISPLAYS} 4x20 LCD displays are used.${NC}" 
else
  echo -e "${RED}[ERROR] The number of 4x20 LCD displays used must be 0, 1 or 2.${NC}" 
  usage
  exit 1
fi

# ------------------------------
# | Check the operating system |
# ------------------------------

if [[ "$OSTYPE" == "linux-gnu" || "$OSTYPE" == "linux-gnueabihf" ]]; then
    # Linux
    echo -e "${YELLOW}[INFO] The operating system is Linux: ${OSTYPE}${NC}" | ${TEE_PROGRAM_LOG} 
elif [[ "$OSTYPE" == "freebsd"* ]]; then
    # FreeBSD
    echo -e "${YELLOW}[INFO] The operating system is FreeBSD: ${OSTYPE}${NC}" | ${TEE_PROGRAM_LOG} 
    echo -e "${YELLOW}[INFO] Using the pest detector in FreeBSD was never tested.${NC}" | ${TEE_PROGRAM_LOG} 
    echo -e "${YELLOW}[INFO] Please report to the developer if it worked or not.${NC}" | ${TEE_PROGRAM_LOG} 
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # Mac OS X
    echo -e "${YELLOW}[INFO] The operating system is Mac OS X: ${OSTYPE}${NC}" | ${TEE_PROGRAM_LOG} 
    echo -e "${YELLOW}[INFO] Using the pest detector in Mac OS X was never tested.${NC}" | ${TEE_PROGRAM_LOG} 
    echo -e "${YELLOW}[INFO] Please report to the developer if it worked or not.${NC}" | ${TEE_PROGRAM_LOG} 
elif [[ "$OSTYPE" == "msys" ]]; then
    # Windows 
    echo -e "${YELLOW}[INFO] The operating system is Windows: ${OSTYPE}${NC}" | ${TEE_PROGRAM_LOG} 
    echo -e "${YELLOW}[INFO] Using the pest detector in Windows was never tested.${NC}" | ${TEE_PROGRAM_LOG} 
    echo -e "${YELLOW}[INFO] Please report to the developer if it worked or not.${NC}" | ${TEE_PROGRAM_LOG} 
elif [[ "$OSTYPE" == "cygwin" ]]; then
    # POSIX compatibility layer for Windows
    echo -e "${YELLOW}[INFO] POSIX compatibility layer for Windows detected: ${OSTYPE}${NC}" | ${TEE_PROGRAM_LOG} 
    echo -e "${YELLOW}[INFO] Using the pest detector in Windows was never tested.${NC}" | ${TEE_PROGRAM_LOG} 
    echo -e "${YELLOW}[INFO] Please report to the developer if it worked or not.${NC}" | ${TEE_PROGRAM_LOG} 
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

# This is only required if we use 1 or 2 LCD displays.
if [[ "$NUM_LCD_DISPLAYS" -eq 1 || "$NUM_LCD_DISPLAYS" -eq 2 ]] ; then
  # Check if the LCD "driver" for LCD display 1 (just a command line tool tool to print lines on the LCD) is available
  if ! [ -f "${LCD_DRIVER1}" ] ; then
    echo -e "${RED}[ERROR] The LCD command line tool ${LCD_DRIVER1} is missing.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
  else
    if ! python3 ${CLEAR_LCD_DRIVER1} ; then
      echo -e "${RED}[ERROR] The LCD command line tool ${CLEAR_LCD_DRIVER1} does not operate properly.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
    fi
    # No matter if we have 1 or 2 LCD displays, the first one will show a welcome message
    if ! python3 ${LCD_DRIVER1} "Welcome to" "pestdetector" "on host" "${HOSTNAME}" ; then
      echo -e "${RED}[ERROR] The LCD command line tool ${LCD_DRIVER1} does not operate properly.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
    fi
  fi
fi

sleep 10  ## 1

# This is only required if we use 2 LCD displays.
if [[ "$NUM_LCD_DISPLAYS" -eq 2 ]] ; then
  # Check if the LCD "driver" for LCD display 2 (just a command line tool tool to print lines on the LCD) is available
  if ! [ -f "${LCD_DRIVER1}" ]; then
    echo -e "${RED}[ERROR] The LCD command line tool ${LCD_DRIVER2} is missing.${NC}" && exit 1
  else
    if ! python3 ${CLEAR_LCD_DRIVER2} ; then
      echo -e "${RED}[ERROR] The LCD command line tool ${CLEAR_LCD_DRIVER2} does not operate properly.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
    fi
    if ! python3 ${LCD_DRIVER2} "This display informs" "about the state of" "the pestdetector" "software" ; then
      echo -e "${RED}[ERROR] The LCD command line tool ${LCD_DRIVER2} does not operate properly.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
    fi
  fi
fi

# ------------------------------------------------------
# | Check if the Telegram Bot notification is possible |
# ------------------------------------------------------

# Only if the command line parameter -t is set, the Telegram Bot notifications
# are send when the pest detector is started and when objects are detected
if [ "$USE_TELEGRAM_BOT" -eq 1 ] ; then
  # If the file with the Telegram Bot url token und the chat ID exist, import the
  # variables $TELEGRAM_TOKEN and $TELEGRAM_CHAT_ID
  PEST_DETECT_TELEGRAM_CONFIG_FILE="/home/pi/pest_detect_telegram_credentials.sh"
  if [ -f $PEST_DETECT_TELEGRAM_CONFIG_FILE ] ; then  
    . $PEST_DETECT_TELEGRAM_CONFIG_FILE
    echo -e "${GREEN}[OK] The file with the Telegram Bot information is present.${NC}" | ${TEE_PROGRAM_LOG}
  else 
    echo -e "${YELLOW}[INFO] The file with the Telegram Bot information is not present.${NC}" | ${TEE_PROGRAM_LOG}
  fi

  # Check if all variables that are required for the Telegram Bot notification
  # do exist and are not empty 
  if [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ] ; then
    echo -e "${YELLOW}[INFO] One or more variables that are reqiored for the Telegram Bot notifications are undefined.${NC}" | ${TEE_PROGRAM_LOG}
    echo -e "${YELLOW}[INFO] Please set the variables \$TELEGRAM_TOKEN and \$TELEGRAM_CHAT_ID if you want using Telegram Bot notifications.${NC}" | ${TEE_PROGRAM_LOG}
    TELEGRAM_NOTIFICATIONS=0
  else
    TELEGRAM_NOTIFICATIONS=1  
  fi

  if [[ ${TELEGRAM_NOTIFICATIONS} -eq 1 ]]; then 
    curl -s -X POST ${TELEGRAM_TOKEN}/sendMessage --data text="Pest Detector has been started." --data chat_id=${TELEGRAM_CHAT_ID} > /dev/null
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

# Clear the LCD display(s)
clear_lcd_displays

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

  # This is only required if we use 2 LCD displays
  if [[ "$NUM_LCD_DISPLAYS" -eq 2 ]] ; then
    # Print some information on LCD display 2
    LCD_LINE_2_1="Make a picture      "
    LCD_LINE_2_2="                    "
    LCD_LINE_2_3="                    "
    LCD_LINE_2_4="                    "
    if ! python3 ${LCD_DRIVER2} "${LCD_LINE_2_1}" "${LCD_LINE_2_2}" "${LCD_LINE_2_3}" "${LCD_LINE_2_4}" ; then
      echo -e "${RED}[ERROR] The LCD command line tool ${LCD_DRIVER2} does not operate properly.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
    fi
  # If we just have 1 LCD display, print some status information on LCD display 1
  elif [[ "$NUM_LCD_DISPLAYS" -eq 1 ]] ; then
    LCD_LINE_1_1="Make a picture      "
    if ! python3 ${LCD_DRIVER1} "${LCD_LINE_1_1}" "${LCD_LINE_1_2}" "${LCD_LINE_1_3}" "${LCD_LINE_1_4}" ; then
      echo -e "${RED}[ERROR] The LCD command line tool ${LCD_DRIVER1} does not operate properly.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
    fi
  fi

sleep 10  ## 2

  make_a_picture

  # -----------------------------------------
  # | Object detection and logfile creation |
  # -----------------------------------------

  # This is only required if we use 2 LCD displays
  if [[ "$NUM_LCD_DISPLAYS" -eq 2 ]] ; then
    # Print some information on LCD display 2
    LCD_LINE_2_1="                    "
    LCD_LINE_2_2="Detect objects      "
    LCD_LINE_2_3="                    "
    LCD_LINE_2_4="                    "
    if ! python3 ${LCD_DRIVER2} "${LCD_LINE_2_1}" "${LCD_LINE_2_2}" "${LCD_LINE_2_3}" "${LCD_LINE_2_4}" ; then
      echo -e "${RED}[ERROR] The LCD command line tool ${LCD_DRIVER2} does not operate properly.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
    fi
  # If we just have 1 LCD display, print some status information on LCD display 1
  elif [[ "$NUM_LCD_DISPLAYS" -eq 1 ]] ; then
    LCD_LINE_1_1="Detect objects      "
    if ! python3 ${LCD_DRIVER1} "${LCD_LINE_1_1}" "${LCD_LINE_1_2}" "${LCD_LINE_1_3}" "${LCD_LINE_1_4}" ; then
      echo -e "${RED}[ERROR] The LCD command line tool ${LCD_DRIVER1} does not operate properly.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
    fi
  fi

sleep 10  ## 3

  detect_objects

  # ----------------------------------------------------
  # | Check of one or more objects have been detected. |
  # | If there have been objects detected, move the    | 
  # | picture and the log file to the images directory |
  # ----------------------------------------------------

  # This is only required if we use 2 LCD displays
  if [[ "$NUM_LCD_DISPLAYS" -eq 2 ]] ; then
    # Print some information on LCD display 2
    LCD_LINE_2_1="                    "
    LCD_LINE_2_2="                    "
    LCD_LINE_2_3="Analyze results     "
    LCD_LINE_2_4="                    "
    if ! python3 ${LCD_DRIVER2} "${LCD_LINE_2_1}" "${LCD_LINE_2_2}" "${LCD_LINE_2_3}" "${LCD_LINE_2_4}" ; then
      echo -e "${RED}[ERROR] The LCD command line tool ${LCD_DRIVER2} does not operate properly.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
    fi
  # If we just have 1 LCD display, print some status information on LCD display 1
  elif [[ "$NUM_LCD_DISPLAYS" -eq 1 ]] ; then
    LCD_LINE_1_1="Analyze results     "
    if ! python3 ${LCD_DRIVER1} "${LCD_LINE_1_1}" "${LCD_LINE_1_2}" "${LCD_LINE_1_3}" "${LCD_LINE_1_4}" ; then
      echo -e "${RED}[ERROR] The LCD command line tool ${LCD_DRIVER1} does not operate properly.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
    fi
  fi

  sleep 10  ## 4

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
    # This is only required if we use 1 or 2 LCD displays
    if [[ "$NUM_LCD_DISPLAYS" -eq 1 || "$NUM_LCD_DISPLAYS" -eq 2 ]] ; then
      print_result_on_LCD 
    fi
    # Write information about deteceted objects into log file
    write_detected_objects_message_into_logfile
    # Telegram Bot notification about detected objects will only be send if the
    # user wants to do this by providing command line argument -t and if the 
    # required variables $TELEGRAM_TOKEN and $TELEGRAM_CHAT_ID are present
    if [[ ${USE_TELEGRAM_BOT} -eq 1 && ${TELEGRAM_NOTIFICATIONS} -eq 1 ]]; then 
      # Inform the Telegram Bot about the detected objects
      inform_telegram_bot
    fi  
  else
    # If no object has been detected...
    # This is only required if we use 1 or 2 LCD displays.
    if [[ "$NUM_LCD_DISPLAYS" -eq 1 || "$NUM_LCD_DISPLAYS" -eq 2 ]] ; then
      print_no_object_detected_on_LCD
    fi
  fi

  # ----------------------------------------------
  # | Prevent the images directory from overflow |
  # ----------------------------------------------

  # This is only required if we use 2 LCD displays
  if [[ "$NUM_LCD_DISPLAYS" -eq 2 ]] ; then
    # Print some information on LCD display 2
    LCD_LINE_2_1="                    "
    LCD_LINE_2_2="                    "
    LCD_LINE_2_3="                    "
    LCD_LINE_2_4="Organize folders    "
    if ! python3 ${LCD_DRIVER2} "${LCD_LINE_2_1}" "${LCD_LINE_2_2}" "${LCD_LINE_2_3}" "${LCD_LINE_2_4}" ; then
      echo -e "${RED}[ERROR] The LCD command line tool ${LCD_DRIVER2} does not operate properly.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
    fi
  # If we just have 1 LCD display, print some status information on LCD display 1
  elif [[ "$NUM_LCD_DISPLAYS" -eq 1 ]] ; then
    LCD_LINE_1_1="Organize folders    "
    if ! python3 ${LCD_DRIVER1} "${LCD_LINE_1_1}" "${LCD_LINE_1_2}" "${LCD_LINE_1_3}" "${LCD_LINE_1_4}" ; then
      echo -e "${RED}[ERROR] The LCD command line tool ${LCD_DRIVER1} does not operate properly.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
    fi
  fi

sleep 10  ## 5

  prevent_directory_overflow    

done

exit 0