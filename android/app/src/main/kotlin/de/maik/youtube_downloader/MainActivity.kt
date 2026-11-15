package de.maik.youtube_downloader

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.net.Uri
import android.provider.DocumentsContract
import android.content.Intent

class MainActivity : FlutterActivity() {
    private lateinit var olderFiles: OlderFiles

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (::olderFiles.isInitialized) olderFiles.close()
        olderFiles = OlderFiles(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "de.maik.youtube_downloader/older_files")
            .setMethodCallHandler(olderFiles::handle)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "de.maik.youtube_downloader/delete_file")
            .setMethodCallHandler { call, result ->
                if (call.method != "delete") {
                    result.notImplemented()
                } else {
                    try {
                        val uri = Uri.parse(call.arguments as String)
                        if (uri.scheme != "content") {
                            result.error("invalid_uri", "Not a content URI", null)
                        } else {
                            val deleted = if (DocumentsContract.isDocumentUri(this, uri)) {
                                DocumentsContract.deleteDocument(contentResolver, uri)
                            } else {
                                contentResolver.delete(uri, null, null) > 0
                            }
                            result.success(deleted)
                        }
                    } catch (e: Exception) {
                        result.error("delete_failed", e.message, null)
                    }
                }
            }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        if (::olderFiles.isInitialized) olderFiles.close()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (::olderFiles.isInitialized) olderFiles.onActivityResult(requestCode, resultCode)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (::olderFiles.isInitialized) olderFiles.onRequestPermissionsResult(requestCode)
    }

    override fun onDestroy() {
        if (::olderFiles.isInitialized) olderFiles.close()
        super.onDestroy()
    }
}
