/*
Name: source/WakeAlarmManager.mc
Description: Manages wake alarms for the SleepMonitor Connect IQ watch app.
             Handles setting, retrieving, and triggering wake alarms.
Authors: Audrey Pan
Created: February 22, 2026
Last Modified: February 22, 2026
*/
using Toybox.Attention;
using Toybox.System;

class WakeAlarmManager {

    // Epoch seconds (UTC) or null if unset
    private var _wakeEpoch = null;

    function initialize() {
        _wakeEpoch = null;
    }

    function setWakeTimeEpoch(epoch) as Void {
        _wakeEpoch = epoch;
        System.println("WakeAlarmManager: setWakeTimeEpoch=" + epoch);
    }

    function getWakeTimeEpoch() {
        return _wakeEpoch;
    }

    // Temporary test trigger: buzz + tone right now
    function triggerNowTest() as Void {
        System.println("WakeAlarmManager: triggerNowTest()");

        var vibes = [];

        vibes.add(new Attention.VibeProfile(100, 400));
        vibes.add(new Attention.VibeProfile(0,   200));
        vibes.add(new Attention.VibeProfile(100, 400));

        Attention.vibrate(vibes);

        Attention.playTone(Attention.TONE_ALARM);
    }

}
