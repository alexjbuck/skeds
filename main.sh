#!/bin/bash
echo ''
echo '************ WebSkedsAutoChecker ************'
echo '*             by Alexander Buck             *'
echo '*********************************************'

FPDIR='./FrontPage'

# Your Squadron
SQUADRON='VT-6'
# Your filter name
NAME='buck'
# How long to sleep between attempts
SLEEPTIME=60
# Flags to indicate if the current schedule and frontpage has been downloaded
GOTSKED=false
GOTFP=false
# Keep looking for the next day schedule up until this hour on that day
POLLUNTIL=8
# Switch to lower frequency polling at this hour
POLLSTOP=8
# Switch back to higher frequency polling at this hour
POLLSTART=14

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
  CALDATE=JULIAN+5113

  if [ -f "$FPDIR/\$$DATESTR\$$SQUADRON\$Frontpage.pdf" ]
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
    else
       echo "xx"
       echo "xx Failed to download front page."
       echo "xx"
    fi
  fi


  if [  -f ./PNGs/$CALDATE\page3.png  -a  -f ./PNGs/$CALDATE\page4.png ]; then
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
       echo '++ Copying files to google drive for sharing.'
       cp -R ./FrontPage '/Users/alexanderbuck/Google Drive/WebSchedule/'
       cp -R ./PNGs '/Users/alexanderbuck/Google Drive/WebSchedule/'
    else
       echo "xx"
       echo "xx Failed to download schedule."
       echo "xx"
    fi
  fi

  echo "It is now: `date`"
  if [ "$GOTSKED" = true ] && [ "$GOTFP" = true ]; then
    # We already have both the Front page and Schedule that we are looking for
    SLEEPTIME=1800
  else
    # We still don't have one of them, keep polling if within the valid window
    if [ $(date +%H) -ge $POLLSTART ] || [ $(date +%H) -lt $POLLSTOP ]; then
      # Inside desired polling timeframe (1400-0800 local time)
      # Poll once per minute
      SLEEPTIME=60
    else
      # Outside desired polling timeframe
      # Poll once per 30 minutes
      SLEEPTIME=1800
    fi
  fi

  echo "Sleeping for $SLEEPTIME"
  echo -n "zzz... "
  sleep $SLEEPTIME
  echo " ...yawn"

done
