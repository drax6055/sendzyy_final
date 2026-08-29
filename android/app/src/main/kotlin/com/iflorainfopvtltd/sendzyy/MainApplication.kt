package com.iflorainfopvtltd.sendzyy

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build

/**
 * Custom Application class.
 *
 * Creates the FCM notification channel at the native level during app startup,
 * before Flutter initializes. This guarantees that even when the app is
 * terminated/killed, Android can display FCM notifications on the correct channel
 * without needing the Flutter Dart isolate to be running.
 *
 * This is required for reliable notification delivery on all Android OEMs
 * (Samsung, Xiaomi, OnePlus, etc.) that aggressively kill background processes.
 */
class MainApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "sendzyy_notifications"
            val channelName = "Sendzyy Notifications"
            val channelDescription = "All Sendzyy platform notifications including new messages, campaign results, and alerts"
            val importance = NotificationManager.IMPORTANCE_HIGH

            val channel = NotificationChannel(channelId, channelName, importance).apply {
                description = channelDescription
                enableVibration(true)
                enableLights(true)
                setShowBadge(true)
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager?.createNotificationChannel(channel)
        }
    }
}
