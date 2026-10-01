package com.example.dusk

import android.app.Activity
import android.app.KeyguardManager
import android.app.WallpaperManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.view.WindowManager
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val exportChannel = "com.example.dusk/media_export"
    private val shareChannelName = "com.example.dusk/share_intent"
    private val pickAudioRequestCode = 9042

    private var pendingAudioPickResult: MethodChannel.Result? = null
    private var lastSharedExtraText: String? = null
    private var lastSharedExtraSubject: String? = null
    private val lastSharedFiles = mutableListOf<Map<String, String>>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, exportChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveImageToGallery" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val fileName = call.argument<String>("fileName") ?: "dusk_insight_${System.currentTimeMillis()}.png"
                        if (bytes == null) {
                            result.error("INVALID_ARGS", "Image bytes are null", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val savedPath = savePngToMediaStore(bytes, fileName)
                            result.success(savedPath)
                        } catch (e: Exception) {
                            result.error("SAVE_FAILED", e.message, null)
                        }
                    }
                    "setWallpaper" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val target = call.argument<String>("target") ?: "lock" // "lock", "system", "both"
                        if (bytes == null) {
                            result.error("INVALID_ARGS", "Image bytes are null", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                            val wm = WallpaperManager.getInstance(applicationContext)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                                val flag = when (target) {
                                    "lock" -> WallpaperManager.FLAG_LOCK
                                    "system" -> WallpaperManager.FLAG_SYSTEM
                                    else -> WallpaperManager.FLAG_LOCK or WallpaperManager.FLAG_SYSTEM
                                }
                                wm.setBitmap(bitmap, null, true, flag)
                            } else {
                                wm.setBitmap(bitmap)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("WALLPAPER_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shareChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumeShareExtras" -> {
                        val payload = mapOf(
                            "text" to lastSharedExtraText,
                            "subject" to lastSharedExtraSubject,
                            "files" to ArrayList(lastSharedFiles)
                        )
                        lastSharedExtraText = null
                        lastSharedExtraSubject = null
                        lastSharedFiles.clear()
                        result.success(payload)
                    }
                    "pickAudioFiles" -> {
                        if (pendingAudioPickResult != null) {
                            result.error("BUSY", "Audio picker already active", null)
                            return@setMethodCallHandler
                        }
                        pendingAudioPickResult = result
                        try {
                            val pickIntent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "audio/*"
                                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                                putExtra(
                                    Intent.EXTRA_MIME_TYPES,
                                    arrayOf("audio/*", "application/ogg")
                                )
                            }
                            startActivityForResult(pickIntent, pickAudioRequestCode)
                        } catch (e: Exception) {
                            pendingAudioPickResult = null
                            result.error("PICK_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == pickAudioRequestCode) {
            val callback = pendingAudioPickResult
            pendingAudioPickResult = null
            if (callback == null) return

            if (resultCode != Activity.RESULT_OK || data == null) {
                callback.success(emptyList<Map<String, String>>())
                return
            }

            try {
                val picked = mutableListOf<Map<String, String>>()
                val clipData = data.clipData
                if (clipData != null && clipData.itemCount > 0) {
                    for (i in 0 until clipData.itemCount) {
                        val uri = clipData.getItemAt(i)?.uri ?: continue
                        copySharedUriToCache(uri, "audio/*")?.let { picked.add(it) }
                    }
                } else {
                    data.data?.let { uri ->
                        copySharedUriToCache(uri, "audio/*")?.let { picked.add(it) }
                    }
                }
                callback.success(picked)
            } catch (e: Exception) {
                callback.error("COPY_FAILED", e.message, null)
            }
        }
    }

    private fun normalizeIncomingShareIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action ?: return
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) return

        try {
            lastSharedExtraText = intent.getStringExtra(Intent.EXTRA_TEXT)
            lastSharedExtraSubject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
            lastSharedFiles.clear()

            if (action == Intent.ACTION_SEND) {
                val streamUri = getParcelableUri(intent, Intent.EXTRA_STREAM)
                    ?: intent.clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.uri
                if (streamUri != null) {
                    val copied = copySharedUriToCache(streamUri, intent.type)
                    if (copied != null) {
                        lastSharedFiles.add(copied)
                        val fileUri = Uri.fromFile(File(copied["path"]!!))
                        intent.putExtra(Intent.EXTRA_STREAM, fileUri)
                        val resolvedMime = copied["mimeType"]
                        if (!resolvedMime.isNullOrBlank()) {
                            intent.type = resolvedMime
                        }
                    }
                }
            } else if (action == Intent.ACTION_SEND_MULTIPLE) {
                val uris = getParcelableUriList(intent, Intent.EXTRA_STREAM).toMutableList()
                if (uris.isEmpty() && intent.clipData != null) {
                    for (i in 0 until intent.clipData!!.itemCount) {
                        intent.clipData!!.getItemAt(i)?.uri?.let { uris.add(it) }
                    }
                }
                if (uris.isNotEmpty()) {
                    val newUris = ArrayList<Uri>()
                    val mimeTypes = mutableListOf<String>()
                    for (u in uris) {
                        val copied = copySharedUriToCache(u, intent.type)
                        if (copied != null) {
                            lastSharedFiles.add(copied)
                            newUris.add(Uri.fromFile(File(copied["path"]!!)))
                            mimeTypes.add(copied["mimeType"] ?: intent.type ?: "*/*")
                        }
                    }
                    if (newUris.isNotEmpty()) {
                        intent.putParcelableArrayListExtra(Intent.EXTRA_STREAM, newUris)
                        intent.putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes.toTypedArray())
                    }
                }
            }
        } catch (_: Exception) {
            // Fall back gracefully if any URI cannot be pre-copied
        }
    }

    private fun copySharedUriToCache(uri: Uri, fallbackMimeType: String?): Map<String, String>? {
        val resolver = applicationContext.contentResolver
        var displayName: String? = null
        if ("content".equals(uri.scheme, ignoreCase = true)) {
            try {
                resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (idx >= 0) {
                            displayName = cursor.getString(idx)
                        }
                    }
                }
            } catch (_: Exception) {}
        } else if ("file".equals(uri.scheme, ignoreCase = true)) {
            val path = uri.path
            if (path != null) {
                val f = File(path)
                if (f.exists()) {
                    displayName = f.name
                }
            }
        }

        val rawMime = resolver.getType(uri) ?: fallbackMimeType ?: ""
        val extFromName = displayName?.substringAfterLast('.', "")?.lowercase() ?: ""
        val ext = when {
            extFromName.isNotEmpty() && extFromName.length <= 5 -> extFromName
            rawMime.contains("audio/mp4") || rawMime.contains("audio/x-m4a") || rawMime.contains("audio/m4a") || rawMime.contains("audio/aac") -> "m4a"
            rawMime.contains("audio/mpeg") || rawMime.contains("audio/mp3") -> "mp3"
            rawMime.contains("audio/ogg") || rawMime.contains("application/ogg") || rawMime.contains("audio/opus") -> "ogg"
            rawMime.contains("audio/wav") || rawMime.contains("audio/x-wav") -> "wav"
            rawMime.contains("audio/flac") -> "flac"
            rawMime.contains("audio/webm") -> "webm"
            rawMime.contains("audio/3gpp") || rawMime.contains("audio/amr") -> "m4a"
            rawMime.startsWith("audio/") -> MimeTypeMap.getSingleton().getExtensionFromMimeType(rawMime) ?: "m4a"
            rawMime.contains("image/png") -> "png"
            rawMime.contains("image/webp") -> "webp"
            rawMime.contains("image/gif") -> "gif"
            rawMime.startsWith("image/") -> "jpg"
            rawMime.startsWith("text/") -> "txt"
            else -> MimeTypeMap.getSingleton().getExtensionFromMimeType(rawMime) ?: "bin"
        }

        val resolvedMime = when {
            rawMime.isNotBlank() && rawMime != "*/*" && rawMime != "application/octet-stream" -> {
                if (rawMime == "application/ogg") "audio/ogg" else rawMime
            }
            ext in listOf("m4a", "aac", "3gp", "3gpp") -> "audio/mp4"
            ext == "mp3" -> "audio/mpeg"
            ext in listOf("ogg", "opus") -> "audio/ogg"
            ext == "wav" -> "audio/wav"
            ext == "flac" -> "audio/flac"
            ext in listOf("jpg", "jpeg") -> "image/jpeg"
            ext == "png" -> "image/png"
            ext == "webp" -> "image/webp"
            ext in listOf("txt", "md", "csv", "json") -> "text/plain"
            else -> if (rawMime.isNotBlank()) rawMime else "application/octet-stream"
        }

        val cleanBase = (displayName?.substringBeforeLast('.') ?: "shared_${System.currentTimeMillis()}")
            .replace(Regex("[^a-zA-Z0-9._-]"), "_")
            .take(48)
            .ifBlank { "shared" }

        val dir = File(applicationContext.cacheDir, "shared_incoming")
        if (!dir.exists()) dir.mkdirs()

        val targetFile = File(dir, "${cleanBase}_${System.currentTimeMillis()}.$ext")
        if ("file".equals(uri.scheme, ignoreCase = true) && uri.path != null) {
            val src = File(uri.path!!)
            if (src.exists()) {
                src.copyTo(targetFile, overwrite = true)
            } else {
                return null
            }
        } else {
            val input = resolver.openInputStream(uri) ?: return null
            input.use { stream ->
                FileOutputStream(targetFile).use { out ->
                    stream.copyTo(out)
                }
            }
        }

        return mapOf(
            "path" to targetFile.absolutePath,
            "name" to (displayName ?: targetFile.name),
            "mimeType" to resolvedMime
        )
    }

    private fun getParcelableUri(intent: Intent, key: String): Uri? = when {
        Build.VERSION.SDK_INT >= 33 -> intent.getParcelableExtra(key, Uri::class.java)
        else -> @Suppress("DEPRECATION") intent.getParcelableExtra(key) as? Uri
    }

    private fun getParcelableUriList(intent: Intent, key: String): List<Uri> = when {
        Build.VERSION.SDK_INT >= 33 -> intent.getParcelableArrayListExtra(key, Uri::class.java) ?: emptyList()
        else -> @Suppress("DEPRECATION") intent.getParcelableArrayListExtra<Uri>(key) ?: emptyList()
    }

    private fun savePngToMediaStore(bytes: ByteArray, fileName: String): String {
        val resolver = applicationContext.contentResolver
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, "image/png")
                put(MediaStore.MediaColumns.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/Dusk")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)
                ?: throw Exception("Could not create MediaStore entry")
            resolver.openOutputStream(uri)?.use { stream ->
                stream.write(bytes)
                stream.flush()
            }
            contentValues.clear()
            contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, contentValues, null, null)
            return "Pictures/Dusk/$fileName"
        } else {
            val picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
            val duskDir = File(picturesDir, "Dusk")
            if (!duskDir.exists()) duskDir.mkdirs()
            val file = File(duskDir, fileName)
            FileOutputStream(file).use { stream ->
                stream.write(bytes)
                stream.flush()
            }
            return file.absolutePath
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        normalizeIncomingShareIntent(intent)
        super.onCreate(savedInstanceState)
        turnScreenOnAndShowWhenLocked()
    }

    override fun onNewIntent(intent: Intent) {
        normalizeIncomingShareIntent(intent)
        setIntent(intent)
        super.onNewIntent(intent)
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        turnScreenOnAndShowWhenLocked()
    }

    private fun turnScreenOnAndShowWhenLocked() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            keyguardManager?.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }
}


