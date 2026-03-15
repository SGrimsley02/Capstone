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
import Toybox.Lang;

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

    // Touch Taps
   function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        var tapX = coords[0];
        var tapY = coords[1];

        // Podcast
        if (isInHitbox(tapX, tapY, _view._podcastHitbox)) {
            _playPodcast();
            return true;
        }

        // Music
        if (isInHitbox(tapX, tapY, _view._musicHitbox)) {
            _playMusic();
            return true;
        }

        // Dismiss / leave screen
        if (isInHitbox(tapX, tapY, _view._dismissIconHitbox) ||
            isInHitbox(tapX, tapY, _view._dismissPillHitbox)) {

            if (!_view.isDismissed()) {
                _dismissAlarm();
            } else {
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            }
            return true;
        }

        // Snooze only while alarm is actively ringing
        if (!_view.isDismissed()) {
            if (isInHitbox(tapX, tapY, _view._snoozeHitbox)) {
                _snoozeAlarm();
                return true;
            }
        }

        return false;
    }

    // Helper for onTap: Check if a point (tx, ty) is inside a square [x, y, size]
    private function isInHitbox(tx, ty, hitbox) as Boolean {
        if (hitbox == null) { return false; }
        var hX = hitbox[0];
        var hY = hitbox[1];
        var hW = hitbox[2];
        var hH = hitbox.size() > 3 ? hitbox[3] : hitbox[2];

        return (tx >= hX && tx <= hX + hW && ty >= hY && ty <= hY + hH);
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
        if (_view has :setDismissed) { _view.setDismissed(false); }
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

    // Stops alarm and transitions to podcast mode
    function _playPodcast() as Void {

        // Ask manager if podcast is ready (if method exists)
        var ready = false;
        if (_manager != null && (_manager has :isPodcastReady)) {
            ready = _manager.isPodcastReady();
        }

        // If NOT ready → do NOT stop alarm
         if (!ready) {
             return; // so when the podcast is not ready and the button is clicked, don't do anything
            }
         

        // If ready → stop alarm and proceed
        _stopAllAlarmActions();

        if (_view has :setDismissed) { _view.setDismissed(true); }
        if (_view has :setStatusText) { _view.setStatusText("LINK SENT..."); }

        // Optional: send link to phone if implemented
        if (_manager != null && (_manager has :sendPodcastLinkToPhone)) {
            _manager.sendPodcastLinkToPhone();
        }
    }

    function _playMusic() as Void {
        _stopAllAlarmActions();

        if (_view has :setDismissed) { _view.setDismissed(true); }
        if (_view has :setStatusText) { _view.setStatusText("PLAYING MUSIC"); }
    }

    function onTimerTick() as Void {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
            _stopAllAlarmActions();
            if (_view has :setDismissed) { _view.setDismissed(false); }
            if (_view has :setStatusText) { _view.setStatusText("WAKE UP!"); }
            _manager.scheduleAlarmInSeconds(0);
        } else if (_view has :setSnoozeTime) {
            _view.setSnoozeTime(_secondsLeft);
        }
    }
}
