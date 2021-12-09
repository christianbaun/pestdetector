#!/bin/bash
#
# title:        functionlibrary.sh
# description:  This file contains the functions of pestdetector.sh
# author:       Dr. Christian Baun
# url:          https://github.com/christianbaun/pestdetector
# license:      GPLv3
# date:         December 9th 2021
# version:      0.14
# bash_version: tested with 5.1.4(1)-release
# requires:     libcamera-still command line tool that uses the libcamera open 
#               source camera stack.
# optional:     none
# notes:        This script has been developed to run on a Raspberry Pi 4 
#               (4 GB RAM). A LCD 4x20 with a HD44780 controller, 
#               connected via the I2C interface is used to inform about the
#               work of the pest detector.
# example:      ./pestdetector.sh
# ----------------------------------------------------------------------------

# ----------------------------------------
# | Try to make a picture with the camera|
# ----------------------------------------

function make_a_picture(){
  # Store timestamp of the date and time in a variable
  DATE_TIME_STAMP=$(date +%Y-%m-%d)
  CLOCK_TIME_STAMP=$(date +%H-%M-%S)
  DATE_AND_TIME_STAMP="${DATE_TIME_STAMP}-${CLOCK_TIME_STAMP}"
  IMAGE_FILENAME_AND_PATH="${DIRECTORY_MOST_RECENT_IMAGE}/${DATE_AND_TIME_STAMP}.jpg"

  # We use the new libcamera tools and not the legacy raspistill tool
  # The old command to make a picture was:
  # raspistill -n -o ${IMAGE_FILENAME_AND_PATH}
  # The new libcamera-still tool works in a similar way.
  # The parameters are:
  # -n = no preview window
  # -t n: timeout in milliseconds. -t 1 says: make the picture as fast a possible
  if libcamera-still -n -t 1 -o ${IMAGE_FILENAME_AND_PATH} &> /dev/shm/libcamera-still_output ; then
    echo -e "${GREEN}[OK] The picture ${IMAGE_FILENAME_AND_PATH} has been created.${NC}"
  else
    echo -e "${RED}[ERROR] Unable to create the picture ${IMAGE_FILENAME_AND_PATH}.${NC}" && exit 1
  fi
}

# -----------------------------------------
# | Object detection and logfile creation |
# -----------------------------------------

function detect_objects(){
  # Filename of the log file
  LOG_FILENAME_AND_PATH="${DIRECTORY_MOST_RECENT_IMAGE}/${DATE_AND_TIME_STAMP}.txt"

  if [[ -f "${IMAGE_FILENAME_AND_PATH}" ]] ; then
    python3 TFLite_detection_image_modified.py --modeldir=${MODEL} --graph=detect_edgetpu.tflite --labels=${LABELS} --edgetpu --image=${IMAGE_FILENAME_AND_PATH} 2>&1 | tee -a ${LOG_FILENAME_AND_PATH}
  else
    # There should be a log file. If there is no log file, something strange happened
    echo -e "${RED}[ERROR] The image file ${IMAGE_FILENAME_AND_PATH} was not found.${NC}" && exit 1
  fi
}

# ----------------------------------------------------
# | Check of one or more objects have been detected. |
# | If there have been objects detected, move the    | 
# | picture and the log file to the images directory |
# ----------------------------------------------------

