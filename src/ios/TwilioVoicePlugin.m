//
//  TwilioVoicePlugin.m
//  TwilioVoiceExample
//
//  Created by Jeffrey Linwood on 3/11/17.
//  Updated by Adam Rivera 02/24/2018.
//  Updated by Devin DeLapp 11/15/2019.
//
//  Based on https://github.com/twilio/voice-callkit-quickstart-objc
//

#import "TwilioVoicePlugin.h"

@import AVFoundation;
@import CallKit;
@import PushKit;
@import TwilioVoice;
@import UserNotifications;

static NSString *const kTwimlParamTo = @"To";
static NSString *const kTwimlParamFrom = @"From";

@interface TwilioVoicePlugin () <PKPushRegistryDelegate, TVONotificationDelegate, TVOCallDelegate, CXProviderDelegate>

// Callback for the Javascript plugin delegate, used for events
@property(nonatomic, strong) NSString *callback;

// Push registry for APNS VOIP
@property (nonatomic, strong) PKPushRegistry *voipPushRegistry;
@property (nonatomic, strong) void(^incomingPushCompletionCallback)(void);

// Current call (can be nil)
@property (nonatomic, strong) TVOCall *call;
@property (nonatomic, strong) NSUUID *callUUID;

// Current call invite (can be nil)
@property (nonatomic, strong) TVOCallInvite *callInvite;

// Device Token from Apple Push Notification Service for VOIP
@property (nonatomic, strong) NSString *pushDeviceToken;

// Access Token from Twilio
@property (nonatomic, strong) NSString *accessToken;

// Outgoing call params
@property (nonatomic, strong) NSDictionary *outgoingCallParams;

// Configure whether or not to mask the incoming phone number for privacy via the plist
// This is a variable from plugin installation (MASK_INCOMING_PHONE_NUMBER)
@property (nonatomic, assign) BOOL maskIncomingPhoneNumber;

// Call Kit member variables
@property (nonatomic, strong) CXProvider *callKitProvider;
@property (nonatomic, strong) CXCallController *callKitCallController;
@property (nonatomic, strong) void(^callKitCompletionCallback)(BOOL);

// Audio Properties
@property (nonatomic, strong) AVAudioPlayer *ringtonePlayer;
@property (nonatomic, strong) TVODefaultAudioDevice *audioDevice;

@end

@implementation TwilioVoicePlugin

- (void) pluginInitialize {
    [super pluginInitialize];

    NSLog(@"Initializing TwilioVoicePlugin");
    NSString *debugTwilioPreference = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"TVPEnableDebugging"] uppercaseString];
    if ([debugTwilioPreference isEqualToString:@"YES"] || [debugTwilioPreference isEqualToString:@"TRUE"]) {
        [TwilioVoice setLogLevel:TVOLogLevelDebug];
    } else {
        [TwilioVoice setLogLevel:TVOLogLevelOff];
    }

    self.audioDevice = [TVODefaultAudioDevice audioDevice];
    TwilioVoice.audioDevice = self.audioDevice;

    // read in MASK_INCOMING_PHONE_NUMBER preference
    NSString *enableMaskIncomingPhoneNumberPreference = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"TVPMaskIncomingPhoneNumber"] uppercaseString];
    if ([enableMaskIncomingPhoneNumberPreference isEqualToString:@"YES"] || [enableMaskIncomingPhoneNumberPreference isEqualToString:@"TRUE"]) {
        self.maskIncomingPhoneNumber = YES;
    } else {
        self.maskIncomingPhoneNumber = NO;
    }


    //ask for notification support
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    UNAuthorizationOptions options = UNAuthorizationOptionAlert + UNAuthorizationOptionSound;

    [center requestAuthorizationWithOptions:options
                          completionHandler:^(BOOL granted, NSError * _Nullable error) {
                              if (!granted) {
                                  NSLog(@"Notifications not granted");
                              }
                          }];

    // initialize ringtone player
    NSURL *ringtoneURL = [[NSBundle mainBundle] URLForResource:@"ringing.wav" withExtension:nil];
    if (ringtoneURL) {
        NSError *error = nil;
        self.ringtonePlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:ringtoneURL error:&error];
        if (error) {
            NSLog(@"Error initializing ring tone player: %@",[error localizedDescription]);
        } else {
            //looping ring
            self.ringtonePlayer.numberOfLoops = -1;
            [self.ringtonePlayer prepareToPlay];
        }
    }
}

