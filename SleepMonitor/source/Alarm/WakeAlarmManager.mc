/*
Name: source/Alarm/WakeAlarmManager.mc
Description: Manages wake alarms for the SleepMonitor Connect IQ watch app.
             Handles setting, retrieving, and triggering wake alarms.
Authors: Audrey Pan
Created: February 22, 2026
Last Modified: February 27, 2026
*/

using Toybox.Timer;
using Toybox.Time;
using Toybox.System;
using Toybox.Attention;
using Toybox.WatchUi;

// NOTE: Make sure AlarmView.mc and AlarmDelegate.mc are in source/Alarm/
// and compile in the project (no extra config needed).
class WakeAlarmManager {

    // No "private" + no typed vars for this SDK profile
    var _wakeEpoch = null;
    var _alarmTimer = null;
    var _ringTimer = null;
    var _isRinging = false;

    // Tracks whether the alarm UI is already on-screen
    var _alarmShowing = false;

    function initialize() { }

    // Schedules an alarm for an absolute epoch (seconds since epoch).
    function scheduleAlarmAtEpoch(wakeEpoch) {
        // Cancel existing timer
        if (_alarmTimer != null) {
            _alarmTimer.stop();
            _alarmTimer = null;
        }

        _wakeEpoch = wakeEpoch;

        var nowEpoch = Time.now().value();
        var secondsUntil = wakeEpoch - nowEpoch;

        System.println("WakeAlarmManager: now=" + nowEpoch + " wake=" + wakeEpoch + " delta=" + secondsUntil);

        // If time already passed or is immediate, trigger now
        if (secondsUntil <= 0) {
            _fireAlarmUiAndRing();
            return;
        }

        _alarmTimer = new Timer.Timer();
        _alarmTimer.start(method(:_onAlarmTimer), secondsUntil * 1000, false);
    }

    // Relative scheduling helper (e.g., now + N seconds).
    function scheduleAlarmInSeconds(seconds) {
        var nowEpoch = Time.now().value();
        scheduleAlarmAtEpoch(nowEpoch + seconds);
    }

    function _onAlarmTimer() as Void {
        System.println("WakeAlarmManager: timer fired");

        // One-shot timer: clear reference after it fires
        if (_alarmTimer != null) {
            _alarmTimer.stop();
            _alarmTimer = null;
        }

        _fireAlarmUiAndRing();
        return;
    }

    // Centralized fire logic so "immediate" and "timer" paths behave the same
    function _fireAlarmUiAndRing() {
        // Show UI once (if not already showing)
        _showAlarmUiOnce();

        // Start the repeating ring pattern (vibe/tone)
        startRinging();
    }

    // Shows the alarm UI exactly once while alarm is active
    function _showAlarmUiOnce() {
        if (_alarmShowing) { 
            System.println("WakeAlarmManager: alarm UI already showing");
            return;
        }

        _alarmShowing = true;

        // IMPORTANT: Use the SAME view instance so delegate updates affect it
        var v = new AlarmView();
        var d = new AlarmDelegate(v, self);

        System.println("WakeAlarmManager: pushing AlarmView");
        WatchUi.pushView(v, d, WatchUi.SLIDE_UP);
    }

    // Called by AlarmDelegate when user dismisses/snoozes (or when alarm view exits)
    function setAlarmShowing(showing) {
        _alarmShowing = showing;
    }

    function startRinging() {
        if (_isRinging) { return; }
        _isRinging = true;

        // Ring immediately once
        _ringOnce();

        // Repeat every 2 seconds (vibe/tone only — DO NOT re-push the UI)
        _ringTimer = new Timer.Timer();
        _ringTimer.start(method(:_onRingTick), 2000, true); // true = repeat
    }

    function stopRinging() {
        _isRinging = false;

        if (_ringTimer != null) {
            _ringTimer.stop();
            _ringTimer = null;
        }

        System.println("WakeAlarmManager: stopped ringing");
    }

    function isRinging() {
        return _isRinging;
    }

    function _onRingTick() as Void {
        if (!_isRinging) { return; }
        _ringOnce();
        return;
    }

    // One ring action (vibration + tone). No UI pushing in here.
    function _ringOnce() {
        var vibes = [];
        vibes.add(new Attention.VibeProfile(100, 400));
        vibes.add(new Attention.VibeProfile(0,   200));
        vibes.add(new Attention.VibeProfile(100, 400));
        Attention.vibrate(vibes);

        // Tone is device-dependent; vibration is the universal fallback
        Attention.playTone(Attention.TONE_ALARM);
    }
}
