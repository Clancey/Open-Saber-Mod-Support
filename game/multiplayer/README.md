# Online multiplayer foundation

Client-side pieces for Beat Saber style online play: 2-8 players meet in a
lobby, the host starts a song that everyone begins at the same moment, and
players see each other's live score/combo and a simple avatar (head plus two
sabers). Nothing here is wired into the main menu or the game scene yet; this
file explains how to do that.

## Pieces

| File | Role |
| --- | --- |
| `addons/webrtc/` | godot-webrtc-native GDExtension (Windows, Android arm64/x86_64, Linux, macOS, iOS binaries) so `WebRTCPeerConnection` works outside the web export. |
| `WebRtcSignaling.gd` | WebSocket client for the Cloudflare Worker signaling server (`wss://vr-cooking-game-server-prod.james-clancey.workers.dev`, `gameId=open-saber`). |
| `WebRtcClient.gd` | Turns signaling into a `WebRTCMultiplayerPeer` mesh (peer with the lower id offers; the host never does). STUN only, see TURN below. |
| `ClockSync.gd` | NTP style offset estimation (best-RTT sample wins). Unit tested in `tests/test_clock_sync.gd`. |
| `MultiplayerSession.gd` | Autoload `MultiplayerSession`: lobby membership, roster, ready state, clock sync, score/finish RPCs and the synchronized song start. |
| `RemotePlayer.tscn/.gd` | Avatar: headset box, name tag, two `default_saber` instances tinted with the viewer's left/right colours; `Head`, `LeftHand`, `RightHand` transforms replicated by a `MultiplayerSynchronizer` at 20 Hz. |
| `MultiplayerAvatars.gd` | Spawns one `RemotePlayer` per roster entry, side by side on X (1.2 m apart, peer-id order) with the local player at the origin. |
| `LocalPlayerBroadcaster.gd` | Feeds the local XR camera and controller transforms into the local avatar every frame. |
| `LobbyPanel.tscn/.gd` | Themed lobby UI: Host, 4-character code spinners + Join, big lobby code, roster with ready/song state and live scores, Ready toggle, host-only Pick Song and Start, Leave. Owns a `LobbyMapFetcher`. |
| `LobbySongKey.gd` | Builds/parses the JSON lobby song key and matches it against local maps (hash, then folder, then name + author). |
| `LobbyMapFetcher.gd` | Checks the selected song locally, otherwise looks it up on BeatSaver by level hash (then id), downloads and installs it, refreshes the menu. |
| `MapDownloader.gd` | Reusable download + unzip of a BeatSaver zip into the Songs folder (the logic from `BeatSaverPanel`). |

## Server facts that shaped the client

* The worker keys each lobby by `gameId:<URL path>`; the JOIN message only
  echoes the code back. So the client always connects to
  `wss://.../<CODE>?gameId=open-saber`. Hosting generates a random code
  client-side (alphabet `A-Z2-9`, same as the server) and verifies it was
  assigned peer id 1; joining verifies it was *not* assigned id 1 (an unknown
  code silently creates a new lobby, which we report as `lobby_not_found`).
* The host is always peer 1. There is no host migration: when the host leaves
  the server closes everyone and `lobby_left("host_left")` fires.
* Sockets that do not JOIN within 1 s are dropped; the client JOINs on open.

## MultiplayerSession API

```gdscript
MultiplayerSession.player_name = "James"        # before hosting/joining
MultiplayerSession.host_lobby() -> bool          # lobby_joined(code) or lobby_left(reason)
MultiplayerSession.join_lobby("AB27") -> bool
MultiplayerSession.leave()
MultiplayerSession.is_online() / is_host() / get_local_id()
MultiplayerSession.get_players() -> Array[Dictionary]   # sorted, host first
    # {id, name, ready, score, combo, percent, finished, rank}
MultiplayerSession.set_ready(true)
MultiplayerSession.all_ready() -> bool
MultiplayerSession.start_song(song_key, difficulty) -> bool   # host only
MultiplayerSession.report_score(score, combo, percent)         # throttled to ~5 Hz, unreliable_ordered
MultiplayerSession.report_finished(score, percent, rank)       # reliable
MultiplayerSession.get_host_time_ms() / host_time_to_local_ms(ms) / is_clock_synced()
```

Signals:

* `lobby_joined(code)`
* `lobby_left(reason)` - `left`, `timeout`, `connect_failed`, `lobby_not_found`,
  `code_taken`, `invalid_code`, `host_left`, `disconnected`, `sealed`
* `roster_changed(players)` - after any join/leave/ready/score change
* `song_start_requested(song_key, difficulty, local_start_time_ms)` - on every
  peer including the host; `local_start_time_ms` is on this machine's
  `Time.get_ticks_msec()` clock, about 3 s in the future
* `clock_synced(offset_ms, rtt_ms)`, `player_finished(id, score, percent, rank)`

Clock sync: after the data channel to the host opens, each client sends 8
pings 150 ms apart, then one every 5 s. The host answers with its
`Time.get_ticks_msec()`; the client keeps the lowest-RTT sample's offset.
`start_song` broadcasts `start_at` in host time and every receiver converts it
locally, so all peers start within roughly half the RTT jitter of each other.

## Song key and downloads

