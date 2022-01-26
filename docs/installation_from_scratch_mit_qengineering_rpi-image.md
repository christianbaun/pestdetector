# Pestdetector Installation from Scratch with the Raspberry Pi 4 64-OS Image from Qengineering (2022-01-24)

This tutorial uses the Raspberry Pi 4 64-OS [image](https://github.com/Qengineering/RPi-image) from [Qengineering](https://github.com/Qengineering) that bases on Debian Buster. It has the relevant deep learning frameworks already installed such as:

    OpenCV 4.5.1
    TensorFlow-Lite 2.4.1
    TensorFLow 2.4.1
    
    $ python3
    Python 3.7.3 (default, Jan 22 2021, 20:04:44) 
    [GCC 8.3.0] on linux
    Type "help", "copyright", "credits" or "license" for more information.
    >>> import cv2
    >>> cv2.__version__
    '4.5.1'
    >>> import tensorflow
    >>> tensorflow.__version__
    '2.4.1'
    >>> 

## Download the operating system image, unzip it and copy it to the micro SD card

Download the operating system image from [here](https://drive.google.com/file/d/1Aco_oXYsgZZ6RDJOh695glDGYdrzgm8F/view?usp=sharing)

    $ unzip RPi_64OS_DNN.zip
    Archive:  RPi_64OS_DNN.zip
      inflating: RPi_64OS_DNN.img  
    
Check carefully that you write the image to the correct micro SD card device. On my system it was ´/dev/sda´. On your system it may be different.

    $ lsblk  | grep sda
    sda           8:0    1  29,8G  0 disk 
    └─sda1        8:1    1  29,8G  0 part 

Write the image to the micro SD card:

    $ sudo dd bs=4M if=RPi_64OS_DNN.img of=/dev/sda status=progress
    $ sudo sync

Next, boot the system.

## Configuration steps

Start the configuration tool:

    $ sudo raspi-config

Enable the camera module, the SPI interface and the SSH deamon:

    3 Interface Options ->  P1 Camera 
    3 Interface Options ->  P3 SSH 
    3 Interface Options ->  P4 SPI
    
Set the localisation options:

    5 Localisation Options -> L1 Locale
    5 Localisation Options -> L2 Timezone 		
    5 Localisation Options -> L3 Keyboard
    5 Localisation Options -> L4 WLAN Country

Set the hostname and the password:

    1 System Options > S3 Password
    1 System Options > S4 Hostname 

Next, reboot the system.

Set the WiFi cretentials (e.g. in the graphical X11 user interface).

Check the system parameters.

    $ uname -a
    Linux pstdetect-02 5.10.92-v8+ #1514 SMP PREEMPT Mon Jan 17 17:39:38 GMT 2022 aarch64 GNU/Linux
    $ cat /etc/debian_version 
    10.11
    $ neofetch 
           _,met$$$$$gg.          pi@pstdetect-02 
        ,g$$$$$$$$$$$$$$$P.       --------------- 
      ,g$$P"     """Y$$.".        OS: Debian GNU/Linux 10 (buster) aarch64 
     ,$$P'              `$$$.     Host: Raspberry Pi 4 Model B Rev 1.4 
    ',$$P       ,ggs.     `$$b:   Kernel: 5.10.92-v8+ 
    `d$$'     ,$P"'   .    $$$    Uptime: 27 mins 
     $$P      d$'     ,    $$P    Packages: 1644 (dpkg) 
     $$:      $$.   -    ,d$$'    Shell: bash 5.0.3 
     $$;      Y$b._   _,d$P'      Terminal: /dev/pts/0 
     Y$$.    `.`"Y$$$$P"'         CPU: (4) @ 1.500GHz 
     `$$b      "-.__              Memory: 273MiB / 7633MiB 
      `Y$$
       `Y$$.                                              
         `$$b.
           `Y$$b.
              `"Y$b._
                  `"""

## Install some packets

    $ sudo apt update
    
The libcamera-tools are missing. Install them:
    
    $ sudo apt install -y libcamera-apps
    
This is a good time to install some usfull packets

    $ sudo apt install -y joe telnet nmap htop sysbench iperf git neofetch
    $ sudo apt install -y bonnie++ iftop nload hdparm bc stress sysstat 
    $ sudo apt install -y zip locate nuttcp attr imagemagick geeqie

Next, reboot the system.

## Fix the camera module

As mentined [here](https://github.com/Qengineering/RPi-image/issues/2) and [here](https://forums.raspberrypi.com/viewtopic.php?t=285868) and several other sources, no 64-bit versions of the tools `raspistill`, `raspivid`, ... for the legacy camera software stack exist. But despite the fact, that the operating system image bases on Debian Buster (10) and not Bullseye (11), the libcamera stack tools like `libcamera-still`, `libcamera-vid` and `libcamera-hello` can be used.

If such an error message appears...

    $ libcamera-hello --verbose
    ...
    [0:00:26.317162465] [1015]  INFO Camera camera_manager.cpp:293 libcamera v0.0.0+3384-44d59841
    [0:00:26.354590576] [1016]  WARN RPI raspberrypi.cpp:1202 Mismatch between Unicam and CamHelper for embedded data usage!
    [0:00:26.355638872] [1016] ERROR RPI raspberrypi.cpp:1230 Unicam driver does not use the MediaController, please update your kernel!
    [0:00:26.356345279] [1016] ERROR RPI raspberrypi.cpp:1129 Failed to register camera imx219 10-0010: -22
    Closing Libcamera application(frames displayed 0, dropped 0)
    Camera stopped!
    Tearing down requests, buffers and configuration
    Camera closed
    ERROR: *** no cameras available ***

... it is required to execute `rpi-update`:

     $ sudo rpi-update
     *** Raspberry Pi firmware updater by Hexxeh, enhanced by AndrewS and Dom
     *** Performing self-update
     *** Relaunching after update
     *** Raspberry Pi firmware updater by Hexxeh, enhanced by AndrewS and Dom
     *** We're running for the first time
     *** Backing up files (this will take a few minutes)
     *** Remove old firmware backup
     *** Backing up firmware
     *** Remove old modules backup
     *** Backing up modules 5.10.63-v8+
    ...
     *** Updating firmware
     *** Updating kernel modules
     *** depmod 5.10.92+
     *** depmod 5.10.92-v7+
     *** depmod 5.10.92-v8+
     *** depmod 5.10.92-v7l+
     *** Updating VideoCore libraries
    ...
     *** A reboot is needed to activate the new firmware

After a reboot, the `libcamera`-tools should work well. e.g.

    $ libcamera-still -t 0

## Install the pestdetector

    $ cd ~
    $ git clone https://github.com/christianbaun/pestdetector.git
    $ mv model_2021_07_08_rat_bug_hedgehog/ ~

## Install the Google Coral TPU Accelerator software

Install the Edge TPU runtime. The Edge TPU runtime provides the core programming interface for the Edge TPU. 

    $ echo "deb https://packages.cloud.google.com/apt coral-edgetpu-stable main" | sudo tee /etc/apt/sources.list.d/coral-edgetpu.list
    $ curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    $ sudo apt-get update
    $ sudo apt-get install libedgetpu1-std

Install the PyCoral library. PyCoral is a Python library built on top of the TensorFlow Lite library to speed up your development and provide extra functionality for the Edge TPU.

    $ sudo apt-get install python3-pycoral

Now, the pestdetector can be used with the Coral TPU Accelerator USB

    $ ./pestdetector.sh -c 

## Use the Telegram notification feature

Create a file with the [Telegram](https://telegram.org/) crecentials 

    $ bash -c 'cat <<EOF > ~/pest_detect_telegram_credentials.sh
    TELEGRAM_CHAT_ID="<HERE_YOUR_CHAT_ID>"
    TELEGRAM_TOKEN="<HERE_YOUR_TOKEN>"
    EOF'

Now, the pestdetector notfy you about detected objects via the Telegram messaging service

    $ ./pestdetector.sh -t
