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

Connect a sufficiently strong USB power supply to the Raspberry Pi. It will boot automatically and start the initial confiuration steps of the operating system.
