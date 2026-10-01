package dev.ragoose.gramx

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Receives text shared into gramX. The text is held here until Dart asks for
 * it, since a share that launches the app arrives before the Dart handler is
 * registered.
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

        capture(intent)
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
    }
}
