// ================================================================
// vscript_loader_list_all.nut - Script list for the loader.
// ----------------------------------------------------------------
// The loader reads this file to know which scripts it will load.
// You can add as many scripts you want.
// The list shouldn't be loaded manually.
// ================================================================
Msg("[VSCRIPT LOADER] Loading vscript file list from " + __FILE__ + "\n");    // OPTIONAL

// OPTIONAL: The ID for the list. Can be any value. Use it when you want to detect any overrides from the custom or vscripts folder.
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
    path = "multijump"  // If not 'scope', the scope will be set to the root scope.
})

VscriptLoader.AddScript({
    path = "dummy_temp"

    // If 'scope' is g_MapVScript or contains a string with 'mapscript', then round_only is set to true
    scope = g_MapVScript    
    round_only = false

})
