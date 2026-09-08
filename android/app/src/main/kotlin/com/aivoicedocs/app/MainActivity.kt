package com.aivoicedocs.app

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity, not FlutterActivity — local_auth's biometric
// prompt dialog needs a FragmentActivity host to attach to.
class MainActivity : FlutterFragmentActivity()
