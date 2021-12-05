#!/bin/bash

DATEI="$1"

if [ $# -eq 0 ]; then
  echo "Bitte Datei als Parameter angeben!"
  exit 1
fi
 
if [[ -f "$DATEI" ]]; then
    echo "$DATEI existiert."
else
    echo "$DATEI existiert nicht."
    exit 1
fi
   
for i in 10 15 20 30 40 50 60 70 80 90 100
do
convert -verbose $DATEI -resize $i% scaled_$i\_$DATEI
done
