/* global cordova */

var exec = require('cordova/exec');

var TwilioVoiceClient = {

    delegate = {},

    call = function(accessToken, params) {
        Cordova.exec(null,null,"TwilioVoicePlugin","call",[accessToken, params]);
    },

    sendDigits = function(digits) {
        Cordova.exec(null,null,"TwilioVoicePlugin","sendDigits",[digits]);
    },

    disconnect = function() {
        Cordova.exec(null,null,"TwilioVoicePlugin","disconnect",null);
    },

    rejectCallInvite = function() {
        Cordova.exec(null,null,"TwilioVoicePlugin","rejectCallInvite",null);
    },

    acceptCallInvite = function() {
        Cordova.exec(null,null,"TwilioVoicePlugin","acceptCallInvite",null);
    },

    setSpeaker = function(mode) {
        // "on" or "off"        
        Cordova.exec(null, null, "TwilioVoicePlugin", "setSpeaker", [mode]);
    },

    muteCall = function() {
        Cordova.exec(null, null, "TwilioVoicePlugin", "muteCall", null);
    },

    unmuteCall = function() {
        Cordova.exec(null, null, "TwilioVoicePlugin", "unmuteCall", null);
    },

    isCallMuted = function(fn) {
        Cordova.exec(fn, null, "TwilioVoicePlugin", "isCallMuted", null);
    },

    initialize = function(accessToken) {

        var error = function(error) {
            //TODO: Handle errors here
            if(delegate['onerror']) delegate['onerror'](error)
        }

        var success = function(callback) {
            var argument = callback['arguments'];
            if (delegate[callback['callback']]) delegate[callback['callback']](argument);
        }


        Cordova.exec(success,error,"TwilioVoicePlugin","initializeWithAccessToken",[accessToken]);
    },

    error = function(fn) {
        delegate['onerror'] = fn;
    },

    clientInitialized = function(fn) {
        delegate['onclientinitialized'] = fn;
    },

    callInviteReceived = function(fn) {
        delegate['oncallinvitereceived'] = fn;
    },

    callInviteCanceled = function(fn) {
        delegate['oncallinvitecanceled'] = fn;
    },

    callDidConnect = function(fn) {
        delegate['oncalldidconnect'] = fn;
    },

    callDidDisconnect = function(fn) {
        delegate['oncalldiddisconnect'] = fn;
    }
};

// prime it. setTimeout so that proxy gets time to init
window.setTimeout(function () {
    exec(function (res) {
        if (typeof res == 'object') {
            if (res.type == 'tap') {
                cordova.fireWindowEvent('statusTap');
            }
        } else {
            StatusBar.isVisible = res;
        }
    }, null, "TwilioVoiceClient", "_ready", []);
}, 0);

module.exports = TwilioVoiceClient;