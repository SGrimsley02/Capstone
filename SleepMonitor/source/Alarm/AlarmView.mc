/*
Name: source/Alarm/AlarmView.mc
Description: Wake alarm UI view for the SleepMonitor Connect IQ watch app.
             Renders the current time, alarm status messaging, and snooze countdown.
             Displays persistent media actions (podcast/music) and conditionally shows
             alarm controls (snooze + dismiss prompt) while the alarm is active.
             Updates are driven by AlarmDelegate via simple setter methods that trigger redraws.
Authors: Audrey Pan
Created: February 22, 2026
Last Modified: February 27, 2026
*/

import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;

class AlarmView extends WatchUi.View {

    var _statusText = "WAKE UP!";// Current UI state shown in the center area (e.g., "WAKE UP!", "ALARM OFF")
    var _isDismissed = false;  // True once the alarm has been handled (dismissed / music / podcast)
    var _snoozeTimeRemaining = 0; // Snooze countdown in seconds (0 means not snoozing)
    var _manager; // Reference to the alarm manager for potential future use (e.g., showing next alarm time)

    function initialize() {
        WatchUi.View.initialize();
    }

    function onLayout(dc) {
        // Replacing onUpdate with onLayout for UI updates

        setLayout(Rez.Layouts.AlarmScreen(dc));
    }




    // Setter for manager reference (called by delegate after both are initialized)
    function setManager(manager) {
        _manager = manager;
    }

    function onHide() {
        // Reset state when view is hidden (alarm handled or user navigated away)
        if (_manager != null && (_manager has :setAlarmShowing)) {
            _manager.setAlarmShowing(false);
        }
    }

    // Updates snooze timer state and refreshes the screen
    function setSnoozeTime(seconds) {
        _snoozeTimeRemaining = seconds;
        WatchUi.requestUpdate();
    }

    // Updates the center status text and refreshes the screen
    function setStatusText(msg) {
        _statusText = msg;
        WatchUi.requestUpdate();
    }

    // Updates whether alarm controls should be hidden/shown and refreshes the screen
    function setDismissed(state) {
        _isDismissed = state;
        WatchUi.requestUpdate();
    }

    // Returns whether the alarm has been dismissed (used by delegate to gate input handling)
    public function isDismissed() {
        return _isDismissed;
    }

    // Draws the alarm screen UI each frame
    function onUpdate(dc) {
        View.onUpdate(dc);


        var W = dc.getWidth();
        var H = dc.getHeight();
        var cx = W / 2;

        // Layout grid positions (scaled to screen height)
        var rowTime   = H * 0.22;
        var rowTopBtn = H * 0.38;
        var rowMid    = H * 0.54;
        var rowBotBtn = H * 0.64;
        var rowPill   = H * 0.82;
        var margin    = W * 0.10;

        // Clear background
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // 1) Draw current time at the top
        var ct = System.getClockTime();
        var timeStr = Lang.format(
            "$1$:$2$",
            [ct.hour.format("%02d"), ct.min.format("%02d")]
        );

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            cx, rowTime,
            Graphics.FONT_NUMBER_MEDIUM,
            timeStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // 2) Center content changes depending on state:
        //    - Snoozing: show countdown
        //    - Dismissed/media: show final status
        //    - Active alarm: show "WAKE UP!" status
        if (_snoozeTimeRemaining > 0) {
            // Snooze mode: show countdown as M:SS
            var mins = _snoozeTimeRemaining / 60;
            var secs = _snoozeTimeRemaining % 60;

            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                cx, rowMid,
                Graphics.FONT_MEDIUM,
                Lang.format("$1$:$2$", [mins, secs.format("%02d")]),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

        } else if (_isDismissed) {
            // Dismissed or switched to media: show status
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                cx, rowMid,
                Graphics.FONT_SMALL,
                _statusText,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

        } else {
            // Alarm actively ringing: show urgent status
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                cx, rowMid,
                Graphics.FONT_TINY,
                _statusText,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        // 3) Persistent media labels (always visible)
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(margin, rowTopBtn + 8, Graphics.FONT_XTINY, "PODCAST", Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(margin, rowBotBtn,      Graphics.FONT_XTINY, "MUSIC",   Graphics.TEXT_JUSTIFY_LEFT);

        // 4) Alarm-only controls (only while alarm is actively ringing)
        if (!_isDismissed && _snoozeTimeRemaining <= 0) {

            // Snooze label (right side)
            dc.drawText(W - margin, rowTopBtn, Graphics.FONT_XTINY, "SNOOZE", Graphics.TEXT_JUSTIFY_RIGHT);

            // Dismiss call-to-action pill at the bottom
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_DK_GRAY);
            dc.fillRoundedRectangle(cx - (W * 0.3), rowPill - 18, W * 0.6, 36, 10);

            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                cx, rowPill,
                Graphics.FONT_XTINY,
                "HOLD TO DISMISS",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }
    }
}



class PodcastIcon extends WatchUi.Drawable {
    var _isActive = false;

    function initialize(params as Dictionary) {
        Drawable.initialize(params);

        _isActive = params.get(:isActive) as Boolean;
    }

    function draw(dc as Dc) as Void {
        dc.drawBitmap2(
            x=x,
            y=y,
            bitmap=WatchUi.loadResource(Rez.Drawables.podcast_icon),
            options={
                :tintColor => _isActive ? Graphics.COLOR_WHITE : Graphics.COLOR_DK_GRAY
            }
        )
    }
}