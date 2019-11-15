"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
/**
* The Twilio client plugin provides some functions to access native Twilio SDK.
*/
var TwilioVoiceClient = /** @class */ (function () {
    function TwilioVoiceClient() {
        this.PLUGIN_NAME = 'TwilioVoicePlugin';
        this.delegate = [];
    }
    /**
    * Make an outgoing Call.
    *
    * @param accessToken - A JWT access token which will be used to connect a Call.
    * @param params - Mimics the TVOConnectOptions ["To", "From"]
    */
    TwilioVoiceClient.prototype.call = function (accessToken, params) {
        Cordova.exec(null, null, this.PLUGIN_NAME, "call", [accessToken, params]);
    };
    /**
     * Send a string of digits.
     *
     * @param digits - A string of characters to be played. Valid values are ‘0’ - ‘9’,
     * ‘*’, ‘#’, and ‘w’. Each ‘w’ will cause a 500 ms pause between digits sent.
     */
    TwilioVoiceClient.prototype.sendDigits = function (digits) {
        Cordova.exec(null, null, this.PLUGIN_NAME, "sendDigits", [digits]);
    };
    /**
     * Update a calls data.
     * @param call Updated package of the call's abilities.
     */
    TwilioVoiceClient.prototype.updateCall = function (call) {
        Cordova.exec(null, null, this.PLUGIN_NAME, "updateCall", [call]);
    };
    /**
     * Disconnects the Call.
     */
    TwilioVoiceClient.prototype.disconnect = function () {
        Cordova.exec(null, null, this.PLUGIN_NAME, "disconnect", null);
    };
    /**
     * Rejects the incoming Call Invite.
     */
    TwilioVoiceClient.prototype.rejectCallInvite = function () {
        Cordova.exec(null, null, this.PLUGIN_NAME, "rejectCallInvite", null);
    };
    /**
     * Accepts the incoming Call Invite.
     */
    TwilioVoiceClient.prototype.acceptCallInvite = function () {
        Cordova.exec(null, null, this.PLUGIN_NAME, "acceptCallInvite", null);
    };
    /**
     * Turns on or off phone speaker.
     *
     * @param mode - Can be either on or off.
     */
    TwilioVoiceClient.prototype.setSpeaker = function (mode) {
        // "on" or "off"
        Cordova.exec(null, null, this.PLUGIN_NAME, "setSpeaker", [mode]);
    };
    /**
     * Mute the Call.
     */
    TwilioVoiceClient.prototype.muteCall = function () {
        Cordova.exec(null, null, this.PLUGIN_NAME, "muteCall", null);
    };
    /**
     * Unmute the Call.
     */
    TwilioVoiceClient.prototype.unmuteCall = function () {
        Cordova.exec(null, null, this.PLUGIN_NAME, "unmuteCall", null);
    };
    /**
     * Returns a call delegate with a call mute or unmute.
     */
    TwilioVoiceClient.prototype.isCallMuted = function (fn) {
        Cordova.exec(fn, null, this.PLUGIN_NAME, "isCallMuted", null);
    };
    /**
     * Initializes the plugin to send and receive calls.
     *
     * @param accessToken - A JWT access token which will be used to identify this phone number.
     */
    TwilioVoiceClient.prototype.initialize = function (accessToken) {
        var _this = this;
        var error = function (error) {
            //TODO: Handle errors here
            if (_this.delegate['onerror'])
                _this.delegate['onerror'](error);
        };
        var success = function (callback) {
            var argument = callback['arguments'];
            if (_this.delegate[callback['callback']])
                _this.delegate[callback['callback']](argument);
        };
        Cordova.exec(success, error, this.PLUGIN_NAME, "initializeWithAccessToken", [accessToken]);
    };
    /**
     * Unregisters the JWT access token so this client is not forwarded calls.
     */
    TwilioVoiceClient.prototype.unregister = function () {
        var _this = this;
        return new Promise(function (resolve, reject) {
            Cordova.exec(resolve, reject, _this.PLUGIN_NAME, "unregister");
        });
    };
    /**
     * Error handler
     * @param fn - The callback delegate.
     */
    TwilioVoiceClient.prototype.error = function (fn) {
        this.delegate['onerror'] = fn;
    };
    /**
     * Delegate fired when the Twilio client has been initialized.
     * @param fn - The callback delegate.
     */
    TwilioVoiceClient.prototype.clientInitialized = function (fn) {
        this.delegate['onclientinitialized'] = fn;
    };
    /**
     * Delegate fired when a call invite is received.
     * @param fn - The callback delegate.
     */
    TwilioVoiceClient.prototype.callInviteReceived = function (fn) {
        this.delegate['oncallinvitereceived'] = fn;
    };
    /**
     * Delegate fired when an invite has been canceled.
     * @param fn - The callback delegate.
     */
    TwilioVoiceClient.prototype.callInviteCanceled = function (fn) {
        this.delegate['oncallinvitecanceled'] = fn;
    };
    /**
     * Delegate fired when a call connects.
     * @param fn - The callback delegate.
     */
    TwilioVoiceClient.prototype.callDidConnect = function (fn) {
        this.delegate['oncalldidconnect'] = fn;
    };
    /**
     * Delegate fired when a call disconnects.
     * @param fn - The callback delegate.
     */
    TwilioVoiceClient.prototype.callDidDisconnect = function (fn) {
        this.delegate['oncalldiddisconnect'] = fn;
    };
    /**
     * Delegate fired when the twilio VoIP push notification token has been invalidated.
     * @param fn - The callback delegate.
     */
    TwilioVoiceClient.prototype.didInvalidatePushToken = function (fn) {
        this.delegate['ondidinvalidatepushtoken'] = fn;
    };
    return TwilioVoiceClient;
}());
exports.TwilioVoiceClient = TwilioVoiceClient;
;
//# sourceMappingURL=TwilioVoiceClient.js.map