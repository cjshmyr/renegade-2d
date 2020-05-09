# renegade-2d
Git repository containing the Renegade 2D code and maps for OpenRA.

![](mods/cnc/maps/renegade-2d-cnc-mapa/map.png) ![](mods/cnc/maps/renegade-2d-cnc-mapb/map.png) ![](mods/cnc/maps/renegade-2d-cnc-mapc/map.png)

## Map links
The released maps are supported on OpenRA release-20200503.
- Alpha (version 0.99): https://resource.openra.net/maps/35099/
- Bravo (version 0.99): https://resource.openra.net/maps/35100/
- Charlie (version 0.99): https://resource.openra.net/maps/35101/

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

The maps in the `mods/{mod}/maps` folder only contain minimal custom yaml for Renegade 2D (player & team settings only).

RA mod rule folders exist, but these rules are out of date and currently unsupported.

## Building maps
To build maps for development, please see and use the `build-maps.ps1` script.