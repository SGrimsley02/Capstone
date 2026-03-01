/*
Name: source/SleepMonitorHttpClient.mc
Description: Networking client for the SleepMonitor Connect IQ watch app.
             Wraps Communications.makeWebRequest() for DEV test calls (GET local, GET public HTTPS,
             POST simulated sleep payload) and updates the UI with status messages.
Authors: Audrey Pan
Created: February 14, 2026
Last Modified: February 14, 2026

PLEASE READ:
- CURRENTLY CODE:
  - Uses a temporary ngrok HTTPS base URL to reach a local Python server.
  - Adds header: "ngrok-skip-browser-warning" => "true" (required for ngrok convenience behavior).
  - Provides local HTTP + public HTTPS + POST test paths triggered manually from menu items.
  - Sends simulated/hardcoded sleep data.
- LATER IMPLEMENT:
  - Replace ngrok base URL with a real backend HTTPS endpoint.
  - Remove ngrok-specific header.
  - Remove local HTTP test flows and menu items.
  - Potentially switch POST body from form-urlencoded to JSON.
  - Add batching/streaming logic (automatic background sends) instead of manual menu-triggered POST.
*/

import Toybox.Communications;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;
import Toybox.WatchUi;

// ngrok URL that forwards to your local Python server
//TODO: replace with real backend HTTPS endpoint
const BASE_URL = "https://unfemale-ingeborg-hyperscholastically.ngrok-free.dev/";

class SleepMonitorHttpClient {

    function initialize() {
        // Purpose: Construct the HTTP client (no state needed currently).
    }

    function sendLocalHttpRequest() as Void {
        // GET request to a local server (mainly useful in simulator/dev).
        // TODO: remove this path and its menu item.
        var url = "http://127.0.0.1:3000/";
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN,
            :context => "LOCAL_HTTP"
        };

        makeRequest(url, null, options);
    }

    function sendPublicHttpsRequest() as Void {
        // GET request to the ngrok public HTTPS URL (proves HTTPS works).
        var url = BASE_URL;
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN,
            :context => "PUBLIC_HTTPS",
            :headers      => {
                "ngrok-skip-browser-warning" => "true",
                "Accept" => "text/plain"
            },
            :timeout      => 15,
        };

        makeRequest(url, null, options);
    }

    function sendPostTestRequest() as Void {
        // POST request that sends simulated sleep data to the backend.
        // TODO: replace URL, remove ngrok header
        var url = BASE_URL + "upload";
        var params = buildSleepPayload();

        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN,
            :context => "SLEEP_POST",
            :headers => {
                // With a Dictionary params + POST, the SDK sends a form-urlencoded body.
                // TODO: if backend expects JSON, change Content-Type and send JSON string instead.
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED,
                "Accept" => "text/plain",
                //remove once backend is set up
                "ngrok-skip-browser-warning" => "true"
            }
        };

        System.println("POST payload: " + params.toString());
        makeRequest(url, params, options);
    }

    private function buildSleepPayload() as Dictionary {
        // Create simulated sleep payload values (placeholder for now)
        var now = System.getClockTime();
        var ts = now.hour.toString() + ":" + now.min.toString() + ":" + now.sec.toString();

        return {
            "eventType" => "sleep_sample",
            "timestamp" => ts,
            "heartRate" => "68",
            "sleepStage" => "light",
            "movement" => "0.02"
        };
    }

    private function makeRequest(
        url as String,
        params as Dictionary or Null,
        options as Dictionary
    ) as Void {
        // shared wrapper around Communications.makeWebRequest() that adds error handling and UI status updates.
        try {
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
}
