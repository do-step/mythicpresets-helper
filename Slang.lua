local ADDON, MPH = ...

MPH.SLANG = {
    classes = {
        DEATHKNIGHT = {
            { 47528 }, { 61999 }, { 49576, "cc" }, { 221562, "cc" }, { 108199, "aoe cc" },
            { 207167, "aoe cc" }, { 48707 }, { 51052 }, { 48792 },
        },
        DEMONHUNTER = {
            { 183752 }, { 217832, "cc" }, { 179057, "aoe cc" }, { 207684, "aoe cc" }, { 202138, "aoe cc" },
            { 196718 }, { 191427 }, { 278326 },
        },
        DRUID = {
            { 20484 }, { 106839 }, { 78675 }, { 5211, "cc" }, { 33786, "cc" }, { 102793, "aoe cc" },
            { 132469, "aoe cc" }, { 99, "aoe cc" }, { 102359, "aoe cc" }, { 106898 }, { 29166 },
            { 22812 }, { 2908 },
        },
        EVOKER = {
            { 351338 }, { 390386 }, { 360806, "cc" }, { 368970, "aoe cc" }, { 357214, "aoe cc" },
            { 358385, "aoe cc" }, { 370665 }, { 374968 }, { 374227 }, { 374251 },
        },
        HUNTER = {
            { 147362 }, { 187707 }, { 264667 }, { 187650, "cc" }, { 19577, "cc" }, { 109248, "aoe cc" },
            { 236776, "aoe cc" }, { 19801 }, { 34477 }, { 186265 }, { 5384 },
        },
        MAGE = {
            { 2139 }, { 80353 }, { 118, "cc" }, { 113724, "aoe cc" }, { 122, "aoe cc" }, { 157981, "aoe cc" },
            { 31661, "aoe cc" }, { 45438 }, { 30449 }, { 475 }, { 1953 }, { 1459 },
        },
        MONK = {
            { 116705 }, { 115078, "cc" }, { 119381, "aoe cc" }, { 116844, "aoe cc" }, { 116849 },
            { 115203 }, { 115310 },
        },
        PALADIN = {
            { 96231 }, { 853, "cc" }, { 20066, "cc" }, { 115750, "aoe cc" }, { 642 }, { 1022 }, { 1044 },
            { 6940 }, { 633 }, { 391054 },
        },
        PRIEST = {
            { 10060 }, { 15487 }, { 9484, "cc" }, { 64044, "cc" }, { 8122, "aoe cc" }, { 32375 }, { 73325 },
            { 528 }, { 62618 }, { 33206 }, { 47788 },
        },
        ROGUE = {
            { 1766 }, { 408, "cc" }, { 1833, "cc" }, { 2094, "cc" }, { 6770, "cc" }, { 1776, "cc" },
            { 114018 }, { 31224 }, { 57934 }, { 5938 },
        },
        SHAMAN = {
            { 57994 }, { 2825 }, { 51514, "cc" }, { 192058, "aoe cc" }, { 51490, "aoe cc" }, { 370 },
            { 8143 }, { 98008 }, { 108271 },
        },
        WARLOCK = {
            { 20707 }, { 6201 }, { 111771 }, { 698 }, { 19647 }, { 5782, "cc" }, { 6789, "cc" },
            { 710, "cc" }, { 30283, "aoe cc" },
        },
        WARRIOR = {
            { 6552 }, { 107570, "cc" }, { 46968, "aoe cc" }, { 5246, "aoe cc" }, { 6673 }, { 97462 },
            { 23920 }, { 871 },
        },
    },
    sections = {
        {
            title = "slang.abilities",
            keys = {
                "cd", "bl", "br", "kick", "stun", "cc", "aoecc", "dispel", "purge", "taunt", "aoe",
                "cleave", "dd", "rangedmelee",
            },
        },
        {
            title = "slang.mplus",
            keys = {
                "key", "timed", "deplete", "keyupgrade", "m0", "pull", "bpbl", "skip", "trash", "forces",
                "rio", "pug",
            },
        },
        {
            title = "slang.raid",
            keys = {
                "lfr", "normal", "heroic", "mythic", "rl", "progress", "farm", "try", "kill", "wipe",
                "phase", "adds", "swap", "soak", "stack", "spread", "kite", "enrage",
            },
        },
        {
            title = "slang.loot",
            keys = {
                "loot", "bis", "ilvl", "upgrade", "trade", "roll", "mainspec", "offspec", "tier", "socket",
                "vault", "INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER", "INVTYPE_CLOAK",
                "INVTYPE_CHEST", "INVTYPE_WRIST", "INVTYPE_HAND", "INVTYPE_WAIST", "INVTYPE_LEGS",
                "INVTYPE_FEET", "INVTYPE_FINGER", "INVTYPE_TRINKET", "INVTYPE_WEAPON", "INVTYPE_2HWEAPON",
                "INVTYPE_HOLDABLE", "INVTYPE_SHIELD",
            },
        },
    },
}
