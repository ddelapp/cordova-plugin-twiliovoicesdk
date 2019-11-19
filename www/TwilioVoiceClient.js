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
        this.cordovaExec(null, null, "call", [accessToken, params]);
    };
    /**
     * Send a string of digits.
     *
     * @param digits - A string of characters to be played. Valid values are ‘0’ - ‘9’,
     * ‘*’, ‘#’, and ‘w’. Each ‘w’ will cause a 500 ms pause between digits sent.
     */
    TwilioVoiceClient.prototype.sendDigits = function (digits) {
        this.cordovaExec(null, null, "sendDigits", [digits]);
    };
    /**
     * Update a calls data.
     * @param call Updated package of the call's abilities.
     */
    TwilioVoiceClient.prototype.updateCall = function (call) {
        this.cordovaExec(null, null, "updateCall", [
            call.localizedCallerName,
            call.supportsHolding,
            call.supportsGrouping,
            call.supportsUngrouping,
            call.supportsDtmf,
            call.hasVideo
        ]);
    };
    /**
     * Disconnects the Call.
     */
    TwilioVoiceClient.prototype.disconnect = function () {
        this.cordovaExec(null, null, "disconnect", null);
    };
    /**
     * Rejects the incoming Call Invite.
     */
    TwilioVoiceClient.prototype.rejectCallInvite = function () {
        this.cordovaExec(null, null, "rejectCallInvite", null);
    };
    /**
     * Accepts the incoming Call Invite.
     */
    TwilioVoiceClient.prototype.acceptCallInvite = function () {
        this.cordovaExec(null, null, "acceptCallInvite", null);
    };
    /**
     * Turns on or off phone speaker.
     *
     * @param mode - Can be either on or off.
     */
    TwilioVoiceClient.prototype.setSpeaker = function (mode) {
        // "on" or "off"
        this.cordovaExec(null, null, "setSpeaker", [mode]);
    };
    /**
     * Mute the Call.
     */
    TwilioVoiceClient.prototype.muteCall = function () {
        this.cordovaExec(null, null, "muteCall", null);
    };
    /**
     * Unmute the Call.
     */
    TwilioVoiceClient.prototype.unmuteCall = function () {
        this.cordovaExec(null, null, "unmuteCall", null);
    };
    /**
     * Returns a call delegate with a call mute or unmute.
     */
    TwilioVoiceClient.prototype.isCallMuted = function (fn) {
        this.cordovaExec(fn, null, "isCallMuted", null);
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
        this.cordovaExec(success, error, "initializeWithAccessToken", [accessToken]);
    };
    /**
     * Unregisters the twilio client from receiving inbound calls.
     * @param accessToken Optional: Provide a valid Twilio JWT.  If this is not supplied the existing
     * token is used, but may have already expired and prevent the unregister from occuring.
     * @param deviceToken Optional: In the event that the DidInvalidatePushToken was trigger, supply the
     * deviceToken provided from that event, and a new accessToken to unregister this client, then reinit.
     */
    TwilioVoiceClient.prototype.unregister = function (accessToken, deviceToken) {
        var _this = this;
        return new Promise(function (resolve, reject) {
            var args = [];
            if (accessToken)
                args['accessToken'] = accessToken;
            if (deviceToken)
                args['deviceToken'] = deviceToken;
            _this.cordovaExec(resolve, reject, "unregister", args);
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
    TwilioVoiceClient.prototype.cordovaExec = function (resolve, reject, method, args) {
        if (!Cordova) {
            console.warn('Native: tried calling ' +
                this.PLUGIN_NAME +
                '.' +
                method +
                ', but Cordova is not available. Make sure to include cordova.js or run in a device/simulator');
            return;
        }
        // Execute the Cordova command
        Cordova.exec(resolve, reject, this.PLUGIN_NAME, method, args);
    };
    return TwilioVoiceClient;
}());
exports.TwilioVoiceClient = TwilioVoiceClient;
;
//# sourceMappingURL=TwilioVoiceClient.js.map