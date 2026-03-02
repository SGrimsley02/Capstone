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

class WakeAlarmManager {

    var _wakeEpoch = null;
    var _alarmTimer = null;
    var _ringTimer = null;
    var _isRinging = false;
    var _alarmShowing = false;
    
    // Store the view reference to update it later
    var _currentView = null;

    // Reuse the same alarm UI instance so it is unified across pushes
    var _alarmView = null;
    var _alarmDelegate = null;

    function initialize() { }

    function scheduleAlarmAtEpoch(wakeEpoch) {
        if (_alarmTimer != null) {
            _alarmTimer.stop();
            _alarmTimer = null;
        }
        _wakeEpoch = wakeEpoch;
        var nowEpoch = Time.now().value();
        var secondsUntil = wakeEpoch - nowEpoch;

        if (secondsUntil <= 0) {
            _fireAlarmUiAndRing();
            return;
        }

        _alarmTimer = new Timer.Timer();
        _alarmTimer.start(method(:_onAlarmTimer), secondsUntil * 1000, false);
    }

    function scheduleAlarmInSeconds(seconds) {
        var nowEpoch = Time.now().value();
        scheduleAlarmAtEpoch(nowEpoch + seconds);
    }

    function _onAlarmTimer() as Void {
        if (_alarmTimer != null) {
            _alarmTimer.stop();
            _alarmTimer = null;
        }
        _fireAlarmUiAndRing();
        return;
    }

    function _fireAlarmUiAndRing() {
        _showAlarmUiOnce();
        startRinging();
    }

    function _showAlarmUiOnce() {
        if (_alarmShowing) { 
            System.println("WakeAlarmManager: alarm UI already showing");
            return;
        }
        _alarmShowing = true;

        // IMPORTANT: Use the SAME view instance so delegate updates affect it
        if (_alarmView == null) {
            _alarmView = new AlarmView();

            // Attach manager so AlarmView can clear _alarmShowing when user exits the screen
            if (_alarmView has :setManager) { _alarmView.setManager(self); }

            _alarmDelegate = new AlarmDelegate(_alarmView, self);
        }

        System.println("WakeAlarmManager: pushing AlarmView");
        WatchUi.pushView(_alarmView, _alarmDelegate, WatchUi.SLIDE_UP);

    }

    function setAlarmShowing(showing) {
        _alarmShowing = showing;
        if (!showing) { _currentView = null; }
    }

    function startRinging() {
        if (_isRinging) { return; }
        _isRinging = true;
        _ringOnce();
        _ringTimer = new Timer.Timer();
        _ringTimer.start(method(:_onRingTick), 2000, true);
    }

    function stopRinging() {
        _isRinging = false;
        if (_ringTimer != null) {
            _ringTimer.stop();
            _ringTimer = null;
        }
    }

    function isRinging() { return _isRinging; }

    function _onRingTick() as Void {
        if (!_isRinging) { return; }
        _ringOnce();
        return;
    }

    function _ringOnce() {
        var vibes = [
            new Attention.VibeProfile(100, 400),
            new Attention.VibeProfile(0, 200),
            new Attention.VibeProfile(100, 400)
        ];
        Attention.vibrate(vibes);
        Attention.playTone(Attention.TONE_ALARM);
    }
}