[![GPLv3 license](https://img.shields.io/badge/License-GPLv3-blue.svg)](http://perso.crans.org/besson/LICENSE.html)
[![made-with-bash](https://img.shields.io/badge/-Made%20with%20Bash-1f425f.svg)](https://www.gnu.org/software/bash/)

# pestdetector

This repository contains bash scripts, python scripts, and documentation material, that I created for my pest detector prototype research work. The pest detector script collection is a command-line tool for detecting rats and other forms of pests like cockroaches in images that are created by a [Raspberry Pi](https://www.raspberrypi.com) single-board computer node with a Raspberry Pi [High-Quality Camera](https://www.raspberrypi.com/products/raspberry-pi-high-quality-camera/) (hqcam), or a Raspberry Pi [Camera Module 2](https://www.raspberrypi.com/products/camera-module-v2/), or a similar model. The object detection is done by [TensorFlow](https://github.com/tensorflow/tensorflow) lite that runs on the Raspberry Pi and can by done by using die CPU of the single board computer or by using a [Coral Accelerator TPU coprocessor](https://coral.ai/products/accelerator/).

## Synopsis

    pestdetector.sh [-h] [-m <modelname>] [-l <labelmap>] [-i <directory>] [-s <size>] [-j <directory>] [-t] [-d <number>] [-c]

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
    -c : use Coral Accelerator TPU coprocessor 

## Requirements

These software packages must be installed:

- [bash](https://www.gnu.org/software/bash/) 5.0.3
- [libcamera-still](https://libcamera.org/) from the libcamera open source camera stack
- [raspistill](https://github.com/raspberrypi/userland/blob/master/host_applications/linux/apps/raspicam/RaspiStill.c) as an alternative tool to libcamera-still
- [curl](https://curl.se) 7.64.0
- hostname 3.21
- [ping](https://github.com/iputils/iputils) iputils-s20180629
- [python](https://www.python.org) 3

## Examples

This command starts pest detector and specidies that a the telegram bot notification is used and one LCD display (4x20) are used to inform about detected objects and the state of the pest detector tool.

`./pestdetector.sh -t -d 1`

![LCD display information](https://github.com/christianbaun/pestdetector/blob/main/docs/lcd_movie.gif)


## Architecture

The pestdetector software is implemented as bash scripts and python scripts. Them main program file is `pestdetector.sh`. Several functions are outsourced to a function library which is `functionlibrary.sh`. 

The script `pestdetector.sh` first checks if the required folders exist and command line tools like `libcamera-still` (when using the newer libcamera stack) or `raspistill` (when using the legacy stack) are present. In addition pestdetector.sh checks if the python script `lcd_output_display1.py` is accessible when one or two LCD displays shall be used and if `lcd_output_display2.py` is accessible too when two LCD displays shall be used.

## Third party components

The TensorFlow Lite application is taken from [here](https://github.com/EdjeElectronics/TensorFlow-Lite-Object-Detection-on-Android-and-Raspberry-Pi). I modified mainly the output.

The LCD driver is taken from [here](https://github.com/ArcadiaLabs/raspberry_lcd4x20_I2C)

## Related Work

Some interesting papers and software projects focusing on object detection with single-board computers:

- [Where's The Bear? - Automating Wildlife Image Processing Using IoT and Edge Cloud Systems](https://cs.ucsb.edu/sites/default/files/documents/tr.pdf). *Andy Rosales Elias, Nevena Golubovic, Chandra Krintz, Rich Wolski*. 2016. In this paper, the authors performed wildlife detection (bear, deer, and coyote) on WIFI-connected edge nodes with motion-triggered cameras. In this project, the training was done using external cloud services. The way of training data generation is remarkable. Background images without animals were combined with animal images (with transparent background) from Google Image Search at different times of the day. In this project, Tensorflow and OpenCV were used to perform automatic classification and tagging for images with detected animals. The image recognition worked very well. The classification accuracy with a TensorFlow confidence value of more than 90% was 66% for all tested images. The error rate for coyote was 0.2%, the error rate for bear was 1% and the error rate for deer was 12%. 
- [Automated detection of elephants in wildlife video](https://core.ac.uk/download/pdf/81703389.pdf). *Matthias Zeppelzauer*. 2013. In this paper, the author describes an automated method for the detection and tracking of elephants in wildlife video. The solution of the author was able to detect Elephants using image recognition and it was able to identify individual animals in over 90% of cases by the color shades of their skin. 
- [Tracking Animals in Wildlife Videos Using Face Detection](http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.60.7522&rep=rep1&type=pdf). *Tilo Burghardt, Janko Calic, Barry Thomas*. 2004. In this paper, the authors present an algorithm for the detection and tracking of animal faces in wildlife videos. The method is illustrated on lions. The authors werde able to detect lions and identify individual animals with the help of image recognition. 
- [Automated identification of animal species in camera trap images](https://link.springer.com/article/10.1186/1687-5281-2013-52). *Xiaoyuan Yu, Jiangping Wang, Roland Kays, Patrick A Jansen, Tianjiang Wang, Thomas Huang*. 2013. In this paper, the authors describe a system for automatic image recognition. The system was able to identify 18 animal species from over 7000 images with an average classification accuracy of 82%.
- [Detecting animals in the backyard - practical application of deep learning](https://towardsdatascience.com/detecting-animals-in-the-backyard-practical-application-of-deep-learning-c030d3263ba8). *Gaiar Baimuratov*. 2020. In this project, the author used image recognition to detect (not classify) animals, persons, and vehicles with the pre-trained open-source model [MegaDetector](http://dmorris.net/misc/cameratraps/ai4e_camera_traps_overview/). The author used Xiaomi/Mi Outdoor Cameras with hacked firmware and a Raspberry Pi single-board computer to copy away from the cameras the video files via FTP to an external USB-connected storage drive. Videos are only created by the cameras when motion is detected. The videos are processed via OpenCV and analyzed with Tensorflow and the MegaDetector model. The Python scripts, the author created, send analyzed videos to his Telegram Channel. The Raspberry Pi needs around 10 minutes to process a FullHD one-minute 10 FPS video file.

## Web Site

Visit the pestdetect web page for more information and the latest revision.

[https://github.com/christianbaun/pestdetector](https://github.com/christianbaun/pestdetector)

## License

[GPLv3](https://www.gnu.org/licenses/gpl-3.0.en.html) or later for the pestdetector.sh<br/>
[GPLv2](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html) or later for the LCD driver<br/>
[Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0) or later for the TFLite application 

