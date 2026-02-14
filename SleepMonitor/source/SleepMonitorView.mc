/*
Name: source/SleepMonitorView.mc
Description: Primary UI view for the SleepMonitor Connect IQ watch app.
             Displays the main layout and renders the current HTTP status
             message returned from network requests.
Authors: Kiara Rose
Created: February 7, 2026
Last Modified: February 7, 2026
*/

import Toybox.Graphics;
import Toybox.WatchUi;

class SleepMonitorView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.MainLayout(dc));
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {
        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {
    }

}
