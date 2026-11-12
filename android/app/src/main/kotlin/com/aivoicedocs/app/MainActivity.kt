package com.aivoicedocs.app

import android.os.Bundle
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(
            messenger,
            "com.aivoicedocs.app/pin_hash",
            StandardMethodCodec.INSTANCE,
            messenger.makeBackgroundTaskQueue(),
        ).setMethodCallHandler { call, result ->
            if (call.method != "derive" || Build.VERSION.SDK_INT < 26) {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val pin = call.argument<String>("pin")
            val salt = call.argument<ByteArray>("salt")
            val iterations = call.argument<Int>("iterations")
            if (pin == null || salt == null || salt.isEmpty() ||
                iterations == null || iterations !in 1..2000000) {
                result.error("invalid_arguments", "Invalid PIN derivation parameters.", null)
                return@setMethodCallHandler
            }
            val password = pin.toCharArray()
            val spec = PBEKeySpec(password, salt, iterations, 256)
            password.fill('\u0000')
            try {
                val key = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
                    .generateSecret(spec).encoded
                result.success(key)
            } catch (_: Exception) {
                result.error("derivation_failed", "PIN verification could not complete.", null)
            } finally {
                spec.clearPassword()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}
