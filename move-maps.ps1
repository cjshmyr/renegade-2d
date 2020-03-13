# Quick and hacky.
# Moves the maps over to an assumed release-20200202 folder.
# Also pulls over the blank shellmap.
Write-Host 'Clearing maps...'
Remove-Item 'C:\Program Files\OpenRA\mods\cnc\maps\*' -Recurse -Force
Write-Host 'Moving maps...'
Copy-Item -Path 'blank-shellmap' -Destination 'C:\Program Files\OpenRA\mods\cnc\maps\' -Recurse
Copy-Item -Path 'renegade-2d-cnc-mapa' -Destination 'C:\Program Files\OpenRA\mods\cnc\maps\' -Recurse
Copy-Item -Path 'renegade-2d-cnc-mapb' -Destination 'C:\Program Files\OpenRA\mods\cnc\maps\' -Recurse
Write-Host 'Done.'