package com.rafel.rafel

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat

/**
 * Plays the full adhan through a foreground media service. A notification
 * channel sound is deliberately not used: Android stops channel sounds after a
 * few seconds, while the adhan is minutes long.
 */
class AdhanService : Service() {
    companion object {
        private const val CHANNEL_ID = "rafel_adhan_playback"
        private const val NOTIFICATION_ID = 900001
        private const val ACTION_START = "com.rafel.rafel.action.ADHAN_START"
        private const val ACTION_STOP = "com.rafel.rafel.action.ADHAN_STOP"
        private const val EXTRA_PRAYER = "prayer"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_BODY = "body"

        fun start(context: Context, alarm: AdhanAlarm) {
            val intent = Intent(context, AdhanService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_PRAYER, alarm.prayer)
                putExtra(EXTRA_TITLE, alarm.title)
                putExtra(EXTRA_BODY, alarm.body)
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, AdhanService::class.java))
        }
    }

    private var player: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var audioManager: AudioManager? = null
    private var focusRequest: AudioFocusRequest? = null
    private var stopping = false

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopPlayback()
                return START_NOT_STICKY
            }
            ACTION_START -> {
                val prayer = intent.getStringExtra(EXTRA_PRAYER) ?: "Prayer"
                val title = intent.getStringExtra(EXTRA_TITLE) ?: "$prayer adhan"
                val body = intent.getStringExtra(EXTRA_BODY) ?: ""
                startForegroundWithType(title, body)
                playAdhan()
            }
        }
        return START_NOT_STICKY
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Adhan playback",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shown while the full adhan is playing."
            setSound(null, null)
            enableVibration(false)
            setShowBadge(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
    }

    private fun notification(title: String, body: String): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?.apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
        val contentIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val stopIntent = Intent(this, AdhanService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPending = PendingIntent.getService(
            this,
            1,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_rafel)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setShowWhen(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .addAction(R.drawable.ic_stat_rafel, "Stop adhan", stopPending)
            .build()
    }

    private fun startForegroundWithType(title: String, body: String) {
        val note = notification(title, body)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceCompat.startForeground(
                this,
                NOTIFICATION_ID,
                note,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(NOTIFICATION_ID, note)
        }
    }

    private fun playAdhan() {
        releasePlayer()
        stopping = false
        val power = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = power.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "rafel:full-adhan",
        ).apply {
            setReferenceCounted(false)
            acquire(16 * 60 * 1000L)
        }

        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()

        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(attributes)
                .setOnAudioFocusChangeListener { }
                .build()
            focusRequest = request
            audioManager?.requestAudioFocus(request)
        } else {
            @Suppress("DEPRECATION")
            audioManager?.requestAudioFocus(
                null,
                AudioManager.STREAM_ALARM,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT,
            )
        }

        try {
            val descriptor = resources.openRawResourceFd(R.raw.adhan)
                ?: throw IllegalStateException("adhan resource missing")
            val media = MediaPlayer().apply {
                setAudioAttributes(attributes)
                setWakeMode(applicationContext, PowerManager.PARTIAL_WAKE_LOCK)
                descriptor.use {
                    setDataSource(it.fileDescriptor, it.startOffset, it.length)
                }
                setOnCompletionListener { stopPlayback() }
                setOnErrorListener { _, _, _ ->
                    stopPlayback()
                    true
                }
                prepare()
                start()
            }
            player = media
        } catch (_: Exception) {
            stopPlayback()
        }
    }

    private fun releasePlayer() {
        player?.let {
            try {
                it.stop()
            } catch (_: IllegalStateException) {
                // Already stopped.
            }
            it.release()
        }
        player = null
    }

    private fun stopPlayback() {
        if (stopping) return
        stopping = true
        releasePlayer()
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { audioManager?.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            audioManager?.abandonAudioFocus(null)
        }
        focusRequest = null
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        releasePlayer()
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
