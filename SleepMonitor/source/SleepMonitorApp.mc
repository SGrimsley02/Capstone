/*
Name: source/SleepMonitorApp.mc
Description: Application entry point for the SleepMonitor Connect IQ watch app.
             Maintains shared in-memory UI/network status and provides the initial
             view + input delegate wiring.
Authors: Kiara Rose, Audrey Pan
Created: February 7, 2026
Last Modified: February 14, 2026
*/

import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class SleepMonitorApp extends Application.AppBase {
    private var _httpStatus as String = "Idle";

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new SleepMonitorView(), new SleepMonitorDelegate() ];
    }

    // Read current networking/UI status for display.
    function getHttpStatus() as String {
        return _httpStatus;
    }

    // Update status message (typically set by HTTP client after responses/errors).
    function setHttpStatus(message as String) as Void {
        _httpStatus = message;
    }
}

// Convenience helper to access the App instance from other modules.
function getApp() as SleepMonitorApp {
    return Application.getApp() as SleepMonitorApp;
}