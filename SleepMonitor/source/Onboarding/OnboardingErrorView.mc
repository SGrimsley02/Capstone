/*
Name: source/OnboardingErrorDelegate.mc
Description: View for displaying an error message to the user when we are unable to obtain the username for their REMix account.
Authors: Lauren D'Souza
Created: April 20, 2026
Last Modified: April 20, 2026
*/

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Math;
import ThemeHelpers;

class OnboardingErrorView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onLayout(dc) {
        // No layout file needed — drawn manually
    }

    function onUpdate(dc) {
        var width  = dc.getWidth();
        var height = dc.getHeight();
        var cx     = width / 2;

        var bgColor = ThemeHelpers.getColor("bg");
        dc.setColor(bgColor, bgColor);
        dc.clear();

        // Responsive Y positions to prevent overlap on smaller displays.
        var iconY = (height * 0.25).toNumber();
        var titleY = (height * 0.4).toNumber();
        var bodyTopY = (height * 0.5).toNumber();
        var bodyAreaHeight = (height * 0.30).toNumber();
        var bodyCenterY = bodyTopY + (bodyAreaHeight / 2);
        var bodyMaxWidth = (width * 0.84).toNumber();
        var bodyText = WatchUi.loadResource(Rez.Strings.onboarding_error_body);
        var fittedBodyText = Graphics.fitTextToArea(bodyText, Graphics.FONT_XTINY, bodyMaxWidth, bodyAreaHeight, true);
        if (fittedBodyText == null) {
            fittedBodyText = bodyText;
        }

        // Keep icon proportional and bounded for tiny/large screens.
        var iconRadius = ((width < height ? width : height) * 0.11).toNumber();
        if (iconRadius < 12) { iconRadius = 12; }
        if (iconRadius > 20) { iconRadius = 20; }

        dc.setColor(ThemeHelpers.getColor("onboarding_error_icon_bg"), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, iconY, iconRadius);

        dc.setColor(ThemeHelpers.getColor("onboarding_error_icon_fg"), Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            cx,
            iconY,
            Graphics.FONT_SMALL,
            "!",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // --- Title ---
        dc.setColor(ThemeHelpers.getColor("onboarding_error_title"), Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            cx,
            titleY,
            Graphics.FONT_MEDIUM,
            WatchUi.loadResource(Rez.Strings.onboarding_error_title),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // --- Body text (two lines to fit small screens) ---
        dc.setColor(ThemeHelpers.getColor("onboarding_error_body"), Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            cx,
            bodyCenterY,
            Graphics.FONT_XTINY,
            fittedBodyText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}