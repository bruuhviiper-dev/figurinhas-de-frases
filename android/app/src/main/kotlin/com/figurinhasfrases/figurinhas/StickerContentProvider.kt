package com.figurinhasfrases.figurinhas

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.content.UriMatcher
import android.content.res.AssetFileDescriptor
import android.database.Cursor
import android.database.MatrixCursor
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.ParcelFileDescriptor
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream

/**
 * ContentProvider do WAStickerApps. Serve os packs prontos (PNG dos assets -> WebP em
 * runtime, cache em filesDir/wa/<pack>/) e o pack dinamico "Minhas Figurinhas"
 * (criadas no editor, ja salvas como WebP em filesDir/wa/minhas/).
 */
class StickerContentProvider : ContentProvider() {

    companion object {
        lateinit var AUTHORITY: String
        const val CUSTOM_ID = "minhas"
        private const val METADATA = "metadata"
        private const val STICKERS = "stickers"
        private const val STICKERS_ASSET = "stickers_asset"
        private const val TRAY = "tray.webp"

        private const val C_ID = "sticker_pack_identifier"
        private const val C_NAME = "sticker_pack_name"
        private const val C_PUBLISHER = "sticker_pack_publisher"
        private const val C_ICON = "sticker_pack_icon"
        private const val C_ANDROID = "android_play_store_link"
        private const val C_IOS = "ios_app_download_link"
        private const val C_EMAIL = "sticker_pack_publisher_email"
        private const val C_WEBSITE = "sticker_pack_publisher_website"
        private const val C_PRIVACY = "sticker_pack_privacy_policy_website"
        private const val C_LICENSE = "sticker_pack_license_agreement_website"
        private const val C_DATA_VERSION = "image_data_version"
        private const val C_AVOID_CACHE = "whatsapp_will_not_cache_stickers"
        private const val C_ANIMATED = "animated_sticker_pack"
        private const val C_FILE = "sticker_file_name"
        private const val C_EMOJI = "sticker_emoji"

        /** Converte todos os PNG do pack (assets) -> WebP + bandeja em filesDir/wa/<id>.
         *  Chamado ANTES de abrir o WhatsApp p/ ele so ler arquivos prontos (evita
         *  travar a conversao dentro da chamada binder do WhatsApp). */
        fun prewarm(ctx: Context, id: String): Int {
            val json = ctx.assets.open("flutter_assets/assets/stickers/contents.json")
                .bufferedReader(Charsets.UTF_8).use { it.readText() }
            val arr = JSONObject(json).getJSONArray("packs")
            var pngs: List<String>? = null
            var animated = false
            for (i in 0 until arr.length()) {
                val p = arr.getJSONObject(i)
                if (p.getString("identifier") == id) {
                    val stk = p.getJSONArray("stickers")
                    pngs = (0 until stk.length()).map { stk.getString(it) }
                    animated = p.optBoolean("animated", false)
                    break
                }
            }
            val list = pngs ?: return 0
            val dir = File(ctx.filesDir, "wa/$id"); if (!dir.exists()) dir.mkdirs()
            var count = 0
            for (src in list) {
                val webpFile = File(dir, src.substringBeforeLast(".") + ".webp")
                if (!webpFile.exists() || webpFile.length() == 0L) {
                    if (animated) {
                        // ja e webp animado nos assets: copia crua
                        ctx.assets.open("flutter_assets/assets/stickers/$id/$src").use { input ->
                            FileOutputStream(webpFile).use { input.copyTo(it) }
                        }
                    } else {
                        val bmp = ctx.assets.open("flutter_assets/assets/stickers/$id/$src")
                            .use { BitmapFactory.decodeStream(it) } ?: continue
                        FileOutputStream(webpFile).use {
                            @Suppress("DEPRECATION") bmp.compress(Bitmap.CompressFormat.WEBP, 90, it)
                        }
                        bmp.recycle()
                    }
                }
                count++
            }
            val trayFile = File(dir, TRAY)
            if (!trayFile.exists() || trayFile.length() == 0L) {
                val src = ctx.assets.open("flutter_assets/assets/stickers/$id/${list.first()}")
                    .use { BitmapFactory.decodeStream(it) }
                if (src != null) {
                    val scaled = Bitmap.createScaledBitmap(src, 96, 96, true)
                    FileOutputStream(trayFile).use {
                        @Suppress("DEPRECATION") scaled.compress(Bitmap.CompressFormat.WEBP, 100, it)
                    }
                    src.recycle(); scaled.recycle()
                }
            }
            return count
        }
    }

