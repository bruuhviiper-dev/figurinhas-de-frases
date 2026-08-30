package com.figurinhasfrases.figurinhas

import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    private val channel = "figurinhas/whatsapp"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "isWhatsAppInstalled" -> {
                    val pm = packageManager
                    val ok = try { pm.getPackageInfo("com.whatsapp", 0); true }
                    catch (e: Exception) {
                        try { pm.getPackageInfo("com.whatsapp.w4b", 0); true } catch (e2: Exception) { false }
                    }
                    result.success(ok)
                }
                "isPackAdded" -> {
                    val id = call.argument<String>("identifier")
                    if (id == null) { result.success(false); return@setMethodCallHandler }
                    result.success(isWhitelisted(id))
                }
                "prepareWhatsAppPack" -> {
                    val id = call.argument<String>("identifier")
                    if (id == null) { result.error("args", "faltou id", null); return@setMethodCallHandler }
                    Thread {
                        try {
                            val n = StickerContentProvider.prewarm(applicationContext, id)
                            runOnUiThread { result.success(n) }
                        } catch (e: Exception) {
                            Log.e("FIGWA", "prewarm falhou", e)
                            runOnUiThread { result.error("prep", e.message, null) }
                        }
                    }.start()
                }
                "addToWhatsApp" -> {
                    val id = call.argument<String>("identifier")
                    val name = call.argument<String>("name")
                    if (id == null || name == null) { result.error("args", "faltou id/name", null); return@setMethodCallHandler }
                    val intent = Intent("com.whatsapp.intent.action.ENABLE_STICKER_PACK").apply {
                        putExtra("sticker_pack_id", id)
                        putExtra("sticker_pack_authority", "$packageName.stickercontentprovider")
                        putExtra("sticker_pack_name", name)
                    }
                    try {
                        startActivityForResult(intent, 200)
                        result.success(true)
                    } catch (e: ActivityNotFoundException) {
                        result.error("no_wa", "WhatsApp não encontrado", null)
                    }
                }
                "saveCustomSticker" -> {
                    val png = call.argument<ByteArray>("png")
                    if (png == null) { result.error("args", "png nulo", null); return@setMethodCallHandler }
                    try {
                        val bmp = BitmapFactory.decodeByteArray(png, 0, png.size)
                        val scaled = if (bmp.width != 512 || bmp.height != 512)
                            Bitmap.createScaledBitmap(bmp, 512, 512, true) else bmp
                        val dir = File(filesDir, "wa/minhas"); if (!dir.exists()) dir.mkdirs()
                        // invalida a bandeja em cache
                        File(dir, "_tray.webp").delete()
                        val f = File(dir, System.currentTimeMillis().toString() + ".webp")
                        FileOutputStream(f).use { @Suppress("DEPRECATION") scaled.compress(Bitmap.CompressFormat.WEBP, 92, it) }
                        val n = dir.listFiles { fl -> fl.name.matches(Regex("\\d+\\.webp")) }?.size ?: 0
                        result.success(n)
                    } catch (e: Exception) { result.error("save", e.message, null) }
                }
                "listCustomStickers" -> {
                    val dir = File(filesDir, "wa/minhas")
                    val list = dir.listFiles { fl -> fl.name.matches(Regex("\\d+\\.webp")) }
                        ?.sortedByDescending { it.name }?.map { it.absolutePath } ?: emptyList()
                    result.success(list)
                }
                "deleteCustomSticker" -> {
                    val path = call.argument<String>("path")
                    if (path != null) { File(path).delete(); File(filesDir, "wa/minhas/_tray.webp").delete() }
                    result.success(true)
                }
                "shareImage" -> {
                    val png = call.argument<ByteArray>("png")
                    if (png == null) { result.error("args", "png nulo", null); return@setMethodCallHandler }
                    try {
                        val dir = File(cacheDir, "share"); if (!dir.exists()) dir.mkdirs()
                        val f = File(dir, "figurinha.png")
                        FileOutputStream(f).use { it.write(png) }
                        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", f)
                        val send = Intent(Intent.ACTION_SEND).apply {
                            type = "image/png"
                            putExtra(Intent.EXTRA_STREAM, uri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(Intent.createChooser(send, "Compartilhar figurinha"))
                        result.success(true)
                    } catch (e: Exception) { result.error("share", e.message, null) }
                }
                "saveToGallery" -> {
                    val png = call.argument<ByteArray>("png")
                    if (png == null) { result.error("args", "png nulo", null); return@setMethodCallHandler }
                    try {
                        val values = ContentValues().apply {
                            put(MediaStore.Images.Media.DISPLAY_NAME, "figurinha_${System.currentTimeMillis()}.png")
                            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                            if (Build.VERSION.SDK_INT >= 29)
                                put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Figurinhas de Frases")
                        }
                        val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                        if (uri != null) {
                            contentResolver.openOutputStream(uri)?.use { it.write(png) }
                            result.success(true)
                        } else result.error("save", "sem uri", null)
                    } catch (e: Exception) { result.error("save", e.message, null) }
                }
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    if (url == null) { result.error("args", "url nula", null); return@setMethodCallHandler }
                    try {
                        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(true)
                    } catch (e: Exception) { result.error("open", e.message, null) }
                }
                else -> result.notImplemented()
            }
        }
    }

    // Pergunta ao proprio WhatsApp se o pacote ja foi adicionado (provider oficial WAStickerApps).
    private fun isWhitelisted(identifier: String): Boolean {
        val authority = "$packageName.stickercontentprovider"
        for (wa in arrayOf("com.whatsapp", "com.whatsapp.w4b")) {
            try {
                val uri = Uri.parse("content://$wa.provider.sticker_whitelist_check/is_whitelisted")
                    .buildUpon()
                    .appendQueryParameter("authority", authority)
                    .appendQueryParameter("identifier", identifier)
                    .build()
                contentResolver.query(uri, null, null, null, null)?.use { c ->
                    if (c.moveToFirst()) {
                        val i = c.getColumnIndex("result")
                        if (i >= 0 && c.getInt(i) == 1) return true
                    }
                }
            } catch (e: Exception) { /* WhatsApp variante ausente: ignora */ }
        }
        return false
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 200) {
            val err = data?.getStringExtra("validation_error")
            Log.e("FIGWA", "add result=$resultCode validation_error=$err")
        }
    }
}
