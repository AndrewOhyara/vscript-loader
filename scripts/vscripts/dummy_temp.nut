printl("Running dummy round-only script in g_MapVScript scope " + Time());
printl("is in g_MapVScript scope: " + ("g_MapVScript" in getroottable() ? this == getroottable()["g_MapVScript"] : false));
MyScriptExample <- {
    counter = 0 // If this is a round-only script, this value should never be more than 1 on every new round.
    function OnGameEvent_round_start(params)
    {
        counter++;
        printl("HELLO, USER! " + counter + " | address " + this)
        ClientPrint(null, 3, "HELLO, USER! SERVER TIME: " + Time() + " | " + counter);
    }

    OnGameEvent_dod_round_start = function(params)
    {	// round_start for DODS
        counter++;
        printl("HELLO, USER IN DODS! " + counter + " | address " + this)
        ClientPrint(null, 3, "HELLO, USER IN DODS! TIME: " + Time() + " | " + counter);
    }

    OnGameEvent_teamplay_round_start = function(params)
    {	// round_start for TF2
        counter++;
        printl("HELLO, USER IN TF2! " + counter + " | address " + this)
        ClientPrint(null, 3, "HELLO, USER IN TF2! TIME: " + Time() + " | " + counter);
    }
}
__CollectGameEventCallbacks(MyScriptExample);