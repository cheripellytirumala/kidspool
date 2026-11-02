package com.example.kidspool

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Lets Dart skip the map when no Google Maps key is configured.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kidpool/maps")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isConfigured" -> result.success(hasMapsKey())
                    "apiKey" -> result.success(mapsKey())
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasMapsKey(): Boolean = mapsKey() != null

    private fun mapsKey(): String? {
        val info = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
        return info.metaData?.getString("com.google.android.geo.API_KEY")?.takeIf { it.isNotBlank() }
    }
}
