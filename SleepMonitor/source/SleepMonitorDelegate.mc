import Toybox.Lang;
import Toybox.WatchUi;

class SleepMonitorDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onMenu() as Boolean {
        WatchUi.pushView(new Rez.Menus.MainMenu(), new SleepMonitorMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

}