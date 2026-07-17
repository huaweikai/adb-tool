package com.adbtool.clipboard.icon

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.AdaptiveIconDrawable
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Bundle
import android.util.Log
import java.io.File
import java.io.FileOutputStream

class IconDumpActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        try {
            val pm = packageManager
            val packages = pm.getInstalledPackages(0)

            val extDir = getExternalFilesDir("adb-tool-icons")
                ?: File(filesDir, "adb-tool-icons")
            extDir.mkdirs()
            Log.d("IconDump", "extDir=$extDir")

            var count = 0
            for (pkg in packages) {
                try {
                    val icon = pm.getApplicationIcon(pkg.packageName)
                    val bitmap = drawableToBitmap(icon)
                    val pngFile = File(extDir, "${pkg.packageName}.png")
                    FileOutputStream(pngFile).use { out ->
                        bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                    }
                    count++
                } catch (e: Exception) {
                    Log.w("IconDump", "skip ${pkg.packageName}: ${e.message}")
                }
            }

            File(extDir, ".done").writeText("ok")
            Log.d("IconDump", "done: $count icons written")
        } catch (e: Exception) {
            Log.e("IconDump", "failed", e)
            File(filesDir, "adb-tool-icons/.done").apply {
                parentFile?.mkdirs()
                writeText("error: ${e.message}")
            }
        }
        finish()
    }

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable) {
            return drawable.bitmap
        }
        val width = drawable.intrinsicWidth.coerceAtLeast(1)
        val height = drawable.intrinsicHeight.coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)

        if (drawable is AdaptiveIconDrawable) {
            val bg = drawable.background
            if (bg != null) {
                bg.setBounds(0, 0, canvas.width, canvas.height)
                bg.draw(canvas)
            }
        }
        drawable.draw(canvas)
        return bitmap
    }
}
