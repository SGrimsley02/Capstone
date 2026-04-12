/*
Name: source/utils/MenuHelpers.mc
Description: Shared UI layout for all menus (User Menu, Theme Menu, etc.)
Authors: Audrey Pan
Created: April 7, 2026
Last Modified: April 9, 2026
*/  

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.Math;

module MenuHelpers {

    // ── Base Background ────────────────────────────────────
    function drawMenuBackground(dc as Dc) as Void {
        var bgColor = ThemeHelpers.getColor("bg");
        dc.setColor(bgColor, bgColor);
        dc.clear();
    }

    // ── Header Overlay / Mask ──────────────────────────────
    function drawHeaderOverlay(dc as Dc) as Void {
        var W = dc.getWidth();
        var H = dc.getHeight();
        var bgColor = ThemeHelpers.getColor("bg");

        // Opaque mask so scrolling rows pass "behind" the header area
        dc.setColor(bgColor, bgColor);
        dc.fillRectangle(0, 0, W, (H * 0.26).toNumber());

        // Redraw the divider at the bottom of the header band
        dc.setPenWidth(3);
        dc.setColor(ThemeHelpers.getColor("menu_line"), Graphics.COLOR_TRANSPARENT);
        dc.drawLine((W * 0.05).toNumber(), (H * 0.26).toNumber(), (W * 0.95).toNumber(), (H * 0.26).toNumber());
    }

