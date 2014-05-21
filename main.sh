#!/bin/bash
echo ''
echo '************ WebSkedsAutoChecker ************'
echo '*             by Alexander Buck             *'
echo '*********************************************'

if [ $(which phantomjs) ]; then
  echo
else
  echo "I cannot find phantomjs on your path."
  echo "Please download and/or install it first."
  echo "Exiting..."
  echo
  exit 1
fi
if [ $(which curl) ]; then
  echo
else
  echo "I cannot find cURL on your path."
  echo "Please download and/or install it first."
  echo "Exiting..."
  echo
  exit 2
fi


## USER OPTIONS ##
##################
# Your Squadron
SQUADRON='VT-6'
# Your filter name
NAME='buck'
# Your phone number for text notification that schedule has been recorded.
PHONENUM='6302072555'
# Location of your Google Drive directory
GOOGLEDRIVEDIR='/Users/alexanderbuck/Google Drive/WebSchedule/'
# How long to sleep between attempts
SLEEPTIME=60
# Keep looking for the next day schedule up until this hour on that day
POLLUNTIL=8
# Switch to lower frequency polling at this hour
POLLSTOP=8
# Switch back to higher frequency polling at this hour
POLLSTART=14

# Name of FrontPage directory
FPDIR='./FrontPage'
PNGDIR='./PNGs'

# Flags to indicate if the current schedule and frontpage has been downloaded
GOTSKED=false
GOTFP=false
SLEEPTIMENOW=$(date)
SLEEPUNTILTIME=$(date -v+"$SLEEPTIME"S)
SLEEPUNTILTIMESEC=$(date -v+"$SLEEPTIME"S +%s)

declare -i JULIAN
declare -i CALDATE

# Begin polling loop
while : ; do

  if [ $(date +%H) -lt $POLLUNTIL ]; then
    if [ "$GOTSKED" = false ] || [ "$GOTFP" = false ]; then
      # Set the date for the current day
      JULIAN=$(date +%j)
      DATESTR=$(date +%Y-%m-%d)
    else
      # I already have both, set the date for the next day
      JULIAN=$(date -v+1d +%j)
      DATESTR=$(date -v+1d +%Y-%m-%d)
    fi
  else
    # Its after "$SEARCHUNTIL" time, so give up on today and move to tomorrow
    JULIAN=$(date -v+1d +%j)
    DATESTR=$(date -v+1d +%Y-%m-%d)
  fi

  # Conversion: 5245 == Julian Date 132 (May 12th, 2014)
  # (I believe January 1st, 2000 is CALDATE 1)
  CALDATE=JULIAN+5113
  echo "** Searching for Front Page and/or Schedule for $DATESTR"


  if [ -f "$FPDIR"/\$"$DATESTR"\$"$SQUADRON"\$Frontpage.pdf ]
  then
    echo '++ Front page already downloaded.'
    GOTFP=true
  else
    GOTFP=false
    echo '**'
    echo '** Downloading the front page.'
    echo '**'

    URL=http://www.cnatra.navy.mil/scheds/tw5/SQ-VT-6/\$$DATESTR\$$SQUADRON\$Frontpage.pdf

    curl -s -S --create-dirs --fail -o $FPDIR/\$$DATESTR\$$SQUADRON\$Frontpage.pdf $URL

    if [ $? -eq 0 ];then
       echo "++ Successfully downloaded front page."
       echo '++ Copying to google drive for sharing and sending SMS notification.'
       curl http://textbelt.com/text -d number="$PHONENUM" -d message="Front page for $DATESTR now on Google Drive."
       cp "$FPDIR"/\$"$DATESTR"\$"$SQUADRON"\$Frontpage.pdf "$GOOGLEDRIVEDIR""$FPDIR"
    else
       echo "xx"
       echo "xx Failed to download front page."
       echo "xx"
    fi
  fi


  if [  -f ./PNGs/"$CALDATE"\page3.png  -a  -f ./PNGs/"$CALDATE"\page4.png ]; then
    echo "++ Schedule already downloaded."
    GOTSKED=true
  else
    GOTSKED=false
    echo '**'
    echo '** Downloading schedule.'
    echo '**'

    phantomjs singleCheck.js $JULIAN $NAME

    if [ $? -eq 0 ];then
       echo "++ Successfully downloaded schedule."
       echo '++ Copying to google drive for sharing and sending SMS notification.'
       curl http://textbelt.com/text -d number="$PHONENUM" -d message="Schedule for $DATESTR now on Google Drive."
       cp "$PNGDIR"/"$CALDATE"page{3,4}.png "$GOOGLEDRIVEDIR""$PNGDIR"
    else
       echo "xx"
       echo "xx Failed to download schedule."
       echo "xx"
    fi
  fi


  if [[ "$GOTSKED" == true && "$GOTFP" == true ]] && [[ "$DATESTR" != $(date +%Y-%m-%d) ]]; then
    echo "A"
    # We have both FP/Sked for tomorrow, sleep until tomorrow start time
    SLEEPUNTILTIME=$(date -j $(date -v+1d +%m%d"$POLLSTART"00%Y))
    SLEEPUNTILTIMESEC=$(date -j $(date -v+1d +%m%d"$POLLSTART"00%Y) +%s)
  elif [[ "$GOTSKED" == false || "$GOTFP" == false ]] && [[ "$DATESTR" != $(date +%Y-%m-%d) || $(date +%H)<"$POLLUNTIL" ]]; then
    echo "C"
    # We don't have both, and its either not yet tomorrow, or tomorrow before stop time, sleep 60 seconds
    SLEEPUNTILTIME=$(date -v+"$SLEEPTIME"S)
    SLEEPUNTILTIMESEC=$(date -v+"$SLEEPTIME"S +%s)
  else
    echo "B"
    # All other cases, sleep until today at start time (derived from logic table analysis)
    SLEEPUNTILTIME=$(date -j $(date +%m%d"$POLLSTART"00%Y))
    SLEEPUNTILTIMESEC=$(date -j $(date +%m%d"$POLLSTART"00%Y) +%s)
  fi


  echo "It is now $(date), sleeping until $SLEEPUNTILTIME"
  echo -n "zzz... "
  while (( ( $(date +%s)<$SLEEPUNTILTIMESEC ) )); do
    sleep 1
  done
  echo " ...yawn"
  echo ""
  echo ""
  echo "************************************************************************"

done
