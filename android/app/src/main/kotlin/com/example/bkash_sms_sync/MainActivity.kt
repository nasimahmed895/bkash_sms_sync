package com.example.bkash_sms_sync

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIF_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    NotificationEventSink.register(events)
                }
                override fun onCancel(arguments: Any?) {
                    NotificationEventSink.register(null)
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIF_METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isGranted" -> result.success(isNotificationAccessEnabled())
                    "openSettings" -> {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isNotificationAccessEnabled(): Boolean {
        val flat = Settings.Secure.getString(
            contentResolver, "enabled_notification_listeners"
        ) ?: return false
        val cn = ComponentName(this, BkashNotificationListenerService::class.java)
            .flattenToString()
        return flat.contains(cn)
    }

    companion object {
        const val NOTIF_EVENT_CHANNEL = "com.example.bkash_sms_sync/bkash_notifications"
        const val NOTIF_METHOD_CHANNEL = "com.example.bkash_sms_sync/notification_permission"
    }
}
