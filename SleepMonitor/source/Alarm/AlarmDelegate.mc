/*
Name: source/Alarm/AlarmDelegate.mc
Description: Input behavior delegate for the active wake alarm screen.
             Handles hardware button interactions for snoozing,
             dismissing, and switching to music or podcast playback.
             Coordinates alarm state transitions, manages the snooze
             countdown timer, and communicates with AlarmManager
             and AlarmView to update ringing state and UI feedback.
Authors: Audrey Pan
Created: February 22, 2026
Last Modified: February 27, 2026
*/

import Toybox.WatchUi;
import Toybox.System;
import Toybox.Timer;
import Toybox.Lang;

class AlarmDelegate extends WatchUi.BehaviorDelegate {

    // Reference to UI view for updating text/state
    var _view;

    // Reference to alarm manager controlling ringing + scheduling
    var _manager;

    // Timer used for snooze countdown
    var _snoozeTimer;

    // Remaining snooze time (seconds) — default 10 minutes
    var _secondsLeft = 600; 

    function initialize(view, manager) {
        WatchUi.BehaviorDelegate.initialize();

        // Store references so delegate can control UI + alarm logic
        _view = view;
        _manager = manager;
    }

    // Handles all hardware button input while alarm screen is active
    function onKey(evt) {
        var key = evt.getKey();
        
        // Safety check: prevent actions if alarm already handled
        var isDismissed = false;
        if (_view != null && _view has :_isDismissed) {
            isDismissed = _view._isDismissed;
        }

        // ENTER → Snooze alarm
        if (key == WatchUi.KEY_ENTER) {
            if (!isDismissed) { _snoozeAlarm(); }
            return true;
        }

        // ESC → Fully dismiss alarm
        if (key == WatchUi.KEY_ESC) {
            if (!isDismissed) { _dismissAlarm(); }
            return true;
        }

        // UP → Switch to podcast playback
        if (key == WatchUi.KEY_UP) { 
            _playPodcast(); 
            return true; 
        }

        // DOWN → Switch to music playback
        if (key == WatchUi.KEY_DOWN) { 
            _playMusic(); 
            return true; 
        }

        return false;
    }

    // Stops ringing and cancels any active snooze timer
    function _stopAllAlarmActions() as Void {
        _manager.stopRinging();

        if (_snoozeTimer != null) {
            _snoozeTimer.stop();
            _snoozeTimer = null;
        }

        // Reset snooze display if supported by view
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

    // Stops alarm and transitions to music mode
    function _playMusic() as Void {
        _stopAllAlarmActions();

        if (_view has :setDismissed) { _view.setDismissed(true); }
        if (_view has :setStatusText) { _view.setStatusText("PLAYING MUSIC"); }
    }

    // Stops alarm and transitions to podcast mode
    function _playPodcast() as Void {
        _stopAllAlarmActions();

        if (_view has :setDismissed) { _view.setDismissed(true); }
        if (_view has :setStatusText) { _view.setStatusText("PLAYING PODCAST"); }
    }

    // Called every second during snooze countdown
    function onTimerTick() as Void {

        // Decrease remaining snooze time
        _secondsLeft -= 1;

        // Snooze finished → trigger alarm again
        if (_secondsLeft <= 0) {
            _stopAllAlarmActions();

            if (_view has :setDismissed) { _view.setDismissed(false); }
            if (_view has :setStatusText) { _view.setStatusText("WAKE UP!"); }

            // Immediately reschedule alarm
            _manager.scheduleAlarmInSeconds(0); 
        } else {
            // Update countdown display
            if (_view has :setSnoozeTime) {
                _view.setSnoozeTime(_secondsLeft);
            }
        }
    }
}