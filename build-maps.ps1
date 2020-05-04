# Usage:
# ./build-maps.ps1 [-Deploy] [-NoRuleCopy]

# This script builds the Renegade 2D maps.
# Providing the "-Deploy" argument will build the map in the appropriate OpenRA support folder, instead of a bin folder. Currently supported on Windows only.
# Providing the "-NoRuleCopy" argument will ignore copying over yaml rules and lua; useful when making layout changes in the map editor.

# In summary it:
# - Copies maps to the target destination (bin folder, or OpenRA support folder if providing -Deploy).
# - Copies custom rules into the copied maps folders.
# - Copies lua script(s) into the copied maps folders.
# - Appends custom rules definitions to any copied maps' map.yaml files (skipped if providing -NoRuleCopy).

[CmdLetBinding()]
param(
    [switch]$Deploy,
    [switch]$NoRuleCopy
)

# The OpenRA engine version is set as a script variable, which should get updated when targeting new releases.
$openraVersion = 'release-20200503'

# Returns yaml custom rule strings.
function Get-MapYamlRulePaths($mod)
{
    $modYaml = "$($PSScriptRoot)\mods\$($mod)\yaml\"

    # Hacky; instead of this, loop through subfolders and append appropriately.
    $yaml = "`nRules: " + (((Get-ChildItem "$($modYaml)\rules") | ForEach-Object { "yaml\$($mod)\rules\$($_.Name)" }) -join ', ')
    $yaml += "`nWeapons: " + (((Get-ChildItem "$($modYaml)\weapons") | ForEach-Object { "yaml\$($mod)\weapons\$($_.Name)" }) -join ', ')
    $yaml += "`nNotifications: " + (((Get-ChildItem "$($modYaml)\notifications") | ForEach-Object { "yaml\$($mod)\notifications\$($_.Name)" }) -join ', ')
    $yaml += "`nSequences: " + (((Get-ChildItem "$($modYaml)\sequences") | ForEach-Object { "yaml\$($mod)\sequences\$($_.Name)" }) -join ', ')

    return $yaml
}

# Move maps.
foreach ($mod in Get-ChildItem "$($PSScriptRoot)\mods\")
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
    $destination = ""
    if ($Deploy) {
        $destination = "$($env:USERPROFILE)\AppData\Roaming\OpenRA\maps\$($mod)\$($openraVersion)"
    } else {
        $destination = "$($PSScriptRoot)\bin\maps\$($mod)\$($openraVersion)"
    }

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

        if (!$NoRuleCopy) {
            # Copy rules.
            $rulesToPath = "$($destination)\$($mapFolder)\yaml\$($mod)"
            Copy-Item -Path $modRulesFolder -Destination $rulesToPath -Recurse -Force

            # Append any custom rules to map.yaml.
            $mapDotYamlPath = "$($destination)\$($mapFolder)\map.yaml"
            $mapDotYamlRulePaths = Get-MapYamlRulePaths($mod)
            Add-Content -Path $mapDotYamlPath -Value $mapDotYamlRulePaths

            # Copy lua script(s).
            $scriptToPath = "$($destination)\$($mapFolder)\lua"
            Copy-Item -Path $luaFolder -Destination $scriptToPath -Recurse -Force
        }
    }
}