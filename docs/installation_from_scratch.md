# pestdetector installation from scratch with Raspberry Pi OS Buster (2021-10-30)

## Copy the Operating System image to the Micro SD Card

Download the Raspberry Pi OS image file:

    $ cd ~/tmp
    $ wget https://downloads.raspberrypi.org/raspios_full_armhf/images/raspios_full_armhf-2021-11-08/2021-10-30-raspios-bullseye-armhf-full.zip
    $ unzip 2021-10-30-raspios-bullseye-armhf-full.zip
      inflating: 2021-10-30-raspios-bullseye-armhf-full.img
    
Check carefully that you write the image to the correct micro SD card device. On my system it was '/dev/sda'. On your system it may be different.

    $ lsblk  | grep sda
    sda           8:0    1  29,8G  0 disk 
    └─sda1        8:1    1  29,8G  0 part 

Write the image to the micro SD card

    $ sudo dd bs=4M if=2021-10-30-raspios-bullseye-armhf-full.img  of=/dev/sda status=progress
    $ sudo sync


## Enable SSH

SSH can be enabled by placing a file named 'ssh' (without any file name extension) into the boot partition of the micro SD card. The content of the file does not matter. It can be empty.

When the Raspberry Pi OS boots, it looks for the 'ssh' file. If it is found, SSH is enabled.

If the Raspbian Pi OS image is written to a micro SD card, two partitions are created automatically. The first one (the smaller one) is the boot partition. 

sudo mount /dev/mmcblk0p1 /media/

    $ lsblk  | grep sda
    sda           8:0    1  29,8G  0 disk 
    ├─sda1        8:1    1   256M  0 part /media/bnc/boot
    └─sda2        8:2    1   8,4G  0 part /media/bnc/rootfs

    $ df | grep sda
    /dev/sda1          258095     49240    208856   20% /media
    
    $ sudo touch /media/ssh
    $ sudo sync
    $ sudo umount /media
    
## Essential Configuration of the Operating System

Insert the micro SD card into the Raspberry Pi 4

Connect monitor, USB keyboard and mouse

Connect a camera module (for this documentation, the Raspberry HQ Camera Module was used)

Connect a sufficiently strong USB power supply to the Raspberry Pi. It will boot automatically and start the initial confiuration steps of the operating system. These are nation, language, timezone, Wifi network credentials,...

If the network configuration worked well, the operating system will start updating the packages automatically. After the system is updated, a reboot is recommended.


## Further Configuration of the Operating System

*Copy your public ssh key to the Raspberry for login without password.*

Run this command from your workstation:

    $ ssh-copy-id -i ~/.ssh/id_rsa.pub pi@<IP-OF-RASPBERRY-PI>

*Enable VNC (on the Raspberry Pi)*

    $ sudo raspi-config
    "3 Interface Options" --> "I3 VNC" 

After a reboot, the Raspberry Pi can be accessed via a VNC client (e.g. [VNC Viewer](https://www.realvnc.com/de/connect/download/viewer/)


*Activate the Camera*

With the new libcamera camera stack, the Raspberry Pi Camera modules should be detected automatically. 
If you plan to use the legacy camera stack, it can be enabled this way:

    $ sudo raspi-config
    "3 Interface Options" --> "I1 Legacy Camera" 


If you use the libcamera camera stack, the camera can be tested by this command:

    $ libcamera-hello
    
    
If you use the legacy camera stack, the camera can be tested by this command:

    $ raspistill -t 0

*Activate the SPI interface*

If you plan using one or two LCD HD44780 LCD displays (20x4) that are connected via the SPI interface, it can be enabled via this way:

    $ sudo raspi-config
    "3 Interface Options" --> "I4 SPI" 

*Install some useful packets*

    $ sudo apt update
    $ sudo apt dist-upgrade
    $ sudo apt-get install -y joe telnet nmap htop sysbench iperf git bonnie++ iftop nload hdparm bc stress sysstat zip locate nuttcp attr imagemagick virtualenv 

*Install tensorflow*

    $ sudo apt install python3-pip
    $ pip3 -V
    pip 20.3.4 from /usr/lib/python3/dist-packages/pip (python 3.9)
    $ sudo pip3 install --upgrade pip
    ...
    Successfully installed pip-21.3.1
    $ pip3 -V
    pip 21.3.1 from /usr/local/lib/python3.9/dist-packages/pip (python 3.9)


    $ sudo apt-get install gfortran
    $ sudo apt-get install libhdf5-dev libc-ares-dev libeigen3-dev
    $ sudo apt-get install libatlas-base-dev libopenblas-dev libblas-dev
    $ sudo apt-get install openmpi-bin libopenmpi-dev
    $ sudo apt-get install liblapack-dev cython3

*Install OpenCV*
    $ sudo pip3 install opencv-python==3.4.17.61
