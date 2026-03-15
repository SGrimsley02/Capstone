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
import Toybox.System;

// --- GLOBAL THEME CONSTANTS ---
const PURPLE_MID  = 0x7B5EA7;
const PURPLE_LITE = 0xB39DDB;
const PURPLE_DARK = 0x2D1B4E;
const TEAL_LITE   = 0x4FC3F7;
const TEAL_DARK   = 0x0D2B3E;
const GRAY_MID    = 0x9E9E9E;
const SUNSET_ROSE = 0xFF8A80; 

class AlarmView extends WatchUi.View {

    var _statusText = "WAKE UP!"; // Current UI state shown in the center area (e.g., "WAKE UP!", "ALARM OFF")
    var _isDismissed = false;  // True once the alarm has been handled (dismissed / music / podcast)
    var _snoozeTimeRemaining = 0; // Snooze countdown in seconds (0 means not snoozing)
    var _manager; // Reference to the alarm manager for potential future use (e.g., showing next alarm time)
    var _podcastReady = false; // Podcast becomes active when a link is available

    //Drawable icons
    var _music_icon;
    var _podcast_icon;
    var _snooze_icon;
    var _dismiss_icon;
    private var _remixLogo;

    //Hitbox!
    var _podcastHitbox = [0, 0, 0]; // [x, y, size]
    var _musicHitbox   = [0, 0, 0];
    var _snoozeHitbox  = [0, 0, 0];
    var _dismissPillHitbox = [0, 0, 0];
    var _dismissIconHitbox = [0, 0, 0];

    function initialize() {
        WatchUi.View.initialize();
        _music_icon = loadResource(Rez.Drawables.musicIcon);
        _podcast_icon = loadResource(Rez.Drawables.podcastIcon);
        _snooze_icon = loadResource(Rez.Drawables.snoozeIcon);
        _dismiss_icon = loadResource(Rez.Drawables.dismissIcon);
        _remixLogo = loadResource(Rez.Drawables.remixLogo);
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

    function setPodcastReady(isReady) {
        _podcastReady = isReady;
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
        var hitboxSize = 45;

        // Layout rows
        var rowTime   = H * 0.30;
        var rowTopBtn = H * 0.38;
        var rowMid    = H * 0.54;
        var rowBotBtn = H * 0.64;
        
        // adjusted margins for curved screen
        var botMargin = W * 0.07;
        var topMargin = W * 0.03;


        // Clear background
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Use the shared UI helpers
        UIHelpers.drawBranding(dc, cx, H, _remixLogo);
        UIHelpers.drawClock(dc, cx, rowTime.toNumber(), Graphics.FONT_NUMBER_MEDIUM);

        // 2. Center State
        if (_snoozeTimeRemaining > 0) {
            dc.setColor(TEAL_LITE, Graphics.COLOR_TRANSPARENT);
            var mins = _snoozeTimeRemaining / 60;
            var secs = _snoozeTimeRemaining % 60;
            dc.drawText(cx, rowMid, Graphics.FONT_MEDIUM, 
                        Lang.format("$1$:$2$", [mins, secs.format("%02d")]), 
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        } else {
            var statusColor = _isDismissed ? PURPLE_LITE : TEAL_LITE;
            dc.setColor(statusColor, Graphics.COLOR_TRANSPARENT);
            
            var font = (_statusText.length() > 10) ? Graphics.FONT_XTINY : Graphics.FONT_TINY;
            dc.drawText(cx, rowMid, font, _statusText, 
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // 3. Media Labels (PODCAST turns WHITE when ready)
        // PODCAST 
        var podColor = _podcastReady ? PURPLE_LITE : GRAY_MID;
        _podcastHitbox = [topMargin, rowTopBtn, hitboxSize];
        dc.drawBitmap2(topMargin, rowTopBtn, _podcast_icon, { :tintColor => podColor });

        // MUSIC
        _musicHitbox = [botMargin, rowBotBtn, hitboxSize];
        dc.drawBitmap2(botMargin, rowBotBtn, _music_icon, { :tintColor => PURPLE_MID });

        //DISMISS
            var dW = _dismiss_icon.getWidth();
            var dX = W - botMargin - dW;
            _dismissIconHitbox = [dX, rowBotBtn, hitboxSize];
            dc.drawBitmap2(dX, rowBotBtn, _dismiss_icon, { :tintColor => TEAL_LITE });

 // --- 4) Alarm Controls & Dynamic Footer ---
        
        // Bubbles (Persistent background)
        var bubbleRadius = W * 0.50;
        var bubbleY = H * 1.30;
        dc.setColor(PURPLE_DARK, Graphics.COLOR_TRANSPARENT); 
        dc.fillCircle(W * 0.25, bubbleY, bubbleRadius); 
        dc.setColor(TEAL_DARK, Graphics.COLOR_TRANSPARENT); 
        dc.fillCircle(W * 0.75, bubbleY, bubbleRadius); 

        var pillY = H * 0.90;
        var pillW = W * 0.53; // Perfect fit for the curve!
        var pillH = 34;

        // Logic: Show "Dismiss" if it's ringing OR if it's currently snoozing
        var showDismissAction = (!_isDismissed || _snoozeTimeRemaining > 0); 
        
        // 1. Draw the SNOOZE icon ONLY if alarm is actively ringing
        if (!_isDismissed && _snoozeTimeRemaining <= 0) {
            var snoozeW = _snooze_icon.getWidth();
            _snoozeHitbox = [W - topMargin - snoozeW, rowTopBtn, hitboxSize];
            dc.drawBitmap2(W - topMargin - snoozeW, rowTopBtn, _snooze_icon, { :tintColor => TEAL_LITE });
        }

        // --- 2. THE DYNAMIC PILL ---
        // 1. Declare and initialize here
        var outlineColor = Graphics.COLOR_TRANSPARENT;
        var footerText = "";
        var textColor = Graphics.COLOR_WHITE;
        var showPill = (showDismissAction || (_isDismissed && _podcastReady ));

        if (showPill) {
            
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - (pillW/2), pillY - (pillH/2), pillW, pillH, 17);

            if (showDismissAction) {
                outlineColor = PURPLE_LITE;
                footerText   = "CLICK TO DISMISS";
                textColor    = Graphics.COLOR_WHITE;
                _dismissPillHitbox = [cx - (pillW/2), pillY - (pillH/2), pillW, pillH];
            } 
            else if (_isDismissed && _podcastReady) {
                outlineColor = GRAY_MID;
                footerText   = "PODCAST READY";
                textColor    = Graphics.COLOR_WHITE;
                _dismissPillHitbox = [0,0,0,0];
            }

            dc.setPenWidth(2);
            dc.setColor(outlineColor, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(cx - (pillW/2), pillY - (pillH/2), pillW, pillH, 17);

            dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, pillY, Graphics.FONT_XTINY, footerText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}