- (void) initialize:(CDVInvokedUrlCommand*)command  {
    NSLog(@"TwilioVoicePlugin - Initialize");

    // retain this command as the callback to use for raising Twilio events
    self.callback = command.callbackId;

    // initialize VOIP Push Registry
    self.voipPushRegistry = [[PKPushRegistry alloc] initWithQueue:dispatch_get_main_queue()];
    self.voipPushRegistry.delegate = self;
    self.voipPushRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];

    // initialize CallKit (based on Twilio ObjCVoiceCallKitQuickstart)
    NSString *incomingCallAppName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"TVPIncomingCallAppName"];
    CXProviderConfiguration *configuration = [[CXProviderConfiguration alloc] initWithLocalizedName:incomingCallAppName];

    configuration.maximumCallGroups = 1;
    configuration.maximumCallsPerCallGroup = 1;
    UIImage *callkitIcon = [UIImage imageNamed:@"CallKitIcon"];
    configuration.iconTemplateImageData = UIImagePNGRepresentation(callkitIcon);
    configuration.ringtoneSound = @"traditionalring.mp3";

    self.callKitProvider = [[CXProvider alloc] initWithConfiguration:configuration];
    [self.callKitProvider setDelegate:self queue:nil];

    self.callKitCallController = [[CXCallController alloc] init];

    [self javascriptCallback:@"onclientinitialized"];

}

- (void) unregister:(CDVInvokedUrlCommand*)command  {
    NSLog(@"Unregister access token");

    // Optional arguments should be brought in to unregister: accessToken and deviceToken.
    // These should superceed the self.accessToken and self.pushDeviceToken.
    // This is because in the event that the access token has expired, you cannot
    // Unregister the device token, so in the event that the pushRegistry calls
    // ondidinvalidatepushtoken, the unregister should be called, supplying a new accessToken.

    // retain this command as the callback to use for raising Twilio events
    self.callback = command.callbackId;

    NSString* accessToken = self.accessToken;

    if(command.arguments.count > 0) {
        NSDictionary* args = command.arguments[0];
        NSLog(@"Params for unregister %@", args);
        if([args objectForKey:@"accessToken"] == nil) {
            accessToken = args[@"accessToken"];
        }
    }

    // If the access token or device token are empty, then the registration never took place.
    // There is no need to unregister the client.
    if(accessToken == nil || self.pushDeviceToken == nil) {
        NSLog(@"TwilioVoicePlugin - No unregistration required.");
        return;
    }


    [TwilioVoice unregisterWithAccessToken: accessToken
                               deviceToken: self.pushDeviceToken
                                completion: ^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error unregistering Voice Client for VOIP Push: %@", [error localizedDescription]);
        } else {
            NSLog(@"Unregistered Voice Client for VOIP Push");
        }
        [self javascriptCallback:@"onunregistered"];
    }];

    // Deactivate any calls.
    [self.callKitProvider invalidate];
}

- (void) call:(CDVInvokedUrlCommand*)command {
    if ([command.arguments count] > 0) {
        self.accessToken = command.arguments[0];
        if ([command.arguments count] > 1) {
            self.outgoingCallParams = command.arguments[1];
        }

        if (self.call && self.call.state == TVOCallStateConnected) {
            [self performEndCallActionWithUUID:self.call.uuid];
        } else {
            self.callUUID = [NSUUID UUID];
            NSString *incomingCallAppName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"TVPIncomingCallAppName"];
            [self performStartCallActionWithUUID:self.callUUID handle:incomingCallAppName withName: self.outgoingCallParams[@"displayName"]];
        }
    }
}

- (void) sendDigits:(CDVInvokedUrlCommand*)command {
    if ([command.arguments count] > 0) {
        [self.call sendDigits:command.arguments[0]];
    }
}

- (void) disconnect:(CDVInvokedUrlCommand*)command {
    if (self.callInvite && self.call && self.call.state == TVOCallStateRinging) {
        [self.callInvite reject];
        self.callInvite = nil;
    } else if (self.call) {
        [self.call disconnect];
    }
}

- (void) acceptCallInvite:(CDVInvokedUrlCommand*)command {
    if (self.callInvite) {
        [self.callInvite acceptWithDelegate:self];
    }
    if ([self.ringtonePlayer isPlaying]) {
        //pause ringtone
        [self.ringtonePlayer pause];
    }
}

