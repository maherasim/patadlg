package com.example.patadlg

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

// local_auth's biometric prompt needs a FragmentActivity host, not the plain
// FlutterActivity the template starts with.
class MainActivity : FlutterFragmentActivity() {
    private val channelName = "patadlg/downloads"

    // Exports (Excel/PDF) are fetched over an authenticated Dio request into
    // the app's private temp dir first — this channel is the second half:
    // copying those already-downloaded bytes into the SHARED Downloads
    // collection so the file actually shows up in the user's file manager,
    // like a normal browser download. Plugins like file_saver's plain
    // saveFile() only write to getExternalFilesDir (still app-private), which
    // doesn't satisfy that — hence a few lines of direct MediaStore code
    // instead of a dependency that doesn't actually do the job.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            if (call.method == "saveToDownloads") {
                val fileName = call.argument<String>("fileName") ?: "download"
                val bytes = call.argument<ByteArray>("bytes")
                val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                if (bytes == null) {
                    result.error("NO_BYTES", "No file bytes provided", null)
                    return@setMethodCallHandler
                }
                try {
                    val savedPath = saveToDownloads(fileName, bytes, mimeType)
                    result.success(savedPath)
                } catch (e: Exception) {
                    result.error("SAVE_FAILED", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun saveToDownloads(fileName: String, bytes: ByteArray, mimeType: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Scoped storage — inserting into the Downloads collection needs no
            // runtime permission, and the file is immediately visible to the
            // user's file manager / Downloads app.
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            }
            val resolver = applicationContext.contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Could not create file in Downloads")
            resolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw IllegalStateException("Could not open Downloads file for writing")
            return uri.toString()
        } else {
            // Pre-scoped-storage — caller must have already been granted
            // WRITE_EXTERNAL_STORAGE before invoking this method.
            val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!downloadsDir.exists()) downloadsDir.mkdirs()
            val file = File(downloadsDir, fileName)
            FileOutputStream(file).use { it.write(bytes) }
            return file.absolutePath
        }
    }
}
