export interface ICallDidConnect {
    callSid: string;
    from: string;
    isMuted: boolean;
    state: string; //connected
    to: string;
}