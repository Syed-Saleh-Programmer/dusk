package com.example.dusk

import android.app.KeyguardManager
import android.app.WallpaperManager
import android.content.ContentValues
import android.content.Context
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val exportChannel = "com.example.dusk/media_export"

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
        super.onCreate(savedInstanceState)
        turnScreenOnAndShowWhenLocked()
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

