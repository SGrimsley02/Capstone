import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;

module UIHelpers {

    // ── Shared Branding ──────────────────────────────────────────
    function drawBranding(dc as Graphics.Dc, cx as Number, H as Number, logo as Graphics.BitmapReference?) as Void {
        if (logo != null) {
            var logoW = logo.getWidth();
            // Standardize logo at 4% height
            dc.drawBitmap2(cx - logoW / 2, (H * 0.04).toNumber(), logo, {:tintColor => 0xB39DDB}); // PURPLE_LITE
        } else {
            dc.setColor(0xB39DDB, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (H * 0.10).toNumber(), Graphics.FONT_TINY, "REMix", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // ── Shared Clock ─────────────────────────────────────────────
    function drawClock(dc as Graphics.Dc, cx as Number, y as Number, font as Graphics.FontDefinition) as Void {
        var ct = System.getClockTime();
        var hour = ct.hour;
        var amPm = "";
        var use12h = !System.getDeviceSettings().is24Hour;

        if (use12h) {
            if      (hour == 0)  { hour = 12; amPm = "AM"; }
            else if (hour < 12)  { amPm = "AM"; }
            else if (hour == 12) { amPm = "PM"; }
            else                 { hour -= 12; amPm = "PM"; }
        }

        var timeStr = Lang.format("$1$:$2$", [hour.format("%d"), ct.min.format("%02d")]);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, font, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (use12h && amPm.length() > 0) {
            dc.setColor(0x9E9E9E, Graphics.COLOR_TRANSPARENT); // GRAY_MID
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