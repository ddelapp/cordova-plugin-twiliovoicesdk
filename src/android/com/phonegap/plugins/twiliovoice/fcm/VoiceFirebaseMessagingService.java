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
        Log.d(TAG, "patrick0: " + remoteMessage.getData());
        Log.d(TAG, "patrick1: " + remoteMessage.getData().getClass().getName());
        Log.d(TAG, "patrick2: " + remoteMessage.getNotification());

        boolean isCall = remoteMessage.getData().containsKey("twi_account_sid");

        // Check if message contains a data payload.
        if (isCall) {
            Map<String, String> data = remoteMessage.getData();
            final int notificationId = (int) (System.currentTimeMillis() % Integer.MAX_VALUE);
            Voice.handleMessage(data, new MessageListener() {
                @Override
                public void onCallInvite(CallInvite callInvite) {
                    VoiceFirebaseMessagingService.this.notify(callInvite, notificationId);
                    VoiceFirebaseMessagingService.this.sendCallInviteToPlugin(callInvite, notificationId);
                }

                @Override
                public void onCancelledCallInvite(@NonNull CancelledCallInvite cancelledCallInvite) {
                    Log.e(TAG, cancelledCallInvite.getFrom());
                }
            });
        } else {
            HashMap<String, String> hashMap = new HashMap<String, String>(remoteMessage.getData());

            Log.d(TAG, "patrick3: " + hashMap.getClass().getName());

            Intent intent = new Intent(TwilioVoicePlugin.ACTION_INCOMING_SNS);
            intent.putExtra("hashmap", hashMap);
            intent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
            LocalBroadcastManager.getInstance(this).sendBroadcast(intent);
        }
    }

    private void notify(CallInvite callInvite, int notificationId) {
        String callSid = callInvite.getCallSid();
        Notification notification = null;

        Intent intent = getPackageManager().getLaunchIntentForPackage(getPackageName());
        intent.setAction(TwilioVoicePlugin.ACTION_INCOMING_CALL);
        intent.putExtra(TwilioVoicePlugin.INCOMING_CALL_NOTIFICATION_ID, notificationId);
        intent.putExtra(TwilioVoicePlugin.INCOMING_CALL_INVITE, callInvite);
        intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        PendingIntent pendingIntent =
                PendingIntent.getActivity(this, notificationId, intent, PendingIntent.FLAG_CANCEL_CURRENT);

        Bundle extras = new Bundle();
        extras.putInt(NOTIFICATION_ID_KEY, notificationId);
        extras.putString(CALL_SID_KEY, callSid);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel callInviteChannel = new NotificationChannel(VOICE_CHANNEL,
                    "Primary Voice Channel", NotificationManager.IMPORTANCE_DEFAULT);
            callInviteChannel.setLightColor(Color.RED);
            callInviteChannel.setLockscreenVisibility(Notification.VISIBILITY_PRIVATE);
            notificationManager.createNotificationChannel(callInviteChannel);

            notification = buildNotification(callInvite.getFrom() + " is calling", pendingIntent, extras);
            notificationManager.notify(notificationId, notification);
        } else {
            int iconIdentifier = getResources().getIdentifier("icon", "mipmap", getPackageName());
            int incomingCallAppNameId = (int) getResources().getIdentifier("incoming_call_app_name", "string", getPackageName());
            String contentTitle = getString(incomingCallAppNameId);

            if (contentTitle == null) {
                contentTitle = "Incoming Call";
            }
            final String from = callInvite.getFrom() + " is calling";

            NotificationCompat.Builder notificationBuilder =
                    new NotificationCompat.Builder(this)
                            .setSmallIcon(iconIdentifier)
                            .setContentTitle(contentTitle)
                            .setContentText(from)
                            .setAutoCancel(true)
                            .setExtras(extras)
                            .setContentIntent(pendingIntent)
                            .setGroup("voice_app_notification")
                            .setColor(Color.rgb(225, 0, 0));

            notificationManager.notify(notificationId, notificationBuilder.build());

        }
    }

    /**
     * Build a notification.
     *
     * @param text          the text of the notification
     * @param pendingIntent the body, pending intent for the notification
     * @param extras        extras passed with the notification
     * @return the builder
     */
    @TargetApi(Build.VERSION_CODES.O)
    public Notification buildNotification(String text, PendingIntent pendingIntent, Bundle extras) {
        int iconIdentifier = getResources().getIdentifier("ic_launcher", "mipmap", getPackageName());
        if (iconIdentifier == 0) {
            iconIdentifier = getResources().getIdentifier("ic_launcher", "drawable", getPackageName());
        }
        int incomingCallAppNameId = getResources().getIdentifier("incoming_call_app_name", "string", getPackageName());
        //String contentTitle = getString(incomingCallAppNameId);   -- this crashes for some reason, default to empty string.
        String contentTitle = "";
        return new Notification.Builder(getApplicationContext(), VOICE_CHANNEL)
                .setSmallIcon(iconIdentifier)
                .setContentTitle(contentTitle)
                .setContentText(text)
                .setContentIntent(pendingIntent)
                .setExtras(extras)
                .setAutoCancel(true)
                .build();
    }

    /*
     * Send the IncomingCallMessage to the Plugin
     */
    private void sendCallInviteToPlugin(CallInvite incomingCallMessage, int notificationId) {
        Intent intent = new Intent(TwilioVoicePlugin.ACTION_INCOMING_CALL);
        intent.putExtra(TwilioVoicePlugin.INCOMING_CALL_INVITE, incomingCallMessage);
        intent.putExtra(TwilioVoicePlugin.INCOMING_CALL_NOTIFICATION_ID, notificationId);
        intent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
        LocalBroadcastManager.getInstance(this).sendBroadcast(intent);
    }

}
