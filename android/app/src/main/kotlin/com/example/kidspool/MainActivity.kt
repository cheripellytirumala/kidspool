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
                    // Places search: its own key if set, else the map key.
                    "apiKey" -> result.success(metaKey("kidpool.places.API_KEY") ?: mapsKey())
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasMapsKey(): Boolean = mapsKey() != null

    private fun mapsKey(): String? = metaKey("com.google.android.geo.API_KEY")

    private fun metaKey(name: String): String? {
        val info = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
        return info.metaData?.getString(name)?.takeIf { it.isNotBlank() }
    }
}