    // ── Header Text Layer ──────────────────────────────────
    function drawHeaderText(dc as Dc, title as String) as Void {
        var W = dc.getWidth();
        var H = dc.getHeight();
        var cx = W / 2;

        dc.setColor(ThemeHelpers.getColor("menu_title"), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (H * 0.12).toNumber(), Graphics.FONT_SMALL, title, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var dateTimeColor = ThemeHelpers.getColor("menu_date_time");
        dc.setColor(dateTimeColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText((W * 0.28).toNumber(), (H * 0.22).toNumber(), Graphics.FONT_XTINY, _getTimeString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText((W * 0.72).toNumber(), (H * 0.22).toNumber(), Graphics.FONT_XTINY, _getDateString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ── Compatibility Wrapper ──────────────────────────────
    function drawHeader(dc as Dc, title as String) as Void {
        drawMenuBackground(dc);
        drawHeaderOverlay(dc);
        drawHeaderText(dc, title);
    }

    // ── Draw Selection Highlight at Explicit Y ─────────────
    function drawSelectionHighlightAtY(dc as Dc, y as Number) as Void {
        var W = dc.getWidth();
        var H = dc.getHeight();
        var rowHeight = (H * 0.16).toNumber();

        dc.setColor(ThemeHelpers.getColor("menu_selection"), Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle((W * 0.06).toNumber(), y + 3, (W * 0.88).toNumber(), rowHeight - 6, 10);
    }

    function drawSelectionHighlight(dc as Dc, index as Number, itemCount as Number) as Void {
        // If Exit is selected, do not draw a row highlight
        if (index >= itemCount) {
            return;
        }

        var H = dc.getHeight();
        var rowTop = (H * 0.28).toNumber();
        var rowHeight = (H * 0.16).toNumber();
        var y = rowTop + (index * rowHeight);
        drawSelectionHighlightAtY(dc, y);
    }

    // ── Compatibility Row Draw ─────────────────────────────
    function drawMenuRow(dc as Dc, index as Number, text as String, icon as BitmapReference?, iconColor as Number) as Void {
        var H = dc.getHeight();
        var rowTop = (H * 0.28).toNumber();
        var rowHeight = (H * 0.16).toNumber();
        var y = rowTop + (index * rowHeight);
        drawMenuRowAtY(dc, text, icon, iconColor, y, true);
    }

    // ── Draw Row at Explicit Y ─────────────────────────────
    function drawMenuRowAtY(dc as Dc, text as String, icon as BitmapReference?, iconColor as Number, y as Number, drawDivider as Boolean) as Void {
        var W = dc.getWidth();
        var H = dc.getHeight();
        var rowHeight = (H * 0.16).toNumber();

        var iconX = (W * 0.10).toNumber();
        var textX = (W * 0.26).toNumber();

        dc.setColor(ThemeHelpers.getColor("menu_text"), Graphics.COLOR_TRANSPARENT);
        dc.drawText(textX, (y + rowHeight / 2).toNumber(), Graphics.FONT_SMALL, text, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        if (icon != null) {
            dc.drawBitmap2(iconX, (y + rowHeight * 0.23).toNumber(), icon, { :tintColor => iconColor });
        }

        if (drawDivider) {
            dc.setPenWidth(2);
            dc.setColor(ThemeHelpers.getColor("menu_line"), Graphics.COLOR_TRANSPARENT);
            dc.drawLine((W * 0.08).toNumber(), (y + rowHeight).toNumber(), (W * 0.92).toNumber(), (y + rowHeight).toNumber());
        }
    }

    // ── Draw Wave Footer & Exit ─────────────────────────────
    function drawFooter(dc as Dc, selectedIndex as Number, itemCount as Number) as Void {
        var W = dc.getWidth();
        var H = dc.getHeight();
        var cx = W / 2;
        var cy = H / 2;
        var baseY = (H * 0.72).toNumber();
        var bgColor = ThemeHelpers.getColor("bg");

        // Opaque footer background so rows pass behind it
        dc.setColor(bgColor, bgColor);
        dc.fillRectangle(0, baseY.toNumber(), W, H - baseY.toNumber());

        _drawWave(dc, W, baseY,      15.0, 3.0, ThemeHelpers.getColor("menu_wave1"), 8);
        _drawWave(dc, W, baseY + 9,  15.0, 3.0, ThemeHelpers.getColor("menu_wave2"), 8);

        dc.setColor(ThemeHelpers.getColor("menu_wave2"), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(12);
        dc.drawArc(cx, cy, (W / 2) - 6, Graphics.ARC_COUNTER_CLOCKWISE, 213, 335);

        var isExitSelected = (selectedIndex == itemCount);
        dc.setColor(
            isExitSelected ? ThemeHelpers.getColor("menu_exit_active") : ThemeHelpers.getColor("menu_exit_resting"),
            Graphics.COLOR_TRANSPARENT
        );
        dc.drawText(
            cx,
            (H * 0.86).toNumber(),
            isExitSelected ? Graphics.FONT_SMALL : Graphics.FONT_XTINY,
            "EXIT MENU",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    // ── Internal Helpers ───────────────────────────────────
    function _drawWave(dc as Dc, width as Number, baseY as Number, amplitude as Float, cycles as Float, color as Number, thickness as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(thickness);

        var prevX = 0;
        var prevY = baseY + (Math.sin(0.0) * amplitude);

        for (var x = 4; x <= width; x += 4) {
            var angle = (x.toFloat() / width.toFloat()) * cycles * 2.0 * Math.PI;
            var y = baseY + (Math.sin(angle) * amplitude);
            dc.drawLine(prevX, prevY.toNumber(), x, y.toNumber());
            prevX = x;
            prevY = y;
        }
    }

    function _getTimeString() as String {
        var ct = System.getClockTime();
        var hour = ct.hour;
        var amPm = "";

        if (!System.getDeviceSettings().is24Hour) {
            if (hour == 0) {
                hour = 12;
                amPm = " AM";
            } else if (hour < 12) {
                amPm = " AM";
            } else if (hour == 12) {
                amPm = " PM";
            } else {
                hour -= 12;
                amPm = " PM";
            }
        }

        return Lang.format("$1$:$2$$3$", [hour.format("%d"), ct.min.format("%02d"), amPm]);
    }

    function _getDateString() as String {
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        return Lang.format("$1$, $2$ $3$", [info.day_of_week, info.month, info.day]);
    }
}