# HOLLOWMERE — Subject 09

A cinematic Roblox horror game about **The Grinner**: a 12-stud, barely-human thing with
arms past its knees and a smile wider than its skull. It stalks you through an abandoned
psychiatric annex. When it notices you, it freezes, turns its head all the way around,
goes silent, **screams**, and then runs at you faster than anything should move.

Everything is generated in code: the map, the props, the monster rig, all the animations
and the UI. The project has no uploaded meshes, images or animations, so it runs as soon
as you sync it.

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
| – | **Main menu** | A live 3D corridor with a slow camera dolly, fog, flickering tubes, an animated title, and the Grinner breathing at the far end. It sometimes glitches closer. The menu has PLAY / SETTINGS / CREDITS. |
| 1 | *Find a fuse.* | It's pitch black and you only have a flashlight. The reception log points you to Storage. When you pick up the fuse, the Grinner appears at the end of the corridor, watching. It vanishes when you look away. |
| 2 | *Restore the power.* | You insert the fuse in the Generator Room and the lights stutter back to life. Seven seconds later, something screams downstairs. |
| 3 | *Find the exit.* | The main doors are chained shut. A note says the only way out is the maintenance tunnel, and the key is in Security. The office phone rings; if you answer, it breathes and says "I SEE YOU". |
| 4 | *Find the basement key.* | A blackout hits, and when the lights return the Grinner is loose: it patrols, investigates, stalks and chases. The Security door creaks open on its own. The Break Room (steel door) is the safe room. |
| 5 | **RUN.** | Taking the key sets off red alarm lighting and jams the safe room. The Grinner appears at the far end of the corridor, back turned. Its head rotates 180°, everything goes silent, it screams, and it sprints straight at you. |
| 6 | *Escape through the maintenance tunnel.* | You run down the stairwell, through the sub-level corridor (weaving around debris) and the flooded tunnel. |
| ✓ | **YOU ESCAPED** | The gate crashes down behind you. The Grinner slams against it, then you get the epilogue. |

If you die during the final chase, you restart right outside the Security office with
the key back on its hook, so retries are quick.

---

## Project structure

```
default.project.json          Rojo project
src/shared/  (ReplicatedStorage.Shared)
  Config.lua                  ALL tuning: speeds, ranges, timings, stamina, FOV
  Sounds.lua                  every sound, grouped by folder; put your asset ids here
  SoundLibrary.lua            builds SoundService/{Ambient,Music,Monster,Player,UI,Jumpscare} + SoundGroups
  AnimationIds.lua            optional keyframe animation ids (override procedural ones)
  MonsterRig.lua              builds the Grinner (Motor6D rig + Humanoid)
  MonsterPoses.lua            16 procedural monster animations
  MonsterAnimator.lua         blends poses, head tracking, footstep events, AnimationTrack override
  Remotes.lua, Util.lua
src/server/  (ServerScriptService.Server)
  init.server.lua             entry point / wiring / progression
  MapLayout.lua               cell-grid floor plans (ground floor + sub-level)
  MapBuilder.lua              walls, floors, ceilings, windows, doors, lights, stairs, exterior, menu set
  Props.lua                   procedural prop library (furniture, pipes, blood, graffiti, fog, rain...)
  Decorator.lua               furnishes every room + environmental storytelling
  Doors.lua                   hinged doors, locks, monster smashing, auto-open during chases
  Interactions.lua            fuse, fuse box, key, notes, drawer, phone, radio, wheelchair scare, exit gate
  Objectives.lua              stage machine
  MonsterAI.lua               server AI state machine
  ChaseDirector.lua           chase world state, safe room, final chase
  Noise.lua                   noise events the monster hears
  PlayerService.lua           spawn / death / restart / menu / settings DataStore
src/client/  (StarterPlayerScripts.Client)
  init.client.lua             entry point / game flow
  Audio.lua                   volume groups, ducking, crossfaded loops, heartbeat, random ambience
  CameraFX.lua                trauma shake, FOV layers, head bob, roll
  PostFX.lua                  vignettes, chromatic fringe, grain, scanlines, grading, blur, flashes
  ChaseFX.lua                 turns monster proximity/chase state into music, heartbeat, FOV, screen FX
  LightController.lua         flicker / broken / emergency / alarm lights; lights die near the monster
  Movement.lua                sprint + stamina, crouch, flashlight, chase speed boost, view mode
  PlayerAnimator.lua          crouch / fear / interact / door / pickup layers for every player
  MonsterVisuals.lua          animates the monster locally + gait-synced footsteps
  Jumpscare.lua               the animated jumpscare
  UI/                         Theme, Widgets, Fader, MainMenu, SettingsMenu, Credits, HUD,
                              PromptUI, NoteReader, DeathScreen, WinScreen
```

