#!/bin/bash

# This script is different from the powershell "build-maps.ps1" script.
# - It currently hard codes all the .yaml rule file paths.
# - It does not yet copy to the OpenRA support directory. This script copies to a /bin folder instead.
# Eventually both scripts should function identically.

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
    declare destination="./bin"

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