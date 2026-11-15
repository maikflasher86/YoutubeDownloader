package de.maik.youtube_downloader

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.net.Uri
import android.provider.DocumentsContract

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
}
