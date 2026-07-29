package com.example.patadlg

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth's biometric prompt needs a FragmentActivity host, not the plain
// FlutterActivity the template starts with.
class MainActivity : FlutterFragmentActivity()
