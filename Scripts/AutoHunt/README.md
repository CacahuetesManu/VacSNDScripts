# AutoHuntLog

Automated hunt log completion script for FFXIV using SND (SomethingNeedDoing).

## Acknowledgements

Super thank you to WigglyMuffin and Friendly (AutoParty) for working on this and keeping up with it while I was not here.

Friendly (AutoParty) will try to help with bugs. Don't ping WigglyMuffin for this script.

CacahuetesManu may help with this script too, but my availability isn't all that good.

## What It Does

1. Reads the hunt log to find incomplete mobs
2. Looks up spawn locations from embedded MobData
3. Teleports to the zone
4. Navigates to the spawn location
5. Kills the required mobs using RSR
6. Repeats until all hunt log entries are complete

For GC hunt logs, also supports:
- Running dungeons via AutoDuty for dungeon-only mobs
- Dungeon unlock quests via Questionable

## Files

| File | Description |
|------|-------------|
| `AutoHuntLog_Master.lua` | Main script - run this |

## Requirements

### Plugins (Core)
- **vnavmesh** - Pathfinding (`/vnav moveflag`, `/vnav moveto`)
- **Lifestream** - Teleportation (`/li ZoneName`)
- **RotationSolver Reborn** - Combat automation (`/rotation manual`)

### Plugins (GC Dungeons - Optional)
- **AutoDuty** - Dungeon automation (`/autoduty run support <contentId> 1`)
- **Questionable** - Dungeon unlock quests (`/qst next`, `IPC.Questionable.AddQuestPriority`)

### Setup
1. Ensure all required plugins are installed and enabled
2. Open the hunt log at least once so the UI is initialized
3. Run `AutoHuntLog_Master.lua` from SND

## Settings

Edit the `Settings` table at the top of the script:

```lua
local Settings = {
    -- Hunt Log Type
    hunt_type = "class",          -- "class" for current job's hunt log, "gc" for Grand Company

    -- GC Dungeon Settings (only used when hunt_type = "gc")
    do_dungeons = true,           -- Run dungeons for GC hunt log mobs
    do_extra_dungeons = true,     -- Run Dzemael Darkhold / Aurum Vale for rank 9
    stop_at_rank_two = false,     -- Stop after rank 2 (skip rank 3)
    duty_timer_limit = 20,        -- Minutes before abandoning a dungeon

    -- Rank-up Settings (only used when hunt_type = "gc")
    do_rankup = true,             -- Attempt to rank up after completing logs

    -- Movement Settings
    mount_name = "Company Chocobo"  -- Fallback mount if Mount Roulette fails
}
```

When `hunt_type = "class"`, the script automatically detects your current job and runs its hunt log.

**Supported classes**: GLA, MRD, PGL, LNC, ARC, CNJ, THM, ACN, ROG (and their jobs)

## Features

### Overworld Hunting
- **Auto-navigation**: Teleports to zones and pathfinds to spawn locations
- **Anti-stuck detection**: Jumps while moving forward and restarts navigation if stuck for 2+ seconds
- **Smart targeting**: Moves closer to mobs if out of range, handles being attacked
- **RSR integration**: Enables combat rotation automatically, re-enables if it drops
- **Progress tracking**: Reads hunt log dynamically to track kills

### GC Dungeon Support
- **Dungeon detection**: Knows which dungeons are needed for each GC rank
- **AutoDuty integration**: Queues and runs dungeons automatically
- **Unlock quest handling**: Uses Questionable to complete dungeon unlock quests before running
- **Rank-up support**: Checks quest requirements for ranks 8 and 9

#### GC Dungeons by Rank
| Rank | Dungeon | Unlock Quest | Game ID | Qst ID | AD Content ID |
|------|---------|--------------|---------|--------|---------------|
| 1 | Halatali | Hallo Halatali | 66233 | 697 | 1245 |
| 2 | The Sunken Temple of Qarn | Braving New Depths | 66300 | 764 | 1267 |
| 2 | Cutter's Cry (Flames only) | Dishonor Before Death | 66457 | 921 | 1303 |
| 3 | The Wanderer's Palace | Trauma Queen | 66406 | 870 | N/A |

