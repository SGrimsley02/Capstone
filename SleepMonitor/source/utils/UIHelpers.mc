/*
Name: source/utils/UIHelpers.mc
Description: UI helper functions for the SleepMonitor Connect IQ app.
Authors: Kiara Rose, Audrey Pan
Created: March 24, 2026
Last Modified: March 24, 2026
*/

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

module UIHelpers {

    // ── Shared Branding ──────────────────────────────────────────
    function drawBranding(dc as Graphics.Dc, cx as Number, H as Number, logo as Graphics.BitmapReference?) as Void {
        if (logo != null) {
            var logoW = logo.getWidth();
            // Standardize logo at 4% height
            dc.drawBitmap2(cx - logoW / 2, (H * 0.04).toNumber(), logo, {:tintColor => ThemeHelpers.getColor("3rdAccent")}); // PURPLE_LITE
        } else {
            dc.setColor(ThemeHelpers.getColor("3rdAccent"), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (H * 0.10).toNumber(), Graphics.FONT_TINY, WatchUi.loadResource(Rez.Strings.AppName), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // ── Shared Clock ─────────────────────────────────────────────
    function drawClock(dc as Graphics.Dc, cx as Number, y as Number, font as Graphics.FontDefinition) as Void {
        var ct = System.getClockTime();
        var hour = ct.hour;
        var amPm = "";
        var use12h = !System.getDeviceSettings().is24Hour;

        if (use12h) {
            if      (hour == 0)  { hour = 12; amPm = WatchUi.loadResource(Rez.Strings.AM); }
            else if (hour < 12)  { amPm = WatchUi.loadResource(Rez.Strings.AM); }
            else if (hour == 12) { amPm = WatchUi.loadResource(Rez.Strings.PM); }
            else                 { hour -= 12; amPm = WatchUi.loadResource(Rez.Strings.PM); }
        }

        var timeStr = Lang.format("$1$:$2$", [hour.format("%d"), ct.min.format("%02d")]);

        dc.setColor(ThemeHelpers.getColor("primaryText"), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, font, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (use12h && amPm.length() > 0) {
            dc.setColor(ThemeHelpers.getColor("secondaryText"), Graphics.COLOR_TRANSPARENT); // GRAY_MID
            dc.drawText(
                (cx + dc.getWidth() * 0.23).toNumber(),
                (y - dc.getHeight() * 0.03).toNumber(),
                Graphics.FONT_XTINY,
                amPm,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }
    }
    
}