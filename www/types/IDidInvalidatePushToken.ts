export interface IDidInvalidatePushToken {
    reason: string; // The reason the invalidation occurred.
    deviceToken: string // The device token used to unregister the device from Twilio
}