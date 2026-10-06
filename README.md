# HOLLOWMERE — Don't Look Away

A cinematic Roblox horror game about **the Girl in White**, a too-tall figure in a
filthy nightgown with black hair hanging over her face. She follows Weeping Angel
rules: **while she's anywhere in front of you she cannot move**. Turn your back on her
and you hear her stomping toward you.

Everything is generated in code: the map, the props, her rig, all the animations and
the UI. The project has no uploaded meshes, images or animations.

---

## Quick start

1. Install [Rojo](https://rojo.space) (VS Code extension or CLI) and the Rojo Studio plugin.
2. In this folder run `rojo serve`, open a new **Baseplate** in Roblox Studio, delete the
   Baseplate part, and click **Connect** in the Rojo plugin.
   *(Or `rojo build -o Hollowmere.rbxl` and open the file.)*
3. Press **Play**. The server builds the facility on start (about a second).
4. For the full effect, turn on **Game Settings → Security → Enable Studio Access to API
   Services** so the settings menu can save to a DataStore. Without it, settings still
   work but aren't saved.

`default.project.json` also sets `Lighting.Technology = Future`, `Players.CharacterAutoLoads = false`
(the menu decides when you spawn) and `Workspace.StreamingEnabled = false`.

### Controls

| Key | Action |
| --- | --- |
| WASD / mouse | Move / look (first person by default) |
| Shift | Run (uses stamina) |
| C / Ctrl | Crouch (quieter, harder to see) |
| F | Flashlight |
| E | Interact / read / open doors |

Mobile and gamepad buttons are created through `ContextActionService`.

---

## Game flow

| # | Objective | What happens |
| --- | --- | --- |
| – | **Main menu** | A live 3D corridor with fog, flickering tubes, an animated title and the Girl standing at the far end. She glitches closer now and then. The menu has PLAY / SETTINGS / CREDITS. |
| 0 | *(intro)* | You start in a lit night office. After a few quiet seconds the power dies. "Huh? What was that...?" |
| 1 | *Get your flashlight.* | The flashlight on the desk pulses with a yellow glow. Pick it up, and **the moment you turn around she leaps into your face** and screams. |
| 2 | *Find a key.* | She is hunting you now. Notes point to Ward C, where the storage key lies on a bloody bed. |
| 3 | *Unlock the storage room.* | The padlocked storage room holds the main-entrance key. |
| 4 | *Get out through the main exit.* | You unlock the exit doors and swing them open, revealing a solid brick wall. |
| ✓ | **THE END** | You can look around but not move. As soon as you turn your back on the wall she leaps at you, and the game ends. If you never turn, something turns you. |

If she catches you, you get a jumpscare and RESTART puts you back in the corridor
outside the office. Keys you already found stay found.

Subtitles are always white and never block movement. Reading a note pauses you
until you close it.

## Project structure

```
default.project.json          Rojo project
src/shared/  (ReplicatedStorage.Shared)
  Config.lua                  ALL tuning: speeds, timings, stamina, lighting levels
  Sounds.lua                  every sound, grouped by folder; put your asset ids here
  SoundLibrary.lua            builds SoundService/{Ambient,Music,Monster,Player,UI,Jumpscare} + SoundGroups
  AnimationIds.lua            optional keyframe animation ids (override procedural ones)
  GirlRig.lua                 builds the Girl in White (Motor6D rig + Humanoid)
  GirlPoses.lua               her procedural animations
  RigAnimator.lua             blends poses, freezing, head tracking, footstep events, AnimationTrack override
  Remotes.lua, Util.lua
src/server/  (ServerScriptService.Server)
  init.server.lua             entry point / story beats
  MapLayout.lua               cell-grid floor plan
  MapBuilder.lua              walls, floors, ceilings, windows, doors, lights, bricked exit, exterior, menu set
  Props.lua                   procedural prop library (furniture, dolls, blood, graffiti, fog, rain...)
  Decorator.lua               furnishes every room (wall decorations are raycast-validated)
  Doors.lua                   hinged doors, padlocks, the Girl bursting doors open
  Interactions.lua            flashlight, keys, notes, music box, storage & exit doors
  Objectives.lua              stage machine
  GirlAI.lua                  "only moves when nobody is looking" AI
  PlayerService.lua           spawn / death / restart / menu / settings DataStore
src/client/  (StarterPlayerScripts.Client)
  init.client.lua             entry point / game flow / scripted scares
  Lock.lua                    freezes movement/camera while story text is on screen
  Audio.lua                   volume groups, ducking, crossfaded loops, heartbeat, random ambience
  CameraFX.lua                trauma shake, FOV layers, head bob, roll
  PostFX.lua                  vignettes, chromatic fringe, grain, scanlines, grading, blur, flashes
  TensionFX.lua               her proximity -> music, heartbeat, breathing, screen FX
  LightController.lua         flicker / broken / emergency lights, low-power, blinks
  Movement.lua                sprint + stamina, crouch, flashlight, view mode
  PlayerAnimator.lua          crouch / fear / interact / door / pickup layers for every player
  GirlVisuals.lua             animates her locally, instant local freeze, stomps
  Jumpscare.lua               the animated leap jumpscare
  UI/                         Theme, Widgets, Fader, MainMenu, SettingsMenu, Credits, HUD,
                              PromptUI, NoteReader, DeathScreen, WinScreen (THE END)
```

---

## The Girl's AI (`src/server/GirlAI.lua`)

- **In front of you means frozen.** If she is anywhere in the front half of any
  player's view (walls don't matter), her body is anchored and her animation stops
  mid-pose. She only moves once she is behind you. The server re-checks the moment a
  camera update arrives, and your client freezes her on the same frame, so you never
  catch her moving.
