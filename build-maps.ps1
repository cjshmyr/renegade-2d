# This script copies maps from the `maps` directory into the appropriate OpenRA Windows support directory's map folder.
# The map will be copied, followed by the Lua script, and the yaml rules for that specific mod.
# The map will also have references to yaml files added automatically.
# This allows for one maintained source of Lua scripts & custom rules, separate from the maps themselves.

# The OpenRA engine version is set as a script variable, which should get updated when targeting new releases.
$openraVersion = 'playtest-20200329'

# Returns yaml custom rule strings.
function Get-MapYamlRulePaths($mod)
{
    $modYaml = "$($PSScriptRoot)\mods\$($mod)\yaml\"

    # Hacky; instead of this, loop through subfolders and append appropriately.
    $yaml = "`nRules: " + (((dir "$($modYaml)\rules") | %{ "yaml\$($mod)\rules\$($_.Name)" }) -join ', ')
    $yaml += "`nWeapons: " + (((dir "$($modYaml)\weapons") | %{ "yaml\$($mod)\weapons\$($_.Name)" }) -join ', ')
    $yaml += "`nNotifications: " + (((dir "$($modYaml)\notifications") | %{ "yaml\$($mod)\notifications\$($_.Name)" }) -join ', ')
    $yaml += "`nSequences: " + (((dir "$($modYaml)\sequences") | %{ "yaml\$($mod)\sequences\$($_.Name)" }) -join ', ')

    return $yaml
}

# Move maps.
foreach ($mod in dir "$($PSScriptRoot)\mods\")
{
    $modMapsFolder = "$($PSScriptRoot)\mods\$($mod)\maps"
    $modRulesFolder = "$($PSScriptRoot)\mods\$($mod)\yaml"
    $luaFolder = "$($PSScriptRoot)\lua"

    # Skip directory if empty.
    $modMapCount = (Get-ChildItem -Path $modMapsFolder | Measure-Object).Count
    if ($modMapCount -eq 0) {
        continue;
    }

    # Targeted destination directory.
    $destination = "$($env:USERPROFILE)\AppData\Roaming\OpenRA\maps\$($mod)\$($openraVersion)"

    # Create destination if it doesn't exist.
    New-Item -ItemType Directory -Force -Path $destination | Out-Null

    # Copy all maps from a mod's map folder, and also the yaml/rules.
    $mapFolders = Get-ChildItem -Path $modMapsFolder
    foreach ($mapFolder in $mapFolders)
    {
        # Delete map if exists.
        $existingMapFolder = "$($destination)\$($mapFolder)"
        Remove-Item $existingMapFolder -Recurse -ErrorAction Ignore

        # Copy map.
        $mapFromPath = "$($modMapsFolder)\$($mapFolder)"
        Copy-Item -Path $mapFromPath -Destination $destination -Recurse -Force

        # Copy lua script(s).
        $scripttoPath = "$($destination)\$($mapFolder)\lua"
        Copy-Item -Path $luaFolder -Destination $scriptToPath -Recurse -Force

        # Copy rules.
        $rulesToPath = "$($destination)\$($mapFolder)\yaml\$($mod)"
        Copy-Item -Path $modRulesFolder -Destination $rulesToPath -Recurse -Force

        # Append any custom rules to map.yaml.
        $mapDotYamlPath = "$($destination)\$($mapFolder)\map.yaml"
        $mapDotYamlRulePaths = Get-MapYamlRulePaths($mod)
        Add-Content -Path $mapDotYamlPath -Value $mapDotYamlRulePaths
    }
}