import { CallUpdate } from "./types/CallUpdate";
import { ICallInviteReceived } from "./types/ICallInviteReceived";
import { ICallDidConnect } from "./types/ICallDidConnect";
import { IDidInvalidatePushToken } from './types/IDidInvalidatePushToken';

/* global Cordova */
declare var Cordova: any;


/**
* The Twilio client plugin provides some functions to access native Twilio SDK.
*/
export class TwilioVoiceClient {

    PLUGIN_NAME = 'TwilioVoicePlugin';

    private delegate = [];

    /**
    * Make an outgoing Call.
    * 
    * @param accessToken - A JWT access token which will be used to connect a Call.
    * @param params - Mimics the TVOConnectOptions ["To", "From"]
    */
    public call(accessToken: string, params: any) : void {
        this.cordovaExec(null, null, "call", [accessToken, params]);
    }

   /**
    * Send a string of digits.
    * 
    * @param digits - A string of characters to be played. Valid values are ‘0’ - ‘9’, 
    * ‘*’, ‘#’, and ‘w’. Each ‘w’ will cause a 500 ms pause between digits sent.
    */
    public sendDigits(digits: string) : void {
        this.cordovaExec(null, null, "sendDigits", [digits]);
    }

    /**
     * Update a calls data.
     * @param call Updated package of the call's abilities.
     */
    public updateCall(call: CallUpdate) : void {
        this.cordovaExec(null, null, "updateCall", [{
            "localizedCallerName": call.localizedCallerName,
            "supportsHolding": call.supportsHolding,
            "supportsGrouping": call.supportsGrouping,
            "supportsUngrouping": call.supportsUngrouping,
            "supportsDtmf": call.supportsDtmf,
            "hasVideo": call.hasVideo
        }]);
    }

   /**
    * Disconnects the Call.
    */
    public disconnect() : void {
        this.cordovaExec(null, null, "disconnect", null);
    }

   /**
    * Rejects the incoming Call Invite.
    */
    public rejectCallInvite() : void {
        this.cordovaExec(null, null, "rejectCallInvite", null);
    }

   /**
    * Accepts the incoming Call Invite.
    */
    public acceptCallInvite() : void {
        this.cordovaExec(null, null, "acceptCallInvite", null);
    }

   /**
    * Turns on or off phone speaker.
    * 
    * @param mode - Can be either on or off.
    */
    public setSpeaker(mode: string) : void {
        // "on" or "off"
        this.cordovaExec(null, null, "setSpeaker", [mode]);
    }

   /**
    * Mute the Call.
    */
    public muteCall() : void {
        this.cordovaExec(null, null, "muteCall", null);
    }

   /**
    * Unmute the Call.
    */
    public unmuteCall() : void {
        this.cordovaExec(null, null, "unmuteCall", null);
    }

   /**
    * Returns a call delegate with a call mute or unmute. 
    */
    public isCallMuted(fn: (isMuted: boolean) => boolean) : void {
        this.cordovaExec(fn, null, "isCallMuted", null);
    }

   /**
    * Initializes the plugin to send and receive calls.
    */
    public initialize() : void {

        var error = (error: any) => {
            //TODO: Handle errors here
            if(this.delegate['onerror']) this.delegate['onerror'](error)
        }

        var success = (callback: any) => {
            var argument = callback['arguments'];
            if (this.delegate[callback['callback']]) this.delegate[callback['callback']](argument);
        }
        
        this.cordovaExec(success, error, "initialize", null);
    }

   /**
    * After the plugin has been initialized, Register this client with Twilio using an access token.
    * This should be called when onReauthenticateRequired is fired.
    * 
    * @param accessToken - A JWT access token which will be used to identify this phone number.
    */
    public registerWithAccessToken(accessToken: string) : void {
        this.cordovaExec(null, null , "registerWithAccessToken", [accessToken]);
    }

    /**
     * Unregisters the twilio client from receiving inbound calls.
     * @param accessToken Optional: Provide a valid Twilio JWT.  If this is not supplied the existing
     * token is used, but may have already expired and prevent the unregister from occuring.
     */
    public unregister(accessToken?: string) : Promise<string> {
        return new Promise<string>((resolve, reject) => {
            var args =[];
            if(accessToken) args['accessToken'] = accessToken;

            this.cordovaExec(resolve, reject, "unregister", args)
        });
    }

   /**
    * Error handler
    * @param fn - The callback delegate.
    */
    public onError(fn: (error: any) => any) : void {
        this.delegate['onerror'] = fn;
    }

   /**
    * Delegate fired when the Twilio client has been initialized.
    * @param fn - The callback delegate.
    */
    public onClientInitialized(fn: () => any) : void {
        this.delegate['onclientinitialized'] = fn;
    }

   /**
    * Delegate fired when a call invite is received.
    * @param fn - The callback delegate.
    */
    public onCallInviteReceived(fn: (result: ICallInviteReceived) => any) : void {
        this.delegate['oncallinvitereceived'] = fn;
    }

   /**
    * Delegate fired when an invite has been canceled.
    * @param fn - The callback delegate.
    */
    public onCallInviteCanceled(fn: () => any) : void {
        this.delegate['oncallinvitecanceled'] = fn;
    }

   /**
    * Delegate fired when a call connects.
    * @param fn - The callback delegate.
    */
    public onCallDidConnect(fn: (result: ICallDidConnect) => any) : void {
        this.delegate['oncalldidconnect'] = fn;
    }

    /**
     * Delegate fired when a call disconnects.
     * @param fn - The callback delegate.
     */
     public onCallDidDisconnect(fn: () => any) : void {
         this.delegate['oncalldiddisconnect'] = fn;
     }

     /**
      * Delegate fired when the twilio VoIP push notification token has been invalidated.
      * @param fn - The callback delegate.
      */
      public onDidInvalidatePushToken(fn: (result: IDidInvalidatePushToken) => any) : void {
          this.delegate['ondidinvalidatepushtoken'] = fn;
      }


     /**
      * Delegate fired when the twilio VoIP push notification token been updated.
      * @param fn - The callback delegate.
      */
      public onAuthenticateRequired(fn: (result: IDidInvalidatePushToken) => any) : void {
          this.delegate['onauthenticaterequired'] = fn;
      }

      private cordovaExec(resolve: any, reject: any, method: string, args: any)
      {
        if(typeof Cordova === 'undefined') {
            console.warn('Native: tried calling ' +
            this.PLUGIN_NAME +
            '.' +
            method +
            ', but Cordova is not available. Make sure to include cordova.js or run in a device/simulator');
            return;
        }

        // Execute the Cordova command
        Cordova.exec(resolve, reject, this.PLUGIN_NAME, method, args);

      }
};