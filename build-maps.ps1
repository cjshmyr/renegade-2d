# This script copies maps from the `maps` directory into the appropriate OpenRA Windows support directory's map folder.
# The map will be copied, followed by the Lua script, and the yaml rules for that specific mod.
# This allows for one maintained source of Lua scripts & maps, separate from the maps themselves.

# Important:
# - Maps still have specific yaml file references in them. We can remove them and have the script append them.

# The OpenRA version is set as a script variable.
$openraVersion = 'release-20200202'
$scriptName = 'renegade.lua'

$mods = Get-ChildItem -Path "maps\"
foreach ($mod in $mods)
{
    # Skip directory if empty.
    $modMapCount = (Get-ChildItem "maps\$($mod)" | Measure-Object).Count
    if ($modMapCount -eq 0) {
        continue;
    }

    # Targeted destination directory.
    $destination = "$($env:USERPROFILE)\AppData\Roaming\OpenRA\maps\$($mod)\$($openraVersion)"

    # Create destination if it doesn't exist.
    New-Item -ItemType Directory -Force -Path $destination | Out-Null

    # Copy all maps from a mod's map folder, and also the yaml/rules.
    $mapsModFolder = "maps\$($mod)"

    $folders = Get-ChildItem -Path $mapsModFolder
    foreach ($folder in $folders)
    {
        # Delete map if exists.
        $existingMap = "$($destination)\$($folder)"
        Remove-Item $existingMap -Recurse

        # Copy map.
        $mapFromPath = "$($mapsModFolder)\$($folder)"
        Copy-Item -Path $mapFromPath -Destination $destination -Recurse -Force

        # Copy renegade.lua script.
        $scriptFromPath = "src\$($scriptName)"
        $scripttoPath = "$($destination)\$($folder)\$($scriptName)"
        Copy-Item -Path $scriptFromPath -Destination $scriptToPath -Force

        # Copy rules.
        $rulesFromPath = "src\$($mod)"
        $rulesToPath = "$($destination)\$($folder)\$($mod)"
        Copy-Item -Path $rulesFromPath -Destination $rulesToPath -Recurse -Force
    }
}