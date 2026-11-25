package com.pondok.kassantri

import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

class MainActivity : FlutterFragmentActivity() {
    private val securityChannelName = "com.pondok.kassantri/security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, securityChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecureScreen" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        runOnUiThread {
                            if (enabled) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            }
                        }
                        result.success(true)
                    }
                    "checkDeviceIntegrity" -> {
                        result.success(collectDeviceIntegritySignals())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun collectDeviceIntegritySignals(): Map<String, Any> {
        val isDebuggable = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        val hasTestKeys = Build.TAGS?.contains("test-keys") == true

        val rootPaths = listOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su",
            "/su/bin/su"
        )
        val hasRootBinary = rootPaths.any { path ->
            try {
                File(path).exists()
            } catch (_: Throwable) {
                false
            }
        }

        val isEmulator = (Build.FINGERPRINT.startsWith("generic")
                || Build.FINGERPRINT.startsWith("unknown")
                || Build.MODEL.contains("google_sdk")
                || Build.MODEL.contains("Emulator")
                || Build.MODEL.contains("Android SDK built for x86")
                || Build.MANUFACTURER.contains("Genymotion")
                || (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic")))

        val certSha256 = getSigningCertSha256()

        return mapOf(
            "isDebuggable" to isDebuggable,
            "hasTestKeys" to hasTestKeys,
            "hasRootBinary" to hasRootBinary,
            "isEmulator" to isEmulator,
            "signingCertSha256" to certSha256
        )
    }

    @Suppress("DEPRECATION")
    private fun getSigningCertSha256(): String {
        return try {
            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val pkgInfo = packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNING_CERTIFICATES
                )
                pkgInfo.signingInfo?.apkContentsSigners
            } else {
                val pkgInfo = packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNATURES
                )
                pkgInfo.signatures
            }
            val firstCert = signatures?.firstOrNull()?.toByteArray() ?: return ""
            val digest = MessageDigest.getInstance("SHA-256").digest(firstCert)
            digest.joinToString("") { "%02x".format(it) }
        } catch (_: Throwable) {
            ""
        }
    }
}

