import sys
sys.path.append("./lib")
import lcddriver
from time import *

lcd = lcddriver.lcd()
lcd.lcd_clear()

line1=sys.argv[1]
line2=sys.argv[2]
line3=sys.argv[3]
line4=sys.argv[4]
 
lcd.lcd_display_string(line1, 1)
lcd.lcd_display_string(line2, 2)
lcd.lcd_display_string(line3, 3)
lcd.lcd_display_string(line4, 4)
