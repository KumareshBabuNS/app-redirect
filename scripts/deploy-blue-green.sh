#!/bin/bash

if [ $# != 1 ] && [ $# != 4 ] ; then cat << EOM

    This script is used for deploying to blue/green configured environments

    You should build the app before using this script, eg: 'mvn clean package'

    usage: $0 SPACE PATH_TO_CF EMAIL PASSWORD

    where SPACE is one of (staging|production)
      and (optional) PATH_TO_CF is the path to the 'cf' executable
      and (optional) EMAIL and PASSWORD are your CF credentials

    *** if the optional arguments are not passed in, it assumes 'cf'
        is on your path and you are logged in correctly

    *** passing in one optional argument requires all others as well

EOM
    exit
fi

echo "Starting blue-green deploy script"

SPACE=$1
CF=$2
USER=$3
PASS=$4

if [[ -z "$2" ]]; then
    CF=cf
    SPACE=$1
else
    echo "loading RVM"
    [[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*

    PATH=$PATH:~/.rvm/rubies/ruby-1.9.3-p429/bin/:~/.rvm/bin/

    rvm use 1.9.3

    echo "validating $CF executable"
    if [[ ! -f $CF ]]; then echo "$CF does not exist"; exit 100; fi
    if [[ ! -x $CF ]]; then echo "$CF is not executable"; exit 101; fi

    echo "logging in to CF"
    $CF target api.run.pivotal.io || echo "unable to target api.run.pivotal.io, attempting to continue.."
    $CF login --email $USER --password $PASS || echo "unable to log in to CF as user [$USER], attempting to continue.."
fi

echo "switching to space $SPACE"
$CF space $SPACE || exit

echo "Checking for running app"
# check that we don't have >1 or 0 apps running. We might make a case for 0 and deploy redirect-blue.
CHECK=`$CF apps --url downloads.cfapps.io | grep -E 'green|blue' | wc -l`

if [ $CHECK != 1 ];
    then echo "There must be exactly one CF green or blue app running. Exiting.";
    exit 1;
fi

CURRENT=`$CF apps --url downloads.cfapps.io | grep -E 'green|blue'`

echo App currently running is $CURRENT.

NEXT=`if [ "$CURRENT" == "redirect-green" ]; then echo redirect-blue; else echo redirect-green; fi`

echo Next app to be deployed will be $NEXT.

$CF push --manifest ../manifest.yml --name $NEXT --reset --start || $(dirname $0)/wait-for-app-to-start.sh $NEXT 100 $CF || exit

$(dirname $0)/map-blue-green.sh $SPACE $CF $CURRENT $NEXT

