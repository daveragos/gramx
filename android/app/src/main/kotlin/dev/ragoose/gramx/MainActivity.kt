package dev.ragoose.gramx

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Receives text shared into gramX. The text is held here until Dart asks for
 * it, since a share that launches the app arrives before the Dart handler is
 * registered.
 *
 * Also hands links to the Telegram app, which gramX's own claim on t.me
 * links would otherwise catch.
 */
class MainActivity : FlutterActivity() {
    private var pendingSharedText: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Cleared once taken, so a resume cannot open it twice.
                    "takeSharedText" -> {
                        result.success(pendingSharedText)
                        pendingSharedText = null
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TELEGRAM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "open" -> result.success(openInTelegram(call.arguments as String))
                    else -> result.notImplemented()
                }
            }

        capture(intent)
    }

    /** Opens [link] in the first installed Telegram app, if any. */
    private fun openInTelegram(link: String): Boolean {
        for (pkg in TELEGRAM_PACKAGES) {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(link)).setPackage(pkg)
            try {
                startActivity(intent)
                return true
            } catch (_: ActivityNotFoundException) {
                // Not installed; try the next build.
            }
        }
        return false
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        capture(intent)
    }

    private fun capture(intent: Intent?) {
        if (intent == null || intent.action != Intent.ACTION_SEND) return
        if (intent.type != "text/plain") return

        val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return
        if (text.isBlank()) return

        pendingSharedText = text

        // Cleared so a configuration change does not replay the share.
        intent.action = null
    }

    companion object {
        private const val CHANNEL = "dev.ragoose.gramx/share"
        private const val TELEGRAM_CHANNEL = "dev.ragoose.gramx/telegram"

        /** Telegram's Play, direct-download and beta builds. */
        private val TELEGRAM_PACKAGES = listOf(
            "org.telegram.messenger",
            "org.telegram.messenger.web",
            "org.telegram.messenger.beta",
        )
    }
}
