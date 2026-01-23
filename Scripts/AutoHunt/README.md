#Acknolegements
Super thank you to Muffin and Friendly <AutoParty> for working on this and keeping up with it while I was not here. 

Friendly (ping me) <AutoParty>, will try to help with bugs. Don't ping Wiggly for this script.

# AutoHuntLog

Automated hunt log completion script for FFXIV using SND (SomethingNeedDoing).

## What It Does

1. Reads the hunt log to find incomplete mobs
2. Looks up spawn locations from embedded MobData
3. Teleports to the zone
4. Navigates to the spawn location
5. Kills the required mobs using RSR
6. Repeats until all hunt log entries are complete

## Files

| File | Description |
|------|-------------|
| `AutoHuntLog_Master.lua` | Main script - run this |

## Requirements

### Plugins
- **vnavmesh** - Pathfinding (`/vnav moveflag`, `/vnav moveto`)
- **Lifestream** - Teleportation (`/li ZoneName`)
- **RotationSolver Reborn** - Combat automation (`/rotation manual`)

### Setup
1. Ensure all required plugins are installed and enabled
2. Open the hunt log at least once so the UI is initialized
3. Run `AutoHuntLog_Master.lua` from SND

## Features

- **Auto-navigation**: Teleports to zones and pathfinds to spawn locations
- **Anti-stuck detection**: Jumps and restarts navigation if stuck for 2+ seconds
- **Smart targeting**: Moves closer to mobs if out of range, handles being attacked
- **RSR integration**: Enables combat rotation automatically, re-enables if it drops
- **Progress tracking**: Reads hunt log dynamically to track kills

## Coordinate System

The script handles two types of spawn coordinates:

- **2D map coords** (xCoord, yCoord): Converted to raw coords and placed as map flag, then navigated via `/vnav moveflag`
- **3D world coords** (xCoord, yCoord, zCoord): Navigated directly via `/vnav moveto`

Conversion formula for 2D → raw: `raw = (mapCoord * 50) - 25 - 1024`

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

## Technical Details

### Hunt Log Reading
Uses `Addons.GetAddon("MonsterNote"):GetAtkValue()` to read mob names (indices 80-130) and progress (indices 160-210).

### Key APIs Used
| Purpose | API |
|---------|-----|
| Current zone | `Svc.ClientState.TerritoryType` |
| Player ready | `Player.Available` |
| In combat | `Svc.Condition[26]` |
| Mounted | `Svc.Condition[4]` |
| Has target | `Entity.Target ~= nil` |
| Target distance | `Entity.Target.DistanceTo` |
| Nav running | `IPC.vnavmesh.IsRunning()` |
| Set map flag | `Instances.Map.Flag:SetFlagMapMarker(terri, map, rawX, rawY)` |
