#!/bin/bash

LCD_DRIVER1="lcd_output_display1.py"
LCD_DRIVER2="lcd_output_display2.py"

(cd ~/pestdetector ; python3 ${LCD_DRIVER2} "Make a picture" "" "" "" )

sleep 5

(cd ~/pestdetector ; python3 ${LCD_DRIVER2} "Make a picture" "Detect objects" "" "" )
 
sleep 5

(cd ~/pestdetector ; python3 ${LCD_DRIVER2} "Make a picture" "Detect objects" "Analyze results" "" )
 
sleep 5

(cd ~/pestdetector ; python3 ${LCD_DRIVER2} "Make a picture" "Detect objects" "Analyze results" "Organize folders" )


done

exit 0