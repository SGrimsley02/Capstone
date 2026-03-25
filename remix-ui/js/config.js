/**
  * config.js - Configuration constants for the Remix dashboard
  * This file contains constants used throughout the application.
  * Authors: Kiara Rose
  * Created: March 24, 2026
  * Last updated: March 25, 2026
*/

export const LS_SESSION = "remix_session_v1";
export const API_BASE = "https://kyajhve0ek.execute-api.us-east-2.amazonaws.com/dev";
export const FRONTEND_BASE = `${window.location.origin}/remix-ui/`;

export const DEFAULT_NEWS_SOURCES = [ // Default news sources if none picked
  "NY Times",
  "BBC News",
  "The Guardian",
  "Al Jazeera",
  "TechRadar",
  "Time Magazine",
  "Yahoo Sports",
  "Not Boring"
];
