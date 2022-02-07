#!/bin/bash
#
# title:        functionlibrary.sh
# description:  This file contains the functions of pestdetector.sh
# author:       Dr. Christian Baun
# url:          https://github.com/christianbaun/pestdetector
# license:      GPLv3
# date:         February 7th 2022
# version:      1.4
# bash_version: tested with 5.1.4(1)-release
# requires:     libcamera-still command line tool that uses the libcamera open 
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
#               (4 GB RAM). A LCD 4x20 with a HD44780 controller, 
#               connected via the I2C interface is used to inform about the
#               work of the pest detector.
# example:      ./pestdetector.sh
# ----------------------------------------------------------------------------

# ----------------------------
# | Clear the LCD display(s) |
# ----------------------------

function clear_lcd_displays(){
  # This is required if we use 1 or 2 LCD displays.
  if [[ "$NUM_LCD_DISPLAYS" -eq 1 || "$NUM_LCD_DISPLAYS" -eq 2 ]] ; then
    if ! python3 ${CLEAR_LCD_DRIVER1} ; then
      echo -e "${RED}[ERROR] The LCD command line tool ${CLEAR_LCD_DRIVER2} does not operate properly.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
    fi
  fi

  # This is only required if we use 2 LCD displays.
  if [[ "$NUM_LCD_DISPLAYS" -eq 2 ]] ; then
    if ! python3 ${CLEAR_LCD_DRIVER2} ; then
      echo -e "${RED}[ERROR] The LCD command line tool ${CLEAR_LCD_DRIVER2} does not operate properly.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
    fi
  fi
}

# ----------------------------------------
# | Try to make a picture with the camera|
# ----------------------------------------

function make_a_picture(){
  # Store timestamp of the date and time in a variable
  DATE_TIME_STAMP=$(date +%Y-%m-%d)
  CLOCK_TIME_STAMP=$(date +%H-%M-%S)
  DATE_AND_TIME_STAMP="${DATE_TIME_STAMP}-${CLOCK_TIME_STAMP}"
  IMAGE_FILENAME_AND_PATH="${DIRECTORY_MOST_RECENT_IMAGE}/${DATE_AND_TIME_STAMP}.jpg"

  ROTATE_PARAMETER=""
  if [[ ${ROTATE_CAMERA_IMAGE} -eq 1 ]]; then 
    ROTATE_PARAMETER="--hflip --vflip"
    echo -e "${GREEN}[OK] The camera picture will be rotated 180 degree.${NC}" | ${TEE_PROGRAM_LOG}
  fi

  # Per default, we use the new libcamera tools and not the legacy raspistill tool
  # The parameters are:
  # -n = no preview window
  # -t n: timeout in milliseconds. -t 1 says: make the picture as fast a possible

  # If libcamera-still is present and working, we will use it...
  if [[ ${TRY_LEGACY_RASPISTILL} -eq 0 ]]; then 
    if libcamera-still -n ${ROTATE_PARAMETER} -t 1 -o ${IMAGE_FILENAME_AND_PATH} &> /dev/shm/libcamera-still_output ; then
      echo -e "${GREEN}[OK] The picture ${IMAGE_FILENAME_AND_PATH} has been created with libcamera-still.${NC}" | ${TEE_PROGRAM_LOG}
    else
      echo -e "${RED}[ERROR] Unable to create the picture ${IMAGE_FILENAME_AND_PATH} with libcamera-still.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
    fi 
  # If libcamera-still is not present and working, we will try using raspistill instead...
  else
    if raspistill -n ${ROTATE_PARAMETER} -t 1 -o ${IMAGE_FILENAME_AND_PATH} &> /dev/shm/raspistill_output ; then
      echo -e "${GREEN}[OK] The picture ${IMAGE_FILENAME_AND_PATH} has been created with raspistill.${NC}" | ${TEE_PROGRAM_LOG}
    else
      echo -e "${RED}[ERROR] Unable to create the picture ${IMAGE_FILENAME_AND_PATH} with raspistill.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
    fi
  fi
}

