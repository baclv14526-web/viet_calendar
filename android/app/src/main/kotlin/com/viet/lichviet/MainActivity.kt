package com.viet.lichviet

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.viet.lichviet/notification_service"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "startForegroundService") {
                try {
                    NotificationForegroundService.startService(this)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("SERVICE_ERROR", "Failed to start foreground service", e.message)
                }
            } else if (call.method == "stopForegroundService") {
                try {
                    NotificationForegroundService.stopService(this)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("SERVICE_ERROR", "Failed to stop foreground service", e.message)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
