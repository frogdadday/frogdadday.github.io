package com.frogdadday.cosmicspinner

// Block One //////////////////////////////////////////////////////////////
import android.media.AudioManager
import android.media.AudioAttributes
import android.media.ToneGenerator
import android.content.Intent
import android.os.Bundle
import android.speech.tts.TextToSpeech
import androidx.core.net.toUri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.concurrent.Executors

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    private val storageExecutor = Executors.newSingleThreadExecutor()
    private var speech: TextToSpeech? = null
    private var speechReady = false
    // ToneGenerator volume is 0–100 on the user's normal media stream.
    private val kickTone = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
    private val tickTone = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
    private val revealTone = ToneGenerator(AudioManager.STREAM_MUSIC, 100)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        speech = TextToSpeech(this, this)
    }

    override fun onInit(status: Int) {
        val languageStatus = speech?.setLanguage(Locale.US) ?: TextToSpeech.ERROR
        speechReady = status == TextToSpeech.SUCCESS &&
            languageStatus != TextToSpeech.LANG_MISSING_DATA &&
            languageStatus != TextToSpeech.LANG_NOT_SUPPORTED
        if (speechReady) {
            speech?.setPitch(1.08f)
            speech?.setSpeechRate(0.92f)
            speech?.setAudioAttributes(
                AudioAttributes.Builder()
                    // This follows the phone's ordinary media-volume slider.
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            )
        }
    }

    // Block Two //////////////////////////////////////////////////////////
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cosmic_spinner/storage")
            .setMethodCallHandler { call, result ->
                // Disk work is serialized off the UI thread; report failures to Dart.
                storageExecutor.execute {
                    try {
                        val preferences = getSharedPreferences("cosmic_spinner", MODE_PRIVATE)
                        when (call.method) {
                            "read" -> {
                                val raw = preferences.getString("app_state", null)
                                runOnUiThread { result.success(raw) }
                            }
                            "write" -> {
                                val raw = call.arguments as? String
                                    ?: throw IllegalArgumentException("Expected state JSON")
                                val committed = preferences.edit().putString("app_state", raw).commit()
                                runOnUiThread {
                                    if (committed) result.success(null)
                                    else result.error("STORAGE_WRITE", "Unable to save state", null)
                                }
                            }
                            else -> runOnUiThread { result.notImplemented() }
                        }
                    } catch (error: Exception) {
                        runOnUiThread { result.error("STORAGE", "Storage unavailable", null) }
                    }
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cosmic_spinner/sound")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "kick" -> {
                        // A short impact makes the kick audible even while a device
                        // starts its text-to-speech engine.
                        kickTone.startTone(ToneGenerator.TONE_PROP_BEEP2, 95)
                        if (speechReady) {
                            val options = Bundle().apply {
                                // Use the full media-volume range selected by the user.
                                putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, 1.0f)
                            }
                            val spoken = speech?.speak(
                                "Hi-ya!",
                                TextToSpeech.QUEUE_FLUSH,
                                options,
                                "frog-kick"
                            )
                            if (spoken != TextToSpeech.SUCCESS) {
                                kickTone.startTone(ToneGenerator.TONE_PROP_BEEP2, 240)
                            }
                        } else {
                            kickTone.startTone(ToneGenerator.TONE_PROP_BEEP2, 240)
                        }
                        result.success(null)
                    }
                    "tick" -> {
                        tickTone.startTone(ToneGenerator.TONE_PROP_BEEP2, 52)
                        result.success(null)
                    }
                    "reveal" -> {
                        revealTone.startTone(ToneGenerator.TONE_PROP_ACK, 520)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cosmic_spinner/link")
            .setMethodCallHandler { call, result ->
                val url = when (call.method) {
                    "openSupport" -> "https://buymeacoffee.com/frogdadday"
                    "openPrivacyPolicy" -> "https://frogdadday.github.io/Cosmic-Spinner-Privacy-Policy/"
                    else -> {
                        result.notImplemented()
                        return@setMethodCallHandler
                    }
                }
                try {
                    val intent = Intent(
                        Intent.ACTION_VIEW,
                        url.toUri()
                    )
                    startActivity(intent)
                    result.success(true)
                } catch (_: Exception) {
                    result.success(false)
                }
            }
    }

    override fun onDestroy() {
        storageExecutor.shutdown()
        speech?.stop()
        speech?.shutdown()
        kickTone.release()
        tickTone.release()
        revealTone.release()
        super.onDestroy()
    }
}
