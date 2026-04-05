/*
Name: source/Alarm/AlarmView.mc
Description: Wake alarm UI view for the SleepMonitor Connect IQ watch app.
             Renders the current time, alarm status messaging, and snooze countdown.
Authors: Audrey Pan
Created: February 22, 2026
Last Modified: March 15, 2026
*/

import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;

class AlarmView extends WatchUi.View {

    var _statusText = WatchUi.loadResource(Rez.Strings.WakeUp);      // Current UI state shown in the center area
    var _isDismissed = false;          // True once the alarm has been handled
    var _snoozeTimeRemaining = 0;      // Snooze countdown in seconds (0 means not snoozing)
    var _manager;                      // Reference to the alarm manager
    var _podcastReady = false;         // Podcast becomes active when a link is available

    // ── Drawables ──────────────────────────────────────────────
    var _musicIcon;
    var _podcastIcon;
    var _snoozeIcon;
    var _dismissIcon;
    private var _remixLogo;

    // ── Hitboxes ───────────────────────────────────────────────
    // Standard icon hitboxes use [x, y, size]
    // Dismiss pill hitbox uses [x, y, w, h]
    var _podcastHitbox = [0, 0, 0];
    var _musicHitbox = [0, 0, 0];
    var _snoozeHitbox = [0, 0, 0];
    var _dismissPillHitbox = [0, 0, 0];
    var _dismissIconHitbox = [0, 0, 0];

    function initialize() {
        WatchUi.View.initialize();

        _musicIcon = loadResource(Rez.Drawables.musicIcon);
        _podcastIcon = loadResource(Rez.Drawables.podcastIcon);
        _snoozeIcon = loadResource(Rez.Drawables.snoozeIcon);
        _dismissIcon = loadResource(Rez.Drawables.dismissIcon);
        _remixLogo = loadResource(Rez.Drawables.remixLogo);
    }

    function onLayout(dc) {
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
            setDismissed(false);

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

    function setPodcastReady(isReady) {
        _podcastReady = isReady;
        WatchUi.requestUpdate();
    }

    // Returns whether the alarm has been dismissed
    public function isDismissed() {
        return _isDismissed;
    }

    // Draws the alarm screen UI each frame
    function onUpdate(dc) {
        View.onUpdate(dc);

        var W = dc.getWidth();
        var H = dc.getHeight();
        var cx = W / 2;
        var hitboxSize = 45;

        // ── Layout ───────────────────────────────────────────────
        var rowTime = H * 0.30;
        var rowTopBtn = H * 0.38;
        var rowMid = H * 0.54;
        var rowBotBtn = H * 0.64;

        // Adjusted margins for curved screen
        var botMargin = W * 0.07;
        var topMargin = W * 0.03;

        var bubbleRadius = W * 0.50;
        var bubbleY = H * 1.30;

        var pillY = H * 0.90;
        var pillW = W * 0.53;
        var pillH = 34;

        var isSnoozing = _snoozeTimeRemaining > 0;
        var showDismissAction = (!_isDismissed || isSnoozing);
        var showPill = (showDismissAction || _isDismissed);

        // ── Background ───────────────────────────────────────────
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // ── Branding + clock ─────────────────────────────────────
        UIHelpers.drawBranding(dc, cx, H, _remixLogo);
        UIHelpers.drawClock(dc, cx, rowTime.toNumber(), Graphics.FONT_NUMBER_MEDIUM);

        // ── Center status / snooze timer ─────────────────────────
        if (isSnoozing) {
            dc.setColor(Colors.TEAL_LITE, Graphics.COLOR_TRANSPARENT);

            var mins = _snoozeTimeRemaining / 60;
            var secs = _snoozeTimeRemaining % 60;

            dc.drawText(
                cx,
                rowMid,
                Graphics.FONT_MEDIUM,
                Lang.format("$1$:$2$", [mins, secs.format("%02d")]),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        } else {
            var statusColor = _isDismissed ? Colors.PURPLE_LITE : Colors.TEAL_LITE;
            var font = (_statusText.length() > 10) ? Graphics.FONT_XTINY : Graphics.FONT_TINY;

            dc.setColor(statusColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                cx,
                rowMid,
                font,
                _statusText,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        // ── Media action icons ───────────────────────────────────
        // Podcast
        var podColor = _podcastReady ? Colors.PURPLE_LITE : Colors.GRAY_MID;
        _podcastHitbox = [topMargin, rowTopBtn, hitboxSize];
        dc.drawBitmap2(topMargin, rowTopBtn, _podcastIcon, { :tintColor => podColor });

        // Music
        _musicHitbox = [botMargin, rowBotBtn, hitboxSize];
        dc.drawBitmap2(botMargin, rowBotBtn, _musicIcon, { :tintColor => Colors.PURPLE_MID });

        // Dismiss icon
        var dismissW = _dismissIcon.getWidth();
        var dismissX = W - botMargin - dismissW;
        _dismissIconHitbox = [dismissX, rowBotBtn, hitboxSize];
        dc.drawBitmap2(dismissX, rowBotBtn, _dismissIcon, { :tintColor => Colors.TEAL_LITE });

        // Snooze icon only while alarm is actively ringing
        if (!_isDismissed && !isSnoozing) {
            var snoozeW = _snoozeIcon.getWidth();
            var snoozeX = W - topMargin - snoozeW;

            _snoozeHitbox = [snoozeX, rowTopBtn, hitboxSize];
            dc.drawBitmap2(snoozeX, rowTopBtn, _snoozeIcon, { :tintColor => Colors.TEAL_LITE });
        }

        // ── Footer bubbles ───────────────────────────────────────
        dc.setColor(Colors.PURPLE_DARK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(W * 0.25, bubbleY, bubbleRadius);

        dc.setColor(Colors.TEAL_DARK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(W * 0.75, bubbleY, bubbleRadius);

        // ── Dynamic footer pill ──────────────────────────────────
        var outlineColor = Graphics.COLOR_TRANSPARENT;
        var footerText = "";
        var textColor = Graphics.COLOR_WHITE;

        if (showPill) {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - (pillW / 2), pillY - (pillH / 2), pillW, pillH, 17);

            if (showDismissAction) {
                outlineColor = Colors.PURPLE_LITE;
                footerText = WatchUi.loadResource(Rez.Strings.DismissAlarm);
                textColor = Graphics.COLOR_WHITE;
                _dismissPillHitbox = [cx - (pillW / 2), pillY - (pillH / 2), pillW, pillH];
            } else if (_isDismissed) {
                if (_podcastReady) {
                    outlineColor = Colors.PURPLE_LITE;
                    footerText = WatchUi.loadResource(Rez.Strings.PodcastReady);
                } else {
                    outlineColor = Colors.GRAY_MID;
                    footerText = WatchUi.loadResource(Rez.Strings.PodcastLoading);
                }

                _dismissPillHitbox = [0, 0, 0, 0];
            }

            dc.setPenWidth(2);
            dc.setColor(outlineColor, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(cx - (pillW / 2), pillY - (pillH / 2), pillW, pillH, 17);

            dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                cx,
                pillY,
                Graphics.FONT_XTINY,
                footerText,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }
    }
}
