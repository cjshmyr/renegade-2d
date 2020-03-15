# Hacky variables.
$mod = 'cnc'
$scriptName = 'renegade.lua'

# Targeted OpenRA version.
$openraVersion = 'release-20200202'

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
