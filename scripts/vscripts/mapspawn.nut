Msg("VSCRIPT: Running mapspawn.nut\n");

// VSCRIPT LOADER SYSTEM.
// SUPPORTED GAMES: TF2, CSS, DOD, HL2DM, HLSDM and any TF2 branch engine game.
// UNSUPPORTED GAMES: L4D2 (Make a pull-req if you make it work in that game)
// ---------------------------------------------------------------------
// Globals
// ---------------------------------------------------------------------
g_VscriptFileOrder <- 1;                        // File counter
g_iVscriptMaxLoad <- 256;                       // Maximum allowed vscript files to be loaded
g_VscriptListFile <- "vscript_loader_list_all"; // list file path
g_VscriptFileList <- {                          // List of vscript files
    default_data = []   // All scripts will be added here.
    round_only = []     // round-only scripts are added here.
}         
g_VscriptScopedScripts <- {};                   // Scoped scripts will be referenced here by its path if 'scope' is not null, root or g_MapVScript scope
g_MapVScript <- {}                              // Scope for round-only scripts (like l4d2's director_base_addon).

// ---------------------------------------------------------------------
// Excecution
// ---------------------------------------------------------------------
local vsloader_version = 1.0;
if (!("VscriptLoader" in this) || VscriptLoader.Version < vsloader_version)
{
    ::VscriptLoader <- {
        Version = vsloader_version
        Calls = 0
        Enabled = true
        ShouldLoadFiles = false
        FileLoadFinished = false
        EntityToListen = null
        RoundStartCount = 0

        function IsValidEntity(entity)
        {
            return entity != null && entity.IsValid() && entity instanceof CBaseEntity;
        }

        function GetGameName()
        {   // Only for vscript supported official games!
            if ("CTFPlayer" in getroottable() && "AddCond" in ::CTFPlayer && ::CTFPlayer.AddCond.getinfos().native)
                return "TF2";

            if ("CTerrorPlayer" in getroottable() && "GetButtonMask" in ::CTerrorPlayer && ::CTerrorPlayer.GetButtonMask.getinfos().native)
                return "L4D2";

            if ("CPortal_Player" in getroottable() && "TurnOnPotatos" in ::CPortal_Player && ::CPortal_Player.TurnOnPotatos.getinfos().native)
                return "PORTAL2";

            if ("CGameCoopMissionManager" in getroottable() 
                && "GetWaveNumber" in ::CGameCoopMissionManager 
                && ::CGameCoopMissionManager.GetWaveNumber.getinfos().native)
                return "CSGO";
            else if (Convars.GetFloat("ammo_hegrenade_max") != null)
                return "CSS";

            if (Convars.GetFloat("dod_bonusround") != null)
                return "DODS";

            if (Convars.GetFloat("hl1_new_pull") != null)
                return "HLDMS"; // Half-Life Deathmatch: Source

            return "HL2DM";
        }

        function IsCheatSession()
        {
            return developer() > 0 || Convars.GetFloat("sv_cheats") > 0;
        }

        function errorl(msg)
        {   // Prints an error message with a line feed after.
            error(msg + "\n");
        }

        function IncludeScriptSafe(file, scope = null)
        {
            local gr = {data = file success = null error = null};
            try 
            {
                local status = IncludeScript(file, scope);
                gr.success = status;
                gr.error = "";
            }
            catch (ex)
            {
                gr.success = false;
                gr.error = ex;
            }
            return gr;
        }

        // Slightly modified from the VDC website. Adding support for logical entities that doesn't have an entity index
        // because they will always return 0 -> EntIndexToHScript(0) -> null.
        function SetDestroyCallback(entity, callback)
        {
            entity.ValidateScriptScope();
            local original_scope = entity.GetScriptScope();
            original_scope.setdelegate({}.setdelegate({
                    parent   = original_scope.getdelegate()
                    id       = entity.GetScriptId()
                    index    = entity.entindex()
                    callback = callback
                    _get = function(k)
                    {
                        return parent[k]
                    }
                    
                    _delslot = function(k)
                    {
                        if (k == id)
                        {
                            entity = EntIndexToHScript(index);
                            local scope;
                            if (!entity || !entity.IsValid())
                                scope = original_scope;
                            else                        
                                scope = entity.GetScriptScope();

                            scope.self <- entity;
                            callback.pcall(scope);
                        }
                        delete parent[k]
                    }
                })
            )
        }

        function ConstructEntity(from_event = "")
        {
            if (IsValidEntity(EntityToListen))
                return;

            if (IsCheatSession())
                printl("[VSCRIPT LOADER][DEBUG] Constructing EntityToListen in event " + from_event);

            EntityToListen = Entities.CreateByClassname("logic_timer");
            EntityToListen.KeyValueFromString("targetname", UniqueString("dummy_logictimer_private"));
            NetProps.SetPropBool(EntityToListen, "m_bForcePurgeFixedupStrings", true);
            SetDestroyCallback(EntityToListen, function()
            {
                ///// TRICK TO LISTEN WHEN A SERVER CLOSES OR CHANGES LEVEL /////
                // First() doesn't always return worldspawn if we don't restart from the very first round for listen servers.
                // it can return the host instead.
                // local world = Entities.First();   
                local world = Entities.FindByClassname(null, "worldspawn");
                // To avoid loading round-only scripts again if the map changes or server closes because the VM is still alive for a few ms.
                if (!world || !world.IsValid())
                {
                    if (::VscriptLoader.IsCheatSession())
                        printl("[VSCRIPT LOADER][DEBUG] Server shutdown or changelevel detected. Not reloading scripts\n\t" +
                                "worldspawn handle: " + world + " | mapname: " + GetMapName() + " | time: " + Time() + " | frame: " + GetFrameCount());

                    return;
                }

                if ("g_MapVScript" in getroottable() && g_MapVScript != null) 
                {
                    g_MapVScript.clear(); // clean the table
                    ::VscriptLoader.LoadRoundOnlyFiles();
                }
                if (::VscriptLoader.IsCheatSession())
                    printl("[VSCRIPT LOADER][DEBUG] EntityToListen HAS BEEN REMOVED, HOPE THIS WORKS BEFORE STARTING A NEW ROUND");
            })
        }

        function AddScript(script_data)
        {
            if (typeof script_data != "table" || script_data.len() == 0)
                return;

            local path = "path" in script_data ? script_data["path"] : null;
            local scope = "scope" in script_data ? script_data["scope"] : null;
            local round_only = "round_only" in script_data ? !!script_data["round_only"] : false;

            if (!scope || scope == getroottable()|| scope == this || scope.tostring().tolower() == "root")
            {
                script_data["scope"] <- "ROOT";
            }
            script_data["order_in_list"] <- g_VscriptFileList["default_data"].len()+1;
            script_data["is_loaded"] <- false;

            if (round_only || (scope && (scope == getroottable()["g_MapVScript"] || scope.tostring().tolower().find("mapscript") != null)))
            {
                script_data["scope"] <- "g_MapVScript";
                script_data["round_only"] <- true;
                g_VscriptFileList["round_only"].push(script_data);
            }
            g_VscriptFileList["default_data"].push(script_data);
            return true;
        }

        function LoadFiles()
        {
            // It seems for Half-Life Deathmatch: Source, "mapspawn.nut" runs twice. Check VscriptLoader.Calls
            // There's no round restart like HL2DM tho, so round-only scripts would be useless for that game.
            // Almost nobody plays it but i'm giving it some support btw.
            if (!ShouldLoadFiles || (GetGameName() != "HLDMS" && FileLoadFinished) || Calls > 1)
                return;

            printl("======================================= LOAD FILES =======================================");
            local loaded_count = 0;
            local len = g_VscriptFileList["default_data"].len();
            for (local i = 0; i < len && g_VscriptFileOrder <= g_iVscriptMaxLoad; i++)
            {
                local script = g_VscriptFileList["default_data"][i];
                local path = "path" in script ? script["path"] : null;
                local scope = "scope" in script ? script["scope"] : null;
                local round_only = "round_only" in script ? script["round_only"] : false;

                if (!path)
                {
                    printl("[VSCRIPT LOADER] File " + g_VscriptFileOrder + " has no 'path'. Skipping...");
                    g_VscriptFileOrder++;
                    continue;
                }

                if (scope == "ROOT")
                    scope = getroottable();

                if (round_only)
                {
                    if ("scope" in script)
                        script["scope"] = "g_MapVScript";

                    scope = getroottable()["g_MapVScript"];
                }

                local response = IncludeScriptSafe(path, scope);
                if (path.find(".nut") == null || !endswith(path, ".nut"))
                    path += ".nut";

                if (response.success)
                {
                    printl(">>> Loaded addon script " + path + " (Order in list: " + g_VscriptFileOrder + ")");
                    if (scope != getroottable() && scope != getroottable()["g_MapVScript"])
                        g_VscriptScopedScripts[path] <- scope;

                    loaded_count++;
                    script["is_loaded"] = true;
                }
                else
                {
                    errorl("[VSCRIPT LOADER] Couldn't load file " + path + " (Order in list: " + g_VscriptFileOrder + ")");
                }
                g_VscriptFileOrder++;
            }
            printl("[VSCRIPT LOADER] Done. " + loaded_count + "/" + len + " scripts loaded.");
            printl("======================================= LOAD FILES =======================================");

            FileLoadFinished = true;
        }

        function LoadRoundOnlyFiles()
        {
            if (Calls < 1)
            {
                //Calls++;
                if (IsCheatSession())
                    printl("[VSCRIPT LOADER][DEBUG] Attempt to call LoadRoundOnlyFiles() failed.")

                return;
            }
            if (g_VscriptFileList["round_only"].len() == 0)
            {
                printl("[VSCRIPT LOADER] No round-only scripts to load.");
                return;
            }

            printl("==================================== ROUND-ONLY FILES ====================================");
            printl("[VSCRIPT LOADER] Loading round-only scripts...");
            local round_only_order = 1;
            local round_only_loaded_count = 0;
            local round_only_len = g_VscriptFileList["round_only"].len();
            for (local i = 0; i < round_only_len && round_only_order <= g_iVscriptMaxLoad; i++)
            {
                local script = g_VscriptFileList["round_only"][i];
                script["is_loaded"] = false;    // Reseting state
                local path = "path" in script ? script["path"] : null;
                local scope = "scope" in script ? script["scope"] : null;
                local round_only = "round_only" in script ? script["round_only"] : false;
                local order_in_list = script["order_in_list"];

                if (!path)
                {
                    printl("[VSCRIPT LOADER] File " + order_in_list + " has no 'path'. Skipping...");
                    round_only_order++;
                    continue;
                }

                if (!round_only)
                    continue;
                else
                    scope = getroottable()["g_MapVScript"];

                local response = IncludeScriptSafe(path, scope);
                if (path.find(".nut") == null || !endswith(path, ".nut"))
                    path += ".nut";

                if (response.success)
                {
                    printl(">>> Loaded addon script " + path + " (Order in list: " + order_in_list + ")");
                    if (scope != getroottable() && scope != getroottable()["g_MapVScript"])
                        g_VscriptScopedScripts[path] <- scope;

                    round_only_loaded_count++;
                    script["is_loaded"] = true;
                }
                else
                {
                    errorl("[VSCRIPT LOADER] Couldn't load file " + path + " (Order in list: " + order_in_list + ")");
                }
                round_only_order++;
            }
            printl("[VSCRIPT LOADER] Done. " + round_only_loaded_count + "/" + round_only_len + " round-only scripts loaded.");
            printl("==================================== ROUND-ONLY FILES ====================================");
        }

        function Init()
        {
            // No support for l4d2. Use the built-in addon script loader system instead.
            // The destroy callback doesn't work well, making LoadRoundOnlyFiles() never be called. 
            if (!Enabled)
                return;

            printl("==========================================================================================");
            printl("VSCRIPT: Initializing VSCRIPT LOADER. Version: " + Version.tofloat());
            local res = IncludeScriptSafe(g_VscriptListFile, getroottable());
            if (!res.success)
            {
                errorl("[VSCRIPT LOADER] Could not load list file: " + g_VscriptListFile);
                errorl("Error: " + res.error);
                return;
            }

            // Showing the list id just in case the user want to reassure their list is actually loading.
            if ("g_VscriptListId" in getroottable())
                printl("[VSCRIPT LOADER] Active list ID: " + g_VscriptListId);
            else 
                printl("[VSCRIPT LOADER] No list ID found in " + g_VscriptListFile);

            // The script stops here if the list is empty.
            if (!g_VscriptFileList || g_VscriptFileList.len() == 0 || g_VscriptFileList["default_data"].len() == 0)
            {
                errorl("[VSCRIPT LOADER] Script list empty. Not loading.")
                return;
            }
            ShouldLoadFiles = true;
            LoadFiles();
            ConstructEntity("VscriptLoader::Init()");

            Calls++;
        }
    }
}

