/*
Name: source/utils/MenuHelpers.mc
Description: Shared UI layout for all menus (User Menu, Theme Menu, etc.)
Authors: Audrey Pan
Created: April 7, 2026
Last Modified: April 7, 2026
*/  

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.Math;

module MenuHelpers {

    // ── Color Palette ────────────────────────────────────────
    const COLOR_TEAL_DARK  = 0x0F5961; 
    const COLOR_TEAL_LIGHT = 0x008080; 
    const COLOR_CORAL      = 0xFF6A5C; 
    const COLOR_GREY_LIGHT = 0xDCDCDC; 
    const COLOR_BLUE_MIST  = 0xEAF4F5; 
    const COLOR_BROWN_ICON = 0x9B8A78; 
    const COLOR_WHITE      = 0xFFFFFF; 
    const COLOR_BLACK      = 0x000000; 

    // ── Draw Background & Header ───────────────────────────
    function drawHeader(dc as Dc, title as String) as Void {
        var W = dc.getWidth();
        var H = dc.getHeight();
        var cx = W / 2;

        dc.setColor(COLOR_WHITE, COLOR_WHITE);
        dc.clear();

        dc.setColor(COLOR_TEAL_DARK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (H * 0.12).toNumber(), Graphics.FONT_SMALL, title, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.drawText((W * 0.28).toNumber(), (H * 0.22).toNumber(), Graphics.FONT_XTINY, _getTimeString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText((W * 0.72).toNumber(), (H * 0.22).toNumber(), Graphics.FONT_XTINY, _getDateString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setPenWidth(3);
        dc.setColor(COLOR_GREY_LIGHT, Graphics.COLOR_TRANSPARENT);
        dc.drawLine((W * 0.05).toNumber(), (H * 0.26).toNumber(), (W * 0.95).toNumber(), (H * 0.26).toNumber());
    }

    // ── Draw Selection Highlight ────────────────────────────
    function drawSelectionHighlight(dc as Dc, index as Number) as Void {
        var W = dc.getWidth();
        var H = dc.getHeight();
        var row1Top = (H * 0.28).toNumber();
        var rowHeight = (H * 0.16).toNumber();
        
        if (index < 2) {
            var highlightY = (index == 0) ? row1Top : (row1Top + rowHeight).toNumber();
            dc.setColor(COLOR_BLUE_MIST, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle((W * 0.06).toNumber(), highlightY + 3, (W * 0.88).toNumber(), rowHeight - 6, 10);
        }
    }

    // ── Draw Row ───────────────────────────────────────────
    function drawMenuRow(dc as Dc, index as Number, text as String, icon as BitmapReference?, iconColor as Number) as Void {
        var W = dc.getWidth();
        var H = dc.getHeight();
        var row1Top = (H * 0.28).toNumber();
        var rowHeight = (H * 0.16).toNumber();
        var currentY = row1Top + (index * rowHeight);
        
        var iconX = (W * 0.10).toNumber();  
        var textX = (W * 0.26).toNumber();

        dc.setColor(COLOR_TEAL_DARK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(textX, (currentY + rowHeight / 2).toNumber(), Graphics.FONT_SMALL, text, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        
        if (icon != null) { 
            dc.drawBitmap2(iconX, (currentY + rowHeight * 0.23).toNumber(), icon, { :tintColor => iconColor }); 
        }

        dc.setPenWidth(2);
        dc.setColor(COLOR_GREY_LIGHT, Graphics.COLOR_TRANSPARENT);
        dc.drawLine((W * 0.08).toNumber(), (currentY + rowHeight).toNumber(), (W * 0.92).toNumber(), (currentY + rowHeight).toNumber());
    }

    // ── Draw Wave Footer & Exit ─────────────────────────────
    function drawFooter(dc as Dc, selectedIndex as Number) as Void {
        var W = dc.getWidth();
        var H = dc.getHeight();
        var cx = W / 2;
        var cy = H / 2;
        var baseY = (H * 0.72).toNumber();

        _drawWave(dc, W, baseY,      15.0, 3.0, COLOR_TEAL_LIGHT, 8); 
        _drawWave(dc, W, baseY + 9,  15.0, 3.0, COLOR_CORAL, 8); 

        dc.setColor(COLOR_CORAL, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(12);
        dc.drawArc(cx, cy, (W / 2) - 6, Graphics.ARC_COUNTER_CLOCKWISE, 213, 335);

        var isExitSelected = (selectedIndex == 2);
        dc.setColor(isExitSelected ? COLOR_CORAL : COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (H * 0.86).toNumber(), isExitSelected ? Graphics.FONT_SMALL : Graphics.FONT_XTINY, "EXIT MENU", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ── Internal Helpers (No 'private' keyword allowed here!) ──
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
            if (hour == 0) { hour = 12; amPm = " AM"; }
            else if (hour < 12) { amPm = " AM"; }
            else if (hour == 12) { amPm = " PM"; }
            else { hour -= 12; amPm = " PM"; }
        }
        return Lang.format("$1$:$2$$3$", [hour.format("%d"), ct.min.format("%02d"), amPm]);
    }

    function _getDateString() as String {
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        return Lang.format("$1$, $2$ $3$", [info.day_of_week, info.month, info.day]);
    }
}