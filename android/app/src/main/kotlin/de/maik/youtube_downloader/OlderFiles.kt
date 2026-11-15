package de.maik.youtube_downloader

import android.Manifest
import android.app.Activity
import android.app.RecoverableSecurityException
import android.content.ContentUris
import android.content.IntentSender
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

internal class OlderFiles(private val activity: MainActivity) {
    private val resolver = activity.contentResolver
    private val worker = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    private var listed = emptyMap<String, Entry>()
    private var selectedUri: Uri? = null
    private var selectedDocument = false
    private var selectedEntry: Entry? = null
    private var tree: String? = null
    private var closed = false
    private var consentDeletes = false
    private var consentRequested = false

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "list" && call.method != "delete") {
            result.notImplemented()
            return
        }
        if (pending != null) {
            result.error("busy", "Another file operation is in progress.", null)
            return
        }
        when (call.method) {
            "list" -> {
                listed = emptyMap()
                if (call.arguments != null && call.arguments !is String) {
                    result.error("invalid_argument", "The tree URI must be a string or null.", null)
                    return
                }
                tree = call.arguments as String?
                pending = result
                try {
                    if (tree == null && !hasReadPermissions()) {
                        activity.requestPermissions(readPermissions(), READ_REQUEST)
                    } else {
                        list()
                    }
                } catch (e: Exception) {
                    fail("list_failed", e.message ?: "The app cannot request read access.")
                }
            }
            "delete" -> {
                val value = call.arguments as? String
                val entry = value?.let { listed[it] }
                if (value == null || entry == null) {
                    result.error("invalid_uri", "The URI is not in the latest file list.", null)
                    return
                }
                selectedUri = Uri.parse(value)
                selectedDocument = entry.document
                selectedEntry = entry
                consentRequested = false
                pending = result
                try {
                    if (!entry.document && Build.VERSION.SDK_INT >= 23 && Build.VERSION.SDK_INT <= 28 &&
                        activity.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED
                    ) {
                        activity.requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), WRITE_REQUEST)
                    } else {
                        delete()
                    }
                } catch (e: Exception) {
                    fail("delete_failed", e.message ?: "The app cannot request write access.")
                }
            }
        }
    }

    private fun readPermissions(): Array<String> = when {
        Build.VERSION.SDK_INT >= 34 -> arrayOf(
            Manifest.permission.READ_MEDIA_AUDIO,
            Manifest.permission.READ_MEDIA_VIDEO,
            Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED
        )
        Build.VERSION.SDK_INT >= 33 -> arrayOf(
            Manifest.permission.READ_MEDIA_AUDIO, Manifest.permission.READ_MEDIA_VIDEO
        )
        else -> arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
    }

    private fun hasReadPermissions(): Boolean {
        if (Build.VERSION.SDK_INT < 23) return true
        val required = if (Build.VERSION.SDK_INT >= 33) {
            arrayOf(Manifest.permission.READ_MEDIA_AUDIO, Manifest.permission.READ_MEDIA_VIDEO)
        } else arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        return required.all { activity.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }
    }

    fun onRequestPermissionsResult(requestCode: Int) {
        if (pending == null || closed) return
        when (requestCode) {
            READ_REQUEST -> if (hasReadPermissions()) list() else fail("permission_denied", "The app cannot read all audio and video files.")
            WRITE_REQUEST -> if (activity.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED) {
                delete()
            } else finish(false)
        }
    }

    private fun list() {
        val treeValue = tree
        worker.execute {
            try {
                val scan = if (treeValue == null) listMedia() else listDocuments(treeValue)
                activity.runOnUiThread {
                    if (!closed && pending != null) {
                        listed = scan.files.associateBy { it.uri }
                        finish(mapOf("files" to scan.files.map { it.values() }, "issues" to scan.issues))
                    }
                }
            } catch (e: Exception) {
                reportException("list_failed", e)
            }
        }
    }

    private fun listMedia(): Scan {
        val entries = mutableListOf<Entry>()
        val issues = mutableListOf<String>()
        val destinations = listOf(Environment.DIRECTORY_MUSIC, Environment.DIRECTORY_MOVIES).mapNotNull { directory ->
            val relative = "$directory/YouTube Downloader/"
            val folder = File(Environment.getExternalStoragePublicDirectory(directory), "YouTube Downloader")
            if (folder.isDirectory) relative to folder else {
                issues.add("The download folder is missing or inaccessible: $relative")
                null
            }
        }
        for (audio in listOf(true, false)) {
            val collection = if (Build.VERSION.SDK_INT >= 29) {
                if (audio) MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                else MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                if (audio) MediaStore.Audio.Media.EXTERNAL_CONTENT_URI else MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            }
            val pathColumn = if (Build.VERSION.SDK_INT >= 29) MediaStore.MediaColumns.RELATIVE_PATH else MediaStore.MediaColumns.DATA
            val projection = arrayOf(
                MediaStore.MediaColumns._ID, MediaStore.MediaColumns.DISPLAY_NAME,
                MediaStore.MediaColumns.MIME_TYPE, MediaStore.MediaColumns.SIZE,
                MediaStore.MediaColumns.DATE_MODIFIED, pathColumn
            )
            for ((relative, destination) in destinations) {
                val basePath = if (Build.VERSION.SDK_INT >= 29) relative else
                    destination.absolutePath + File.separator
                val selection = if (Build.VERSION.SDK_INT >= 29) "$pathColumn = ?" else
                    "$pathColumn LIKE ? AND $pathColumn NOT LIKE ?"
                val args = if (Build.VERSION.SDK_INT >= 29) arrayOf(basePath) else arrayOf("$basePath%", "$basePath%/%")
                query(collection, projection, selection, args).use { cursor ->
                    while (cursor.moveToNext()) {
                        val path = cursor.getString(cursor.getColumnIndexOrThrow(pathColumn))
                        val validPath = if (Build.VERSION.SDK_INT >= 29) path == basePath else
                            path != null && File(path).parent == basePath.dropLast(1)
                        if (!validPath) throw IllegalStateException("MediaStore returned a file outside the requested folder.")
                        val name = cursor.requiredString(MediaStore.MediaColumns.DISPLAY_NAME)
                        val mime = cursor.requiredString(MediaStore.MediaColumns.MIME_TYPE)
                        val uri = ContentUris.withAppendedId(collection, cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)))
                        entries.add(Entry(uri.toString(), name, "$relative$name", mime,
                            cursor.optionalLong(MediaStore.MediaColumns.SIZE),
                            cursor.optionalLong(MediaStore.MediaColumns.DATE_MODIFIED)?.times(1000), audio, false))
                    }
                    checkProviderResult(cursor)
                }
            }
        }
        return Scan(unique(entries), issues)
    }

    private fun listDocuments(value: String): Scan {
        val treeUri = Uri.parse(value)
        require(treeUri.scheme == "content" && DocumentsContract.isTreeUri(treeUri)) { "The URI is not a document tree." }
        val rootId = DocumentsContract.getTreeDocumentId(treeUri)
        val rootUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, rootId)
        val rootName = query(rootUri, arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null).use {
            check(it.moveToFirst()) { "The selected folder is missing." }
            val name = it.requiredString(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            checkProviderResult(it)
            name
        }
        val folders = mutableMapOf<String, String>()
        children(treeUri, rootId).use { cursor ->
            while (cursor.moveToNext()) {
                val name = cursor.requiredString(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                val mime = cursor.requiredString(DocumentsContract.Document.COLUMN_MIME_TYPE)
                if (name in listOf("Audio", "Video") && mime == DocumentsContract.Document.MIME_TYPE_DIR) {
                    val id = cursor.requiredString(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
                    check(folders.put(name, id) == null) { "The selected folder contains duplicate $name folders." }
                }
            }
            checkProviderResult(cursor)
        }
        val entries = mutableListOf<Entry>()
        val issues = mutableListOf<String>()
        for (folder in listOf("Audio", "Video")) {
            val id = folders[folder]
            if (id == null) {
                issues.add("The selected folder does not contain $folder.")
                continue
            }
            children(treeUri, id).use { cursor ->
                while (cursor.moveToNext()) {
                    val providerMime = cursor.requiredString(DocumentsContract.Document.COLUMN_MIME_TYPE)
                    if (providerMime == DocumentsContract.Document.MIME_TYPE_DIR) continue
                    val name = cursor.requiredString(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                    val mime = if (providerMime.startsWith("audio/") || providerMime.startsWith("video/")) {
                        providerMime
                    } else if (providerMime == "application/octet-stream") {
                        MimeTypeMap.getSingleton().getMimeTypeFromExtension(name.substringAfterLast('.', "").lowercase())
                            ?: continue
                    } else continue
                    if (!mime.startsWith("audio/") && !mime.startsWith("video/")) continue
                    val docId = cursor.requiredString(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
                    val uri = DocumentsContract.buildDocumentUriUsingTree(treeUri, docId)
                    entries.add(Entry(uri.toString(), name, "$rootName/$folder/$name", mime,
                        cursor.optionalLong(DocumentsContract.Document.COLUMN_SIZE),
                        cursor.optionalLong(DocumentsContract.Document.COLUMN_LAST_MODIFIED),
                        mime.startsWith("audio/"), true))
                }
                checkProviderResult(cursor)
            }
        }
        return Scan(unique(entries), issues)
    }

    private fun children(treeUri: Uri, id: String): Cursor = query(
        DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, id),
        arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE, DocumentsContract.Document.COLUMN_SIZE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED), null, null
    )

    private fun query(uri: Uri, projection: Array<String>, selection: String?, args: Array<String>?): Cursor =
        resolver.query(uri, projection, selection, args, null)
            ?: throw IllegalStateException("The storage provider did not return a result.")

    private fun Cursor.requiredString(column: String): String =
        getString(getColumnIndexOrThrow(column)) ?: throw IllegalStateException("The storage provider did not return $column.")

    private fun Cursor.optionalLong(column: String): Long? {
        val index = getColumnIndex(column)
        return if (index < 0 || isNull(index)) null else getLong(index)
    }

    private fun checkProviderResult(cursor: Cursor) {
        val extras = cursor.extras
        val error = extras.getString(DocumentsContract.EXTRA_ERROR)
        check(error == null) { error ?: "The storage provider failed." }
        check(!extras.getBoolean(DocumentsContract.EXTRA_LOADING, false)) { "The storage provider returned an incomplete list." }
    }

    private fun unique(entries: List<Entry>): List<Entry> {
        val result = linkedMapOf<String, Entry>()
        for (entry in entries) {
            val previous = result[entry.uri]
            check(previous == null || previous == entry) { "The storage provider returned conflicting file references." }
            result[entry.uri] = entry
        }
        return result.values.toList()
    }

    private fun delete() {
        val uri = selectedUri ?: return fail("delete_failed", "The file URI is missing.")
        val document = selectedDocument
        val selected = selectedEntry ?: return fail("delete_failed", "The file is no longer selected.")
        val treeValue = tree
        worker.execute {
            try {
                val current = if (treeValue == null) listMedia() else listDocuments(treeValue)
                check(current.files.any { it == selected }) { "The file changed or is no longer in the download folder." }
                val deleted = if (document) DocumentsContract.deleteDocument(resolver, uri)
                    else resolver.delete(uri, null, null) > 0
                activity.runOnUiThread {
                    if (!closed && pending != null) {
                        if (deleted) {
                            listed = listed - uri.toString()
                            finish(true)
                        } else fail("delete_failed", "The storage provider did not delete the file.")
                    }
                }
            } catch (e: SecurityException) {
                activity.runOnUiThread {
                    if (!closed && pending != null) requestDeleteConsent(uri, document, e)
                }
            } catch (e: Exception) {
                reportException("delete_failed", e)
            }
        }
    }

    private fun requestDeleteConsent(uri: Uri, document: Boolean, error: SecurityException) {
        try {
            if (consentRequested) throw error
            val sender: IntentSender = when {
                document -> throw error
                Build.VERSION.SDK_INT >= 30 -> {
                    consentDeletes = true
                    MediaStore.createDeleteRequest(resolver, listOf(uri)).intentSender
                }
                Build.VERSION.SDK_INT == 29 && error is RecoverableSecurityException -> {
                    consentDeletes = false
                    error.userAction.actionIntent.intentSender
                }
                else -> throw error
            }
            consentRequested = true
            activity.startIntentSenderForResult(sender, DELETE_REQUEST, null, 0, 0, 0)
        } catch (e: Exception) {
            fail("delete_failed", e.message ?: "The app cannot delete the file.")
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int) {
        if (requestCode != DELETE_REQUEST || pending == null || closed) return
        if (resultCode != Activity.RESULT_OK) {
            finish(false)
        } else if (consentDeletes) {
            selectedUri?.let { listed = listed - it.toString() }
            finish(true)
        } else {
            delete()
        }
    }

    private fun reportException(code: String, e: Exception) {
        activity.runOnUiThread { if (!closed && pending != null) fail(code, e.message ?: "The storage operation failed.") }
    }

    private fun finish(value: Any?) {
        val result = pending ?: return
        pending = null
        selectedUri = null
        selectedEntry = null
        result.success(value)
    }

    private fun fail(code: String, message: String) {
        val result = pending ?: return
        pending = null
        selectedUri = null
        selectedEntry = null
        result.error(code, message, null)
    }

    fun close() {
        closed = true
        listed = emptyMap()
        fail("activity_closed", "The activity closed during the file operation.")
        worker.shutdown()
    }

    private data class Scan(val files: List<Entry>, val issues: List<String>)

    private data class Entry(
        val uri: String, val name: String, val location: String, val mime: String,
        val size: Long?, val modified: Long?, val audio: Boolean, val document: Boolean
    ) {
        fun values(): Map<String, Any?> = mapOf(
            "uri" to uri, "name" to name, "location" to location, "mime" to mime,
            "size" to size, "modified" to modified, "audio" to audio
        )
    }

    companion object {
        private const val READ_REQUEST = 48320
        private const val WRITE_REQUEST = 48321
        private const val DELETE_REQUEST = 48322
    }
}
