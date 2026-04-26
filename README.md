# nex_elevators

A fully-featured elevator system for FiveM with a modern React-based NUI interface, in-game admin panel, and multi-framework support.

## Features

- **Interactive Elevator UI** - Animated elevator panel with visual shaft, floor indicators, and smooth transitions
- **In-Game Admin Panel** - Create, edit, and delete elevators without restarting the server (`/elevatoradmin`)
- **Grab Position** - Walk to a spot and press E to capture coordinates and heading when adding floors
- **Job Restrictions** - Lock elevators or individual floors behind job requirements with minimum grade support
- **Multi-Framework Support** - Works with QBox, QBCore, ESX, and OX out of the box
- **Persistent Storage** - Elevator data saved to JSON and synced to all players in real time
- **Server-Side Validation** - All permission checks and teleportation handled server-side with rate limiting

## Dependencies

- [ox_lib](https://github.com/overextended/ox_lib)
- One of the supported frameworks: `qbx_core`, `qb-core`, `es_extended`, or `ox_core`

## Installation

1. Download and place `nex_elevators` into your server's resources folder
2. Add `ensure nex_elevators` to your `server.cfg` (after your framework and `ox_lib`)
3. Set your framework in `config.lua`:
   ```lua
   Config.Framework = "qbox" -- "qbox", "qbcore", "esx", or "ox"
   ```
4. Start your server — default elevators from the config are imported automatically on first run

## Configuration

All settings are in `config.lua`:

| Option | Default | Description |
|---|---|---|
| `Config.Framework` | `"qbox"` | Active framework |
| `Config.Debug` | `false` | Draw debug zones |
| `Config.InteractKey` | `38` (E) | Key to open the elevator panel |
| `Config.ZoneSize` | `vec3(2.0, 2.0, 4.0)` | Interaction zone dimensions |
| `Config.FadeDuration` | `800` | Screen fade duration in ms |
| `Config.FreezeOnTransit` | `true` | Freeze player during teleport |

### Sounds

Elevator sounds can be customized in `Config.Sound`:

```lua
Config.Sound = {
    enter  = { name = "Elevator_Open",  ref = "DLC_DMOD_Prop_Editor_Sounds" },
    move   = { name = "FLIGHT_DETAILS_TICKER", ref = "DLC_HEIST_PLANNING_BOARD_SOUNDS" },
    arrive = { name = "Elevator_Close", ref = "DLC_DMOD_Prop_Editor_Sounds" },
}
```

### Default Elevators

`Config.Elevators` defines the initial set of elevators imported on first run. After that, all elevator data is managed through the admin panel and stored in `data/elevators.json`.

```lua
Config.Elevators = {
    {
        name = "Los Santos Tower",
        jobRequired = nil, -- or { name = "police", minGrade = 0 }
        floors = {
            { label = "Ground Floor", coords = vector3(-1091.6, -808.9, 19.27), heading = 220.0 },
            { label = "Roof Access",  coords = vector3(-1091.6, -808.9, 52.42), heading = 220.0, jobRequired = { name = "police", minGrade = 2 } },
        }
    },
}
```

## Admin Panel

Use the `/elevatoradmin` command to open the admin panel. Permission is granted via:

- ACE permission: `nex_elevators.admin`
- Framework admin/god groups (QBX, QBCore, ESX)
- OX admin group

From the admin panel you can:

- **Create** elevators with a name, optional job lock, and multiple floors
- **Edit** existing elevators — rename, change restrictions, add/remove/reorder floors
- **Delete** elevators with a confirmation prompt
- **Grab Position** — walk to a location and press E to capture coords + heading for a floor

All changes take effect immediately for all connected players without a server restart.

## Project Structure

```
nex_elevators/
├── fxmanifest.lua          # Resource manifest
├── config.lua              # Configuration
├── bridge/                 # Framework abstraction layer
│   ├── framework.lua       # Client bridge
│   └── sv_framework.lua    # Server bridge
├── client/
│   └── cl_main.lua         # Zones, UI triggers, teleportation
├── server/
│   ├── sv_main.lua         # Events, permissions, admin commands
│   └── sv_storage.lua      # JSON persistence
├── data/
│   └── elevators.json      # Persistent elevator data
└── web/                    # React NUI (Vite + TypeScript + Tailwind)
    ├── src/
    │   ├── components/
    │   │   ├── ElevatorPanel.tsx   # Player UI
    │   │   └── AdminPanel.tsx      # Admin CRUD interface
    │   └── utils/                  # NUI helpers
    └── build/                      # Compiled assets
```

## Building the Web UI

The web UI is pre-built in `web/build/`. If you need to make changes:

```bash
cd web
npm install
npm run build
```

## License

All rights reserved.
