/*
Name: source/Menu/MenuUserView.mc
Description: Custom user menu view for the SleepMonitor Connect IQ watch app.
             Draws the user menu header, menu rows, and wave footer action.
Authors: Audrey Pan
Created: April 5, 2026
Last Modified: April 7, 2026
*/

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.Math;

class MenuUserView extends WatchUi.View {

    private var _linkIcon;
    private var _gearIcon;
    private var _remixLogo;

    private var _selectedIndex = 0;

    function initialize() {
        View.initialize();

        _linkIcon = loadResource(Rez.Drawables.linkIcon);
        _gearIcon = loadResource(Rez.Drawables.settingsIcon);
        _remixLogo = loadResource(Rez.Drawables.remixLogo);
    }

    function onLayout(dc as Dc) as Void {
        // Fully custom-drawn screen; no layout XML required
    }

    function onShow() as Void {
        WatchUi.requestUpdate();
    }

    function onHide() as Void { }

    function moveSelectionUp() as Void {
        if (_selectedIndex > 0) {
            _selectedIndex -= 1;
            WatchUi.requestUpdate();
        }
    }

    function moveSelectionDown() as Void {
        if (_selectedIndex < 2) {
            _selectedIndex += 1;
            WatchUi.requestUpdate();
        }
    }

    function getSelectedIndex() as Number {
        return _selectedIndex;
    }

    // ... (keep all your imports and class variables at the top as they were)

    function onUpdate(dc as Dc) as Void {
        var W = dc.getWidth();
        var H = dc.getHeight();
        var cx = (W / 2).toNumber();
        var cy = (H / 2).toNumber();


        // ── Background ───────────────────────────────────────────
        // Using White for the "inspiration" look
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.clear();

        // ── Title ────────────────────────────────────────────────
        dc.setColor(0x0F5961, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (H * 0.12).toNumber(), Graphics.FONT_SMALL, "USER MENU", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── Time / Date ──────────────────────────────────────────
        dc.drawText((W * 0.28).toNumber(), (H * 0.22).toNumber(), Graphics.FONT_XTINY, _getTimeString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText((W * 0.72).toNumber(), (H * 0.22).toNumber(), Graphics.FONT_XTINY, _getDateString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── Menu Rows ────────────────────────────────────────────
        var row1Top = (H * 0.28).toNumber();
        var rowHeight = (H * 0.16).toNumber();
        var row2Top = (row1Top + rowHeight).toNumber();

        var dividerLeft = (W * 0.08).toNumber(); 
        var dividerRight = (W * 0.92).toNumber(); 

        //Shifted icons a little more to the left 
        var iconX = (W * 0.10).toNumber();  
        var textX = (W * 0.26).toNumber();  

        // ── Header Divider (The new one) ────────────────────────
        dc.setPenWidth(3);
        dc.setColor(0xDCDCDC, Graphics.COLOR_TRANSPARENT);
        
        // Placed at 0.26 to sit between Date and the first Row
        dc.drawLine(
            (W * 0.05).toNumber(), 
            (H * 0.26).toNumber(), 
            (W * 0.95).toNumber(), 
            (H * 0.26).toNumber()
        );
    
        // ── Selected Row Highlight (Wider and Taller) ─────────────
        if (_selectedIndex < 2) {
            var highlightY = (_selectedIndex == 0) ? row1Top : row2Top;
            
            dc.setColor(0xEAF4F5, Graphics.COLOR_TRANSPARENT);

            // Shifting further left (W * 0.06) and increasing width (to W * 0.88)
            // Using +3 Y and -6 Height to add significant vertical padding.
            dc.fillRoundedRectangle(
                (W * 0.06).toNumber(), 
                highlightY + 3,        
                (W * 0.88).toNumber()
                rowHeight - 6, 
                10 
            );
        }

        // ── Row Content ──────────────────────────────────────────

        // Draw Row 1
        dc.setColor(0x0F5961, Graphics.COLOR_TRANSPARENT);
        dc.drawText(textX, (row1Top + rowHeight / 2).toNumber(), Graphics.FONT_SMALL, "Relink Website", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        if (_linkIcon != null) { dc.drawBitmap2(iconX, (row1Top + rowHeight * 0.23).toNumber(), _linkIcon, { :tintColor => 0x9B8A78 }); }

        // Thin divider
        dc.setPenWidth(2);
        dc.setColor(0xDCDCDC, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(dividerLeft, row2Top, dividerRight, row2Top);

        // Draw Row 2
        dc.setColor(0x0F5961, Graphics.COLOR_TRANSPARENT);
        dc.drawText(textX, (row2Top + rowHeight / 2).toNumber(), Graphics.FONT_SMALL, "UI Customization", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        if (_gearIcon != null) { dc.drawBitmap2(iconX, (row2Top + rowHeight * 0.23).toNumber(), _gearIcon, { :tintColor => 0x9B8A78 }); }

        // Thin bottom divider
        dc.setColor(0xDCDCDC, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(dividerLeft, (row2Top + rowHeight).toNumber(), dividerRight, (row2Top + rowHeight).toNumber());

        // ── Wave Footer ─────────────────────────
        var baseY = (H * 0.72).toNumber();

        _drawSinglePassWave(dc, W, baseY,      15.0, 3.0, 0x008080, 8); // Teal
        _drawSinglePassWave(dc, W, baseY + 9,  15.0, 3.0, 0xFF6A5C, 8); // Red

        // ── Bottom Footer Arc & Label ────────────────────────────
        dc.setColor(0xFF6A5C, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(12);
        dc.drawArc(cx, cy, (W / 2) - 6, Graphics.ARC_COUNTER_CLOCKWISE, 213, 335);

    
        // Determine if Exit is selected (index 2)
        var isExitSelected = (_selectedIndex == 2);
        var exitColor = isExitSelected ? 0xFF6A5C : Graphics.COLOR_BLACK;
        var exitFont = isExitSelected ? Graphics.FONT_SMALL : Graphics.FONT_XTINY;

        dc.setColor(exitColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            cx, 
            (H * 0.86).toNumber(), 
            exitFont, 
            "EXIT MENU", 
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    // Draws the wave for the bottom of the screen
    function _drawSinglePassWave(dc as Dc, width as Number, baseY as Number, amplitude as Float, cycles as Float, color as Number, thickness as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(thickness);

        var prevX = 0;
        var prevY = baseY + (Math.sin(0.0) * amplitude);

        // Increment by 4 pixels instead of 1 to save CPU; the line stays smooth
        for (var x = 4; x <= width; x += 4) {
            var angle = (x.toFloat() / width.toFloat()) * cycles * 2.0 * Math.PI;
            var y = baseY + (Math.sin(angle) * amplitude);
            dc.drawLine(prevX, prevY.toNumber(), x, y.toNumber());
            prevX = x;
            prevY = y;
        }
    }

    private function _getTimeString() as String {
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

    private function _getDateString() as String {
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        return Lang.format("$1$, $2$ $3$", [info.day_of_week, info.month, info.day]);
    }
}