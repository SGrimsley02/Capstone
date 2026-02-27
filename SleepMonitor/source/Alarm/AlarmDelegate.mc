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
    var _view, _manager, _snoozeTimer;
    var _secondsLeft = 600;

    function initialize(view, manager) {
        WatchUi.BehaviorDelegate.initialize();
        _view = view;
        _manager = manager;
    }

    function onKey(evt) {
        var key = evt.getKey();
        var dismissed = (_view != null && _view has :_isDismissed) ? _view._isDismissed : false;

        if (key == WatchUi.KEY_ENTER && !dismissed) { _snoozeAlarm(); return true; }
        if (key == WatchUi.KEY_ESC && !dismissed) { _dismissAlarm(); return true; }
        
        // PODCAST BUTTON (UP)
        if (key == WatchUi.KEY_UP) { 
            _playPodcast(); 
            return true; 
        }
        
        // MUSIC BUTTON (DOWN)
        if (key == WatchUi.KEY_DOWN) { 
            _playMusic(); 
            return true; 
        }
        return false;
    }

    function _stopAll() {
        _manager.stopRinging();
        if (_snoozeTimer != null) { _snoozeTimer.stop(); _snoozeTimer = null; }
        if (_view has :setSnoozeTime) { _view.setSnoozeTime(0); }
    }

    function _playPodcast() {
        // ONLY allow if the podcast is ready
        if (_view != null && _view._podcastReady) {
            _stopAll();
            if (_view has :setDismissed) { _view.setDismissed(true); }
            // New specific confirmation message
            if (_view has :setStatusText) { _view.setStatusText("LINK SENT TO PHONE"); }
        } else {
            System.println("Podcast not ready yet.");
        }
    }

    function _playMusic() {
        _stopAll();
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