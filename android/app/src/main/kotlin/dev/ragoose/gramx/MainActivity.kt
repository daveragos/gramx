package dev.ragoose.gramx

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Receives text shared into gramX.
 *
 * Pull rather than push: the shared text is parked here and Dart asks for it,
 * at startup and on every resume. Pushing would mean invoking a method on an
 * engine whose Dart handler may not be registered yet — a share that launches
 * the app is exactly that case — and the two paths would then have to agree on
 * which of them delivered it.
 *
 * Only `text/plain`. The composer takes photos and videos from the gallery
 * picker, and accepting them here as well would be two ways into one screen
 * with different rules; the manifest's intent filter says the same thing.
 */
class MainActivity : FlutterActivity() {
    private var pendingSharedText: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Taken, not read: whoever asks gets it once, so a resume
                    // right after the composer opened cannot open a second one
                    // with the same text in it.
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

        // Consumed, so a configuration change — a rotation, a theme switch —
        // does not replay the same share on the way back.
        intent.action = null
    }

    companion object {
        private const val CHANNEL = "dev.ragoose.gramx/share"
    }
}
