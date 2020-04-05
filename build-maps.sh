#!/bin/bash

# Usage:
# ./build-maps.sh [-d|--deploy]

# Information:
# This script builds the Renegade 2D maps.
# Providing the "--deploy" argument will build the map in the appropriate OpenRA support folder, instead of a bin folder.
# In summary it:
# - Copies maps to the target destination (bin folder or OpenRA support folder)
# - Copies custom rules into the copied maps folders.
# - Copies lua script(s) into the copied maps folders.
# - Appends custom rules definitions to any copied maps' map.yaml files.
# This allows for one maintained source of Lua scripts & custom rules, separate from the maps themselves.

declare deploy=false
while :; do
    case $1 in
        --deploy) deploy=true
        ;;
        *) break
    esac
    shift
done

# The OpenRA engine version is set as a script variable, which should get updated when targeting new releases.
declare openraVersion="playtest-20200329"

# Move maps.
for modPath in mods/*; do
    declare mod=$(basename "$modPath")

    declare modMapsFolder="./${modPath}/maps"
    declare modRulesFolder="./${modPath}/yaml"
    declare luaFolder="./lua"

    # Skip directory if empty.
    declare modMapCount=$(ls ${modMapsFolder} -1 | wc -l)
    if [ $modMapCount == 0 ]
    then
        continue
    fi

    # Targeted destination directory.
    declare destination=""
    if [ $deploy == true ]
    then
        destination="${home}/.openra/maps/{$mod}/{$openraVersion}"
    else
        destination="./bin/maps/${mod}/${openraVersion}"
    fi

    # Create destination if it doesn't exist.
    mkdir -p $destination

    # Copy all maps from a mod's map folder, and also the yaml/rules.
    for fullMapFolder in $modMapsFolder/*; do
        declare mapFolder=$(basename "$fullMapFolder")

        # Delete map if exists.
        declare existingMapFolder="${destination}/${mapFolder}"
        if [ -d "$existingMapFolder" ]; then rm -rf $existingMapFolder; fi

        # Copy map.
        declare mapFromPath="${modMapsFolder}/${mapFolder}"
        cp -r $mapFromPath $destination

        # Copy lua script(s).
        declare scriptToPath="${destination}/${mapFolder}/lua"
        cp -r $luaFolder $scriptToPath

        # Copy rules
        declare rulesToPath="${destination}/${mapFolder}/yaml/${mod}"
        mkdir -p $rulesToPath
        cp -r $modRulesFolder $rulesToPath

        # Append any custom rules to map.yaml
        # This should not be hard-coded, see the powershell script.
        declare mapDotYamlPath="${destination}/${mapFolder}/map.yaml"
        echo "\n" >> $mapDotYamlPath
        echo "Rules: yaml\cnc\rules\aircraft.yaml, yaml\cnc\rules\defaults.yaml, yaml\cnc\rules\infantry.yaml, yaml\cnc\rules\renegade.yaml, yaml\cnc\rules\rules.yaml, yaml\cnc\rules\structures.yaml, yaml\cnc\rules\vehicles.yaml" >> $mapDotYamlPath
        echo "Weapons: yaml\cnc\weapons\weapons.yaml" >> $mapDotYamlPath
        echo "Notifications: yaml\cnc\notifications\notifications.yaml" >> $mapDotYamlPath
        echo "Sequences: yaml\cnc\sequences\sequences.yaml" >> $mapDotYamlPath
    done
done