-- Von Hand gepflegter Beispieldatensatz. Struktur = Datenvertrag der Spec.
-- Wird spaeter durch generierte Pipeline-Daten ersetzt.
MetaMirrorData = {
    version = "sample-2026-08-31",
    specs = {
        [1] = { -- Krieger
            [71] = { -- Waffen
                mythicplus = {
                    sampleSize = 100,
                    stats = {
                        { key = "haste",   pct = 34.0 },
                        { key = "crit",    pct = 28.0 },
                        { key = "mastery", pct = 22.0 },
                        { key = "vers",    pct = 16.0 },
                    },
                    talents = { { importString = "SAMPLE-ARMS-MPLUS", usagePct = 68 } },
                    gear = {
                        { slot = "HEAD",     itemID = 0, name = "Helm der Meta" },
                        { slot = "NECK",     itemID = 0, name = "Amulett der Meta" },
                        { slot = "SHOULDER", itemID = 0, name = "Schultern der Meta" },
                        { slot = "CHEST",    itemID = 0, name = "Robe der Meta" },
                        { slot = "MAINHAND", itemID = 0, name = "Klinge der Meta" },
                    },
                    gems     = { { slot = "RING1", itemID = 0, name = "+Tempo" } },
                    enchants = { { slot = "WEAPON", id = 0, name = "Waffe: Tempo" } },
                    consumables = { flask = 0, potion = 0, food = 0, rune = 0 },
                },
                raid = {
                    sampleSize = 100,
                    stats = {
                        { key = "haste",   pct = 30.0 },
                        { key = "crit",    pct = 32.0 },
                        { key = "mastery", pct = 22.0 },
                        { key = "vers",    pct = 16.0 },
                    },
                    talents = { { importString = "SAMPLE-ARMS-RAID", usagePct = 61 } },
                    gear = {
                        { slot = "HEAD", itemID = 0, name = "Raid-Helm" },
                        { slot = "NECK", itemID = 0, name = "Raid-Amulett" },
                    },
                    gems     = { { slot = "RING1", itemID = 0, name = "+Krit" } },
                    enchants = { { slot = "WEAPON", id = 0, name = "Waffe: Krit" } },
                    consumables = { flask = 0, potion = 0, food = 0, rune = 0 },
                },
            },
        },
        [8] = { -- Magier
            [64] = { -- Frost
                mythicplus = {
                    sampleSize = 100,
                    stats = {
                        { key = "haste",   pct = 25.0 },
                        { key = "crit",    pct = 33.0 },
                        { key = "mastery", pct = 20.0 },
                        { key = "vers",    pct = 22.0 },
                    },
                    talents = { { importString = "SAMPLE-FROST-MPLUS", usagePct = 72 } },
                    gear = { { slot = "HEAD", itemID = 0, name = "Frost-Kapuze" } },
                    gems     = { { slot = "RING1", itemID = 0, name = "+Krit" } },
                    enchants = { { slot = "WEAPON", id = 0, name = "Waffe: Intelligenz" } },
                    consumables = { flask = 0, potion = 0, food = 0, rune = 0 },
                },
                raid = {
                    sampleSize = 100,
                    stats = {
                        { key = "haste",   pct = 22.0 },
                        { key = "crit",    pct = 36.0 },
                        { key = "mastery", pct = 20.0 },
                        { key = "vers",    pct = 22.0 },
                    },
                    talents = { { importString = "SAMPLE-FROST-RAID", usagePct = 65 } },
                    gear = { { slot = "HEAD", itemID = 0, name = "Frost-Raidkapuze" } },
                    gems     = { { slot = "RING1", itemID = 0, name = "+Vielseitigkeit" } },
                    enchants = { { slot = "WEAPON", id = 0, name = "Waffe: Intelligenz" } },
                    consumables = { flask = 0, potion = 0, food = 0, rune = 0 },
                },
            },
        },
        [9] = { -- Hexenmeister
            [266] = { -- Daemonologie
                mythicplus = {
                    sampleSize = 100,
                    stats = {
                        { key = "haste",   pct = 30.0 },
                        { key = "crit",    pct = 24.0 },
                        { key = "mastery", pct = 28.0 },
                        { key = "vers",    pct = 18.0 },
                    },
                    talents = { { importString = "SAMPLE-DEMO-MPLUS", usagePct = 70 } },
                    gear = {
                        { slot = "HEAD", itemID = 0, name = "Demo-Kapuze" },
                        { slot = "NECK", itemID = 0, name = "Demo-Amulett" },
                    },
                    gems     = { { slot = "RING1", itemID = 0, name = "+Tempo" } },
                    enchants = { { slot = "WEAPON", id = 0, name = "Waffe: Intelligenz" } },
                    consumables = { flask = 0, potion = 0, food = 0, rune = 0 },
                },
                raid = {
                    sampleSize = 100,
                    stats = {
                        { key = "haste",   pct = 27.0 },
                        { key = "crit",    pct = 22.0 },
                        { key = "mastery", pct = 33.0 },
                        { key = "vers",    pct = 16.0 },
                    },
                    talents = { { importString = "SAMPLE-DEMO-RAID", usagePct = 64 } },
                    gear = {
                        { slot = "HEAD", itemID = 0, name = "Demo-Raidkapuze" },
                    },
                    gems     = { { slot = "RING1", itemID = 0, name = "+Meisterschaft" } },
                    enchants = { { slot = "WEAPON", id = 0, name = "Waffe: Intelligenz" } },
                    consumables = { flask = 0, potion = 0, food = 0, rune = 0 },
                },
            },
        },
    },
}
