#!/bin/bash

DATEI="$1"

if [ $# -eq 0 ]; then
  echo "Bitte Datei als Parameter angeben!"
  exit 1
fi

if cp -v ../resize.bat . ; then
    echo "Resize-Programm kopiert."
    ./resize.bat "$1"
else
    echo "Command failed"
    exit 1
fi

if cp -v ../detect.bat . ; then
    echo "Detect-Programm kopiert."
    ./detect.bat "$1"
else
    echo "Command failed"
    exit 1
fi




