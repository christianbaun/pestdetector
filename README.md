[![GPLv3 license](https://img.shields.io/badge/License-GPLv3-blue.svg)](http://perso.crans.org/besson/LICENSE.html)
[![made-with-bash](https://img.shields.io/badge/-Made%20with%20Bash-1f425f.svg)](https://www.gnu.org/software/bash/)

# pestdetector

This repository contains bash scripts, python scripts, and documentation material, that I created for my pest detector prototype research work. The pest detector script collection is a command-line tool for detecting rats and other forms of pests like cockroaches in images that are created by a Raspberry Pi single-board computer with a Raspberry Pi High-Quality Camera (hqcam), or a Raspberry Pi Camera V2, or a similar model. The object detection is done by TensorFlow lite that runs on the Raspberry Pi and is accelerated by a Coral Accelerator TPU coprocessor.

## Synopsis

    pestdetector.sh [-h] [-m <modelname>] [-l <labelmap>] [-i <directory>] [-s <size>] [-j <directory>] [-t] [-d <number>]

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
        The bot token url and the chat ID must be specified as variables $TELEGRAM_TOKEN
        and $TELEGRAM_CHAT_ID in the file /home/pi/pest_detect_telegram_credentials.sh
    -d : use 0, 1 or 2 LCD displays (4x20)

## Requirements

These software packages must be installed:

- [bash](https://www.gnu.org/software/bash/) 5.0.3
- [libcamera-still](https://libcamera.org/) from the libcamera open source camera stack
- [raspistill](https://github.com/raspberrypi/userland/blob/master/host_applications/linux/apps/raspicam/RaspiStill.c) as an alternative tool to libcamera-still
- [curl](https://curl.se) 7.64.0
- hostname 3.21
- [ping](https://github.com/iputils/iputils) iputils-s20180629

## Examples

This command starts pest detector and specidies that a the telegram bot notification is used and two LCD displays (4x20) are used to inform about detected objects and the state of the pest detector tool.

`./pestdetector.sh -t -d 2`

## Third party components

The TensorFlow Lite application is taken from [here](https://github.com/EdjeElectronics/TensorFlow-Lite-Object-Detection-on-Android-and-Raspberry-Pi). I modified mainly the output.

The LCD driver is taken from [here](https://github.com/ArcadiaLabs/raspberry_lcd4x20_I2C)

## Related Work

Some interesting papers and software projects focusing on object detection with single-board computers:

- [Where's The Bear? - Automating Wildlife Image Processing Using IoT and Edge Cloud Systems]{https://cs.ucsb.edu/sites/default/files/documents/tr.pdf}. The authors performed wildlife detection (bear, deer, and coyote) on WIFI-connected edge nodes with motion-triggered cameras. In this project, the training was done using external cloud services. The way of training data generation is remarkable. Background images without animals were combined with animal images (with transparent background) from Google Image Search at different times of the day. In this project, Tensorflow and OpenCV were used. The image recognition worked very well. The classification accuracy with a TensorFlow confidence value of more than 90% was 66% for all tested images. The error rate for coyote was 0.2%, the error rate for bear was 1% and the error rate for deer was 12%. 

## Web Site

Visit the pestdetect web page for more information and the latest revision.

[https://github.com/christianbaun/pestdetector](https://github.com/christianbaun/pestdetector)

## License

[GPLv3](https://www.gnu.org/licenses/gpl-3.0.en.html) or later for the pestdetector.sh<br/>
[GPLv2](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html) or later for the LCD driver<br/>
[Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0) or later for the TFLite application 