function check_if_objects_have_been_deteted(){
  # Check in the log file of the picture what the output of TFLite_detection_image_modified.py is
  # If one or more objects have been detected, there will be one or more lines like these:
  # Detected Object: rat with 87 %
  # The return code of grep is 0 when the search patern "Detected" is inside the log file at least one time.
  if grep "Detected" ${LOG_FILENAME_AND_PATH} ; then
    HIT=1
    echo -e "${GREEN}[OK] One or more objects have been deteted in the picture ${LOG_FILENAME_AND_PATH}.${NC}"
    # Move the picture file from the directory "most_recent_image" to the directory "images" 
    if mv ${IMAGE_FILENAME_AND_PATH} ${DIRECTORY_IMAGES} ; then
      echo -e "${GREEN}[OK] The picture ${IMAGE_FILENAME_AND_PATH} has been moved to the directory ${DIRECTORY_IMAGES}.${NC}"
    else
      # If it is implossible to move the picture file, something strange happened
      echo -e "${RED}[ERROR] The attempt to move the picture ${IMAGE_FILENAME_AND_PATH} to the directory ${DIRECTORY_IMAGES} failed.${NC}" && exit 1
    fi
    # Move the log file from the directory "most_recent_image" to the directory "images" 
    if mv ${LOG_FILENAME_AND_PATH} ${DIRECTORY_IMAGES} ; then
      echo -e "${GREEN}[OK] The logfile ${LOG_FILENAME_AND_PATH} has been moved to the directory ${DIRECTORY_IMAGES}.${NC}"
    else
      # If it is implossible to move the log file, something strange happened
      echo -e "${RED}[ERROR] The attempt to move the logfile ${LOG_FILENAME_AND_PATH} to the directory ${DIRECTORY_IMAGES} failed.${NC}" && exit 1
    fi
  else
    HIT=0
    echo -e "${GREEN}[OK] No objects have been detected in the picture ${LOG_FILENAME_AND_PATH}.${NC}"
    # If no objects have been detected in the picture, the content of the directory "most_recent_image" is erased
    if rm ${DIRECTORY_MOST_RECENT_IMAGE}/* ; then
      echo -e "${GREEN}[OK] The directory ${DIRECTORY_MOST_RECENT_IMAGE} has been emptied.${NC}"
    else
      # If it is implossible to erase of files inside the directory "most_recent_image"
      echo -e "${RED}[ERROR] The attempt to erase all files inside the directory ${DIRECTORY_MOST_RECENT_IMAGE} failed.${NC}" && exit 1
    fi
  fi
}

# ----------------------------------------------------
# | If one or more objects have been detected, print |
# | the results on the LCD screen                    |
# ----------------------------------------------------

function print_result_on_LCD(){
  # Count in the log file of the picture the number of lines that that contain "Detected"
  NUMBER_OF_LINES_IN_LOG_FILE_WITH_DETECTED=$(grep -c Detected ${DIRECTORY_IMAGES}/${DATE_AND_TIME_STAMP}.txt) 
  # If there is just a single line that contain "Detected"...
  if [ "$NUMBER_OF_LINES_IN_LOG_FILE_WITH_DETECTED" -eq 1 ] ; then
    # Fetch from the log file of the picture all lines that contain "Detected" and take the first one.
    # The pattern "Detected Object: " at the very beginning of the line is removed by using sed
    LINE1_DETECTED=$(cat ${DIRECTORY_IMAGES}/${DATE_AND_TIME_STAMP}.txt | grep Detected | head -n 1 | sed 's/Detected Object: //' )
    LINE2_DETECTED=""
    LINE3_DETECTED=""
  # If two lines contain "Detected" => the number of detected objects is equal 2...
  elif [ "$NUMBER_OF_LINES_IN_LOG_FILE_WITH_DETECTED" -eq 2 ] ; then  
    # Fetch from the log file of the picture all lines that contain "Detected" and take the first one.
    # The pattern "Detected Object: " at the very beginning of the line is removed by using sed
    LINE1_DETECTED=$(cat ${DIRECTORY_IMAGES}/${DATE_AND_TIME_STAMP}.txt | grep Detected | head -n 1 | sed 's/Detected Object: //' )
    # Fetch from the log file of the picture all lines that contain "Detected" and take the first two lines 
    # and keep just the last one, which is the second from top.
    # The pattern "Detected Object: " at the very beginning of the line is removed by using sed
    LINE2_DETECTED=$(cat ${DIRECTORY_IMAGES}/${DATE_AND_TIME_STAMP}.txt | grep Detected | head -n 2 | tail -n 1 | sed 's/Detected Object: //' )
    # Fetch from the log file of the picture all lines that contain "Detected" and take the first three lines 
    # and keep just the last one, which is the third from top.
    # The pattern "Detected Object: " at the very beginning of the line is removed by using sed
    LINE3_DETECTED=""
  # If three or more lines contain "Detected" => the number of detected objects is greater or equal 3...
  elif [ "$NUMBER_OF_LINES_IN_LOG_FILE_WITH_DETECTED" -ge 3 ] ; then  
    # Fetch from the log file of the picture all lines that contain "Detected" and take the first one.
    # The pattern "Detected Object: " at the very beginning of the line is removed by using sed
    LINE1_DETECTED=$(cat ${DIRECTORY_IMAGES}/${DATE_AND_TIME_STAMP}.txt | grep Detected | head -n 1 | sed 's/Detected Object: //' )
    # Fetch from the log file of the picture all lines that contain "Detected" and take the first two lines 
    # and keep just the last one, which is the second from top.
    # The pattern "Detected Object: " at the very beginning of the line is removed by using sed
    LINE2_DETECTED=$(cat ${DIRECTORY_IMAGES}/${DATE_AND_TIME_STAMP}.txt | grep Detected | head -n 2 | tail -n 1 | sed 's/Detected Object: //' )
    # Fetch from the log file of the picture all lines that contain "Detected" and take the first three lines 
    # and keep just the last one, which is the third from top.
    # The pattern "Detected Object: " at the very beginning of the line is removed by using sed
    LINE3_DETECTED=$(cat ${DIRECTORY_IMAGES}/${DATE_AND_TIME_STAMP}.txt | grep Detected | head -n 3 | tail -n 1 | sed 's/Detected Object: //' )
    LINE4_DETECTED=""
  else
    # If the object detection resulted in a hit, the log file should contain at least a single
    # line with contains "Detected". If not, something strange happened
    LINE1_DETECTED=""
    LINE2_DETECTED=""
    LINE3_DETECTED=""
  fi
  # Now, try to print the results of the object detection on the LCD screen
  # And have colons insted of dashes in the variable CLOCK_TIME_STAMP
  CLOCK_TIME_STAMP_WITH_COLONS=$(echo ${CLOCK_TIME_STAMP} | sed 's/-/:/g' )
  if ! python3 ${LCD_DRIVER1} "${DATE_TIME_STAMP} ${CLOCK_TIME_STAMP_WITH_COLONS}" "$LINE1_DETECTED" "$LINE2_DETECTED" "$LINE3_DETECTED" ; then
    echo -e "${RED}[ERROR] The LCD command line tool ${LCD_DRIVER1} does not operate properly.${NC}" && exit 1
  fi
} 

# ------------------------------------------------------------------------
# | If no objects have been detected, print the result on the LCD screen |
# ------------------------------------------------------------------------

function print_no_object_detected_on_LCD(){
  CLOCK_TIME_STAMP_WITH_COLONS=$(echo ${CLOCK_TIME_STAMP} | sed 's/-/:/g' )
  if ! python3 ${LCD_DRIVER1} "${DATE_TIME_STAMP} ${CLOCK_TIME_STAMP_WITH_COLONS}" "No objects detected" "" "" ; then
    echo -e "${RED}[ERROR] The LCD command line tool ${LCD_DRIVER1} does not operate properly.${NC}" && exit 1
  fi
} 

# ----------------------------------------------
# | Prevent the images directory from overflow |
# ----------------------------------------------

function prevent_directory_overflow(){
  # Get the sum of the bytes in the images directory and keep only the first column of the output with awk
  DIRECTORY_IMAGES_ACTUAL_SIZE=$(du -s ${DIRECTORY_IMAGES} | awk '{ print $1 }')

  # Get the number of files in the images directory
  # But first, check if the images directory is not empty and contains a least a single jpg file
  if [[ -z "$(ls -A ${DIRECTORY_IMAGES})" ]] ; then
    # -z string True if the string is null (an empty string)
    # -A means list all except . and ..
    echo -e "${GREEN}[OK] The directory ${DIRECTORY_IMAGES} is empty.${NC}"
  else
    DIRECTORY_IMAGES_NUMBER_OF_FILES=$(ls -Ubad1 ${DIRECTORY_IMAGES}/*.jpg | wc -l)
  
    # Get the sum of the bytes in the images directory and keep only the first column of the output with awk
    DIRECTORY_IMAGES_ACTUAL_SIZE=$(du -s ${DIRECTORY_IMAGES} | awk '{ print $1 }')

    echo -e "${GREEN}[OK] Files in ${DIRECTORY_IMAGES}: ${DIRECTORY_IMAGES_NUMBER_OF_FILES}${NC}"
    echo -e "${GREEN}[OK] Used Bytes in ${DIRECTORY_IMAGES}: ${DIRECTORY_IMAGES_ACTUAL_SIZE}${NC}"   
  fi
    
  if [[ "${DIRECTORY_IMAGES_ACTUAL_SIZE}" -lt "${DIRECTORY_IMAGES_MAX_SIZE}" ]] ; then
    echo -e "${GREEN}[OK] There is enough free storage capacity in the directory ${DIRECTORY_IMAGES}${NC}"
  else
    echo -e "${YELLOW}[INFO] The directory ${DIRECTORY_IMAGES} consumes ${DIRECTORY_IMAGES_ACTUAL_SIZE} Bytes which is more than the permitted maximum ${DIRECTORY_IMAGES_MAX_SIZE} Bytes.${NC}"  
    while [ "${DIRECTORY_IMAGES_ACTUAL_SIZE}" -gt "${DIRECTORY_IMAGES_MAX_SIZE}" ]; do 
      DIRECTORY_IMAGES_OLDEST_FILE=$(ls -t ${DIRECTORY_IMAGES} | tail -1)
      if rm ${DIRECTORY_IMAGES}/${DIRECTORY_IMAGES_OLDEST_FILE}; then
        echo -e "${GREEN}[OK] Erased the file ${DIRECTORY_IMAGES_OLDEST_FILE} from ${DIRECTORY_IMAGES}${NC}"
        # Fetch the new sum of the bytes in the images directory and keep only the first column of the output with awk
        DIRECTORY_IMAGES_ACTUAL_SIZE=$(du -s ${DIRECTORY_IMAGES} | awk '{ print $1 }')
      else 
        echo -e "${RED}[INFO] Attention: Unable to erase ${DIRECTORY_IMAGES_OLDEST_FILE} from directory ${DIRECTORY_IMAGES}!${NC}" && exit 1
      fi
    done
    echo -e "${GREEN}[OK] Now, the directory ${DIRECTORY_IMAGES} consumes ${DIRECTORY_IMAGES_ACTUAL_SIZE} Bytes which is less than the permitted maximum ${DIRECTORY_IMAGES_MAX_SIZE} Bytes.${NC}" 
  fi
}