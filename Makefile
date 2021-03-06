# sudo npm install -g ios-deploy --unsafe-perm=true
# Set up a profile by signing in to XCode. Build the app and try to install it. You may need to change the app ID if you change the account signed in to
# On the device you may need to explicitly trust the certificate as well.
# Then run make deploy to compile and deploy the app!

# Old device was c401a2efd4f960ef3a8f35992f434e5571cac3d7
# New device is 00008020-001915C43AE1002E

#DEVICES=00008020-001915C43AE1002E c27c7b8bc3c0d0aa49000cbfb66d730ebd89b0d4 7aeaec90d56f07c609e0f42573e1decacc42e407
DEVICES=00008020-001915C43AE1002E

deploy:
	xcodebuild -destination generic/platform=iOS build -allowProvisioningUpdates -workspace 'Schindler3.xcworkspace' -scheme "schindler3"
	@for i in ${DEVICES} ; do echo "Deploying to $$i" && ios-deploy -v -n -i $$i -b $(shell xcodebuild -workspace 'Schindler3.xcworkspace' -scheme "schindler3" -showBuildSettings | grep BUILD_ROOT | sed 's/[ ]*BUILD_ROOT = //')/Debug-iphoneos/schindler3.app; done
#	ios-deploy -v -n -i 00008020-001915C43AE1002E -b build/Release-iphoneos/schindler3.app

no-sign:
	xcodebuild clean build -destination generic/platform=iOS CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO -workspace 'Schindler3.xcworkspace' -scheme "schindler3"


clean:
	xcodebuild -destination generic/platform=iOS build -allowProvisioningUpdates -workspace 'Schindler3.xcworkspace' -scheme "schindler3" -archivePath "build/archive" clean
