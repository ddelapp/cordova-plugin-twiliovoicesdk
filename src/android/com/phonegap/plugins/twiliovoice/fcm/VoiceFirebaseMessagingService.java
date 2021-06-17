package com.phonegap.plugins.twiliovoice.fcm;

import android.annotation.TargetApi;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
import android.os.PowerManager;
import android.net.Uri;
import android.service.notification.StatusBarNotification;
import android.support.annotation.NonNull;
import android.support.v4.app.NotificationCompat;
import android.support.v4.content.LocalBroadcastManager;
import android.util.Log;

import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;
import com.twilio.voice.CallInvite;
import com.twilio.voice.CancelledCallInvite;
import com.twilio.voice.MessageListener;
import com.twilio.voice.Voice;

import static android.R.attr.data;

import com.phonegap.plugins.twiliovoice.SoundPoolManager;
import com.phonegap.plugins.twiliovoice.TwilioVoicePlugin;

import java.util.Map;
import java.util.HashMap;

public class VoiceFirebaseMessagingService extends FirebaseMessagingService {
    private static final String TAG = "VoiceFCMService";
    private static final String NOTIFICATION_ID_KEY = "NOTIFICATION_ID";
    private static final String CALL_SID_KEY = "CALL_SID";
    private static final String VOICE_CHANNEL = "default";
    private NotificationManager notificationManager;

    @Override
    public void onCreate() {
        super.onCreate();
        notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
    }

    /**
     * Called when message is received.
     *
     * @param remoteMessage Object representing the message received from Firebase Cloud Messaging.
     */
    @Override
    public void onMessageReceived(RemoteMessage remoteMessage) {
        Log.d(TAG, "onMessageReceived: " + remoteMessage.getData());
        Log.d(TAG, "onMessageReceived: " + remoteMessage.getData().getClass().getName());
        Log.d(TAG, "onMessageReceived: " + remoteMessage.getNotification());

        boolean isCall = remoteMessage.getData().containsKey("twi_account_sid");

        final int notificationId = (int) (System.currentTimeMillis() % Integer.MAX_VALUE);

        // Check if message contains a data payload.
        if (isCall) {
            Map<String, String> data = remoteMessage.getData();
            Voice.handleMessage(data, new MessageListener() {
                @Override
                public void onCallInvite(CallInvite callInvite) {
                    VoiceFirebaseMessagingService.this.callHandler(callInvite, notificationId);
                    VoiceFirebaseMessagingService.this.sendCallInviteToPlugin(callInvite, notificationId);
                }

                @Override
                public void onCancelledCallInvite(@NonNull CancelledCallInvite cancelledCallInvite) {
                    VoiceFirebaseMessagingService.this.sendCallInviteCancelToPlugin();
                }
            });
        } else {
            // Handle SNS from API here...

            // Serialize the payload coming from SNS
            HashMap<String, String> hashMap = new HashMap<String, String>(remoteMessage.getData());

            Intent intent = new Intent(TwilioVoicePlugin.ACTION_INCOMING_SNS);
            intent.putExtra("hashmap", hashMap);
            intent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);

            PendingIntent pendingIntent = PendingIntent.getActivity(this, notificationId, intent, PendingIntent.FLAG_CANCEL_CURRENT);
            Bundle extras = new Bundle();

            String title = hashMap.get("title");
            String body = hashMap.get("body");

            notify(notificationId, title, body, pendingIntent, extras);
            LocalBroadcastManager.getInstance(this).sendBroadcast(intent);
        }
    }

    private void callHandler(CallInvite callInvite, int notificationId) {
        // Build Intent
        Intent intent = getPackageManager().getLaunchIntentForPackage(getPackageName());
        intent.setAction(TwilioVoicePlugin.ACTION_INCOMING_CALL);
        intent.putExtra(TwilioVoicePlugin.INCOMING_CALL_NOTIFICATION_ID, notificationId);
        intent.putExtra(TwilioVoicePlugin.INCOMING_CALL_INVITE, callInvite);
        intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);

        // Build Pending Intent
        PendingIntent pendingIntent = PendingIntent.getActivity(this, notificationId, intent, PendingIntent.FLAG_CANCEL_CURRENT);

        // Build Bundle
        Bundle extras = new Bundle();
        extras.putInt(NOTIFICATION_ID_KEY, notificationId);
        extras.putString(CALL_SID_KEY, callInvite.getCallSid());

        // Build notification title & body
        String title = "Incoming call from: ";
        String body = callInvite.getFrom().substring(2);
        body = body.replaceFirst("(\\d{3})(\\d{3})(\\d+)", "($1) $2-$3"); // Format 10-digit number.

        notify(notificationId, title, body, pendingIntent, extras);
    }

    private void notify(int notificationId, String title, String body, PendingIntent pendingIntent, Bundle extras) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(VOICE_CHANNEL, "Primary Channel", NotificationManager.IMPORTANCE_DEFAULT);
            channel.setLightColor(Color.RED);
            channel.setLockscreenVisibility(Notification.VISIBILITY_PRIVATE);
            notificationManager.createNotificationChannel(channel);
        }

        int iconIdentifier = getResources().getIdentifier("ic_launcher", "mipmap", getPackageName());
        if (iconIdentifier == 0) {
            iconIdentifier = getResources().getIdentifier("ic_launcher", "drawable", getPackageName());
        }

        NotificationCompat.Builder notification = new NotificationCompat.Builder(this, VOICE_CHANNEL)
                        .setSmallIcon(iconIdentifier)
                        .setContentTitle(title)
                        .setContentText(body)
                        .setContentIntent(pendingIntent)
                        .setAutoCancel(true)
                        .setExtras(extras)
                        .setAutoCancel(true);

        notificationManager.notify(notificationId, notification.build());
    }

    private void sendCallInviteToPlugin(CallInvite incomingCallMessage, int notificationId) {
        Intent intent = new Intent(TwilioVoicePlugin.ACTION_INCOMING_CALL);
        intent.putExtra(TwilioVoicePlugin.INCOMING_CALL_INVITE, incomingCallMessage);
        intent.putExtra(TwilioVoicePlugin.INCOMING_CALL_NOTIFICATION_ID, notificationId);
        intent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
        LocalBroadcastManager.getInstance(this).sendBroadcast(intent);
    }

    private void sendCallInviteCancelToPlugin() {
        Intent intent = new Intent(TwilioVoicePlugin.INCOMING_CALL_INVITE_CANCEL);
        intent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
        LocalBroadcastManager.getInstance(this).sendBroadcast(intent);
    }

}