## Plugin used
- [flutter_stripe](https://pub.dev/packages/flutter_stripe) : The Stripe Flutter SDK allows you to build delightful payment experiences in your native Android and iOS apps using Flutter.

## Integration
- [View integration setup](https://docs.page/flutter-stripe/flutter_stripe)

## Requirements

**Android**

This plugin requires several changes to be able to work on Android devices. Please make sure you follow all these steps:

- Use Android 5.0 (API level 21) and above
- Use Kotlin version 1.5.0 and above: example
- Requires Android Gradle plugin 8 and higher
- Using a descendant of Theme.AppCompat for your activity
- Using an up-to-date Android gradle build tools version
- Using FlutterFragmentActivity instead of FlutterActivity in MainActivity.kt: example
- Add the following rules to your proguard-rules.pro file: example
   `-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
    -dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
    -dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
    -dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
    -dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider`
- Rebuild the app, as the above changes don't update with hot reload
These changes are needed because the Android Stripe SDK requires the use of the AppCompat theme for their UI components and the Support Fragment Manager for the Payment Sheets

**iOS**

Compatible with apps targeting iOS 13 or above.
To upgrade your iOS deployment target to 13.0, you can either do so in Xcode under your Build Settings, or by modifying IPHONEOS_DEPLOYMENT_TARGET in your project.pbxproj directly.
You will also need to update in your Podfile:
`platform :ios, '13.0'`