    data class Pack(val id: String, val name: String, val emoji: String,
                    val files: List<String>, val animated: Boolean = false,
                    val version: String = "1")

    private var publisher = "Figurinhas de Frases"
    private val assetPacks = ArrayList<Pack>()
    private lateinit var matcher: UriMatcher

    override fun onCreate(): Boolean {
        AUTHORITY = context!!.packageName + ".stickercontentprovider"
        matcher = UriMatcher(UriMatcher.NO_MATCH).apply {
            addURI(AUTHORITY, METADATA, 1)
            addURI(AUTHORITY, "$METADATA/*", 2)
            addURI(AUTHORITY, "$STICKERS/*", 3)
            addURI(AUTHORITY, "$STICKERS_ASSET/*/*", 4)
        }
        loadContents()
        return true
    }

    private fun loadContents() {
        try {
            val json = context!!.assets.open("flutter_assets/assets/stickers/contents.json")
                .bufferedReader(Charsets.UTF_8).use { it.readText() }
            val root = JSONObject(json)
            publisher = root.optString("publisher", publisher)
            val arr = root.getJSONArray("packs")
            for (i in 0 until arr.length()) {
                val p = arr.getJSONObject(i)
                val stk = p.getJSONArray("stickers")
                val list = ArrayList<String>()
                for (j in 0 until stk.length()) list.add(stk.getString(j))
                assetPacks.add(Pack(p.getString("identifier"), p.getString("name"),
                    p.optString("emoji", "😀"), list, p.optBoolean("animated", false),
                    p.optString("version", "1")))
            }
        } catch (e: Exception) { }
    }

    private fun customDir(): File = File(context!!.filesDir, "wa/$CUSTOM_ID")

    // versao do pack "Minhas": muda sempre que uma figurinha e criada/removida,
    // pra o WhatsApp reler o MESMO pacote (id fixo) sem duplicar.
    private fun customVersion(): String {
        val files = customDir().listFiles { f -> f.name.matches(Regex("\\d+\\.webp")) } ?: return "1"
        val newest = files.maxOfOrNull { it.lastModified() } ?: 0L
        return "${files.size}-$newest"
    }

    // pack dinamico "Minhas Figurinhas" (apenas se houver arquivos)
    private fun customPack(): Pack? {
        val dir = customDir()
        val files = dir.listFiles { f -> f.name.endsWith(".webp") }?.sortedBy { it.name }?.map { it.name }
            ?: return null
        if (files.isEmpty()) return null
        return Pack(CUSTOM_ID, "Minhas Figurinhas", "✨", files)
    }

    // metadata so inclui packs validos p/ o WhatsApp (>=3 figurinhas)
    private fun metaPacks(): List<Pack> {
        val list = ArrayList<Pack>()
        customPack()?.let { if (it.files.size >= 3) list.add(it) }
        list.addAll(assetPacks)
        return list
    }

    private fun packById(id: String?): Pack? {
        if (id == CUSTOM_ID) return customPack()
        return assetPacks.firstOrNull { it.id == id }
    }

    private fun webpName(f: String) = if (f.endsWith(".webp")) f else f.substringBeforeLast(".") + ".webp"

    override fun query(uri: Uri, projection: Array<out String>?, selection: String?,
                       selectionArgs: Array<out String>?, sortOrder: String?): Cursor? {
        return when (matcher.match(uri)) {
            1 -> metaCursor(metaPacks())
            2 -> metaCursor(metaPacks().filter { it.id == uri.lastPathSegment })
            3 -> stickersCursor(packById(uri.lastPathSegment))
            else -> null
        }
    }

    private fun metaCursor(list: List<Pack>): Cursor {
        val cols = arrayOf(C_ID, C_NAME, C_PUBLISHER, C_ICON, C_ANDROID, C_IOS, C_EMAIL,
            C_WEBSITE, C_PRIVACY, C_LICENSE, C_DATA_VERSION, C_AVOID_CACHE, C_ANIMATED)
        val cur = MatrixCursor(cols)
        for (p in list) {
            val ver = if (p.id == CUSTOM_ID) customVersion() else p.version
            cur.addRow(arrayOf<Any>(p.id, p.name, publisher, TRAY, "", "", "", "", "", "",
                ver, 0, if (p.animated) 1 else 0))
        }
        return cur
    }

