/*
Name: source/Alarm/AlarmDelegate.mc
Description: Handles user input for the alarm. Now includes logic to disable 
             the podcast action until the content is verified as ready.
Authors: Audrey Pan
Created: February 22, 2026
Last Modified: February 27, 2026
*/

import Toybox.WatchUi;
import Toybox.Timer;

class AlarmDelegate extends WatchUi.BehaviorDelegate {

    var _view; // Reference to UI view for updating text/state
    var _manager; // Reference to alarm manager controlling ringing + scheduling
    var _snoozeTimer; // Timer used for snooze countdown
    var _secondsLeft = 600; // Remaining snooze time (seconds) — default 10 minutes

    function initialize(view, manager) {
        WatchUi.BehaviorDelegate.initialize();
        _view = view;
        _manager = manager;
    }

    function onKey(evt) {
        var key = evt.getKey();
        var isDismissed = _view.isDismissed();
        // If alarm is already dismissed, allow native navigation behavior.
        // Do not consume hardware buttons so user can exit screen or access menu.
        if (key == WatchUi.KEY_UP) {
            _playPodcast();
            return true;
        } else if (key == WatchUi.KEY_DOWN) {
            _playMusic();
            return true;
        } else if (!isDismissed){
            switch (key) {
                case WatchUi.KEY_ENTER:
                    _snoozeAlarm();
                    return true;

                case WatchUi.KEY_ESC:
                    _dismissAlarm();
                    return true;
            }
        }
        return false;
    }

    function _stopAll() {
        _manager.stopRinging();
        if (_snoozeTimer != null) { _snoozeTimer.stop(); _snoozeTimer = null; }
        if (_view has :setSnoozeTime) { _view.setSnoozeTime(0); }
    }

    // Snoozes alarm and starts countdown timer
    function _snoozeAlarm() as Void {
        _stopAllAlarmActions();

        // Reset snooze duration
        _secondsLeft = 600;
        
        // Update UI state
        if (_view has :setDismissed) { _view.setDismissed(true); }
        if (_view has :setStatusText) { _view.setStatusText("SNOOZING..."); }
        
        // Start 1-second repeating timer
        _snoozeTimer = new Timer.Timer();
        _snoozeTimer.start(method(:onTimerTick), 1000, true);
    }

    // Permanently stops the alarm
    function _dismissAlarm() as Void {
        _stopAllAlarmActions();

        if (_view has :setDismissed) { _view.setDismissed(true); }
        if (_view has :setStatusText) { _view.setStatusText("ALARM OFF"); }
    }


    function _playMusic() as Void {
        _stopAllAlarmActions();

        if (_view has :setDismissed) { _view.setDismissed(true); }
        if (_view has :setStatusText) { _view.setStatusText("PLAYING MUSIC"); }
    }

    function _snoozeAlarm() {
        _stopAll();
        _secondsLeft = 600;
        if (_view has :setDismissed) { _view.setDismissed(true); }
        if (_view has :setStatusText) { _view.setStatusText("SNOOZING..."); }
        _snoozeTimer = new Timer.Timer();
        _snoozeTimer.start(method(:onTimerTick), 1000, true);
    }

    function _dismissAlarm() {
        _stopAll();
        if (_view has :setDismissed) { _view.setDismissed(true); }
        if (_view has :setStatusText) { _view.setStatusText("ALARM OFF"); }
    }

    function onTimerTick() as Void {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
            _stopAll();
            if (_view has :setDismissed) { _view.setDismissed(false); }
            if (_view has :setStatusText) { _view.setStatusText("WAKE UP!"); }
            _manager.scheduleAlarmInSeconds(0);
        } else if (_view has :setSnoozeTime) {
            _view.setSnoozeTime(_secondsLeft);
        }
    }
}