- (void) rejectCallInvite: (CDVInvokedUrlCommand*)command {
    if (self.callInvite) {
        [self.callInvite reject];
    }
    if ([self.ringtonePlayer isPlaying]) {
        //pause ringtone
        [self.ringtonePlayer pause];
    }
}

#pragma mark - AVAudioSession
- (void)toggleAudioRoute:(BOOL)toSpeaker {
    // The mode set by the Voice SDK is "VoiceChat" so the default audio route is the built-in receiver. Use port override to switch the route.
    TVODefaultAudioDevice *audioDevice = self.audioDevice != nil ? self.audioDevice : (TVODefaultAudioDevice *)TwilioVoice.audioDevice;
    audioDevice.block =  ^ {
        // We will execute `kDefaultAVAudioSessionConfigurationBlock` first.
        kTVODefaultAVAudioSessionConfigurationBlock();

        // Overwrite the audio route
        AVAudioSession *session = [AVAudioSession sharedInstance];
        NSError *error = nil;
        if (toSpeaker) {
            if (![session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error]) {
                NSLog(@"Unable to reroute audio: %@", [error localizedDescription]);
            }
        } else {
            if (![session overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:&error]) {
                NSLog(@"Unable to reroute audio: %@", [error localizedDescription]);
            }
        }
    };
    audioDevice.block();
}

-(void)setSpeaker:(CDVInvokedUrlCommand*)command {
    NSString *mode = [command.arguments objectAtIndex:0];
    if([mode isEqual: @"on"]) {
        [self toggleAudioRoute:YES];
    }
    else {
        [self toggleAudioRoute:NO];
    }
}

- (void) muteCall: (CDVInvokedUrlCommand*)command {
    if (self.call) {
        self.call.muted = YES;
    }
}

- (void) unmuteCall: (CDVInvokedUrlCommand*)command {
    if (self.call) {
        self.call.muted = NO;
    }
}

- (void) isCallMuted: (CDVInvokedUrlCommand*)command {
    if (self.call) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:self.call.muted];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    } else {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:NO];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }
}

- (void) updateCall: (CDVInvokedUrlCommand*)command {

    NSDictionary *params = command.arguments[0];

    NSLog(@"Update Call %@ %@", self.callUUID, params);

    CXCallUpdate *callUpdate = [[CXCallUpdate alloc] init];
    callUpdate.remoteHandle = [[CXHandle alloc] initWithType:CXHandleTypePhoneNumber value:@"+19511112222"];;

    callUpdate.localizedCallerName = params[@"localizedCallerName"];
    callUpdate.supportsDTMF = [params[@"supportsDtmf"] isEqual: @"true"];
    callUpdate.supportsHolding = [params[@"supportsHolding"] isEqual: @"true"];
    callUpdate.supportsGrouping = [params[@"supportsGrouping"] isEqual: @"true"];
    callUpdate.supportsUngrouping = [params[@"supportsUngrouping"] isEqual: @"true"];
    callUpdate.hasVideo = [params[@"hasVideo"] isEqual: @"true"];

    [self.callKitProvider reportCallWithUUID:self.callUUID updated: callUpdate];


}

- (void) registerWithAccessToken: (CDVInvokedUrlCommand*)command {

    self.accessToken = [command.arguments objectAtIndex:0];
    if (self.accessToken) {
        // Called from Javascript code to reauthenticate
        NSLog(@"TwilioVoicePlugin - registerWithAccessToken: %@",self.pushDeviceToken);
        [TwilioVoice registerWithAccessToken:self.accessToken
                                 deviceToken:self.pushDeviceToken
                                  completion:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"TwilioVoicePlugin - Error registering Voice Client for VOIP Push: %@", [error localizedDescription]);
            } else {
                NSLog(@"TwilioVoicePlugin - Registered Voice Client for VOIP Push");
            }
        }];

    }
    else {
        NSLog(@"TwilioVoicePlugin - registerWithAccessToken did not provide an access token.");
    }

}

