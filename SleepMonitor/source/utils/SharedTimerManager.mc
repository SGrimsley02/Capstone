/*
Name: source/Timer/SharedTimerManager.mc
Description: Shared master timer manager for short in-app recurring and one-shot work.
             Uses a single 1-second repeating Timer.Timer and dispatches logical tasks
             based on per-task counters.
Authors: Audrey Pan
Created: April 22, 2026
Last Modified: April 22, 2026
*/

import Toybox.Timer;
import Toybox.Lang;
import Toybox.System;

class SharedTimerManager {

    private const MASTER_TICK_MS = 1000;

    private var _masterTimer as Timer.Timer?;
    private var _tasks as Array;

    function initialize() {
        _masterTimer = null;
        _tasks = [];
    }

    function registerRepeatingTask(taskId as String, intervalSec as Number, callback as Method) as Void {
        unregisterTask(taskId);

        _tasks.add({
            :id => taskId,
            :intervalSec => intervalSec,
            :elapsedSec => 0,
            :repeat => true,
            :callback => callback
        });

        _ensureMasterTimerRunning();
    }

    function registerOneShotTask(taskId as String, delaySec as Number, callback as Method) as Void {
        unregisterTask(taskId);

        _tasks.add({
            :id => taskId,
            :intervalSec => delaySec,
            :elapsedSec => 0,
            :repeat => false,
            :callback => callback
        });

        _ensureMasterTimerRunning();
    }

    function unregisterTask(taskId as String) as Void {
        for (var i = _tasks.size() - 1; i >= 0; i -= 1) {
            var task = _tasks[i] as Dictionary;
            if ((task[:id] as String).equals(taskId)) {
                _tasks.remove(i);
            }
        }

        if (_tasks.size() == 0) {
            _stopMasterTimer();
        }
    }

    function clearAllTasks() as Void {
        _tasks = [];
        _stopMasterTimer();
    }

    private function _ensureMasterTimerRunning() as Void {
        if (_masterTimer != null) {
            return;
        }

        _masterTimer = new Timer.Timer();
        _masterTimer.start(method(:_onMasterTick), MASTER_TICK_MS, true);
    }

    private function _stopMasterTimer() as Void {
        if (_masterTimer != null) {
            _masterTimer.stop();
            _masterTimer = null;
        }
    }

    function _onMasterTick() as Void {
        var oneShotIdsToRemove = [];

        for (var i = 0; i < _tasks.size(); i += 1) {
            var task = _tasks[i] as Dictionary;
            var elapsed = task[:elapsedSec] as Number;
            var interval = task[:intervalSec] as Number;
            var repeatTask = task[:repeat] as Boolean;
            var callback = task[:callback] as Method;
            var taskId = task[:id] as String;

            elapsed += 1;
            task[:elapsedSec] = elapsed;

            if (elapsed >= interval) {
                callback.invoke();

                if (repeatTask) {
                    task[:elapsedSec] = 0;
                } else {
                    oneShotIdsToRemove.add(taskId);
                }
            }
        }

        for (var j = 0; j < oneShotIdsToRemove.size(); j += 1) {
            unregisterTask(oneShotIdsToRemove[j] as String);
        }

        if (_tasks.size() == 0) {
            _stopMasterTimer();
        }
    }
}