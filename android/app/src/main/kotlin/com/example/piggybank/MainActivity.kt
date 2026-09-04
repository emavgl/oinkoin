package com.example.piggybank

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterFragmentActivity() {
    private var pendingResult: MethodChannel.Result? = null
    private var widgetChannel: MethodChannel? = null
    private var pendingWidgetAction: String? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .also { widgetChannel = it }
            .setMethodCallHandler { call, result ->
                if (call.method == "getInitialAction") {
                    result.success(pendingWidgetAction)
                    pendingWidgetAction = null
                } else {
                    result.notImplemented()
                }
            }
        handleWidgetIntent(intent)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickBackupDirectory" -> pickBackupDirectory(result)
                    "probeWrite" -> runIo(result) {
                        probeWrite(call.argument<String>("uri"))
                    }

                    "writeFile" -> runIo(result) {
                        writeFile(
                            call.argument<String>("uri"),
                            call.argument<String>("fileName"),
                            call.argument<String>("sourcePath"),
                        )
                    }

                    "deleteFile" -> runIo(result) {
                        deleteFile(
                            call.argument<String>("uri"),
                            call.argument<String>("fileName"),
                        )
                    }

                    "listFiles" -> runIo(result) {
                        listFiles(call.argument<String>("uri"))
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleWidgetIntent(intent)
    }

    /**
     * Forwards home screen widget quick-add taps to Flutter. While the
     * engine runs, the action is pushed immediately; otherwise (cold start)
     * it is stashed for [getInitialAction].
     */
    private fun handleWidgetIntent(intent: Intent?) {
        val action = when (intent?.action) {
            "com.example.piggybank.ADD_EXPENSE" -> "add_expense"
            "com.example.piggybank.ADD_INCOME" -> "add_income"
            else -> return
        }
        try {
            widgetChannel?.invokeMethod("openAddFlow", action)
                ?: run { pendingWidgetAction = action }
        } catch (e: Exception) {
            pendingWidgetAction = action
        }
    }

    /**
     * Runs a blocking storage operation off the main thread and delivers the
     * result back on the platform thread.
     */
    private fun runIo(result: MethodChannel.Result, block: () -> Any?) {
        ioExecutor.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("backup_directory_error", e.message, null)
                }
            }
        }
    }

    /**
     * Opens the system Storage Access Framework picker (ACTION_OPEN_DOCUMENT_TREE)
     * so the user can choose the folder backups are stored in. The result is
     * delivered to [onActivityResult].
     */
    private fun pickBackupDirectory(result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("picker_active", "A directory picker is already active", null)
            return
        }
        pendingResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        }
        @Suppress("DEPRECATION")
        startActivityForResult(intent, REQUEST_PICK_BACKUP_DIRECTORY)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_PICK_BACKUP_DIRECTORY) {
            return
        }
        val result = pendingResult ?: return
        pendingResult = null
        val treeUri = data?.data
        if (resultCode != Activity.RESULT_OK || treeUri == null) {
            // The user dismissed the picker.
            result.success(null)
            return
        }
        persistDirectoryGrant(treeUri)
        result.success(
            mapOf(
                "path" to resolveTreePath(treeUri),
                "uri" to treeUri.toString(),
            )
        )
    }

    override fun onDestroy() {
        pendingResult?.error("picker_cancelled", "The picker was dismissed", null)
        pendingResult = null
        ioExecutor.shutdown()
        super.onDestroy()
    }

    /**
     * Keeps the granted access to the picked folder across reboots and drops
     * the grants of previously picked folders, so the app never runs into the
     * system limit of persisted URI permissions.
     */
    private fun persistDirectoryGrant(treeUri: Uri) {
        val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        try {
            contentResolver.takePersistableUriPermission(treeUri, flags)
        } catch (e: SecurityException) {
            // Some providers do not offer persistable grants.
        }
        for (permission in contentResolver.persistedUriPermissions) {
            val uri = permission.uri
            if (uri != treeUri && uri.path?.startsWith("/tree/") == true) {
                try {
                    contentResolver.releasePersistableUriPermission(uri, flags)
                } catch (e: SecurityException) {
                    // The grant is already gone; nothing to release.
                }
            }
        }
    }

    private fun parseTreeUri(uriString: String?): Uri {
        if (uriString.isNullOrEmpty()) {
            throw IllegalArgumentException("Missing backup folder uri")
        }
        return Uri.parse(uriString)
    }

    private fun rootDocumentUri(treeUri: Uri): Uri =
        DocumentsContract.buildDocumentUriUsingTree(
            treeUri, DocumentsContract.getTreeDocumentId(treeUri)
        )

    private fun childrenUri(treeUri: Uri): Uri =
        DocumentsContract.buildChildDocumentsUriUsingTree(
            treeUri, DocumentsContract.getTreeDocumentId(treeUri)
        )

    private data class ChildDocument(val documentId: String, val name: String)

    private fun queryChildren(treeUri: Uri): List<ChildDocument> {
        val children = mutableListOf<ChildDocument>()
        contentResolver.query(
            childrenUri(treeUri),
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            ),
            null, null, null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                children.add(ChildDocument(cursor.getString(0), cursor.getString(1)))
            }
        }
        return children
    }

    private fun findChild(treeUri: Uri, fileName: String): ChildDocument? =
        queryChildren(treeUri).firstOrNull { it.name == fileName }

    /**
     * Verifies through the Storage Access Framework that the app can create
     * and delete documents in the picked folder. Raw file-path probes are not
     * usable here: scoped storage blocks direct writes outside app-specific
     * directories even when a persistable URI grant exists.
     */
    private fun probeWrite(uriString: String?): Boolean {
        val treeUri = parseTreeUri(uriString)
        val probeUri = DocumentsContract.createDocument(
            contentResolver, rootDocumentUri(treeUri),
            "application/octet-stream", PROBE_FILE_NAME
        ) ?: return false
        return try {
            DocumentsContract.deleteDocument(contentResolver, probeUri)
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Copies the staged backup file [sourcePath] into the picked folder as
     * [fileName]. An existing document with the same name is overwritten in
     * place, so fixed-name backups do not accumulate " (1)" copies.
     */
    private fun writeFile(uriString: String?, fileName: String?, sourcePath: String?): Boolean {
        val treeUri = parseTreeUri(uriString)
        if (fileName.isNullOrEmpty() || sourcePath.isNullOrEmpty()) {
            throw IllegalArgumentException("Missing file name or source path")
        }
        val existing = findChild(treeUri, fileName)
        val targetUri = if (existing != null) {
            DocumentsContract.buildDocumentUriUsingTree(treeUri, existing.documentId)
        } else {
            val mime = if (fileName.endsWith(".json", ignoreCase = true)) {
                "application/json"
            } else {
                "application/octet-stream"
            }
            DocumentsContract.createDocument(
                contentResolver, rootDocumentUri(treeUri), mime, fileName
            )
                ?: throw IllegalStateException("Could not create $fileName in the backup folder")
        }
        FileInputStream(File(sourcePath)).use { input ->
            contentResolver.openOutputStream(targetUri, "wt").use { output ->
                if (output == null) {
                    throw IllegalStateException("The backup folder is not writable")
                }
                input.copyTo(output)
            }
        }
        return true
    }

    private fun deleteFile(uriString: String?, fileName: String?): Boolean {
        val treeUri = parseTreeUri(uriString)
        if (fileName.isNullOrEmpty()) {
            return false
        }
        val existing = findChild(treeUri, fileName) ?: return false
        return DocumentsContract.deleteDocument(
            contentResolver,
            DocumentsContract.buildDocumentUriUsingTree(treeUri, existing.documentId)
        )
    }

    /**
     * Lists the documents in the picked folder with their display names and
     * last-modified timestamps, used for retention cleanup and for detecting
     * the latest backup.
     */
    private fun listFiles(uriString: String?): List<Map<String, Any?>> {
        val treeUri = parseTreeUri(uriString)
        val files = mutableListOf<Map<String, Any?>>()
        contentResolver.query(
            childrenUri(treeUri),
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            ),
            null, null, null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                files.add(
                    mapOf(
                        "name" to cursor.getString(1),
                        "lastModifiedMs" to if (cursor.isNull(2)) null else cursor.getLong(2),
                    )
                )
            }
        }
        return files
    }

    /**
     * Maps a SAF tree URI to the raw filesystem path it points to, e.g.
     * content://com.android.externalstorage.documents/tree/primary:Backups
     * becomes /storage/emulated/0/Backups. Returns null when the provider is
     * not backed by the local filesystem (e.g. a cloud provider). The path is
     * used for display only; all writes go through the content resolver.
     */
    private fun resolveTreePath(treeUri: Uri): String? {
        val docId = try {
            DocumentsContract.getTreeDocumentId(treeUri)
        } catch (e: IllegalArgumentException) {
            return null
        }
        val separator = docId.indexOf(':')
        return if (separator < 0) {
            // Whole-volume pick, e.g. the storage root.
            volumeRoot(docId)
        } else {
            val volumeRoot = volumeRoot(docId.substring(0, separator))
            val relativePath = docId.substring(separator + 1)
            if (relativePath.isEmpty()) volumeRoot else "$volumeRoot/$relativePath"
        }
    }

    private fun volumeRoot(volumeId: String): String {
        @Suppress("DEPRECATION")
        val externalStorage = Environment.getExternalStorageDirectory().absolutePath
        return if (volumeId.equals("primary", ignoreCase = true)) {
            externalStorage
        } else {
            "/storage/$volumeId"
        }
    }

    companion object {
        private const val CHANNEL = "oinkoin/backup_directory"
        private const val WIDGET_CHANNEL = "oinkoin/widget_action"
        private const val REQUEST_PICK_BACKUP_DIRECTORY = 7941
        private const val PROBE_FILE_NAME = ".oinkoin_probe"
    }
}
