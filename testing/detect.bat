#!/bin/bash

DATEI="$1"
MODELLNAME="$2"
STANDARDMODELL=model_2021_07_08_rat_bug_hedgehog

if [ -z "$2" ]; then
  echo "Es wurde kein Modell als Parameter angebeben. Nehme $STANDARDMODELL ."
  MODELLNAME=$STANDARDMODELL
fi

MODEL="/home/pi/$MODELLNAME"
LABELS="/home/pi/$MODELLNAME/labelmap.txt"

NOW=$(date +"%Y-%m-%d")
LOGFILE="log-$NOW.log"

if [ $# -eq 0 ]; then
  echo "Bitte Datei als Parameter angeben!"
  exit 1
fi

for i in 10 15 20 30 40 50 60 70 80 90 100
do
DATEINAME=scaled\_$i\_$DATEI
 
if [[ -f "$DATEINAME" ]]; then
    echo "$DATEINAME existiert."
    echo "Verarbeite $DATEINAME ."
    python3 ~/Prototyp_Software/TFLite_detection_image_modified.py --modeldir=$MODEL --graph=detect_edgetpu.tflite --labels=$LABELS --edgetpu --image=$DATEINAME 2>&1 | tee -a $LOGFILE
else
    echo "Die Datei $DATEINAME wurde nicht gefunden."
    exit 1
fi

done


