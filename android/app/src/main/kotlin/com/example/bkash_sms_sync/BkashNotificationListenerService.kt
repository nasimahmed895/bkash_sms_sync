package com.example.bkash_sms_sync

import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.plugin.common.EventChannel

class BkashNotificationListenerService : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName !in BKASH_PACKAGES) return
        val extras = sbn.notification?.extras ?: return
        val title = extras.getString("android.title").orEmpty()
        val bigText = extras.getCharSequence("android.bigText")?.toString().orEmpty()
        val text = extras.getCharSequence("android.text")?.toString().orEmpty()
        val body = if (bigText.isNotBlank()) bigText else text
        if (body.isBlank()) return
        NotificationEventSink.send("$title $body".trim())
    }

    companion object {
        val BKASH_PACKAGES = setOf(
            "com.bKash.customerapp",
            "com.bkash.merchantapp",
            "com.bkash.agent",
        )
    }
}

object NotificationEventSink {
    @Volatile private var sink: EventChannel.EventSink? = null

    fun register(s: EventChannel.EventSink?) {
        sink = s
    }

    fun send(text: String) {
        Handler(Looper.getMainLooper()).post { sink?.success(text) }
    }
}
