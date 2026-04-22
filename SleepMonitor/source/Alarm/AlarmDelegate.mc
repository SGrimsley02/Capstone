/*
Name: source/Alarm/AlarmDelegate.mc
Description: Handles user input for the alarm. Now includes logic to disable
             the podcast action until the content is verified as ready.
Authors: Audrey Pan
Created: February 22, 2026
Last Modified: April 22, 2026
*/

import Toybox.WatchUi;
import Toybox.Timer;
import Toybox.Lang;

class AlarmDelegate extends WatchUi.BehaviorDelegate {


    var _view; // Reference to UI view for updating text/state
    var _manager; // Reference to alarm manager controlling ringing + scheduling
    var _secondsLeft = TimerConstants.SNOOZE_DURATION_SEC; // Remaining snooze time (seconds) - default 10 minutes
    var _snoozeActive = false;

    function initialize(view, manager) {
        WatchUi.BehaviorDelegate.initialize();
        _view = view;
        _manager = manager;
        _snoozeActive = false;
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
        } else {
            switch (key) {
                case WatchUi.KEY_ENTER:
                    if (!isDismissed && !_snoozeActive) {
                        _snoozeAlarm();
                        return true;
                    }
                    break;

                case WatchUi.KEY_ESC:
                    if (!isDismissed || _snoozeActive) {
                        _dismissAlarm();
                        return true;
                    }
                    break;
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
    private function isInHitbox(tx as Number, ty as Number, hitbox as Array?) as Boolean {
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
        getApp().getSharedTimerManager().unregisterTask(TimerConstants.SNOOZE_TASK_ID);
        _snoozeActive = false;
        // Reset snooze display if supported by view
        if (_view has :setSnoozeTime) { _view.setSnoozeTime(0); }
    }

    // Snoozes alarm and starts countdown timer
    function _snoozeAlarm() as Void {
        _stopAllAlarmActions();

        _manager.stopPodcastPolling();
        // Reset snooze duration
        _secondsLeft = TimerConstants.SNOOZE_DURATION_SEC;
        _snoozeActive = true;

        // Update UI state
        if (_view has :setDismissed) { _view.setDismissed(false); }
        if (_view has :setStatusText) { _view.setStatusText(WatchUi.loadResource(Rez.Strings.Snoozing)); }
        if (_view has :setSnoozeTime) { _view.setSnoozeTime(_secondsLeft); }

        //  1-second repeating timer
        getApp().getSharedTimerManager().registerRepeatingTask(
            TimerConstants.SNOOZE_TASK_ID,
            TimerConstants.SNOOZE_TICK_INTERVAL_SEC,
            method(:onTimerTick)
        );
    }

    function _dismissAlarm() as Void {
        _stopAllAlarmActions();
        _manager.finishAlarmSession();

        if (_view has :setDismissed) { _view.setDismissed(true); }
        if (_view has :setStatusText) { _view.setStatusText(WatchUi.loadResource(Rez.Strings.AlarmOff)); }
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
        if (_view has :setStatusText) { _view.setStatusText(WatchUi.loadResource(Rez.Strings.LinkSent)); }

        if (_manager != null && (_manager has :sendPodcastLinkToPhone)) {
            _manager.sendPodcastLinkToPhone();
        }
    }

    function _playMusic() as Void {
        _stopAllAlarmActions();

        if (_view has :setDismissed) { _view.setDismissed(true); }
        if (_view has :setStatusText) { _view.setStatusText(WatchUi.loadResource(Rez.Strings.PlayingMusic)); }

        var pbView = new PlaybackView();
        WatchUi.pushView(pbView, new PlaybackDelegate(pbView), WatchUi.SLIDE_UP);
    }

    function onTimerTick() as Void {
        if (!_snoozeActive) {
            return;
        }

        _secondsLeft--;

        if (_secondsLeft <= 0) {
            _snoozeActive = false;
            getApp().getSharedTimerManager().unregisterTask(TimerConstants.SNOOZE_TASK_ID);

            if (_view has :setDismissed) { _view.setDismissed(false); }
            if (_view has :setStatusText) { _view.setStatusText(WatchUi.loadResource(Rez.Strings.WakeUp)); }
            _manager.scheduleAlarmInSeconds(0);
        } else if (_view has :setSnoozeTime) {
            _view.setSnoozeTime(_secondsLeft);
        }
    }
}