#pragma mark PKPushRegistryDelegate methods
- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(PKPushType)type {
    NSLog(@"TwilioVoicePlugin - pushRegistry:didUpdatePushCredentials");

    if ([type isEqualToString:PKPushTypeVoIP]) {
        const unsigned *tokenBytes = [credentials.token bytes];

        self.pushDeviceToken = [NSString stringWithFormat:@"<%08x %08x %08x %08x %08x %08x %08x %08x>",
                                        ntohl(tokenBytes[0]), ntohl(tokenBytes[1]), ntohl(tokenBytes[2]),
                                        ntohl(tokenBytes[3]), ntohl(tokenBytes[4]), ntohl(tokenBytes[5]),
                                        ntohl(tokenBytes[6]), ntohl(tokenBytes[7])];

        // the on authenticate required should fire the reauthenticate function in js supplying a new twilio JWT accessToken.
        [self javascriptCallback:@"onauthenticaterequired" withArguments:@{
            @"reason": @"updatedPushCredentials",
            @"deviceToken": self.pushDeviceToken
        }];
    }
}


- (void)pushRegistry:(PKPushRegistry *)registry didInvalidatePushTokenForType:(PKPushType)type {
    if ([type isEqualToString:PKPushTypeVoIP]) {

        // the ondidinvalidatepushtoken should fire the reauthenticate function in js supplying a new accessToken.
        [self javascriptCallback:@"ondidinvalidatepushtoken" withArguments:@{
            @"reason": @"invalidatedPushToken",
            @"deviceToken": self.pushDeviceToken
        }];
    }
}

- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload
             forType:(PKPushType)type withCompletionHandler:(void (^)(void))completion {

    NSLog(@"pushRegistry:didReceiveIncomingPushWithPayload:forType:withCompletionHandler:");

    // Save for later when the notification is properly handled.
    self.incomingPushCompletionCallback = completion;

    if ([type isEqualToString:PKPushTypeVoIP]) {
        if (![TwilioVoice handleNotification:payload.dictionaryPayload delegate:self delegateQueue:nil]) {
            NSLog(@"This is not a valid Twilio Voice notification.");
        }
    }

    if ([payload.dictionaryPayload[@"twi_message_type"] isEqualToString:@"twilio.voice.cancel"]) {
        CXHandle *callHandle = [[CXHandle alloc] initWithType:CXHandleTypePhoneNumber value:@"+1231231234"];

        CXCallUpdate *callUpdate = [[CXCallUpdate alloc] init];
        callUpdate.remoteHandle = callHandle;
        callUpdate.supportsDTMF = YES;
        callUpdate.supportsHolding = YES;
        callUpdate.supportsGrouping = NO;
        callUpdate.supportsUngrouping = NO;
        callUpdate.hasVideo = NO;

        NSUUID *uuid = [NSUUID UUID];

        [self.callKitProvider reportNewIncomingCallWithUUID:uuid update:callUpdate completion:^(NSError *error) {
            NSLog(@"Call Kit Provider reportNewIncomingCallWithUUID.");
        }];

        CXEndCallAction *endCallAction = [[CXEndCallAction alloc] initWithCallUUID:uuid];
        CXTransaction *transaction = [[CXTransaction alloc] initWithAction:endCallAction];

        [self.callKitCallController requestTransaction:transaction completion:^(NSError *error) {
            NSLog(@"Call Kit Provider requestTransaction.");
        }];

        return;
    }






}

- (void)incomingPushHandled {
    if (self.incomingPushCompletionCallback) {
        self.incomingPushCompletionCallback();
        self.incomingPushCompletionCallback = nil;
    }
}

- (void)dealloc {
    if (self.callKitProvider) {
        [self.callKitProvider invalidate];
    }
}

#pragma mark TVONotificationDelegate
- (void)callInviteReceived:(TVOCallInvite *)callInvite {


    /**
     * Calling `[TwilioVoice handleNotification:delegate:]` will synchronously process your notification payload and
     * provide you a `TVOCallInvite` object. Report the incoming call to CallKit upon receiving this callback.
     */

    NSLog(@"Call Invite Received: %@", callInvite.uuid);

    if (self.callInvite) {
        NSLog(@"A CallInvite is already in progress. Ignoring the incoming CallInvite from %@", callInvite.from);
        if ([[NSProcessInfo processInfo] operatingSystemVersion].majorVersion < 13) {
            [self incomingPushHandled];
        }
        return;
    } else if (self.call) {
        NSLog(@"Already an active call. Ignoring the incoming CallInvite from %@", callInvite.from);
        if ([[NSProcessInfo processInfo] operatingSystemVersion].majorVersion < 13) {
            [self incomingPushHandled];
        }
        return;
    }

    self.callInvite = callInvite;
    NSDictionary *callInviteProperties = @{
        @"from":callInvite.from,
        @"to":callInvite.to,
        @"callSid":callInvite.callSid
    };

    NSString *from = @"Voice Bot";
    if (callInvite.from) {
        from = [callInvite.from stringByReplacingOccurrencesOfString:@"client:" withString:@""];
    }

    [self reportIncomingCallFrom:from withUUID:callInvite.uuid];

    [self javascriptCallback:@"oncallinvitereceived" withArguments:callInviteProperties];
}


