/*
Name: source/SleepMonitorHttpClient.mc
Description: Networking client for the SleepMonitor Connect IQ watch app.
             Wraps Communications.makeWebRequest() for DEV test calls (GET local, GET public HTTPS,
             POST simulated sleep payload) and updates the UI with status messages.
Authors: Audrey Pan, Lauren D'Souza
Created: February 14, 2026
Last Modified: March 1st, 2026

PLEASE READ:
- CURRENTLY CODE:
  - Provides local HTTP + public HTTPS + POST test paths triggered manually from menu items.
  - Sends simulated/hardcoded sleep data.
- LATER IMPLEMENT:
  - Remove local HTTP test flows and menu items.
  - Add batching/streaming logic (automatic background sends) instead of manual menu-triggered POST.
*/

import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

// URL to AWS API Gateway endpoint
const BASE_URL = "https://kyajhve0ek.execute-api.us-east-2.amazonaws.com/dev/";
const USER_ID_KEY = "user_id";

class SleepMonitorHttpClient {

    private var _wakeAlarmManager; // Reference to the alarm manager for potential future use (e.g., triggering podcast status checks)

    function initialize() {
        _wakeAlarmManager = new WakeAlarmManager(); 
        // Purpose: Construct the HTTP client (no state needed currently).
    }

    function sendLocalHttpRequest() as Void {
        // GET request to a local server (mainly useful in simulator/dev).
        // TODO: remove this path and its menu item.
        var url = "http://127.0.0.1:5000/";
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN,
            :context => "LOCAL_HTTP"
        };

        makeRequest(url, null, options);
    }

    function sendPublicHttpsRequest(url as String) as Void {
        // GET request to the ngrok public HTTPS URL (proves HTTPS works).
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            :context => "PUBLIC_HTTPS",
            :timeout      => 15,
        };

        makeRequest(url, null, options);
    }

    function sendSleepSummaryRequest() as Void {
        // POST request that sends a nightly summary for the last sleep window.
        var url = BASE_URL + "sleep-summary";

        var userId = getUserId();
        if (userId == null) {
            userId = "demo"; // TODO: Replace with proper error handling. Just use demo id for now since we don't get the userId.
        }

        var params = SleepAnalyzer.buildSleepPayload(userId);
        if (params != null && _wakeAlarmManager != null) {
            _wakeAlarmManager.scheduleAlarmFromSleepPayload(params);
        }

        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN,
            :context => "SLEEP_SUMMARY",
            :headers => {
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED,
                "Accept" => "text/plain"
            }
        };

        if (params == null) {
            // TODO replace with proper error handling once we have real sleep data
            params = {
                "eventType" => "sleep_summary",
                "timestamp" => "",
                "username" => "demo",
                "sleepQuality" => 0
            };
            System.println("No applicable sensor history could be extracted for sleep window.");
        }

        System.println("POST sleep summary: " + params.toString());
        makeRequest(url, params, options);
    }

    private function makeRequest(
        url as String,
        params as Dictionary or Null,
        options as Dictionary
    ) as Void {
        // shared wrapper around Communications.makeWebRequest() that adds error handling and UI status updates.
        try {
            options[:contentType] = Communications.REQUEST_CONTENT_TYPE_JSON;
            setStatus("Sending " + options[:context].toString());
            System.println("Sending request: " + options[:context] + " -> " + url);
            System.println("About to call makeWebRequest");
            Communications.makeWebRequest(url, params, options, method(:onReceive));
        } catch (ex) {
            // catch setup errors before request completes
            setStatus("Setup failed");
            System.println("Request setup failed: " + ex.toString());
        }
    }

    function onReceive(
        responseCode as Number,
        data as Dictionary or String or PersistedContent.Iterator or Null,
        context as Object
    ) as Void {
        //handle HTTP/web responses and update the on-screen status.
        var label = context.toString();
        if (responseCode == 200) {
            setStatus(label + " ok");
            //response body may come back as Dictionary, String, Iterator, null
            if (data instanceof Dictionary) {
                System.println(label + " success. JSON response: " + data.toString());
            } else if (data != null) {
                System.println(label + " success. Body: " + data.toString());
            } else {
                System.println(label + " success with empty body.");
            }
        } else {
            setStatus(label + " err " + responseCode.toString());
            System.println(label + " failed. Response code: " + responseCode.toString());
        }
    }

    private function setStatus(message as String) as Void {
        //store status in-memory and request a UI redraw
        getApp().setHttpStatus(message);
        WatchUi.requestUpdate();
    }

    function setUserId(userId as String) as Void {
        Application.Storage.setValue(USER_ID_KEY, userId);
    }

    private function getUserId() as String or Null {
        return Application.Storage.getValue(USER_ID_KEY) as String?;
    }

    function scheduleAlarmFromSleepPayload(payload as Dictionary) as Void {
        if (payload == null) {
            System.println("WakeAlarmManager: no sleep payload provided");
            return;
        }

        var wakeEpoch = null;

        var recommended = payload.get("recommendedHandoffEpochSec");
        var fallback = payload.get("fallbackHandoffEpochSec");

        if (recommended != null) {
            wakeEpoch = recommended;
            System.println("WakeAlarmManager: using recommended handoff epoch " + wakeEpoch);
        } else if (fallback != null) {
            wakeEpoch = fallback;
            System.println("WakeAlarmManager: using fallback handoff epoch " + wakeEpoch);
        }

        if (wakeEpoch == null) {
            System.println("WakeAlarmManager: no handoff epoch found in payload");
            return;
        }

        _wakeAlarmManager.scheduleAlarmAtEpoch(wakeEpoch);
    }
}