# -----------------------------------------
# | Object detection and logfile creation |
# -----------------------------------------

function detect_objects(){
  # Filename of the log file
  LOG_FILENAME_AND_PATH="${DIRECTORY_MOST_RECENT_IMAGE}/${DATE_AND_TIME_STAMP}.txt"

  if [[ -f "${IMAGE_FILENAME_AND_PATH}" ]] ; then
    
    # Check, if the user wants to use the Coral Accelerator TPU coprocessor (specified with command line parameter -c)
    if [ "$USE_CORAL_TPU_COPROCESSOR" -eq 1 ] ; then
      echo -e "${YELLOW}[INFO] Try to detect obects with the Coral Accelerator TPU coprocessor.${NC}" | ${TEE_PROGRAM_LOG}      
      time python3 TFLite_detection_image_modified.py --modeldir=${MODEL} --graph=detect_edgetpu.tflite --labels=${LABELS} --edgetpu --image=${IMAGE_FILENAME_AND_PATH} 2>&1 | tee -a ${LOG_FILENAME_AND_PATH}
    else
      # If the user does not want to use the Coral Accelerator TPU coprocessor...
      echo -e "${YELLOW}[INFO] Try to detect obects without the Coral Accelerator TPU coprocessor by just using the CPU.${NC}" | ${TEE_PROGRAM_LOG}      
      time python3 TFLite_detection_image_modified.py --modeldir=${MODEL} --graph=detect.tflite --labels=${LABELS} --image=${IMAGE_FILENAME_AND_PATH} 2>&1 | tee -a ${LOG_FILENAME_AND_PATH}
    fi
  else
    # There should be a log file. If there is no log file, something strange happened
    echo -e "${RED}[ERROR] The image file ${IMAGE_FILENAME_AND_PATH} was not found.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
  fi
}

# ----------------------------------------------------
# | Check if one or more objects have been detected. |
# | If there have been objects detected, move the    | 
# | picture and the log file to the images directory |
# ----------------------------------------------------