- **Unwatched means she moves.** She pathfinds to the nearest player at
  `Config.Girl.Speed` (17; you walk at 11 and sprint at 18) with a stop-motion
  lurching run. Every step is a very loud stomp that shakes your camera when she's
  close. Closed doors burst open.
- **Spawning.** She always appears out of sight, at least 45 studs from everyone.
- **Catch.** Within 3.6 studs you get her leap jumpscare and die. She vanishes and
  returns a few seconds later.

All tuning is in `Config.Girl`.

## Animations

**No fake animation code.** Every animation is a real procedural animation that drives
`Motor6D.Transform` each frame.

**The Girl** (`GirlPoses.lua`): Stand (head lolled, faint sway), Run (stop-motion
lurch, arms reaching forward, head cocked), Crouch (coiled before the leap), Leap
(arms flung wide, mouth torn open, shaking) and Scream. "Frozen" isn't an animation:
she simply stops wherever she is.

**Player** (`client/PlayerAnimator.lua`): walk and run use Roblox's stock R15 animations.
On top of those sit procedural layers for crouch, sprint lean, fear (arms up, trembling),
interact, open door and pick up. Other players see them too, because they're driven by
replicated attributes.

### Using your own keyframe animations

Fill in ids in `src/shared/AnimationIds.lua`. A non-empty id replaces the procedural
version of that state. The animator loads it as an `AnimationTrack` and stops writing
transforms while it plays. To author monster animations, get the rig in Studio with:

```lua
require(game.ReplicatedStorage.Shared.GirlRig).Build().Parent = workspace
```

---

## Audio

Folders under `SoundService`: **Ambient, Music, Monster, Player, UI, Jumpscare**, routed
through the `Master → Music / SFX` SoundGroups that the volume sliders control.

Out of the box, every sound uses one of Roblox's built-in client sounds
(`rbxasset://sounds/...`). These are reshaped with pitch and SoundEffects into drones,
screams, heartbeats and so on, so the game is atmospheric with zero uploads. **For a
polished release, put real horror audio in the `id` field of each entry in
`src/shared/Sounds.lua`.** The most valuable ones to replace:

- `Jumpscare.Scream`: the single most important sound in the game
- `Monster.Stomp`, `Monster.Breath`, `Ambient.Giggle`, `Ambient.MusicBox`
- `Music.Tension`, `Music.Pulse`, `Music.MenuTheme`, `Music.Ending`
- `Player.Heartbeat`, `Player.Breathing`
- `Ambient.Drone`, `Ambient.DistantBang`, `Ambient.MetalCreak`, `Ambient.Whisper`

---

## Tuning

Everything that affects pacing lives in `src/shared/Config.lua`:

- `Config.Girl.Speed / CatchDistance`: how fast she closes in when unwatched
- `Config.Girl.ViewDot / SightRange`: how far behind you she must be before she can move
- `Config.Girl.ActivateDelay / MinSpawnDistance / RespawnDelay`
- `Config.Timing.*`: intro blackout delay, turn-around timeouts
- `Config.Lighting.*`: ambient level and post-blackout light level (raise these if it's too dark)
- `Config.Player.*`: walk/sprint/crouch speeds, stamina, flashlight

The floor plan is plain data in `src/server/MapLayout.lua`. Add regions, edges (doors,
windows, openings) and patrol cells, and the builder handles walls, lights and doors.

---

## Notes and limitations

- The code passes `luau-lsp analyze` with the Roblox type definitions. Gameplay feel
  (speeds, timings) should still be tuned by playtesting in Studio.
- The built-in fallback sounds are a stand-in. Real assets in `Sounds.lua` are the
  single biggest upgrade.
- Multiplayer works as co-op (shared objectives; she hunts the nearest player and is
  held still if she's in front of *anyone*), but the pacing is designed for 1–4 players.
