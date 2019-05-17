#!/bin/bash

# Move to the right directory
cd `dirname "$0"`

DEVICES=`cat devices`
APPPATH=`xcodebuild -workspace 'Schindler3.xcworkspace' -scheme "schindler3" -showBuildSettings | grep BUILD_ROOT | sed 's/[ ]*BUILD_ROOT = //'`/Debug-iphoneos/schindler3.app
BUILD=`date "+%Y-%m-%d"`


export PATH=/opt/local/bin:/opt/local/sbin:/opt/local/bin:/opt/local/sbin:/opt/local/bin:/opt/local/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin


# Update the build version
gsed -i -e "s@buildInfo=.*@buildInfo=\"$BUILD\"@g" schindler3/AppDelegate.swift

# Build the app
echo "#### Generating build ${BUILD}"
if ! xcodebuild -destination generic/platform=iOS build -allowProvisioningUpdates -workspace 'Schindler3.xcworkspace' -scheme "schindler3"; then
    echo "#### Failed to build?";
    exit -1
fi

# Deploy the app
echo "#### Deploying build ${BUILD}"
for i in ${DEVICES}; do
    echo "#### Deploying to $i";
    for j in 1 2 3 4 5 6; do
        if [ $j == 6 ]; then
            echo "#### Failed to install to $i. Giving up :(";
            break;
        fi
        if ios-deploy -v -n -i $i -b ${APPPATH} ; then
            break
        fi
        echo "#### Attempt $j failed. Will try again in 10 seconds";
        sleep 10
    done
done

echo "#### Done!"