    private fun stickersCursor(pack: Pack?): Cursor {
        val cur = MatrixCursor(arrayOf(C_FILE, C_EMOJI))
        if (pack != null) for (f in pack.files) cur.addRow(arrayOf<Any>(webpName(f), pack.emoji))
        return cur
    }

    override fun openAssetFile(uri: Uri, mode: String): AssetFileDescriptor? {
        if (matcher.match(uri) != 4) return null
        val seg = uri.pathSegments
        if (seg.size != 3) return null
        val id = seg[1]
        val file = seg[2]
        val pack = packById(id) ?: return null
        val webp = ensureWebp(pack, file) ?: return null
        val pfd = ParcelFileDescriptor.open(webp, ParcelFileDescriptor.MODE_READ_ONLY)
        return AssetFileDescriptor(pfd, 0, AssetFileDescriptor.UNKNOWN_LENGTH)
    }

    private fun ensureWebp(pack: Pack, file: String): File? {
        // pack custom: os webp ja estao em filesDir/wa/minhas
        if (pack.id == CUSTOM_ID) {
            if (file == TRAY) return firstCustomTray(pack)
            val f = File(customDir(), file)
            return if (f.exists()) f else null
        }
        val dir = File(context!!.filesDir, "wa/${pack.id}")
        if (!dir.exists()) dir.mkdirs()
        val outFile = File(dir, file)
        if (outFile.exists() && outFile.length() > 0) return outFile
        // pack animado: os .webp dos assets ja estao prontos (animados). A figurinha
        // e servida crua; so a bandeja e reduzida ao 1o frame (estatica 96x96).
        if (pack.animated && file != TRAY) {
            return try {
                context!!.assets.open("flutter_assets/assets/stickers/${pack.id}/$file").use { input ->
                    FileOutputStream(outFile).use { input.copyTo(it) }
                }
                outFile
            } catch (e: Exception) { outFile.delete(); null }
        }
        val bmp: Bitmap = if (file == TRAY) {
            val src = decodePng(pack.id, pack.files.first()) ?: return null
            val scaled = Bitmap.createScaledBitmap(src, 96, 96, true)
            if (scaled != src) src.recycle()
            scaled
        } else {
            val png = file.substringBeforeLast(".") + ".png"
            decodePng(pack.id, png) ?: return null
        }
        return try {
            FileOutputStream(outFile).use { os ->
                val q = if (file == TRAY) 100 else 90
                @Suppress("DEPRECATION")
                bmp.compress(Bitmap.CompressFormat.WEBP, q, os)
            }
            bmp.recycle(); outFile
        } catch (e: Exception) { outFile.delete(); null }
    }

    // bandeja do pack custom = 1a figurinha reduzida a 96x96
    private fun firstCustomTray(pack: Pack): File? {
        val trayFile = File(customDir(), "_tray.webp")
        if (trayFile.exists() && trayFile.length() > 0) return trayFile
        val src = File(customDir(), pack.files.first())
        if (!src.exists()) return null
        val bmp = BitmapFactory.decodeFile(src.absolutePath) ?: return null
        val scaled = Bitmap.createScaledBitmap(bmp, 96, 96, true)
        return try {
            FileOutputStream(trayFile).use { @Suppress("DEPRECATION") scaled.compress(Bitmap.CompressFormat.WEBP, 100, it) }
            bmp.recycle(); scaled.recycle(); trayFile
        } catch (e: Exception) { null }
    }

    private fun decodePng(id: String, png: String): Bitmap? {
        return try {
            context!!.assets.open("flutter_assets/assets/stickers/$id/$png").use {
                BitmapFactory.decodeStream(it)
            }
        } catch (e: Exception) { null }
    }

    override fun getType(uri: Uri): String? = when (matcher.match(uri)) {
        1 -> "vnd.android.cursor.dir/vnd.$AUTHORITY.$METADATA"
        2 -> "vnd.android.cursor.item/vnd.$AUTHORITY.$METADATA"
        3 -> "vnd.android.cursor.dir/vnd.$AUTHORITY.$STICKERS"
        4 -> "image/webp"
        else -> null
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0
    override fun update(uri: Uri, values: ContentValues?, selection: String?,
                        selectionArgs: Array<out String>?): Int = 0
}
