package com.adbtool.clipboard

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Bundle
import android.util.Base64

class SetClipboardActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val b64 = intent.getStringExtra("text")
        if (!b64.isNullOrEmpty()) {
            try {
                val decoded = Base64.decode(b64, Base64.NO_WRAP)
                val text = String(decoded, Charsets.UTF_8)
                val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                clipboard.setPrimaryClip(ClipData.newPlainText("adb-tool", text))
            } catch (_: Exception) {
            }
        }
        finish()
    }
}
