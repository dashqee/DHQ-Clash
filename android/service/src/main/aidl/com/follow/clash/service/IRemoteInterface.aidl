// IRemoteInterface.aidl
package com.follow.clash.service;

import com.follow.clash.service.ICallbackInterface;
import com.follow.clash.service.IEventInterface;
import com.follow.clash.service.IResultInterface;
import com.follow.clash.service.IVoidInterface;
import com.follow.clash.service.IVideoCallTunnelEventInterface;
import com.follow.clash.service.models.VpnOptions;
import com.follow.clash.service.models.NotificationParams;

interface IRemoteInterface {
    void invokeAction(in String data, in ICallbackInterface callback);
    void quickSetup(in String initParamsString, in String setupParamsString, in ICallbackInterface callback, in IVoidInterface onStarted);
    void updateNotificationParams(in NotificationParams params);
    void startService(in VpnOptions options, in long runTime, in IResultInterface result);
    void stopService(in IResultInterface result);
    void setEventListener(in IEventInterface event);
    void setCrashlytics(in boolean enable);
    boolean startVideoCallTunnel(
        in String joinLink,
        in String displayName,
        in String tunnelMode,
        in int socksPort,
        in String socksUsername,
        in String socksPassword,
        in IVideoCallTunnelEventInterface event
    );
    void stopVideoCallTunnel();
    long getRunTime();
}