`song_key` is a JSON object string built by `LobbySongKey.make(map)`:

```json
{"hash": "B68BF61AC6BE0E128BE32A85810D42E7C53F4756",
 "folder": "Jaroslav Beck - Beat Saber (Built in)",
 "name": "Beat Saber", "author": "Jaroslav Beck", "beatsaver_id": ""}
```

`hash` is Beat Saber's level id (`MapInfo.level_hash()`: SHA1, uppercase hex,
of Info.dat's bytes followed by every listed beatmap file's bytes in Info.dat
order; v4 maps also hash their lightshow files), the id BeatSaver indexes maps
by. `beatsaver_id` is filled when the folder follows the `1a2b (Song - Mapper)`
convention. A plain non-JSON key is treated as a folder name (debug hook).
`lobby_difficulty_key` stays `"<difficulty>|<characteristic>"`.

Flow: the host picks a level -> `MultiplayerSession.select_song(key, diff)`
broadcasts `song_selected` (late joiners get it on connect) -> every peer's
`LobbyMapFetcher.resolve(key)` finds the map locally (hash, folder, name +
author) or GETs `api.beatsaver.com/maps/hash/<hash>` (fallback
`/maps/id/<id>`), picks the version whose hash matches, downloads its zip,
unpacks it into `APPDATA/Songs/<map name>/`, rehashes it and refreshes the
menu. The peer then reports `set_has_song(true)`; the roster shows GETTING
SONG / HAS SONG / READY per player, the Ready toggle is disabled until the
song is ready, and Start stays gated on `all_ready()`.

## Wiring into the game (not done yet)

1. **Main menu** - instantiate `res://game/multiplayer/LobbyPanel.tscn` inside
   an `OQ_UI2DCanvas` next to the other panels (see how `Pause_Panel.tscn` is
   hosted in `BeepSaber_Game.tscn`). Whenever the level selection changes call
   `panel.set_selected_song(map_info.filepath, difficulty_name, "Song - Author")`.
   Connect `MultiplayerSession.song_start_requested` in the menu/game and, on
   it, load the map (`start_map`) but hold the song until
   `Time.get_ticks_msec() >= local_start_time_ms` (a countdown that shows the
   remaining seconds fits Beat Saber's 3-2-1). Non-hosts must also disable
   their own level selection while in a lobby.
2. **Game scene** - add a `MultiplayerAvatars` node named `MultiplayerAvatars`
   directly under the `BeepSaber_Game` root (the node path must be identical
   on every client, the synchronizers address nodes by path) and a
   `LocalPlayerBroadcaster` with `camera_path = XROrigin3D/XRCamera3D`,
   `left_controller_path = XROrigin3D/LeftController`,
   `right_controller_path = XROrigin3D/RightController`,
   `avatars_path = ../MultiplayerAvatars`. The avatars spawn/despawn from
   `roster_changed`; nothing else is needed.
3. **Scores** - in `BeepSaber_Game._display_points()` call
   `MultiplayerSession.report_score(Scoreboard.points, Scoreboard.combo, hit_rate)`
   and in `_on_song_ended()` call
   `MultiplayerSession.report_finished(Scoreboard.points, current_percent, rank)`.
   The `LobbyPanel` roster already shows the live values; an in-game HUD can
   read `MultiplayerSession.get_players()` on `roster_changed`.

## Verification

* `godot --headless --xr-mode off --path . -s tests/run.gd` - includes the
  clock sync and code validation tests.
* `godot --headless --xr-mode off --path . -s tests/multiplayer/smoke.gd` -
  builds the session, panel, avatars and a WebRTC peer without networking.
* `godot --headless --xr-mode off --path . -s tests/multiplayer/fetch_smoke.gd`
  - downloads a small known map from the live BeatSaver API into a throwaway
  folder and checks the installed folder's level hash equals BeatSaver's.
* `godot --headless --xr-mode off --path . -s tests/multiplayer/live_lobby.gd`
  - creates a throwaway lobby on the real worker, joins it from a second
  session in the same process, and checks WebRTC connectivity, roster/ready/
  score replication, clock sync and a synchronized `start_song`.

After adding scripts with `class_name`, run the editor once (or
`godot --headless --xr-mode off --path . --import`) so
`.godot/global_script_class_cache.cfg` knows them; headless runs do not scan.

## What remains

* Main-menu wiring and the in-game start countdown (above).
* In-game HUD for other players' scores (Beat Saber shows a ranked list next
  to the track); `roster_changed` has everything it needs.
* Maps that are not on BeatSaver (Beat Sage output, WIPs) cannot be fetched;
  the panel tells the player to ask the host for another song. Peer-to-peer
  transfer over the data channel would cover those.
* The v4 hash rule (beatmap + lightshow files) is self-consistent between
  peers but not yet verified against a BeatSaver-hosted v4 map.
* TURN: `WebRtcClient.ICE_SERVERS` is STUN-only, so two players behind strict
  NATs (typical mobile hotspots) will not connect. Add TURN credentials there.
* Late joiners / spectating a song in progress (the server's GAME_STATE
  message is parsed but unused), reconnects and host migration.
* Avatar polish: hand meshes, the real goggles mesh, per-player saber colours,
  saber trails on remote avatars (disabled for performance on Quest).
