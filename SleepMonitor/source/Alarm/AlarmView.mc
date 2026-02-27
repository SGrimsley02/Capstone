/*
Name: source/Alarm/AlarmView.mc
Description: Wake alarm UI view for the SleepMonitor Connect IQ watch app.
             Renders the current time, alarm status messaging, and snooze countdown.
Authors: Audrey Pan
Created: February 22, 2026
Last Modified: February 27, 2026
*/

import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;

class AlarmView extends WatchUi.View {
    var _statusText = "WAKE UP!";
    var _isDismissed = false;
    var _snoozeTimeRemaining = 0;
    var _podcastReady = false; // Internal flag for green label

    function initialize() { WatchUi.View.initialize(); }

    function setSnoozeTime(s) { _snoozeTimeRemaining = s; WatchUi.requestUpdate(); }
    function setStatusText(t) { _statusText = t; WatchUi.requestUpdate(); }
    function setDismissed(d) { _isDismissed = d; WatchUi.requestUpdate(); }
    function setPodcastReady(r) { _podcastReady = r; WatchUi.requestUpdate(); }

    function onUpdate(dc) {
        var W = dc.getWidth(), H = dc.getHeight(), cx = W/2;
        var rowMid = H * 0.54, margin = W * 0.10;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // 1. Time
        var ct = System.getClockTime();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, H*0.22, Graphics.FONT_NUMBER_MEDIUM, Lang.format("$1$:$2$", [ct.hour.format("%02d"), ct.min.format("%02d")]), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // 2. Center State
        if (_snoozeTimeRemaining > 0) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, rowMid, Graphics.FONT_MEDIUM, Lang.format("$1$:$2$", [_snoozeTimeRemaining/60, (_snoozeTimeRemaining%60).format("%02d")]), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.setColor(_isDismissed ? Graphics.COLOR_GREEN : Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            // Use XTINY if the message is long ("LINK SENT...")
            var font = (_statusText.length() > 10) ? Graphics.FONT_XTINY : Graphics.FONT_TINY;
            dc.drawText(cx, rowMid, font, _statusText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // 3. Media Labels (PODCAST turns GREEN when ready)
        dc.setColor(_podcastReady ? Graphics.COLOR_GREEN : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(margin, H*0.38+8, Graphics.FONT_XTINY, "PODCAST", Graphics.TEXT_JUSTIFY_LEFT);
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(margin, H*0.64, Graphics.FONT_XTINY, "MUSIC", Graphics.TEXT_JUSTIFY_LEFT);

        // 4. Alarm-only Controls
        if (!_isDismissed && _snoozeTimeRemaining <= 0) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(W-margin, H*0.38, Graphics.FONT_XTINY, "SNOOZE", Graphics.TEXT_JUSTIFY_RIGHT);
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_DK_GRAY);
            dc.fillRoundedRectangle(cx-W*0.3, H*0.82-18, W*0.6, 36, 10);
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, H*0.82, Graphics.FONT_XTINY, "HOLD TO DISMISS", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}