---

## The monster AI (`MonsterAI.lua`)

The AI runs on the server at 10 Hz. Animation intent is published as attributes
(`AnimState`, `LookTarget`, `ChaseTarget`, `Hidden`) and every client animates the rig
locally at full frame rate.

| State | Behaviour |
| --- | --- |
| **DORMANT** | Hidden; only scripted appearances (stages 1–3). |
| **IDLE** | Hunched, twitching, looking around. |
| **PATROL** | Pathfinds between patrol nodes, biased toward the area players are in. Opens doors it walks into (DoorOpen animation). |
| **INVESTIGATE** | Walks (or runs, for loud noises) to sprinting, doors, objective interactions, or something it half-saw. |
| **STALK** | Teleports to a vantage point the player can see but isn't looking at: the end of a hallway, a doorway, behind the generator-room window. It stares and creeps closer while unobserved, then **vanishes the moment you look away** (the client reports camera direction). |
| **DETECTED** | Head turn (body frozen, head rotates up to 175°), then silence (all audio ducks to zero), then scream (the body snaps to face you, arms spread). |
| **CHASE** | Launches at burst speed, accelerates over time, catches up when far behind and stays on your heels when close. Smashes doors (with a stagger). Loses you after 5 s without line of sight (normal chases only). |
| **ATTACK** | Strike, then grab, and the victim gets the jumpscare. |
| **SEARCH** | Scans the last known position. |
| **SLAM** | If you reach the safe room, the steel door slams shut behind you. It pounds on the door, stares, and disappears. |

Detection uses a vision cone, range and line of sight. Crouching shrinks the range, while
your flashlight and sprinting grow it, and a suspicion meter fills faster when you're close.
Windows don't block sight (the glass has `CanQuery = false`).

---

## Animations

**No fake animation code.** Every animation is a real procedural animation that drives
`Motor6D.Transform` each frame.

**Monster** (`MonsterPoses.lua`): Idle, Breathing, LookAround, Search, SlowWalk, Walk
(with a limp), Sprint, AggressiveSprint (torso near-horizontal, arms swept back and
flapping, head cocked 50°, jaw shaking), HeadTurn, Scream, Attack, Grab, Jumpscare,
Stagger (death/door recoil), DoorOpen, DoorSlam.

**Player** (`client/PlayerAnimator.lua`): walk and run use Roblox's stock R15 animations.
On top of those sit procedural layers for crouch, sprint lean, fear (arms up, trembling),
interact, open door and pick up. Other players see them too, because they're driven by
replicated attributes.

### Using your own keyframe animations

Fill in ids in `src/shared/AnimationIds.lua`. A non-empty id replaces the procedural
version of that state. The animator loads it as an `AnimationTrack` and stops writing
transforms while it plays. To author monster animations, get the rig in Studio with:

```lua
require(game.ReplicatedStorage.Shared.MonsterRig).Build().Parent = workspace
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

- `Monster.Scream`, `Jumpscare.Scream`: the two most important sounds in the game
- `Music.ChaseLoop`, `Music.ChaseDrone`, `Music.Tension`, `Music.MenuTheme`
- `Monster.Footstep`, `Monster.Breath`, `Player.Heartbeat`, `Player.Breathing`
- `Ambient.Drone`, `Ambient.DistantBang`, `Ambient.MetalCreak`, `Ambient.Whisper`

---

## Tuning

Everything that affects pacing lives in `src/shared/Config.lua`:

- `Config.Monster.FinalBaseSpeed / FinalMaxSpeed / FinalBurstSpeed`: final chase speed
- `HeelDistance / HeelSlowThreshold`: how hard it punishes slowing down when it's right behind you
- `ChaseBaseSpeed / ChaseRamp / ChaseMaxSpeed / LoseTrackTime`: normal chases
- `HeadTurnTime / SilenceTime / ScreamTime`: the detection beat
- `SightRange / FieldOfView / SuspicionRate`: how perceptive it is
- `Config.Player.*`: walk/sprint/crouch speeds, stamina, chase boost

The floor plan is plain data in `src/server/MapLayout.lua`. Add regions, edges (doors,
windows, openings), patrol cells and stalk points, and the builder handles walls, lights
and doors.

---

## Notes and limitations

- The code passes `luau-lsp analyze` with the Roblox type definitions. Gameplay feel
  (speeds, timings) should still be tuned by playtesting in Studio.
- The built-in fallback sounds are a stand-in. Real assets in `Sounds.lua` are the
  single biggest upgrade.
- Multiplayer works as co-op (shared objectives; the monster hunts one target at a
  time), but the pacing is designed for 1–4 players.