#### Extra Dungeons (Rank 9)
| Dungeon | AD Content ID |
|---------|---------------|
| Dzemael Darkhold | 1330 |
| The Aurum Vale | 1331 |

## Coordinate System

The script handles two types of spawn coordinates:

- **2D map coords** (xCoord, yCoord): Placed as map flag via `Instances.Map.SetFlagMapMarker()`, then navigated via `/vnav moveflag`
- **3D world coords** (xCoord, yCoord, zCoord): Navigated directly via `/vnav moveto`

## Troubleshooting

### Script doesn't find mobs
- Open hunt log manually first to initialize the UI
- Check that the mob has location data in the embedded MobData

### Navigation fails
- Ensure vnavmesh is installed and the navmesh is built for the zone
- Some coordinates may be outside navigable areas - update MobData if needed

### Combat doesn't start
- Ensure RotationSolver Reborn is installed and configured
- Check that you have a valid rotation set up for your job

### Stuck on terrain
- The anti-stuck feature should handle most cases
- If persistent, the coordinates for that mob may need adjustment

### Dungeon doesn't start
- Ensure AutoDuty is installed and has paths for the dungeon
- Check that you meet the level/ilvl requirements

### Dungeon unlock quest doesn't run
- Ensure Questionable is installed
- Check that the Questionable quest ID (Qst ID) is set in `GCDungeonData`
- Note: Questionable uses its own internal quest IDs, not the game's quest IDs

## Known Issues

- **Attacked after kill phase**: If a mob attacks you after the kill phase ends (between targets), RSR won't auto-target and fight back. The character will just stand there getting hit. Workaround: manually target the mob or wait for the next navigation cycle's combat check.
  - *Potential fix*: Add global combat interrupt using `/battletarget` instead of `/targetenemy`

## Future Improvements

### Still Needed
- **GC rank-up acceptance**: Interact with GC NPC to accept rank promotions after completing hunt logs
- **Dungeon mob detection**: MobData needs `isDungeon` flag to identify dungeon-only mobs
- **GC seal turnin**: Auto-exchange gear for seals when needed for rank-up
- **Global combat handler**: Detect combat outside of kill phase and auto-engage attackers

## Technical Details

### Hunt Log Reading
Uses `Addons.GetAddon("MonsterNote"):GetAtkValue()` to read mob names (indices 79-130) and progress (indices 159-210).

### Hunt Log Tab Indices
| Index | Class |
|-------|-------|
| 0 | GLA |
| 1 | PGL |
| 2 | MRD |
| 3 | LNC |
| 4 | ARC |
| 5 | ROG |
| 6 | CNJ |
| 7 | THM |
| 8 | ACN |
| 9 | GC |

### GC Rank APIs
| Purpose | API |
|---------|-----|
| Current GC | `Player.GrandCompany` |
| Maelstrom rank | `Player.GCRankMaelstrom` |
| Twin Adders rank | `Player.GCRankTwinAdders` |
| Immortal Flames rank | `Player.GCRankImmortalFlames` |
| Quest complete | `Quests.IsQuestComplete(id)` |

### Key Quest IDs (Game IDs)
| Purpose | Maelstrom | Adders | Flames |
|---------|-----------|--------|--------|
| Rank 8 unlock | 66664 | 66665 | 66666 |
| Rank 9 unlock | 66667 | 66668 | 66669 |

### Questionable Integration
The script uses two types of quest IDs:
- **Game Quest ID**: Used with `Quests.IsQuestComplete()` to check if a quest is done
- **Questionable Quest ID (Qst ID)**: Used with `IPC.Questionable.AddQuestPriority()` or `/qst next` to tell Questionable which quest to run

These are different numbering systems! For example:
- "Hallo Halatali" = Game ID 66233, Qst ID 697

### API Reference
See the SND API documentation for modern API usage.
