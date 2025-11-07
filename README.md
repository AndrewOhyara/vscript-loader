# Vscript Loader
A simple loader for vscript files for those game that don't have the l4d2's built-in addon script loader system (aka mapspawn_addon, director_base_addon, scriptedmode_addon).

Runs at map spawn and between rounds. Includes a table for scoped scripts.

Supported games: TF2, CSS, DODS, HL2DM, HLDMS and any TF2 branch engine game.

# Index
- [Installation](#installation)
- [Files](#files)
- [Global variables](#global-variables)
- [Vscript file list](#vscript-list-file)
- [Notes](#notes)

## Installation
1. Download "vscript_loader.zip" from Releases and extract it in: <game_folder>/custom

## Files
- mapsapwn.nut -> The loader script. Runs at every map load.
- vscript_file_list_all.nut -> The vscript list you can edit.
- dummy_temp.nut -> A simple test script file.

## Global Variables
```squirrel
g_VscriptFileOrder <- 1;                        // File counter
g_iVscriptMaxLoad <- 256;                       // Maximum allowed vscript files to be loaded
g_VscriptListFile <- "vscript_loader_list_all"; // list file path
g_VscriptFileList <- {                          // List of vscript files
    default_data = []   // All scripts will be added here.
    round_only = []     // round-only scripts are added here.
}         
g_VscriptScopedScripts <- {};                   // Scoped scripts will be referenced here by its path if 'scope' is not null, root or g_MapVScript scope
g_MapVScript <- {}                              // Scope for round-only scripts (like l4d2's director_base_addon)


// Scoped scripts will be referenced here by its path if 'scope' is not null, root or g_MapVScript scope
// Example: g_VscriptScopedScripts["my_script_file.nut"] will reference its own scope
g_VscriptScopedScripts <- {}; 
```

## Vscript List File
In the list file:
```squirrel
// OPTIONAL: The ID for the list. Can be any value. 
// Use it when you want to detect any overrides from custom or vscripts folder.
g_VscriptListId <- "my_default_list_v1";

 // Max files to be loaded. Can be set to more but for now it's 256 by default. 
g_iVscriptFileLoadMax <- 256; 

// EXAMPLE - If "dummy_script_tob_load" doesn't exist, it will return an error message and continue with the list.
VscriptLoader.AddScript({
    path = "dummy_script_tob_load" 
    scope = null 
})

// Add your scripts here
VscriptLoader.AddScript({
    path = "custom_functions/init"
    scope = "ROOT"  // Supported strings to include the script in the root scope (same with "root").
})

VscriptLoader.AddScript({
    path = "l4d2-like_muzzleflashes.nut"    // The extension ".nut" is optional
    scope = null    // If round_only is true, the scope is ignored and set to g_MapScript
    round_only = true	// This will make the loader execute the script on every round
})

VscriptLoader.AddScript({
    path = "gift_grab_achievement"
    scope = null    // If 'scope' is null, the scope will be set to the root scope
})

VscriptLoader.AddScript({
    path = "dissolver-bullet_tracer"
    scope = this    // Same as if 'scope' is null.
})

VscriptLoader.AddScript({
    path = "multijump"  // If no 'scope', the scope will be set to the root scope.
})

VscriptLoader.AddScript({
    path = "dummy_temp"

    // If 'scope' is g_MapVScript or contains a string with 'mapscript', then round_only is set to true
    scope = g_MapVScript    
    round_only = false
})

/*
The console may print something like this (Example in CS:S):
==========================================================================================
VSCRIPT: Initializing VSCRIPT LOADER. Version: 1
[VSCRIPT LOADER] Loading vscript file list from vscript_loader_list_all.nut
[VSCRIPT LOADER] Active list ID: my_default_list_v1
======================================= LOAD FILES =======================================
Script not found (scripts/vscripts/dummy_script_tob_load.nut) 
[VSCRIPT LOADER] Couldn't load file dummy_script_tob_load.nut (Order in list: 1)
[CSS Custom Functions] Loading script...
>>> Loaded addon script custom_functions/init.nut (Order in list: 2)
>>> Loaded addon script hook_and_update_system.nut (Order in list: 3)
>>> Loaded addon script l4d2-like_muzzleflashes.nut (Order in list: 4)
>>> Loaded addon script gift_grab_achievement.nut (Order in list: 5)
>>> Loaded addon script dissolver-bullet_tracer.nut (Order in list: 6)
[MultiJump Vscript] Initializing script...
>>> Loaded addon script multijump.nut (Order in list: 7)
Running dummy round-only script in g_MapVScript scope 1.005
is in g_MapVScript scope: true
>>> Loaded addon script dummy_temp.nut (Order in list: 8)
[VSCRIPT LOADER] Done. 7/8 scripts loaded.
======================================= LOAD FILES =======================================
[VSCRIPT LOADER][DEBUG] Constructing EntityToListen in event VscriptLoader::Init()
THE GIFT GRAB EVENT IS INACTIVE. ACTIVATING...
==================================== ROUND-ONLY FILES ====================================
[VSCRIPT LOADER] Loading round-only scripts...
>>> Loaded addon script l4d2-like_muzzleflashes.nut (Order in list: 4)
Running dummy round-only script in g_MapVScript scope 1.005
is in g_MapVScript scope: true
>>> Loaded addon script dummy_temp.nut (Order in list: 8)
[VSCRIPT LOADER] Done. 2/2 round-only scripts loaded.
==================================== ROUND-ONLY FILES ====================================
[VSCRIPT LOADER][DEBUG] EntityToListen HAS BEEN REMOVED, HOPE THIS WORKS BEFORE STARTING A NEW ROUND
*/
```

## Notes
- If you have another mapspawn.nut file, to avoid conflicts, copy the contents from this mapspawn and paste it into your mapspawn file.
- "round-only" scripts are loaded in the g_MapVScript scope. Use g_MapVScript.<your_table> (eg. g_MapVScript.MyScriptExample)
- You can set the limit of maximum loads in the list file.
- Half-Life Deathmatch: Source doesn't have rounds making round-only scripts useless.
