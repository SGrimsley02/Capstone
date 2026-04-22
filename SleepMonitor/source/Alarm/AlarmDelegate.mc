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

    private const SNOOZE_TASK_ID = "alarm_snooze_countdown";

    var _view;
    var _manager;
    var _secondsLeft = 600;
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

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        var tapX = coords[0];
        var tapY = coords[1];

        if (isInHitbox(tapX, tapY, _view._podcastHitbox)) {
            _playPodcast();
            return true;
        }

        if (isInHitbox(tapX, tapY, _view._musicHitbox)) {
            _playMusic();
            return true;
        }

        if (isInHitbox(tapX, tapY, _view._dismissIconHitbox) ||
            isInHitbox(tapX, tapY, _view._dismissPillHitbox)) {

            if (!_view.isDismissed()) {
                _dismissAlarm();
            } else {
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            }
            return true;
        }

        if (!_view.isDismissed()) {
            if (isInHitbox(tapX, tapY, _view._snoozeHitbox)) {
                _snoozeAlarm();
                return true;
            }
        }

        return false;
    }

    private function isInHitbox(tx as Number, ty as Number, hitbox as Array?) as Boolean {
        if (hitbox == null) { return false; }
        var hX = hitbox[0];
        var hY = hitbox[1];
        var hW = hitbox[2];
        var hH = hitbox.size() > 3 ? hitbox[3] : hitbox[2];

        return (tx >= hX && tx <= hX + hW && ty >= hY && ty <= hY + hH);
    }

    function _stopAllAlarmActions() as Void {
        _manager.stopRinging();
        getApp().getSharedTimerManager().unregisterTask(SNOOZE_TASK_ID);
        _snoozeActive = false;

        if (_view has :setSnoozeTime) { _view.setSnoozeTime(0); }
    }

    function _snoozeAlarm() as Void {
        _stopAllAlarmActions();

        _manager.stopPodcastPolling();

        _secondsLeft = 600;
        _snoozeActive = true;

        if (_view has :setDismissed) { _view.setDismissed(false); }
        if (_view has :setStatusText) { _view.setStatusText(WatchUi.loadResource(Rez.Strings.Snoozing)); }
        if (_view has :setSnoozeTime) { _view.setSnoozeTime(_secondsLeft); }

        getApp().getSharedTimerManager().registerRepeatingTask(
            SNOOZE_TASK_ID,
            1,
            method(:onTimerTick)
        );
    }

    function _dismissAlarm() as Void {
        _stopAllAlarmActions();
        _manager.finishAlarmSession();

        if (_view has :setDismissed) { _view.setDismissed(true); }
        if (_view has :setStatusText) { _view.setStatusText(WatchUi.loadResource(Rez.Strings.AlarmOff)); }
    }

    function _playPodcast() as Void {
        var ready = false;
        if (_manager != null && (_manager has :isPodcastReady)) {
            ready = _manager.isPodcastReady();
        }

        if (!ready) {
            return;
        }

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
            getApp().getSharedTimerManager().unregisterTask(SNOOZE_TASK_ID);

            if (_view has :setDismissed) { _view.setDismissed(false); }
            if (_view has :setStatusText) { _view.setStatusText(WatchUi.loadResource(Rez.Strings.WakeUp)); }
            _manager.scheduleAlarmInSeconds(0);
        } else if (_view has :setSnoozeTime) {
            _view.setSnoozeTime(_secondsLeft);
        }
    }
}