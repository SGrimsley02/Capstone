'''
This is a python class that wraps our common Spotify and ReccoBeats api calls
Spotify:
- Create Playlist
- Update Playlist Items
- Get Playlist Items
- Remove Playlist Items
- Get User's Saved Tracks
- Get User's Top Items
- Get Followed Artists

Reccobeats:
- Track recommendation
- Get multiple audio features

Last updated: 4.16.26
By: Reeny
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
        name[str]        = name of the playlist
        public[bool]     = default to a private playlist
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
        try:
            response = requests.post(url, headers=headers, json=data)
            response.raise_for_status()
            
            #TODO: discuss if any other information is wanted/needed
            return response.json()["id"]
        
        except Exception as e:
            print(f"Failed to create playlist: {str(e)}")
            raise e

    # Update playlist items
    def update_playlist_items(self, playlist_id: str, uris: List[str], position: Optional[int] = None) -> bool:
        '''
        Add a list of tracks to user's playlist

        Input: 
        playlist_id[str]  = id that is returned from create playlist
        uris[List[str]]   = list of tracks: 'spotify:track:4iV5W9uYEdYUVa79Axb7Rh' (MAX = 100)
        position[int]     = zero-based index to insert at; appends if omitted

        Output:
        Boolean: true if successful and false if failed
        '''
        url = f"https://api.spotify.com/v1/playlists/{playlist_id}/items"
        headers = self._get_headers()

        data: Dict[str, Any] = {"uris": uris}
        if position is not None:
            data["position"] = position

        try:
            response = requests.get(url, headers=headers, params=data)
            return response.status_code == 201
        
        except Exception as e:
            print(f'Failed to add tracks to playlist: {str(e)}')
            raise e
        
    def get_playlist_item(self, playlist_id: str, limit: int = 20, offset: int = 0) -> List[Dict[str, Any]]:
        '''
        Get the tracks/episodes in a playlist

        Input:
        playlist_id[str] = Spotify playlist ID
        limit[int]       = max items to return (1-50, default 20)
        offset[int]      = index of first item to return (for pagination)
 
        Output:
        List of dicts with keys: title, artist, uri, id
        '''
        url = f"https://api.spotify.com/v1/playlists/{playlist_id}/items"
        headers = self._get_headers()
 
        data = {
            "limit": limit,
            "offset": offset
        }

        try:
            response = requests.get(url, headers=headers, params=data)
            response.raise_for_status()
 
            items = response.json().get("items", [])
            return [
                {
                    "title": item["track"]["name"],
                    "artist": item["track"]["artists"][0]["name"],
                    "uri": item["track"]["uri"],
                    "id": item["track"]["id"]
                }
                for item in items
                if item.get("track")  # skip episode/null tracks
            ]
 
        except Exception as e:
            print(f"Failed to get playlist items: {str(e)}")
            raise e
    
    def remove_playlist_item(self, playlist_id: str, uris: List[str]) -> bool:
        '''
        Remove one or more tracks from a playlist
        
        Input:
        playlist_id[str] = Spotify playlist ID
        uris[List[str]]  = list of Spotify track URIs to remove
 
        Output:
        bool: True if successful
        '''
        url = f"https://api.spotify.com/v1/playlists/{playlist_id}/items"
        headers = self._get_headers()

        data = {
            "tracks": [{"uri": uri} for uri in uris]
        }

        try:
            response = requests.delete(url, headers=headers, json=data)
            response.raise_for_status()
            return response.status_code == 200
 
        except Exception as e:
            print(f"Failed to remove playlist items: {str(e)}")
            raise e
    
    def get_user_saved_tracks(self, limit: int = 20, offset: int = 0) -> List[Dict[str, Any]]:
        '''
        Get the current user's saved/liked tracks

        Input:
        limit[int]  = max tracks to return (1-50, default 20)
        offset[int] = index of first track to return (for pagination)
 
        Output:
        List of dicts with keys: title, artist, uri, id
        '''
        url = "https://api.spotify.com/v1/me/tracks"
        headers = self._get_headers()
 
        data = {
            "limit": limit,
            "offset": offset
        }
 
        try:
            response = requests.get(url, headers=headers, params=data)
            response.raise_for_status()
 
            items = response.json().get("items", [])
            return [
                {
                    "title": item["track"]["name"],
                    "artist": item["track"]["artists"][0]["name"],
                    "uri": item["track"]["uri"],
                    "id": item["track"]["id"]
                }
                for item in items
                if item.get("track")
            ]
 
        except Exception as e:
            print(f"Failed to get saved tracks: {str(e)}")
            raise e
    
    def get_user_top_tracks(self, time_range: str = "medium_term", limit: int = 20, offset: int = 0) -> List[Dict[str, Any]]:
        '''
        Get the current user's top tracks.
        Requires: user-top-read scope.
 
        Input:
        time_range[str] = "short_term" (~4 weeks), "medium_term" (~6 months),
                          or "long_term" (all time). Default: "medium_term"
        limit[int]      = max items to return (1-50, default 20)
        offset[int]     = index of first item to return (for pagination)
 
        Output:
        List of dicts with keys: title, artist, uri, id
        '''
        url = "https://api.spotify.com/v1/me/top/tracks"
        headers = self._get_headers()
 
        data = {
            "time_range": time_range,
            "limit": limit,
            "offset": offset
        }
 
        try:
            response = requests.get(url, headers=headers, params=data)
            response.raise_for_status()
 
            items = response.json().get("items", [])
            return [
                {
                    "title": track["name"],
                    "artist": track["artists"][0]["name"],
                    "uri": track["uri"],
                    "id": track["id"]
                }
                for track in items
            ]
 
        except Exception as e:
            print(f"Failed to get top tracks: {str(e)}")
            raise e
    
    def get_user_artists(self, limit: int = 20, after: Optional[str] = None) -> List[Dict[str, Any]]:
        '''
        Get the current user's followed artists.
 
        Input:
        limit[int]        = max artists to return (1-50, default 20)
        after[str]        = the last artist ID from a previous request (for pagination)
 
        Output:
        List of dicts with keys: name, id, uri, genres
        '''
        url = "https://api.spotify.com/v1/me/following"
        headers = self._get_headers()
 
        data: Dict[str, Any] = {
            "type": "artist",
            "limit": limit
        }
        if after:
            data["after"] = after
 
        try:
            response = requests.get(url, headers=headers, params=data)
            response.raise_for_status()
 
            artists = response.json().get("artists", {}).get("items", [])
            return [
                {
                    "name": artist["name"],
                    "id": artist["id"],
                    "uri": artist["uri"],
                    "genres": artist["genres"]
                }
                for artist in artists
            ]
 
        except Exception as e:
            print(f"Failed to get followed artists: {str(e)}")
            raise e

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
    
    def get_audio_features(self):
        return 0