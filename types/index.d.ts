// Type definitions for cordova-plugin-twiliovoicesdk

/**
* Global object Window.
*/
interface Window {
    TwilioVoiceClient: TwilioVoiceClient;
}

/**
* The Twilio client plugin provides some functions to access native Twilio SDK.
*/
interface TwilioVoiceClient {
    /**
    * Make an outgoing Call.
    * 
    * @param accessToken - A JWT access token which will be used to connect a Call.
    * @param params - Mimics the TVOConnectOptions ["To", "From"]
    */
   call(accessToken: string, params: any): void;


   /**
    * Send a string of digits.
    * 
    * @param digits - A string of characters to be played. Valid values are ‘0’ - ‘9’, ‘*’, ‘#’, and ‘w’. Each ‘w’ will cause a 500 ms pause between digits sent.
    */
   sendDigits(digits: string): void;

   /**
    * Disconnects the Call.
    */
   disconnect(): void;

   /**
    * Rejects the incoming Call Invite.
    */
   rejectCallInvite(): void;

   /**
    * Accepts the incoming Call Invite.
    */
   acceptCallInvite(): void;

   /**
    * Turns on or off phone speaker.
    * 
    * @param mode - Can be either on or off.
    */
   setSpeaker(mode: string): void;

   /**
    * Must the Call.
    */
   muteCall(): void;

   /**
    * Unmute the Call.
    */
   unmuteCall(): void;

   /**
    * Returns a call delegate with a call mute or unmute. 
    */
   isCallMuted(fn: () => boolean): void;

   /**
    * Initializes the plugin to send and receive calls.
    * 
    * @param accessToken - A JWT access token which will be used to identify this phone number.
    */
   initialize(accessToken: string): void;

   /**
    * Error handler
    * @param fn - The callback delegate.
    */
   error(fn: () => any): void;

   /**
    * Delegate when the Twilio client has been initialized.
    * @param fn - The callback delegate.
    */
   clientInitialized(fn: () => any): void;

   /**
    * Delegate when a call invite is received.
    * @param fn - The callback delegate.
    */
   callInviteReceived(fn: () => any): void;

   /**
    * Delegate when an invite has been canceled.
    * @param fn - The callback delegate.
    */
   callInviteCanceled(fn: () => any): void;

   /**
    * Delegate when a call connects.
    * @param fn - The callback delegate.
    */
   callDidConnect(fn: () => any): void;

   /**
    * Delegate when a call disconnects.
    * @param fn - The callback delegate.
    */
   callDidDisconnect(fn: () => any): void;
}

declare var TwilioVoiceClient: TwilioVoiceClient;