function check_if_objects_have_been_deteted(){
  # Check in the log file of the picture what the output of TFLite_detection_image_modified.py is
  # If one or more objects have been detected, there will be one or more lines like these:
  # Detected Object: rat with 87 %
  # The return code of grep is 0 when the search patern "Detected" is inside the log file at least one time.
  if grep "Detected" ${LOG_FILENAME_AND_PATH} > /dev/null ; then
    HIT=1
    echo -e "${GREEN}[OK] One or more objects have been detected in the picture ${LOG_FILENAME_AND_PATH}.${NC}" | ${TEE_PROGRAM_LOG}
    # Move the picture file from the directory "most_recent_image" to the directory "images" 
    if mv ${IMAGE_FILENAME_AND_PATH} ${DIRECTORY_IMAGES} ; then
      echo -e "${GREEN}[OK] The picture ${IMAGE_FILENAME_AND_PATH} has been moved to the directory ${DIRECTORY_IMAGES}.${NC}" | ${TEE_PROGRAM_LOG}
    else
      # If it is implossible to move the picture file, something strange happened
      echo -e "${RED}[ERROR] The attempt to move the picture ${IMAGE_FILENAME_AND_PATH} to the directory ${DIRECTORY_IMAGES} failed.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
    fi
    # Move the log file from the directory "most_recent_image" to the directory "images" 
    if mv ${LOG_FILENAME_AND_PATH} ${DIRECTORY_IMAGES} ; then
      echo -e "${GREEN}[OK] The logfile ${LOG_FILENAME_AND_PATH} has been moved to the directory ${DIRECTORY_IMAGES}.${NC}" | ${TEE_PROGRAM_LOG}
    else
      # If it is implossible to move the log file, something strange happened
      echo -e "${RED}[ERROR] The attempt to move the logfile ${LOG_FILENAME_AND_PATH} to the directory ${DIRECTORY_IMAGES} failed.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
    fi
  else
    HIT=0
    echo -e "${GREEN}[OK] No objects have been detected in the picture ${LOG_FILENAME_AND_PATH}.${NC}" | ${TEE_PROGRAM_LOG}
    # If no objects have been detected in the picture, the content of the directory "most_recent_image" is erased
    if rm ${DIRECTORY_MOST_RECENT_IMAGE}/* ; then
      echo -e "${GREEN}[OK] The directory ${DIRECTORY_MOST_RECENT_IMAGE} has been emptied.${NC}" | ${TEE_PROGRAM_LOG}
    else
      # If it is implossible to erase of files inside the directory "most_recent_image"
      echo -e "${RED}[ERROR] The attempt to erase all files inside the directory ${DIRECTORY_MOST_RECENT_IMAGE} failed.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
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
    LINE2_DETECTED="                    "
    LINE3_DETECTED="                    "
    LCD_LINE_1_2=$(echo ${LINE1_DETECTED} | sed -e :a -e 's/^.\{1,19\}$/&\ /;ta')
    LCD_LINE_1_3="                    "
    LCD_LINE_1_4="                    "
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
    LINE3_DETECTED="                    "
    LCD_LINE_1_2=$(echo ${LINE1_DETECTED} | sed -e :a -e 's/^.\{1,19\}$/&\ /;ta')
    LCD_LINE_1_3=$(echo ${LINE2_DETECTED} | sed -e :a -e 's/^.\{1,19\}$/&\ /;ta')
    LCD_LINE_1_4="                    "
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
    LCD_LINE_1_2=$(echo ${LINE1_DETECTED} | sed -e :a -e 's/^.\{1,19\}$/&\ /;ta')
    LCD_LINE_1_3=$(echo ${LINE2_DETECTED} | sed -e :a -e 's/^.\{1,19\}$/&\ /;ta')
    LCD_LINE_1_4=$(echo ${LINE3_DETECTED} | sed -e :a -e 's/^.\{1,19\}$/&\ /;ta')
  else
    # If the object detection resulted in a hit, the log file should contain at least a single
    # line with contains "Detected". If not, something strange happened
    LCD_LINE_1_2="Something           "
    LCD_LINE_1_3="strange             "
    LCD_LINE_1_4="happened!           "
  fi
  # Now, try to print the results of the object detection on the LCD screen
  # And have colons insted of dashes in the variable CLOCK_TIME_STAMP
  CLOCK_TIME_STAMP_WITH_COLONS=$(echo ${CLOCK_TIME_STAMP} | sed 's/-/:/g' )
  # If we use 2 LCD displays
  if [[ "$NUM_LCD_DISPLAYS" -eq 2 ]] ; then
    LCD_LINE_1_1="${DATE_TIME_STAMP} ${CLOCK_TIME_STAMP_WITH_COLONS}"
    if ! python3 ${LCD_DRIVER1} "${LCD_LINE_1_1}" "${LCD_LINE_1_2}" "${LCD_LINE_1_3}" "${LCD_LINE_1_4}" ; then
    #if ! python3 ${LCD_DRIVER1} "${LCD_LINE_1_1}" "${LINE1_DETECTED}" "${LINE2_DETECTED}" "${LINE3_DETECTED}" ; then
      echo -e "${RED}[ERROR] The LCD command line tool ${LCD_DRIVER1} does not operate properly.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
    fi    
  # If we just have 1 LCD display
  elif [[ "$NUM_LCD_DISPLAYS" -eq 1 ]] ; then
    LCD_LINE_1_2="${DATE_TIME_STAMP} ${CLOCK_TIME_STAMP_WITH_COLONS}"
    # Pad the lines with blanks by using sed. We need 20 characters for the LCD display. 
    # Otherwise we have trouble with the old content.
    # Inspired by here: https://www.theunixschool.com/2012/05/right-pad-string-or-number-with-zero.html

    # If we have just a single object detected, we use the line 3 of LCD display 1 to show the result
    # and erase line 4.
    if [[ "$NUMBER_OF_LINES_IN_LOG_FILE_WITH_DETECTED" -eq 1 ]] ; then
    LCD_LINE_1_3=$(echo ${LINE1_DETECTED} | sed -e :a -e 's/^.\{1,19\}$/&\ /;ta')
    LCD_LINE_1_4="                    "
    fi
    # If we have two or more objects detected, we use the lines 3 and 4 of LCD display 1 to show the results.
    if [[ "$NUMBER_OF_LINES_IN_LOG_FILE_WITH_DETECTED" -ge 2 ]] ; then
    LCD_LINE_1_3=$(echo ${LINE1_DETECTED} | sed -e :a -e 's/^.\{1,19\}$/&\ /;ta')
    LCD_LINE_1_4=$(echo ${LINE2_DETECTED} | sed -e :a -e 's/^.\{1,19\}$/&\ /;ta')
    fi
    if ! python3 ${LCD_DRIVER1} "${LCD_LINE_1_1}" "${LCD_LINE_1_2}" "${LCD_LINE_1_3}" "${LCD_LINE_1_4}" ; then
      echo -e "${RED}[ERROR] The LCD command line tool ${LCD_DRIVER1} does not operate properly.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
    fi
  fi
} 

# -------------------------------------------------------------------
# | If one or more objects have been detected, copy the information |
# | about it into the log file that informs about detected objects  |
# -------------------------------------------------------------------

function write_detected_objects_message_into_logfile(){
  # Count in the log file of the picture the number of lines that that contain "Detected"
  echo "=======================================================================" >> ${LOGFILE_OBJECTS_DETECTED}
  echo "${DIRECTORY_IMAGES}/${DATE_AND_TIME_STAMP}.jpg" >> ${LOGFILE_OBJECTS_DETECTED}
  DETECTED_OBJECTS_OF_LAST_RUN=$(grep Detected ${DIRECTORY_IMAGES}/${DATE_AND_TIME_STAMP}.txt >> ${LOGFILE_OBJECTS_DETECTED}) 
} 

# ------------------------------------------------------------------------
# | If no objects have been detected, print the result on the LCD screen |
# ------------------------------------------------------------------------

function print_no_object_detected_on_LCD(){
  CLOCK_TIME_STAMP_WITH_COLONS=$(echo ${CLOCK_TIME_STAMP} | sed 's/-/:/g' )
  # If we use 2 LCD displays
  if [[ "$NUM_LCD_DISPLAYS" -eq 2 ]] ; then
    LCD_LINE_1_1="${DATE_TIME_STAMP} ${CLOCK_TIME_STAMP_WITH_COLONS}"
    LCD_LINE_1_2="No objects detected "
    LCD_LINE_1_3="                    "
    LCD_LINE_1_4="                    "
  # If we just have 1 LCD display
  elif [[ "$NUM_LCD_DISPLAYS" -eq 1 ]] ; then
    LCD_LINE_1_2="${DATE_TIME_STAMP} ${CLOCK_TIME_STAMP_WITH_COLONS}"
    LCD_LINE_1_3="No objects detected "
    LCD_LINE_1_4="                    "
  fi

  if ! python3 ${LCD_DRIVER1} "${LCD_LINE_1_1}" "${LCD_LINE_1_2}" "${LCD_LINE_1_3}" "${LCD_LINE_1_4}" ; then
    echo -e "${RED}[ERROR] The LCD command line tool ${LCD_DRIVER1} does not operate properly.${NC}" | ${TEE_PROGRAM_LOG} && exit 1
  fi
} 

# ------------------------------------------------------
# | Inform the Telegram Bot about the detected objects |
# ------------------------------------------------------

function inform_telegram_bot(){
  # Why do I need to do this for the second time, after I did it in the function write_detected_objects_message_into_logfile() ???
  DETECTED_OBJECTS_OF_LAST_RUN=$(grep Detected ${DIRECTORY_IMAGES}/${DATE_AND_TIME_STAMP}.txt)
  # Inform the Telegram Bot about the detected objects
  curl -s -F "chat_id=${TELEGRAM_CHAT_ID}" -F "photo=@${DIRECTORY_IMAGES}/${DATE_AND_TIME_STAMP}.jpg" -F caption="${DETECTED_OBJECTS_OF_LAST_RUN}" -X POST ${TELEGRAM_TOKEN}/sendPhoto > /dev/null
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
    echo -e "${GREEN}[OK] The directory ${DIRECTORY_IMAGES} is empty.${NC}" | ${TEE_PROGRAM_LOG}
  else
    DIRECTORY_IMAGES_NUMBER_OF_FILES=$(ls -Ubad1 ${DIRECTORY_IMAGES}/*.jpg | wc -l)
  
    # Get the sum of the bytes in the images directory and keep only the first column of the output with awk
    DIRECTORY_IMAGES_ACTUAL_SIZE=$(du -s ${DIRECTORY_IMAGES} | awk '{ print $1 }')

    echo -e "${GREEN}[OK] Files in ${DIRECTORY_IMAGES}: ${DIRECTORY_IMAGES_NUMBER_OF_FILES}${NC}" | ${TEE_PROGRAM_LOG}
    echo -e "${GREEN}[OK] Used Bytes in ${DIRECTORY_IMAGES}: ${DIRECTORY_IMAGES_ACTUAL_SIZE}${NC}" | ${TEE_PROGRAM_LOG} 
  fi
    
  if [[ "${DIRECTORY_IMAGES_ACTUAL_SIZE}" -lt "${DIRECTORY_IMAGES_MAX_SIZE}" ]] ; then
    echo -e "${GREEN}[OK] There is enough free storage capacity in the directory ${DIRECTORY_IMAGES}${NC}" | ${TEE_PROGRAM_LOG}
  else
    echo -e "${YELLOW}[INFO] The directory ${DIRECTORY_IMAGES} consumes ${DIRECTORY_IMAGES_ACTUAL_SIZE} Bytes which is more than the permitted maximum ${DIRECTORY_IMAGES_MAX_SIZE} Bytes.${NC}" | ${TEE_PROGRAM_LOG}  
    while [ "${DIRECTORY_IMAGES_ACTUAL_SIZE}" -gt "${DIRECTORY_IMAGES_MAX_SIZE}" ]; do 
      DIRECTORY_IMAGES_OLDEST_FILE=$(ls -t ${DIRECTORY_IMAGES} | tail -1)
      if rm ${DIRECTORY_IMAGES}/${DIRECTORY_IMAGES_OLDEST_FILE}; then
        echo -e "${GREEN}[OK] Erased the file ${DIRECTORY_IMAGES_OLDEST_FILE} from ${DIRECTORY_IMAGES}${NC}" | ${TEE_PROGRAM_LOG}
        # Fetch the new sum of the bytes in the images directory and keep only the first column of the output with awk
        DIRECTORY_IMAGES_ACTUAL_SIZE=$(du -s ${DIRECTORY_IMAGES} | awk '{ print $1 }')
      else 
        echo -e "${RED}[INFO] Attention: Unable to erase ${DIRECTORY_IMAGES_OLDEST_FILE} from directory ${DIRECTORY_IMAGES}!${NC}" | ${TEE_PROGRAM_LOG} && exit 1
      fi
    done
    echo -e "${GREEN}[OK] Now, the directory ${DIRECTORY_IMAGES} consumes ${DIRECTORY_IMAGES_ACTUAL_SIZE} Bytes which is less than the permitted maximum ${DIRECTORY_IMAGES_MAX_SIZE} Bytes.${NC}" | ${TEE_PROGRAM_LOG} 
  fi
}
