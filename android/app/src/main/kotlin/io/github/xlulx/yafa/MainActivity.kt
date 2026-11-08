package io.github.xlulx.yafa

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "yasba/auto_backup")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "save" -> try {
                        val name = call.argument<String>("name")!!
                        val bytes = call.argument<ByteArray>("bytes")!!
                        val keep = call.argument<Int>("keep") ?: 5
                        result.success(save(name, bytes, keep))
                    } catch (e: Exception) {
                        result.error("save_failed", e.message, null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Writes an automatic backup and keeps only the newest [keep] of them.
     * Returns where the file went, for display.
     *
     * Android 10+: Download/YASBA through MediaStore (no permission needed,
     * survives uninstalling the app). Older versions: the app's own folder,
     * since the public Download folder would need a storage permission.
     */
    private fun save(name: String, bytes: ByteArray, keep: Int): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val relativePath = Environment.DIRECTORY_DOWNLOADS + "/YASBA/"
            val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/json")
                put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri = resolver.insert(collection, values)
                ?: throw IllegalStateException("Could not create $name")
            try {
                resolver.openOutputStream(uri)!!.use { it.write(bytes) }
                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
            } catch (e: Exception) {
                resolver.delete(uri, null, null)
                throw e
            }
            // Only files this app created are visible here, newest first.
            resolver.query(
                collection,
                arrayOf(MediaStore.MediaColumns._ID),
                "${MediaStore.MediaColumns.RELATIVE_PATH} = ? AND " +
                    "${MediaStore.MediaColumns.DISPLAY_NAME} LIKE ?",
                arrayOf(relativePath, "yasba-auto-backup-%"),
                "${MediaStore.MediaColumns.DATE_ADDED} DESC",
            )?.use { cursor ->
                var index = 0
                while (cursor.moveToNext()) {
                    if (index++ >= keep) {
                        val id = cursor.getLong(0)
                        resolver.delete(
                            android.content.ContentUris.withAppendedId(collection, id),
                            null,
                            null,
                        )
                    }
                }
            }
            return relativePath + name
        }
        val dir = File(getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), "YASBA")
        dir.mkdirs()
        File(dir, name).writeBytes(bytes)
        dir.listFiles { f -> f.name.startsWith("yasba-auto-backup-") }
            ?.sortedByDescending { it.lastModified() }
            ?.drop(keep)
            ?.forEach { it.delete() }
        return File(dir, name).absolutePath
    }
}
