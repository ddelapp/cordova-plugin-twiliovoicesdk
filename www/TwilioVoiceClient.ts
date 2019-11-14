/* global Cordova */
declare var Cordova: any;


/**
* The Twilio client plugin provides some functions to access native Twilio SDK.
*/
export class TwilioVoiceClient {

    private delegate = [];

    /**
    * Make an outgoing Call.
    * 
    * @param accessToken - A JWT access token which will be used to connect a Call.
    * @param params - Mimics the TVOConnectOptions ["To", "From"]
    */
    public call(accessToken: string, params: any) : void {
        Cordova.exec(null, null, "TwilioVoicePlugin", "call", [accessToken, params]);
    }

   /**
    * Send a string of digits.
    * 
    * @param digits - A string of characters to be played. Valid values are ‘0’ - ‘9’, 
    * ‘*’, ‘#’, and ‘w’. Each ‘w’ will cause a 500 ms pause between digits sent.
    */
    public sendDigits(digits: string) : void {
        Cordova.exec(null, null, "TwilioVoicePlugin", "sendDigits", [digits]);
    }

   /**
    * Disconnects the Call.
    */
    public disconnect() : void {
        Cordova.exec(null, null, "TwilioVoicePlugin", "disconnect", null);
    }

   /**
    * Rejects the incoming Call Invite.
    */
    public rejectCallInvite() : void {
        Cordova.exec(null, null, "TwilioVoicePlugin", "rejectCallInvite", null);
    }

   /**
    * Accepts the incoming Call Invite.
    */
    public acceptCallInvite() : void {
        Cordova.exec(null, null, "TwilioVoicePlugin", "acceptCallInvite", null);
    }

   /**
    * Turns on or off phone speaker.
    * 
    * @param mode - Can be either on or off.
    */
    public setSpeaker(mode: string) : void {
        // "on" or "off"
        Cordova.exec(null, null, "TwilioVoicePlugin", "setSpeaker", [mode]);
    }

   /**
    * Mute the Call.
    */
    public muteCall() : void {
        Cordova.exec(null, null, "TwilioVoicePlugin", "muteCall", null);
    }

   /**
    * Unmute the Call.
    */
    public unmuteCall() : void {
        Cordova.exec(null, null, "TwilioVoicePlugin", "unmuteCall", null);
    }

   /**
    * Returns a call delegate with a call mute or unmute. 
    */
    public isCallMuted(fn: (isMuted: boolean) => boolean) : void {
        Cordova.exec(fn, null, "TwilioVoicePlugin", "isCallMuted", null);
    }

   /**
    * Initializes the plugin to send and receive calls.
    * 
    * @param accessToken - A JWT access token which will be used to identify this phone number.
    */
    public initialize(accessToken: string) : void {

        var error = (error: any) => {
            //TODO: Handle errors here
            if(this.delegate['onerror']) this.delegate['onerror'](error)
        }

        var success = (callback: any) => {
            var argument = callback['arguments'];
            if (this.delegate[callback['callback']]) this.delegate[callback['callback']](argument);
        }
        console.log(Cordova);
        Cordova.exec(success, error, "TwilioVoicePlugin", "initializeWithAccessToken", [accessToken]);
    }

   /**
    * Error handler
    * @param fn - The callback delegate.
    */
    public error(fn: (error: any) => any) : void {
        this.delegate['onerror'] = fn;
    }

   /**
    * Delegate fired when the Twilio client has been initialized.
    * @param fn - The callback delegate.
    */
    public clientInitialized(fn: (result: any) => any) : void {
        this.delegate['onclientinitialized'] = fn;
    }

   /**
    * Delegate fired when a call invite is received.
    * @param fn - The callback delegate.
    */
    public callInviteReceived(fn: (result: any) => any) : void {
        this.delegate['oncallinvitereceived'] = fn;
    }

   /**
    * Delegate fired when an invite has been canceled.
    * @param fn - The callback delegate.
    */
    callInviteCanceled(fn: (result: any) => any) : void {
        this.delegate['oncallinvitecanceled'] = fn;
    }

   /**
    * Delegate fired when a call connects.
    * @param fn - The callback delegate.
    */
    public callDidConnect(fn: (result: any) => any) : void {
        this.delegate['oncalldidconnect'] = fn;
    }

   /**
    * Delegate fired when a call disconnects.
    * @param fn - The callback delegate.
    */
    public callDidDisconnect(fn: (result: any) => any) : void {
        this.delegate['oncalldiddisconnect'] = fn;
    }
};