- (void)cancelledCallInviteReceived:(nonnull TVOCancelledCallInvite *)cancelledCallInvite error:(nonnull NSError *)error {

    /**
     * The SDK may call `[TVONotificationDelegate callInviteReceived:error:]` asynchronously on the dispatch queue
     * with a `TVOCancelledCallInvite` if the caller hangs up or the client encounters any other error before the called
     * party could answer or reject the call.
     */

    NSLog(@"cancelledCallInviteReceived:");

    if (!self.callInvite ||
        ![self.callInvite.callSid isEqualToString:cancelledCallInvite.callSid]) {
        NSLog(@"No matching pending CallInvite. Ignoring the Cancelled CallInvite");
        return;
    }

    [self performEndCallActionWithUUID:self.callInvite.uuid];

    self.callInvite = nil;
    [self javascriptCallback:@"oncallinvitecanceled"];
}

#pragma mark TVOCallDelegate

- (void)callDidConnect:(TVOCall *)call {
    NSLog(@"Call Did Connect: %@", [call description]);
    self.call = call;

    self.callKitCompletionCallback(YES);
    self.callKitCompletionCallback = nil;


    NSMutableDictionary *callProperties = [NSMutableDictionary new];
    if (call.from) {
        callProperties[@"from"] = call.from;
    }
    if (call.to) {
        callProperties[@"to"] = call.to;
    }
    if (call.sid) {
        callProperties[@"callSid"] = call.sid;
    }
    callProperties[@"isMuted"] = [NSNumber numberWithBool:call.isMuted];
    NSString *callState = [self stringFromCallState:call.state];
    if (callState) {
        callProperties[@"state"] = callState;
    }
    [self javascriptCallback:@"oncalldidconnect" withArguments:callProperties];
}

- (void)call:(TVOCall *)call didFailToConnectWithError:(NSError *)error {
    NSLog(@"Call Did Fail with Error: %@, %@", [call description], [error localizedDescription]);

    self.callKitCompletionCallback(NO);

    [self callDisconnected:call];
    [self javascriptErrorback:error];
}

- (void)call:(TVOCall *)call didDisconnectWithError:(NSError *)error {
    if (error) {
        NSLog(@"Call failed: %@", error);
        [self javascriptErrorback:error];
    } else {
        NSLog(@"Call disconnected");
    }

    [self callDisconnected:call];
}

- (void)callDisconnected:(TVOCall *)call {
    NSLog(@"Call Did Disconnect: %@", [call description]);

    // Call Kit Integration
    [self performEndCallActionWithUUID:call.uuid];

    self.call = nil;
    self.callUUID = nil;
    self.callKitCompletionCallback = nil;
    [self javascriptCallback:@"oncalldiddisconnect"];
}

#pragma mark Conversion methods for the plugin

- (NSString*) stringFromCallState:(TVOCallState)state {
    if (state == TVOCallStateRinging) {
        return @"ringing";
    } else if (state == TVOCallStateConnected) {
        return @"connected";
    } else if (state == TVOCallStateConnecting) {
        return @"connecting";
    } else if (state == TVOCallStateDisconnected) {
        return @"disconnected";
    }

    return nil;
}

#pragma mark Cordova Integration methods for the plugin Delegate - from TCPlugin.m/Stevie Graham

- (void) javascriptCallback:(NSString *)event withArguments:(NSDictionary *)arguments {
    NSDictionary *options   = [NSDictionary dictionaryWithObjectsAndKeys:event, @"callback", arguments, @"arguments", nil];
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:options];
    [result setKeepCallbackAsBool:YES];

    [self.commandDelegate sendPluginResult:result callbackId:self.callback];
}

- (void) javascriptCallback:(NSString *)event {
    [self javascriptCallback:event withArguments:nil];
}

