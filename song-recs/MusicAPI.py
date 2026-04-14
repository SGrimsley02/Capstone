'''
This is a python class that wraps our common Spotify and ReccoBeats api calls
Spotify:
- Create Playlist
- Update Playlist Items
- Get Playlist Items
- Remove Playlist Items
- Get User's Saved Tracks ?
- Get User's Top Items ?
- Get Followed Artists ?

Reccobeats:
- Track recommendation
- Get multiple audio features
'''
import base64
import requests
from typing import Optional, Dict, Any, List


class MusicAPI:
    def __init__(self, spotify_client_id: str, spotify_client_secret: str):
        self.spotify_client_id = spotify_client_id
        self.spotify_client_secret = spotify_client_secret
        self.spotify_token = None

    # =========================
    # SPOTIFY AUTH
    # =========================
    def _get_spotify_token(self) -> str:
        url = "https://accounts.spotify.com/api/token"

        auth_str = f"{self.spotify_client_id}:{self.spotify_client_secret}"
        b64_auth = base64.b64encode(auth_str.encode()).decode()

        headers = {
            "Authorization": f"Basic {b64_auth}",
            "Content-Type": "application/x-www-form-urlencoded"
        }

        data = {"grant_type": "client_credentials"}

        response = requests.post(url, headers=headers, data=data)
        response.raise_for_status()

        token = response.json()["access_token"]
        self.spotify_token = token
        return token

    def _get_headers(self) -> Dict[str, str]:
        if not self.spotify_token:
            self._get_spotify_token()

        return {
            "Authorization": f"Bearer {self.spotify_token}",
            "Content-Type": "application/json"
        }

    # =========================
    # SPOTIFY METHODS
    # =========================

    # Create Playlist
    def create_playlist(self, name: str, public: bool = False, description: str = None) -> str:
        '''
        Creat a playlist for a specific user

        Input:
        name[str] = name of the playlist
        public[bool] = default to a private playlist
        description[str] = a description for the playlist

        Output:
        id[str] = spotify ID for this specific playlist
        '''
        url = "https://api.spotify.com/v1/me/playlists"
        headers = self._get_headers()

        data = {
            "name": name,
            "public": public,
            "description": description
        }

        response = requests.get(url, headers=headers, params=data)
        response.raise_for_status()

        info = response.json()

        return info["id"]

    # Update playlist items
    def update_playlist_items(self, playlist_id: str) -> Dict[str, Any]:
        url = f"https://api.spotify.com/v1/playlists/{playlist_id}/items"
        headers = self._get_headers()

        response = requests.get(url, headers=headers)
        response.raise_for_status()

        return response.json()

    # =========================
    # RECOBEATS METHODS
    # =========================
    def get_recommendations(
        self,
        genre: Optional[str] = None,
        mood: Optional[str] = None,
        limit: int = 5
    ) -> List[Dict[str, Any]]:
        """
        RecoBeats API (no auth required)
        Docs: https://recobeats.com/api
        """
        url = "https://api.recobeats.com/v1/track/recommendation"

        params = {
            "size": limit
        }

        if genre:
            params["genre"] = genre
        if mood:
            params["mood"] = mood

        response = requests.get(url, params=params)
        response.raise_for_status()

        data = response.json()

        return [
            {
                "title": track["title"],
                "artist": track["artists"][0]["name"],
                "id": track["id"]
            }
            for track in data.get("content", [])
        ]