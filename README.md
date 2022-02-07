[![GPLv3 license](https://img.shields.io/badge/License-GPLv3-blue.svg)](http://perso.crans.org/besson/LICENSE.html)
[![made-with-bash](https://img.shields.io/badge/-Made%20with%20Bash-1f425f.svg)](https://www.gnu.org/software/bash/)

# pestdetector

This repository contains bash scripts, python scripts, and documentation material, that I created for my pest detector prototype research work. The pest detector script collection is a command-line tool for detecting rats and other forms of pests like cockroaches in images that are created by a [Raspberry Pi](https://www.raspberrypi.com) single-board computer node with a Raspberry Pi [High-Quality Camera](https://www.raspberrypi.com/products/raspberry-pi-high-quality-camera/) (hqcam), or a Raspberry Pi [Camera Module 2](https://www.raspberrypi.com/products/camera-module-v2/), or a similar model. The object detection is done by [TensorFlow](https://github.com/tensorflow/tensorflow) lite that runs on the Raspberry Pi and can be done by using the CPU of the single-board computer or by using a [Coral Accelerator TPU coprocessor](https://coral.ai/products/accelerator/).

## Synopsis

    pestdetector.sh [-h] [-m <modelname>] [-l <labelmap>] [-i <directory>] [-s <size>] [-j <directory>] [-t] [-o <time>] [-d <number>] [-c] [-r]

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
    -o : slow motion operation mode for obervation, debugging and documentation purposes. 
         Inserts a pause of <time> seconds between the single steps of the pest detector.
         Minimum value is 1 (= 1 second) and maximum value is 20 (= 20 seconds)
    -d : use 0, 1 or 2 LCD displays (4x20)
    -c : use Coral Accelerator TPU coprocessor 
    -r : rotate the camera image 180 degrees
## Requirements

These software packages must be installed:

- [bash](https://www.gnu.org/software/bash/) (tested with v5.1.4 and v5.0.3)
- [libcamera-still](https://libcamera.org/) from the libcamera open source camera stack
- [raspistill](https://github.com/raspberrypi/userland/blob/master/host_applications/linux/apps/raspicam/RaspiStill.c) as an alternative tool to libcamera-still that uses the legacy camera stack
- [curl](https://curl.se) (tested with v7.74.0 and v7.64.0)
- hostname (tested with v3.21 and v3.23)
- [ping](https://github.com/iputils/iputils) (tested with iputils-20210202 and iputils-s20180629)
- [python](https://www.python.org) 3

## Examples

This command starts the pest detector and specifies that the Telegram bot notification and one LCD display (4x20) are used to inform about detected objects and the state of the pest detector tool and the maximum size of the directory that stores image files with detected objects is 100 MB. Further command-line arguments specify that the Tensorflow lite model used is stored in the directory `mymodelname` (which is a subfolder of `/home/pi`) and the name of the label map file inside the directory `mymodelname` is `labelmap.txt`.

`./pestdetector.sh -t -d 1 -m mymodelname -l labelmap.txt -s 100000`

![LCD display information](https://github.com/christianbaun/pestdetector/blob/main/docs/lcd_movie.gif)

## Installation

The installation of pestdetector has been tested on Raspberry Pi 4 single board computers only with the [Raspberry Pi OS](https://www.raspberrypi.com/software/) (previously called Raspbian), based on Debian 10 and Debian 11, and with Tensorflow Lite and OpenCV installed.

To simplify the setup of a new machine with pestdetector, a tutorial that uses the [Raspberry Pi 4 64-OS image](https://github.com/Qengineering/RPi-image) from [Qengineering](https://github.com/Qengineering) can be found [here](docs/installation_from_scratch_mit_qengineering_rpi-image.md).

## Architecture

The pest detector software is implemented as bash scripts and python scripts. The main program file is `pestdetector.sh`. Several functions are outsourced to a function library which is `functionlibrary.sh`. 

The pest detector first checks if the required folders exist and required command-line tools like `curl` and `hostname` are present. 

One or two HD44780 LCD displays can be used to inform about the status of the prest detector and if objects have been detected or not. Using LCD displays can be specified by the command line argument `-d <number>`. If LCD displays shall be used, the pest detector checks if the python script `lcd_output_display1.py` is accessible when one or two LCD displays shall be used and if the script `lcd_output_display2.py` is accessible too when two LCD displays shall be used.

The pest detector implements a Telegram Bot notification feature that can be used with the command line argument `-t`. It requires the variables `$TELEGRAM_TOKEN` and `$TELEGRAM_CHAT_ID` to contain the Telegram Bot url token and the chat ID and the command line tool `curl` to be present. The pest detector will check if the file `pest_detect_telegram_credentials.sh`, with contains export commands exists and execute it.

For handling and storing the images, the pest detector uses two directories:

1. The directory that is specified by the variable `$DIRECTORY_MOST_RECENT_IMAGE` is used to store the last image. It makes sense to specify a folder here a subfolder of `/dev/shm/` because this temporary file storage filesystem uses main memory and offers the best performance and does not reduce the lifetime of the flash storage used. 
2. The directory that stores the images with detected objects and the matching logfiles. This folder is specified in the variable `$DIRECTORY_IMAGES` and can be set by the command line argument `-i <folder>`. 

1. Create a picture with the function `make_a_picture()`. The pest detector will use `libcamera-still` when the operating system implements the newer [libcamera](https://libcamera.org/) stack or `raspistill` when using the legacy camera stack. The new picture is stored in the directory that is specified by the variable `$DIRECTORY_MOST_RECENT_IMAGE`.
2. Try to detect objects with the function `detect_objects()`. This function executes the python script `TFLite_detection_image_modified.py` which uses [TensorFlow](https://github.com/tensorflow/tensorflow) lite. Information about the object detection results is written into a log file of the same filename (but with filename extension `txt`).
3. Check if one or more objects have been detected with the function `check_if_objects_have_been_deteted()`. This function analyzes the log file from step 2 by searching with the command line tool `grep` for lines with the search pattern `Detected`. Every detected object results in such a line. If there have been objects detected, the pest detector moves the picture and the log file of the same filename to the directory that is specified by the variable `$DIRECTORY_IMAGES` that stores the images with detected objects and the matching logfiles.
4. If one or two LCD displays are used, the pest detector prints with the fuction `print_result_on_LCD()` information about detected objects on the LCD displays, and write some status information into the logfile with the fuction `write_detected_objects_message_into_logfile()`. In case of detected objects, a Telegram bot notification can be send out with the `function inform_telegram_bot()`. If no objects werde detected, this result is shown on the LCD displays with the fuction `print_no_object_detected_on_LCD()`.
5. For preventing the directory that stores the images with detected objects to overflow, the pest detector checks with the function `prevent_directory_overflow()` the size of the files inside and if the size exceeds the limit, as many oldest files are erased until the limit is not exceeded anymore.

## Running the pestdetector software

in principle, pestdetector should run on any Raspberry Pi with the [Raspberry Pi OS](https://www.raspberrypi.com/software/) (previously called Raspbian). The software is developed and tested on a Rapberry Pi 4 with Raspberry Pi OS based on Debian 11 (*Bullseye*) and Debian 10 (*Buster*).

![Wiring information](https://github.com/christianbaun/pestdetector/blob/main/docs/pestdetector_fritzing_new2.png)

## Third party components

The TensorFlow Lite application is taken from [here](https://github.com/EdjeElectronics/TensorFlow-Lite-Object-Detection-on-Android-and-Raspberry-Pi). I modified mainly the output.

The LCD driver is taken from [here](https://github.com/ArcadiaLabs/raspberry_lcd4x20_I2C)

## Related Work

Some interesting papers and software projects focusing on object detection with single-board computers:

- [Where's The Bear? - Automating Wildlife Image Processing Using IoT and Edge Cloud Systems](https://cs.ucsb.edu/sites/default/files/documents/tr.pdf). *Andy Rosales Elias, Nevena Golubovic, Chandra Krintz, Rich Wolski*. 2016. In this paper, the authors performed wildlife detection (bear, deer, and coyote) on WIFI-connected edge nodes with motion-triggered cameras. In this project, the training was done using external cloud services. The way of training data generation is remarkable. Background images without animals were combined with animal images (with transparent background) from Google Image Search at different times of the day. In this project, Tensorflow and OpenCV were used to perform automatic classification and tagging for images with detected animals. The image recognition worked very well. The classification accuracy with a TensorFlow confidence value of more than 90% was 66% for all tested images. The error rate for coyotes was 0.2%, the error rate for bears was 1% and the error rate for deers was 12%. 
- [Automated detection of elephants in wildlife video](https://core.ac.uk/download/pdf/81703389.pdf). *Matthias Zeppelzauer*. 2013. In this paper, the author describes an automated method for the detection and tracking of elephants in wildlife video. The solution of the author was able to detect Elephants using image recognition and it was able to identify individual animals in over 90% of cases by the color shades of their skin. 
- [Tracking Animals in Wildlife Videos Using Face Detection](http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.60.7522&rep=rep1&type=pdf). *Tilo Burghardt, Janko Calic, Barry Thomas*. 2004. In this paper, the authors present an algorithm for the detection and tracking of animal faces in wildlife videos. The method is illustrated on lions. The authors were able to detect lions and identify individual animals with the help of image recognition. 
- [Automated identification of animal species in camera trap images](https://link.springer.com/article/10.1186/1687-5281-2013-52). *Xiaoyuan Yu, Jiangping Wang, Roland Kays, Patrick A Jansen, Tianjiang Wang, Thomas Huang*. 2013. In this paper, the authors describe a system for automatic image recognition. The system was able to identify 18 animal species from over 7000 images with an average classification accuracy of 82%.
- [Detecting animals in the backyard - practical application of deep learning](https://towardsdatascience.com/detecting-animals-in-the-backyard-practical-application-of-deep-learning-c030d3263ba8). *Gaiar Baimuratov*. 2020. In this project, the author used image recognition to detect (not classify) animals, persons, and vehicles with the pre-trained open-source model [MegaDetector](http://dmorris.net/misc/cameratraps/ai4e_camera_traps_overview/). The author used Xiaomi/Mi Outdoor Cameras with hacked firmware and a Raspberry Pi single-board computer to copy away from the cameras the video files via FTP to an external USB-connected storage drive. Videos are only created by the cameras when motion is detected. The videos are processed via OpenCV and analyzed with Tensorflow and the MegaDetector model. The Python scripts, the author created, send analyzed videos to his Telegram Channel. The Raspberry Pi needs around 10 minutes to process a FullHD one-minute 10 FPS video file.

## Web Site

Visit the pestdetect web page for more information and the latest revision.

[https://github.com/christianbaun/pestdetector](https://github.com/christianbaun/pestdetector)

## License

[GPLv3](https://www.gnu.org/licenses/gpl-3.0.en.html) or later for the pestdetector.sh<br/>
[GPLv2](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html) or later for the LCD driver<br/>
[Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0) or later for the TFLite application 