- (void) javascriptErrorback:(NSError *)error {
    NSDictionary *object    = [NSDictionary dictionaryWithObjectsAndKeys:[error localizedDescription], @"message", nil];
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:object];
    [result setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:result callbackId:self.callback];
}

#pragma mark - CXProviderDelegate - based on Twilio Voice with CallKit Quickstart ObjC

- (void)provider:(CXProvider *)provider performPlayDTMFCallAction:(CXPlayDTMFCallAction *)action {
    if (self.call) {
        NSLog(@"Sending Digits: %@", action.digits);
        [self.call sendDigits:action.digits];
    } else {
        NSLog(@"No current call");
    }

}

// All CallKit Integration Code comes from https://github.com/twilio/voice-callkit-quickstart-objc/blob/master/ObjCVoiceCallKitQuickstart/ViewController.m

- (void)providerDidReset:(CXProvider *)provider {
    NSLog(@"providerDidReset:");
    self.audioDevice.enabled = YES;
}

- (void)providerDidBegin:(CXProvider *)provider {
    NSLog(@"providerDidBegin:");
}

- (void)provider:(CXProvider *)provider didActivateAudioSession:(AVAudioSession *)audioSession {
    NSLog(@"provider:didActivateAudioSession:");
    self.audioDevice.enabled = YES;
}

- (void)provider:(CXProvider *)provider didDeactivateAudioSession:(AVAudioSession *)audioSession {
    NSLog(@"provider:didDeactivateAudioSession:");
}

- (void)provider:(CXProvider *)provider timedOutPerformingAction:(CXAction *)action {
    NSLog(@"provider:timedOutPerformingAction:");
}


- (void)provider:(CXProvider *)provider performStartCallAction:(CXStartCallAction *)action {
    NSLog(@"provider:performStartCallAction:");

    self.audioDevice.enabled = NO;
    self.audioDevice.block();

    [self.callKitProvider reportOutgoingCallWithUUID:action.callUUID startedConnectingAtDate:[NSDate date]];

    TwilioVoicePlugin __weak *weakSelf = self;
    [self performVoiceCallWithUUID:action.callUUID client:nil completion:^(BOOL success) {
        TwilioVoicePlugin __strong *strongSelf = weakSelf;
        if (success) {
            [strongSelf.callKitProvider reportOutgoingCallWithUUID:action.callUUID connectedAtDate:[NSDate date]];
            [action fulfill];
        } else {
            [action fail];
        }
    }];
}

- (void)provider:(CXProvider *)provider performAnswerCallAction:(CXAnswerCallAction *)action {
    NSLog(@"provider:performAnswerCallAction:");

    NSAssert([self.callInvite.uuid isEqual:action.callUUID], @"We only support one Invite at a time.");

    self.audioDevice.enabled = NO;
    self.audioDevice.block();

    [self performAnswerVoiceCallWithUUID:action.callUUID completion:^(BOOL success) {
        if (success) {
            [action fulfill];
        } else {
            [action fail];
        }
    }];

    [action fulfill];
}

- (void)provider:(CXProvider *)provider performEndCallAction:(CXEndCallAction *)action {
    NSLog(@"provider:performEndCallAction:");

    if (self.callInvite) {
        [self.callInvite reject];
        self.callInvite = nil;
        [self javascriptCallback:@"oncallinvitecanceled"];
    } else if (self.call) {
        [self.call disconnect];
    }

    self.audioDevice.enabled = YES;
    [action fulfill];
}
- (void)provider:(CXProvider *)provider performSetMutedCallAction:(nonnull CXSetMutedCallAction *)action {

    NSLog(@"Mute");
    if(self.call)
    {
        self.call.muted = !self.call.muted;
    }
    [action fulfill];

}

- (void)provider:(CXProvider *)provider performSetHeldCallAction:(CXSetHeldCallAction *)action {
    if (self.call && self.call.state == TVOCallStateConnected) {
        [self.call setOnHold:action.isOnHold];
        [action fulfill];
    } else {
        [action fail];
    }
}

