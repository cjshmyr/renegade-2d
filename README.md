# renegade-2d
Git repository containing the Renegade 2D code and maps for OpenRA.

![](mods/cnc/maps/renegade-2d-cnc-mapa/map.png) ![](mods/cnc/maps/renegade-2d-cnc-mapb/map.png)

## Support
The released maps are supported on OpenRA release-20190314.

An update is in progress to support OpenRA release-20200202.

## Map links
release-20190314
- Alpha map (version 0.95): https://resource.openra.net/maps/31296/
- Bravo map (version 0.95): https://resource.openra.net/maps/31297/

## Features
Gameplay is based on the first person shooter C&C Renegade.

Gameplay features:
- Up to 24 players (12v12), GDI vs Nod.
- Control a single unit in a shared base with your team.
- Stand near base buildings to make purchases.
- Base buildings provide various benefits to your team.
- Vehicles require a pilot to be operated; many vehicles hold multiple passengers.
- Engineers can repair vehicles, buildings, and disarm beacons.
- Purchase beacons to call in a delayed superweapon strike.
- Gathered resources are distributed among your team; you have your own wallet.
- Earn $ for your team by purchasing a harvester and gathering resources.
- Earn $ by damaging or killing enemy units and structures.
- Win by destroying the enemy base!

It might crash, it might lag, and it's barely balanced!

There are several Lua hacks to make things work, and bugs.

## Repository structure
`lua` folder - Contains any scripts for running Renegade 2D. The script is mod-agnostic; it works for the CNC & RA mods, and can easily support future mods.

`mods/cnc/rules` folder - Contains CNC rules for Renegade 2D

`mods/cnc/maps` folder - Contains CNC maps for Renegade 2D

RA mod rule folders exist, but these rules are out of date and currently unsupported.

## Building maps
**Currently only supported on Windows**

The maps in the `mods/{mod}/maps` folder do not contain any custom yaml for Renegade 2D (aside from player & team settings at this time).

The build script (`build-maps.ps1`) will:
- Move any maps from the `mods/{mod}/maps` directory to the OpenRA Windows support maps directory (`AppData/Roaming/OpenRA/maps/{mod}/{release}/{map}`).
- Move any custom rules from the `mods/{mod}/yaml` directory to any copied map directories.
- Move any lua scripts from the `lua` directory to the copied map directories.
- Append any specific rule files needed to the copied map's `map.yaml` file, so custom rules are implemented.

This allows for independently developing Lua and custom rules in one location, which can be applied to generic maps.

## Known issues
0.95 harvesters are busted on release-20200202.
- Fixed for the next version.
