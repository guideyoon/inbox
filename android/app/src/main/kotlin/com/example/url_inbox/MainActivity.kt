package com.peoplenetworks.urlinbox

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Patterns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class MainActivity : FlutterActivity() {
    private val channelName = "url_inbox/share"
    private val prefsName = "url_inbox_share_buffer"
    private val keyPendingData = "pending_data"

    override fun onCreate(savedInstanceState: Bundle?) {
        val launchIntentCopy = intent?.let { Intent(it) }
        sanitizeIntentForFlutter(intent)
        super.onCreate(savedInstanceState)
        collectIncomingUrls(launchIntentCopy)
    }

    override fun onNewIntent(intent: Intent) {
        val incomingCopy = Intent(intent)
        sanitizeIntentForFlutter(intent)
        super.onNewIntent(intent)
        setIntent(intent)
        collectIncomingUrls(incomingCopy)
    }

    override fun getInitialRoute(): String {
        return "/"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "consumeSharedUrls") {
                    result.success(consumePendingUrls())
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun collectIncomingUrls(intent: Intent?) {
        if (intent == null) return
        val sharedItems = mutableListOf<Map<String, String>>()

        when (intent.action) {
            Intent.ACTION_SEND -> {
                val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: ""
                val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT) ?: ""
                
                // 디버그 로그 - 공유 데이터 확인
                android.util.Log.d("URL_INBOX_SHARE", "=== SHARE INTENT RECEIVED ===")
                android.util.Log.d("URL_INBOX_SHARE", "EXTRA_SUBJECT: [$subject]")
                android.util.Log.d("URL_INBOX_SHARE", "EXTRA_TEXT: [$text]")
                android.util.Log.d("URL_INBOX_SHARE", "Package: ${intent.`package` ?: "unknown"}")
                
                val urls = extractUrls(text)
                android.util.Log.d("URL_INBOX_SHARE", "Extracted URLs: $urls")
                
                for (url in urls) {
                    val titleCandidate = extractBestTitle(text, url, subject)
                    android.util.Log.d("URL_INBOX_SHARE", "Title candidate for $url: [$titleCandidate]")
                    sharedItems.add(mapOf("url" to url, "title" to titleCandidate))
                }
                
                val stream = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                if (stream != null) sharedItems.add(mapOf("url" to stream.toString(), "title" to ""))
            }

            Intent.ACTION_SEND_MULTIPLE -> {
                val texts = intent.getStringArrayListExtra(Intent.EXTRA_TEXT)
                texts?.forEach { text ->
                    val urls = extractUrls(text)
                    for (url in urls) {
                        sharedItems.add(mapOf("url" to url, "title" to text.replace(url, "").trim()))
                    }
                }
            }

            Intent.ACTION_VIEW -> {
                intent.dataString?.let {
                    if (!isAuthCallbackUrl(it)) {
                        sharedItems.add(mapOf("url" to it, "title" to ""))
                    }
                }
            }
        }

        if (sharedItems.isNotEmpty()) appendPendingData(sharedItems)
    }

    private fun sanitizeIntentForFlutter(intent: Intent?) {
        if (intent == null) return
        if (intent.action == Intent.ACTION_VIEW) {
            val scheme = intent.data?.scheme.orEmpty()
            val host = intent.data?.host.orEmpty()
            if (scheme.equals("urlinbox", ignoreCase = true) && host.equals("login-callback", ignoreCase = true)) {
                return
            }
            intent.data = null
        }
    }

    private fun isAuthCallbackUrl(raw: String): Boolean {
        if (raw.contains("login-callback", ignoreCase = true)) return true
        return try {
            val uri = Uri.parse(raw)
            uri.scheme.equals("urlinbox", ignoreCase = true) &&
                uri.host.equals("login-callback", ignoreCase = true)
        } catch (_: Exception) {
            false
        }
    }

    private fun extractUrls(text: String): List<String> {
        val found = linkedSetOf<String>()
        val matcher = Patterns.WEB_URL.matcher(text)
        while (matcher.find()) {
            val raw = matcher.group().orEmpty()
            val normalized = normalizeUrlToken(raw)
            if (normalized != null) {
                found.add(normalized)
            }
        }

        // 앱별 공유 포맷에서 WEB_URL이 놓치는 케이스 보강 (특히 x.com/t.co 무스킴 URL)
        text.split(Regex("\\s+")).forEach { token ->
            val normalized = normalizeUrlToken(token)
            if (normalized != null) {
                found.add(normalized)
            }
        }

        return found.toList()
    }

    private fun normalizeUrlToken(raw: String): String? {
        val cleaned = raw
            .trim()
            .trimStart('(', '[', '{', '<', '"', '\'')
            .trimEnd(')', ']', '}', '>', '"', '\'', ',', '.', '!', '?', ';', ':')
            .replace("\u200B", "")
            .replace("\u200C", "")
            .replace("\u200D", "")
            .replace("\uFEFF", "")

        if (cleaned.isBlank()) return null

        if (cleaned.startsWith("http://", ignoreCase = true) || cleaned.startsWith("https://", ignoreCase = true)) {
            return cleaned
        }

        val isXLike = cleaned.startsWith("x.com/", ignoreCase = true) ||
            cleaned.startsWith("twitter.com/", ignoreCase = true) ||
            cleaned.startsWith("t.co/", ignoreCase = true) ||
            cleaned.startsWith("www.x.com/", ignoreCase = true) ||
            cleaned.startsWith("www.twitter.com/", ignoreCase = true)

        val isThreadsLike = cleaned.startsWith("threads.net/", ignoreCase = true) ||
            cleaned.startsWith("www.threads.net/", ignoreCase = true) ||
            cleaned.startsWith("threads.com/", ignoreCase = true) ||
            cleaned.startsWith("www.threads.com/", ignoreCase = true)

        return if (isXLike || isThreadsLike) "https://$cleaned" else null
    }

    private fun extractBestTitle(text: String, url: String, subject: String): String {
        // 1. EXTRA_SUBJECT가 있고 의미있는 제목이면 사용
        if (subject.isNotBlank() && !isGenericTitle(subject)) {
            return cleanTitle(subject)
        }

        // 2. 텍스트에서 URL을 제거하고 분석
        val textWithoutUrl = text.replace(url, "").trim()
        
        // 3. 줄바꿈으로 분리하여 첫 번째 의미있는 줄을 제목으로 사용
        //    (네이버 카페 등은 "제목\nURL" 형식으로 공유하는 경우가 많음)
        val lines = textWithoutUrl.split("\n")
            .map { it.trim() }
            .filter { it.isNotBlank() && !isGenericTitle(it) && !it.startsWith("http") }
        
        if (lines.isNotEmpty()) {
            return cleanTitle(lines.first())
        }

        // 4. 한 줄로 된 텍스트에서 URL 제거 후 사용
        val cleaned = textWithoutUrl.replace("\n", " ").trim()
        if (cleaned.isNotBlank() && !isGenericTitle(cleaned)) {
            return cleanTitle(cleaned)
        }

        // 5. subject가 있으면 그대로 사용 (generic이어도)
        if (subject.isNotBlank()) {
            return cleanTitle(subject)
        }

        return ""
    }

    private fun isGenericTitle(title: String): Boolean {
        val genericTitles = listOf(
            "네이버 카페", "naver cafe", "네이버카페",
            "네이버 블로그", "naver blog",
            "카카오톡", "kakaotalk",
            "인스타그램", "instagram",
            "페이스북", "facebook",
            "트위터", "twitter", "x",
            "유튜브", "youtube"
        )
        val lower = title.lowercase().trim()
        return genericTitles.any { lower == it || lower.startsWith("$it ") || lower.endsWith(" $it") }
    }

    private fun cleanTitle(title: String): String {
        // 공통 접미사 제거
        val suffixes = listOf(
            " - 네이버 카페", " : 네이버 카페", " | 네이버 카페",
            " - 네이버 블로그", " : 네이버 블로그", " | 네이버 블로그",
            " - YouTube", " | YouTube",
            " on Instagram", " on Twitter", " on X"
        )
        var result = title.trim()
        for (suffix in suffixes) {
            if (result.endsWith(suffix, ignoreCase = true)) {
                result = result.dropLast(suffix.length).trim()
            }
        }
        return result
    }

    private fun appendPendingData(items: List<Map<String, String>>) {
        val existing = loadPendingData().toMutableList()
        for (item in items) {
            val url = item["url"] ?: continue
            // 중복 체크 (URL 기준)
            if (existing.none { it["url"] == url }) {
                existing.add(item)
            }
        }
        savePendingData(existing)
    }

    private fun consumePendingUrls(): String {
        val data = loadPendingData()
        savePendingData(emptyList())
        val jsonArray = JSONArray()
        data.forEach { item ->
            val obj = org.json.JSONObject()
            item.forEach { (k, v) -> obj.put(k, v) }
            jsonArray.put(obj)
        }
        return jsonArray.toString()
    }

    private fun loadPendingData(): List<Map<String, String>> {
        val prefs = getSharedPreferences(prefsName, MODE_PRIVATE)
        val raw = prefs.getString(keyPendingData, "[]") ?: "[]"
        val json = JSONArray(raw)
        val items = mutableListOf<Map<String, String>>()
        for (i in 0 until json.length()) {
            val obj = json.optJSONObject(i) ?: continue
            val map = mutableMapOf<String, String>()
            val keys = obj.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                map[key] = obj.optString(key)
            }
            items.add(map)
        }
        return items
    }

    private fun savePendingData(items: List<Map<String, String>>) {
        val array = JSONArray()
        items.forEach { item ->
            val obj = org.json.JSONObject()
            item.forEach { (k, v) -> obj.put(k, v) }
            array.put(obj)
        }
        getSharedPreferences(prefsName, MODE_PRIVATE)
            .edit()
            .putString(keyPendingData, array.toString())
            .apply()
    }
}