#pragma mark - CallKit Actions
- (void)performStartCallActionWithUUID:(NSUUID *)uuid handle:(NSString *)handle withName:(NSString *)localizedCallerName {
    if (uuid == nil || handle == nil) {
        return;
    }

    NSLog(@"performStartCallActionWithUUID");

    //dispatch_async(dispatch_get_main_queue(), ^{
    CXHandle *callHandle = [[CXHandle alloc] initWithType:CXHandleTypePhoneNumber value:handle];
    CXStartCallAction *startCallAction = [[CXStartCallAction alloc] initWithCallUUID:uuid handle:callHandle];
    CXTransaction *transaction = [[CXTransaction alloc] initWithAction:startCallAction];

    [self.callKitCallController requestTransaction:transaction completion:^(NSError *error) {
        if (error) {
            NSLog(@"StartCallAction transaction request failed: %@", [error localizedDescription]);
        } else {
            NSLog(@"StartCallAction transaction request successful");

            CXCallUpdate *callUpdate = [[CXCallUpdate alloc] init];
            callUpdate.localizedCallerName = localizedCallerName;
            callUpdate.remoteHandle = callHandle;
            callUpdate.supportsDTMF = YES;
            callUpdate.supportsHolding = YES;
            callUpdate.supportsGrouping = NO;
            callUpdate.supportsUngrouping = NO;
            callUpdate.hasVideo = NO;
            [self.callKitProvider reportCallWithUUID:uuid updated:callUpdate];
        }
    }];
    //});
}

- (void)reportIncomingCallFrom:(NSString *) from withUUID:(NSUUID *)uuid {

    self.callUUID = uuid;

    NSLog(@"reportIncomingCallFrom");

    CXHandle *callHandle = [[CXHandle alloc] initWithType:CXHandleTypePhoneNumber value:from];

    CXCallUpdate *callUpdate = [[CXCallUpdate alloc] init];
    callUpdate.remoteHandle = callHandle;
    callUpdate.supportsDTMF = YES;
    callUpdate.supportsHolding = NO;
    callUpdate.supportsGrouping = NO;
    callUpdate.supportsUngrouping = NO;
    callUpdate.hasVideo = NO;


    [self.callKitProvider reportNewIncomingCallWithUUID:uuid update:callUpdate completion:^(NSError *error) {
        if (!error) {
            NSLog(@"Incoming call successfully reported.");
        }
        else {
            NSLog(@"Failed to report incoming call successfully: %@.", [error localizedDescription]);
        }
    }];


}

- (void)performEndCallActionWithUUID:(NSUUID *)uuid {
    CXEndCallAction *endCallAction = [[CXEndCallAction alloc] initWithCallUUID:uuid];
    CXTransaction *transaction = [[CXTransaction alloc] initWithAction:endCallAction];

    [self.callKitCallController requestTransaction:transaction completion:^(NSError *error) {
        if (error) {
            NSLog(@"EndCallAction transaction request failed: %@", [error localizedDescription]);
        }
        else {
            NSLog(@"EndCallAction transaction request successful");
        }
    }];
}

- (void)performVoiceCallWithUUID:(NSUUID *)uuid
                          client:(NSString *)client
                      completion:(void(^)(BOOL success))completionHandler {

    TwilioVoicePlugin __weak *weakSelf = self;
    TVOConnectOptions *connectOptions = [TVOConnectOptions optionsWithAccessToken:self.accessToken block:^(TVOConnectOptionsBuilder *builder) {
        TwilioVoicePlugin __strong *strongSelf = weakSelf;
        builder.params = @{kTwimlParamTo: strongSelf.outgoingCallParams[@"to"], @"Special": @"Param", @"userPhoneId":strongSelf.outgoingCallParams[@"userPhoneId"]};
        builder.uuid = uuid;
    }];
    self.call = [TwilioVoice connectWithOptions:connectOptions delegate:self];
    self.callKitCompletionCallback = completionHandler;
}

- (void)performAnswerVoiceCallWithUUID:(NSUUID *)uuid
                            completion:(void(^)(BOOL success))completionHandler {
    TwilioVoicePlugin __weak *weakSelf = self;
    TVOAcceptOptions *acceptOptions = [TVOAcceptOptions optionsWithCallInvite:self.callInvite block:^(TVOAcceptOptionsBuilder *builder) {
        TwilioVoicePlugin __strong *strongSelf = weakSelf;
        builder.uuid = strongSelf.callInvite.uuid;
    }];

    self.call = [self.callInvite acceptWithOptions:acceptOptions delegate:self];

    if (!self.call) {
        completionHandler(NO);
    } else {
        self.callKitCompletionCallback = completionHandler;
    }

    self.callInvite = nil;

    if ([[NSProcessInfo processInfo] operatingSystemVersion].majorVersion < 13) {
        [self incomingPushHandled];
    }
}

@end