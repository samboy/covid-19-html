#!/bin/sh
# This script makes the website and puts it in the GNUplot/ directory
# The total execution time is 6.5 minutes on my i7-7600U

lua examine-growth.lua website
cd GNUplot/
gnuplot maps.gnuplot
rm -f *gnuplot *csv
cd ..

# Anything below this line is optional

# ImageMagick needed to run the following 
convert -depth 8 GNUplot/hotSpots.svg GNUplot/hotSpots.png
cat GNUplot/index.html | sed 's/hotSpots.svg/hotSpots.png/g' > foo
if [ -e GNUplot/hotSpots.png ] ; then 
  mv foo GNUplot/index.html
fi

# AdvanceComp to make main PNG files smaller
cd GNUplot/
advpng -z -4 hotSpots.png USA.png USA-deaths.png
ls *png | grep -v , | awk '{print "advpng -z -3 \"" $0 "\""}' | sh

