# sudo npm install -g ios-deploy --unsafe-perm=true
# Set up a profile by signing in to XCode. Build the app and try to install it. You may need to change the app ID if you change the account signed in to
# On the device you may need to explicitly trust the certificate as well.
# Then run make deploy to compile and deploy the app!
deploy:
	xcodebuild -destination generic/platform=iOS build -allowProvisioningUpdates
	ios-deploy -v -n -i c401a2efd4f960ef3a8f35992f434e5571cac3d7 -b build/Release-iphoneos/schindler3.app

no-sign:
	xcodebuild clean build -destination generic/platform=iOS CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