if (!("Events" in VscriptLoader))
{
    VscriptLoader.Events <- {
        OnGameEvent_round_start = function(params)
        {   // Binded enviroment to the VscriptLoader scope
            // HL2DM doesn't trigger this event until the round is restarted by mp_restartround.
            // CSS triggers this event very early when loading the map causing round-only scripts be called twice the first time:
            // mapsapwn.nut (LoadFiles()) -> EntityToListen is destroyed -> LoadRoundOnlyFiles() -> round_start
            // For tf2 and dods, this event isn't called.
            ConstructEntity("round_start");
            RoundStartCount++;
        }.bindenv(VscriptLoader)

        // For TF2 and DODS, they use their respective "round_start" events.
        // In this case they are called when the first player is spawned (from spectator) and the warmup period starts.
        // Hopefully, LoadRoundOnlyFiles() isn't called twice when the map loads for both games.
        // BUT, for TF2 MVM mode, round-only scripts are called twice after a successful change difficulty vote.
        // Entities are reseted twice, causing recalculate_holidays be triggered two times in a frame?

        // TF2 SUPPORT
        OnGameEvent_teamplay_round_start = function(params)
        {	// Team Fortress 2 round_start event.
            if (GetGameName() != "TF2") // No SendGlobalGameEvent() calls
                return;

            ConstructEntity("teamplay_round_start");
            RoundStartCount++;
        }.bindenv(VscriptLoader)

        OnGameEvent_scorestats_accumulated_update = function(params)
        {   // CLEANUP EVENT
            if (IsValidEntity(EntityToListen) && GetGameName() == "TF2")
            {
                if (IsCheatSession())
                    printl("[VSCRIPT LOADER][DEBUG] Killing EntityToListen in scorestats_accumulated_update");

                EntityToListen.Kill();
            }
        }.bindenv(VscriptLoader)

        OnGameEvent_recalculate_holidays = function(params)
        {   // CLEANUP EVENT FOR MVM?
            if ("GetRoundState" in getroottable() && GetRoundState.getinfos().native && GetRoundState() == 3)
            {   // GetRoundState.getinfos().native makes already sure it's from the tf2 vscript api.
                if (IsValidEntity(EntityToListen))
                {
                    if (IsCheatSession())
                        printl("[VSCRIPT LOADER][DEBUG] Killing EntityToListen in recalculate_holidays");

                    EntityToListen.Kill();
                }
            }
        }.bindenv(VscriptLoader)
        // TF2 SUPPORT

        // DOD SUPPORT
        OnGameEvent_dod_round_start = function(params)
        {   // Day of Defeat Source round_start event.
            if (GetGameName() != "DODS")    // No SendGlobalGameEvent() calls
                return;

            ConstructEntity("dod_round_start");
            RoundStartCount++;
        }.bindenv(VscriptLoader)
        // DOD SUPPORT
    }
}
__CollectGameEventCallbacks(VscriptLoader.Events);
VscriptLoader.Init();






