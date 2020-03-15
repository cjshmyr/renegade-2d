# This script copies maps from the `maps` directory into the appropriate OpenRA Windows support directory's map folder.
# The map will be copied, followed by the Lua script, and the yaml rules for that specific mod.
# The map will also have references to yaml files added automatically.
# This allows for one maintained source of Lua scripts & maps, separate from the maps themselves.

# The OpenRA version is set as a script variable.
$openraVersion = 'release-20200202'

# Build yaml custom rule strings.
function Get-MapYamlRulePaths($mod)
{
    $srcYaml = "src\yaml\$($mod)"

    # Hacky.
    # Instead, loop through subfolders and append appropriately.
    $yamlRules = 'Rules: ' + (((dir "$($srcYaml)\rules") | %{ "yaml\$($srcYaml)\$($_.Name)" }) -join ',')
    $yamlSequences = 'Sequences: ' + (((dir "$($srcYaml)\sequences") | %{ "yaml\$($srcYaml)\$($_.Name)" }) -join ',')
    $yamlWeapons = 'Weapons: ' + (((dir "$($srcYaml)\weapons") | %{ "yaml\$($srcYaml)\$($_.Name)" }) -join ',')
    $yamlNotifications = 'Notifications: ' + (((dir "$($srcYaml)\notifications") | %{ "yaml\$($srcYaml)\$($_.Name)" }) -join ',') 
    $yaml = '`n`' + $yamlRules + '`n`' + $yamlSequences + '`n`' + $yamlWeapons + '`n`' + $yamlNotifications

    return $yaml
}

# Move maps
foreach ($mod in dir "maps\")
{
    # Skip directory if empty.
    $modMapCount = (Get-ChildItem -Path "maps\$($mod)" | Measure-Object).Count
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
        $scriptFromPath = "src\lua\"
        $scripttoPath = "$($destination)\$($folder)\lua"
        Copy-Item -Path $scriptFromPath -Destination $scriptToPath -Recurse -Force

        # Copy rules.
        $rulesFromPath = "src\yaml\$($mod)"
        $rulesToPath = "$($destination)\$($folder)\yaml\$($mod)"
        Copy-Item -Path $rulesFromPath -Destination $rulesToPath -Recurse -Force

        # Append any rules to map.yaml.
        $mod
        Get-MapYamlRulePaths($mod)
    }
}