--[[
    AutoHuntLog Master Script

    Combines all chunks:
    1. Read hunt log for incomplete mobs
    2. Look up spawn location from MobData
    3. Navigate to location
    4. Kill required mobs
    5. Repeat until all complete

    For GC hunt logs, also supports:
    - Dungeon mobs via AutoDuty
    - GC rank-up quest completion via Questionable
]]

-------------------------------------------------
-- SETTINGS
-------------------------------------------------
local Settings = {
    -- Hunt Log Type
    hunt_type = "gc",          -- "class" for current job's hunt log, "gc" for Grand Company

    -- GC Dungeon Settings (only used when hunt_type = "gc")
    do_dungeons = true,           -- Run dungeons for GC hunt log mobs
    do_extra_dungeons = true,     -- Run Dzemael Darkhold / Aurum Vale for rank 9
    stop_at_rank_two = false,     -- Stop after rank 2 (skip rank 3)
    duty_timer_limit = 20,        -- Minutes before abandoning a dungeon

    -- Rank-up Settings (only used when hunt_type = "gc")
    do_rankup = true,             -- Attempt to rank up after completing logs

    -- Movement Settings
    mount_name = "Company Chocobo"  -- Fallback mount if Mount Roulette fails
}

-------------------------------------------------
-- ClassJob ID to Hunt Log Index mapping
-------------------------------------------------
-- Maps game ClassJob IDs to hunt log callback indices
-- AtkValue test order: GLA, PGL, MRD, LNC, ARC, ROG, CNJ, THM, ACN, GC
local ClassJobToHuntLog = {
    -- Base classes
    [1] = 0,   -- GLA -> index 0
    [2] = 1,   -- PGL -> index 1
    [3] = 2,   -- MRD -> index 2
    [4] = 3,   -- LNC -> index 3
    [5] = 4,   -- ARC -> index 4
    [29] = 5,  -- ROG -> index 5
    [6] = 6,   -- CNJ -> index 6
    [7] = 7,   -- THM -> index 7
    [26] = 8,  -- ACN -> index 8
    -- Jobs (map to their base class)
    [19] = 0,  -- PLD -> GLA
    [20] = 1,  -- MNK -> PGL
    [21] = 2,  -- WAR -> MRD
    [22] = 3,  -- DRG -> LNC
    [23] = 4,  -- BRD -> ARC
    [30] = 5,  -- NIN -> ROG
    [24] = 6,  -- WHM -> CNJ
    [25] = 7,  -- BLM -> THM
    [27] = 8,  -- SMN -> ACN
    [28] = 8,  -- SCH -> ACN
}

-------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------
local function Debug(msg)
    yield("/echo [Hunt] " .. tostring(msg))
end

local function Sleep(s)
    yield("/wait " .. tostring(s))
end

Debug("=== AutoHuntLog Master ===")

-- Hunt log index names (matches AtkValue test order)
local HuntLogNames = {[0]="GLA",[1]="PGL",[2]="MRD",[3]="LNC",[4]="ARC",[5]="ROG",[6]="CNJ",[7]="THM",[8]="ACN",[9]="GC"}

-- Get current class hunt log index from player's job
local function GetCurrentClassIndex()
    return ClassJobToHuntLog[Player.Job.Id]
end

-- Show configured hunt type
if Settings.hunt_type == "gc" then
    Debug("Mode: Grand Company hunt logs")
else
    local classIdx = GetCurrentClassIndex()
    if classIdx then
        Debug("Mode: Class hunt logs (" .. (HuntLogNames[classIdx] or "Unknown") .. ")")
    else
        Debug("Mode: Class hunt logs (unsupported job - no hunt log)")
    end
end

-------------------------------------------------
-- TERRITORY LOOKUP (embedded)
-------------------------------------------------
Territories = {
    ["129"]="Limsa Lominsa Lower Decks",
    ["130"]="Ul'dah - Steps of Nald",
    ["131"]="Ul'dah - Steps of Thal",
    ["132"]="New Gridania",
    ["133"]="Old Gridania",
    ["134"]="Middle La Noscea",
    ["135"]="Lower La Noscea",
    ["136"]="Mist",
    ["137"]="Eastern La Noscea",
    ["138"]="Western La Noscea",
    ["139"]="Upper La Noscea",
    ["140"]="Western Thanalan",
    ["141"]="Central Thanalan",
    ["142"]="Halatali",
    ["143"]="",
    ["144"]="The Gold Saucer",
    ["145"]="Eastern Thanalan",
    ["146"]="Southern Thanalan",
    ["147"]="Northern Thanalan",
    ["148"]="Central Shroud",
    ["149"]="The Feasting Grounds",
    ["150"]="",
    ["151"]="The World of Darkness",
    ["152"]="East Shroud",
    ["153"]="South Shroud",
    ["154"]="North Shroud",
    ["155"]="Coerthas Central Highlands",
    ["156"]="Mor Dhona",
    ["157"]="",
    ["158"]="",
    ["159"]="The Wanderer's Palace",
    ["160"]="Pharos Sirius",
    ["161"]="",
    ["162"]="Halatali",
    ["163"]="The Sunken Temple of Qarn",
    ["164"]="",
    ["166"]="",
    ["167"]="Amdapor Keep",
    ["168"]="",
    ["169"]="",
    ["170"]="Cutter's Cry",
    ["171"]="Dzemael Darkhold",
    ["172"]="Aurum Vale",
    ["174"]="Labyrinth of the Ancients",
    ["175"]="",
    ["176"]="Mordion Gaol",
    ["177"]="Mizzenmast Inn",
    ["178"]="The Hourglass",
    ["179"]="The Roost",
    ["180"]="Outer La Noscea",
    ["181"]="Limsa Lominsa",
    ["182"]="Ul'dah - Steps of Nald",
    ["183"]="New Gridania",
    ["184"]="",
    ["185"]="",
    ["186"]="",
    ["187"]="",
    ["188"]="The Wanderer's Palace",
    ["189"]="Amdapor Keep",
    ["190"]="Central Shroud",
    ["191"]="East Shroud",
    ["192"]="South Shroud",
    ["193"]="IC-06 Central Decks",
    ["194"]="IC-06 Regeneration Grid",
    ["195"]="IC-06 Main Bridge",
    ["196"]="The Burning Heart",
    ["197"]="",
    ["198"]="Command Room",
    ["199"]="",
    ["200"]="",
    ["201"]="",
    ["202"]="",
    ["203"]="",
    ["204"]="Seat of the First Bow",
    ["205"]="Lotus Stand",
    ["206"]="",
    ["207"]="",
    ["208"]="",
    ["209"]="",
    ["210"]="Heart of the Sworn",
    ["211"]="",
    ["212"]="The Waking Sands",
    ["213"]="",
    ["214"]="Middle La Noscea",
    ["215"]="Western Thanalan",
    ["216"]="Central Thanalan",
    ["217"]="",
    ["218"]="",
    ["219"]="Central Shroud",
    ["220"]="South Shroud",
    ["221"]="Upper La Noscea",
    ["222"]="Lower La Noscea",
    ["223"]="Coerthas Central Highlands",
    ["224"]="",
    ["225"]="Central Shroud",
    ["226"]="Central Shroud",
    ["227"]="Central Shroud",
    ["228"]="North Shroud",
    ["229"]="South Shroud",
    ["230"]="Central Shroud",
    ["231"]="South Shroud",
    ["232"]="South Shroud",
    ["233"]="Central Shroud",
    ["234"]="East Shroud",
    ["235"]="South Shroud",
    ["236"]="South Shroud",
    ["237"]="Central Shroud",
    ["238"]="Old Gridania",
    ["239"]="Central Shroud",
    ["240"]="North Shroud",
    ["241"]="Upper Aetheroacoustic Exploratory Site",
    ["242"]="Lower Aetheroacoustic Exploratory Site",
    ["243"]="The Ragnarok",
    ["244"]="Ragnarok Drive Cylinder",
    ["245"]="Ragnarok Central Core",
    ["246"]="IC-04 Main Bridge",
    ["247"]="Ragnarok Main Bridge",
    ["248"]="Central Thanalan",
    ["249"]="Lower La Noscea",
    ["250"]="Wolves' Den Pier",
    ["251"]="Ul'dah - Steps of Nald",
    ["252"]="Middle La Noscea",
    ["253"]="Central Thanalan",
    ["254"]="Ul'dah - Steps of Nald",
    ["255"]="Western Thanalan",
    ["256"]="Eastern Thanalan",
    ["257"]="Eastern Thanalan",
    ["258"]="Central Thanalan",
    ["259"]="Ul'dah - Steps of Nald",
    ["260"]="Southern Thanalan",
    ["261"]="Southern Thanalan",
    ["262"]="Lower La Noscea",
    ["263"]="Western La Noscea",
    ["264"]="Lower La Noscea",
    ["265"]="Lower La Noscea",
    ["266"]="Eastern Thanalan",
    ["267"]="Western Thanalan",
    ["268"]="Eastern Thanalan",
    ["269"]="Western Thanalan",
    ["270"]="Central Thanalan",
    ["271"]="Central Thanalan",
    ["272"]="Middle La Noscea",
    ["273"]="Western Thanalan",
    ["274"]="Ul'dah - Steps of Nald",
    ["275"]="Eastern Thanalan",
    ["276"]="Hall of Summoning",
    ["277"]="East Shroud",
    ["278"]="Western Thanalan",
    ["279"]="Lower La Noscea",
    ["280"]="Western La Noscea",
    ["281"]="The Whorleater",
    ["282"]="Private Cottage - Mist",
    ["283"]="Private House - Mist",
    ["284"]="Private Mansion - Mist",
    ["285"]="Middle La Noscea",
    ["286"]="Rhotano Sea",
    ["287"]="Lower La Noscea",
    ["288"]="Rhotano Sea",
    ["289"]="East Shroud",
    ["290"]="East Shroud",
    ["291"]="South Shroud",
    ["292"]="Bowl of Embers",
    ["293"]="The Navel",
    ["294"]="The Howling Eye",
    ["295"]="Bowl of Embers",
    ["296"]="The Navel",
    ["297"]="The Howling Eye",
    ["298"]="Coerthas Central Highlands",
    ["299"]="Mor Dhona",
    ["300"]="Mor Dhona",
    ["301"]="Coerthas Central Highlands",
    ["302"]="Coerthas Central Highlands",
    ["303"]="East Shroud",
    ["304"]="Coerthas Central Highlands",
    ["305"]="Mor Dhona",
    ["306"]="Southern Thanalan",
    ["307"]="Lower La Noscea",
    ["308"]="Mor Dhona",
    ["309"]="Mor Dhona",
    ["310"]="Eastern La Noscea",
    ["311"]="Eastern La Noscea",
    ["312"]="Southern Thanalan",
    ["313"]="Coerthas Central Highlands",
    ["314"]="Central Thanalan",
    ["315"]="Mor Dhona",
    ["316"]="Coerthas Central Highlands",
    ["317"]="South Shroud",
    ["318"]="Southern Thanalan",
    ["319"]="Central Shroud",
    ["320"]="Central Shroud",
    ["321"]="North Shroud",
    ["322"]="Coerthas Central Highlands",
    ["323"]="Southern Thanalan",
    ["324"]="North Shroud",
    ["325"]="Outer La Noscea",
    ["326"]="Mor Dhona",
    ["327"]="Eastern La Noscea",
    ["328"]="Upper La Noscea",
    ["329"]="The Wanderer's Palace",
    ["330"]="Western La Noscea",
    ["331"]="The Howling Eye",
    ["332"]="",
    ["333"]="",
    ["334"]="",
    ["335"]="Mor Dhona",
    ["336"]="",
    ["337"]="",
    ["338"]="Eorzean Subterrane",
    ["339"]="Mist",
    ["340"]="The Lavender Beds",
    ["341"]="The Goblet",
    ["342"]="Private Cottage - The Lavender Beds",
    ["343"]="Private House - The Lavender Beds",
    ["344"]="Private Mansion - The Lavender Beds",
    ["345"]="Private Cottage - The Goblet",
    ["346"]="Private House - The Goblet",
    ["347"]="Private Mansion - The Goblet",
    ["348"]="Porta Decumana",
    ["349"]="Copperbell Mines",
    ["350"]="Haukke Manor",
    ["351"]="The Rising Stones",
    ["352"]="",
    ["353"]="Kugane Ohashi",
    ["354"]="The Dancing Plague",
    ["355"]="Dalamud's Shadow",
    ["356"]="The Outer Coil",
    ["357"]="Central Decks",
    ["358"]="The Holocharts",
    ["359"]="The Whorleater",
    ["360"]="Halatali",
    ["361"]="Hullbreaker Isle",
    ["362"]="Brayflox's Longstop",
    ["363"]="The Lost City of Amdapor",
    ["364"]="Thornmarch",
    ["365"]="Stone Vigil",
    ["366"]="Griffin Crossing",
    ["367"]="The Sunken Temple of Qarn",
    ["368"]="The Weeping Saint",
    ["369"]="Hall of the Bestiarii",
    ["370"]="Main Bridge",
    ["371"]="",
    ["372"]="Syrcus Tower",
    ["373"]="The Tam-Tara Deepcroft",
    ["374"]="The Striking Tree",
    ["375"]="The Striking Tree",
    ["376"]="Carteneau Flats: Borderland Ruins",
    ["377"]="Akh Afah Amphitheatre",
    ["378"]="Akh Afah Amphitheatre",
    ["379"]="Mor Dhona",
    ["380"]="Dalamud's Shadow",
    ["381"]="The Outer Coil",
    ["382"]="Central Decks",
    ["383"]="The Holocharts",
    ["384"]="Private Chambers - Mist",
    ["385"]="Private Chambers - The Lavender Beds",
    ["386"]="Private Chambers - The Goblet",
    ["387"]="Sastasha",
    ["388"]="Chocobo Square",
    ["389"]="Chocobo Square",
    ["390"]="Chocobo Square",
    ["391"]="Chocobo Square",
    ["392"]="Sanctum of the Twelve",
    ["393"]="Sanctum of the Twelve",
    ["394"]="South Shroud",
    ["395"]="Intercessory",
    ["396"]="Amdapor Keep",
    ["397"]="Coerthas Western Highlands",
    ["398"]="The Dravanian Forelands",
    ["399"]="The Dravanian Hinterlands",
    ["400"]="The Churning Mists",
    ["401"]="The Sea of Clouds",
    ["402"]="Azys Lla",
    ["403"]="Ala Mhigo",
    ["404"]="Limsa Lominsa Lower Decks",
    ["405"]="Western La Noscea",
    ["406"]="Western La Noscea",
    ["407"]="Rhotano Sea",
    ["408"]="Eastern La Noscea",
    ["409"]="Limsa Lominsa Upper Decks",
    ["410"]="Northern Thanalan",
    ["411"]="Eastern La Noscea",
    ["412"]="Upper La Noscea",
    ["413"]="Western La Noscea",
    ["414"]="Eastern La Noscea",
    ["415"]="Lower La Noscea",
    ["416"]="",
    ["417"]="Chocobo Square",
    ["418"]="Foundation",
    ["419"]="The Pillars",
    ["420"]="Neverreap",
    ["421"]="",
    ["422"]="",
    ["423"]="Company Workshop - Mist",
    ["424"]="Company Workshop - The Goblet",
    ["425"]="Company Workshop - The Lavender Beds",
    ["426"]="The Chrysalis",
    ["427"]="Saint Endalim's Scholasticate",
    ["428"]="Seat of the Lord Commander",
    ["429"]="Cloud Nine",
    ["430"]="The Fractal Continuum",
    ["431"]="Seal Rock",
    ["432"]="Thok ast Thok",
    ["433"]="Fortemps Manor",
    ["434"]="Dusk Vigil",
    ["435"]="",
    ["436"]="The Limitless Blue",
    ["437"]="Singularity Reactor",
    ["438"]="",
    ["439"]="The Lightfeather Proving Grounds",
    ["440"]="Ruling Chamber",
    ["441"]="",
    ["442"]="The Fist of the Father",
    ["443"]="The Cuff of the Father",
    ["444"]="The Arm of the Father",
    ["445"]="The Burden of the Father",
    ["446"]="Thok ast Thok",
    ["447"]="The Limitless Blue",
    ["448"]="Singularity Reactor",
    ["449"]="The Fist of the Father",
    ["450"]="The Cuff of the Father",
    ["451"]="The Arm of the Father",
    ["452"]="The Burden of the Father",
    ["453"]="Western La Noscea",
    ["454"]="Upper La Noscea",
    ["455"]="The Sea of Clouds",
    ["456"]="Ruling Chamber",
    ["457"]="Akh Afah Amphitheatre",
    ["458"]="Foundation",
    ["459"]="Azys Lla",
    ["460"]="Halatali",
    ["461"]="The Sea of Clouds",
    ["462"]="Sacrificial Chamber",
    ["463"]="Matoya's Cave",
    ["464"]="The Dravanian Forelands",
    ["465"]="Eastern Thanalan",
    ["466"]="Upper La Noscea",
    ["467"]="Coerthas Western Highlands",
    ["468"]="Coerthas Central Highlands",
    ["469"]="Coerthas Central Highlands",
    ["470"]="Coerthas Western Highlands",
    ["471"]="Eastern La Noscea",
    ["472"]="Coerthas Western Highlands",
    ["473"]="South Shroud",
    ["474"]="Limsa Lominsa Upper Decks",
    ["475"]="Coerthas Central Highlands",
    ["476"]="The Dravanian Hinterlands",
    ["477"]="Coerthas Western Highlands",
    ["478"]="Idyllshire",
    ["479"]="Coerthas Western Highlands",
    ["480"]="Mor Dhona",
    ["481"]="The Dravanian Forelands",
    ["482"]="The Dravanian Forelands",
    ["483"]="Northern Thanalan",
    ["484"]="Lower La Noscea",
    ["485"]="The Dravanian Hinterlands",
    ["486"]="Outer La Noscea",
    ["487"]="Coerthas Central Highlands",
    ["488"]="Coerthas Central Highlands",
    ["489"]="Coerthas Western Highlands",
    ["490"]="Hullbreaker Isle",
    ["491"]="Southern Thanalan",
    ["492"]="The Sea of Clouds",
    ["493"]="Coerthas Western Highlands",
    ["494"]="Eastern Thanalan",
    ["495"]="Lower La Noscea",
    ["496"]="Coerthas Central Highlands",
    ["497"]="Coerthas Western Highlands",
    ["498"]="Coerthas Western Highlands",
    ["499"]="The Pillars",
    ["500"]="Coerthas Central Highlands",
    ["501"]="The Churning Mists",
    ["502"]="Carteneau Flats: Borderland Ruins",
    ["503"]="The Dravanian Hinterlands",
    ["504"]="The Eighteenth Floor",
    ["505"]="Alexander",
    ["506"]="Chocobo Square",
    ["507"]="Central Azys Lla",
    ["508"]="Void Ark",
    ["509"]="The Gilded Araya",
    ["510"]="Pharos Sirius",
    ["511"]="Saint Mocianne's Arboretum",
    ["512"]="The Diadem",
    ["513"]="The Vault",
    ["514"]="The Diadem",
    ["515"]="The Diadem",
    ["516"]="",
    ["517"]="Containment Bay S1T7",
    ["518"]="",
    ["519"]="The Lost City of Amdapor",
    ["520"]="The Fist of the Son",
    ["521"]="The Cuff of the Son",
    ["522"]="The Arm of the Son",
    ["523"]="The Burden of the Son",
    ["524"]="Containment Bay S1T7",
    ["525"]="",
    ["526"]="",
    ["527"]="",
    ["528"]="",
    ["529"]="The Fist of the Son",
    ["530"]="The Cuff of the Son",
    ["531"]="The Arm of the Son",
    ["532"]="The Burden of the Son",
    ["533"]="Coerthas Central Highlands",
    ["534"]="Twin Adder Barracks",
    ["535"]="Flame Barracks",
    ["536"]="Maelstrom Barracks",
    ["537"]="The Fold",
    ["538"]="The Fold",
    ["539"]="The Fold",
    ["540"]="The Fold",
    ["541"]="The Fold",
    ["542"]="The Fold",
    ["543"]="The Fold",
    ["544"]="The Fold",
    ["545"]="The Fold",
    ["546"]="The Fold",
    ["547"]="The Fold",
    ["548"]="The Fold",
    ["549"]="The Fold",
    ["550"]="The Fold",
    ["551"]="The Fold",
    ["552"]="Western La Noscea",
    ["553"]="Alexander",
    ["554"]="The Fields of Glory",
    ["555"]="",
    ["556"]="The Weeping City of Mhach",
    ["557"]="Hullbreaker Isle",
    ["558"]="The Aquapolis",
    ["559"]="Steps of Faith",
    ["560"]="Aetherochemical Research Facility",
    ["561"]="The Palace of the Dead",
    ["562"]="The Palace of the Dead",
    ["563"]="The Palace of the Dead",
    ["564"]="The Palace of the Dead",
    ["565"]="The Palace of the Dead",
    ["566"]="Steps of Faith",
    ["567"]="The Parrock",
    ["568"]="Leofard's Chambers",
    ["569"]="Steps of Faith",
    ["570"]="The Palace of the Dead",
    ["571"]="Haunted Manor",
    ["572"]="",
    ["573"]="Topmast Apartment Lobby",
    ["574"]="Lily Hills Apartment Lobby",
    ["575"]="Sultana's Breath Apartment Lobby",
    ["576"]="Containment Bay P1T6",
    ["577"]="Containment Bay P1T6",
    ["578"]="The Great Gubal Library",
    ["579"]="The Battlehall",
    ["580"]="Eyes of the Creator",
    ["581"]="Breath of the Creator",
    ["582"]="Heart of the Creator",
    ["583"]="Soul of the Creator",
    ["584"]="Eyes of the Creator",
    ["585"]="Breath of the Creator",
    ["586"]="Heart of the Creator",
    ["587"]="Soul of the Creator",
    ["588"]="Heart of the Creator",
    ["589"]="Chocobo Square",
    ["590"]="Chocobo Square",
    ["591"]="Chocobo Square",
    ["592"]="Bowl of Embers",
    ["593"]="The Palace of the Dead",
    ["594"]="The Palace of the Dead",
    ["595"]="The Palace of the Dead",
    ["596"]="The Palace of the Dead",
    ["597"]="The Palace of the Dead",
    ["598"]="The Palace of the Dead",
    ["599"]="The Palace of the Dead",
    ["600"]="The Palace of the Dead",
    ["601"]="The Palace of the Dead",
    ["602"]="The Palace of the Dead",
    ["603"]="The Palace of the Dead",
    ["604"]="The Palace of the Dead",
    ["605"]="The Palace of the Dead",
    ["606"]="The Palace of the Dead",
    ["607"]="The Palace of the Dead",
    ["608"]="Topmast Apartment",
    ["609"]="Lily Hills Apartment",
    ["610"]="Sultana's Breath Apartment",
    ["611"]="Frondale's Home for Friendless Foundlings",
    ["612"]="The Fringes",
    ["613"]="The Ruby Sea",
    ["614"]="Yanxia",
    ["615"]="",
    ["616"]="Shisui of the Violet Tides",
    ["617"]="Sohm Al",
    ["618"]="",
    ["619"]="",
    ["620"]="The Peaks",
    ["621"]="The Lochs",
    ["622"]="The Azim Steppe",
    ["623"]="Bardam's Mettle",
    ["624"]="The Diadem",
    ["625"]="The Diadem",
    ["626"]="The Sirensong Sea",
    ["627"]="Dun Scaith",
    ["628"]="Kugane",
    ["629"]="Bokairo Inn",
    ["630"]="",
    ["631"]="",
    ["632"]="",
    ["633"]="Carteneau Flats: Borderland Ruins",
    ["634"]="Yanxia",
    ["635"]="Rhalgr's Reach",
    ["636"]="Omega Control",
    ["637"]="Containment Bay Z1T9",
    ["638"]="Containment Bay Z1T9",
    ["639"]="Ruby Bazaar Offices",
    ["640"]="The Fringes",
    ["641"]="Shirogane",
    ["642"]="",
    ["643"]="",
    ["644"]="",
    ["645"]="",
    ["646"]="",
    ["647"]="The Fringes",
    ["648"]="The Fringes",
    ["649"]="Private Cottage - Shirogane",
    ["650"]="Private House - Shirogane",
    ["651"]="Private Mansion - Shirogane",
    ["652"]="Private Chambers - Shirogane",
    ["653"]="Company Workshop - Shirogane",
    ["654"]="Kobai Goten Apartment Lobby",
    ["655"]="Kobai Goten Apartment",
    ["656"]="The Diadem",
    ["657"]="The Ruby Sea",
    ["658"]="The Interdimensional Rift",
    ["659"]="Rhalgr's Reach",
    ["660"]="Doma Castle",
    ["661"]="Castrum Abania",
    ["662"]="Kugane Castle",
    ["663"]="The Temple of the Fist",
    ["664"]="Kugane",
    ["665"]="Kugane",
    ["666"]="Ul'dah - Steps of Thal",
    ["667"]="Kugane",
    ["668"]="Eastern Thanalan",
    ["669"]="Southern Thanalan",
    ["670"]="The Fringes",
    ["671"]="The Fringes",
    ["672"]="Mor Dhona",
    ["673"]="Sohm Al",
    ["674"]="The Blessed Treasury",
    ["675"]="Western La Noscea",
    ["676"]="The Great Gubal Library",
    ["677"]="The Blessed Treasury",
    ["678"]="The Fringes",
    ["679"]="The Royal Airship Landing",
    ["680"]="The <Emphasis>Misery</Emphasis>",
    ["681"]="The House of the Fierce",
    ["682"]="The Doman Enclave",
    ["683"]="The First Altar of Djanan Qhat",
    ["684"]="The Lochs",
    ["685"]="Yanxia",
    ["686"]="The Lochs",
    ["687"]="The Lochs",
    ["688"]="The Azim Steppe",
    ["689"]="Ala Mhigo",
    ["690"]="The Interdimensional Rift",
    ["691"]="Deltascape V1.0",
    ["692"]="Deltascape V2.0",
    ["693"]="Deltascape V3.0",
    ["694"]="Deltascape V4.0",
    ["695"]="Deltascape V1.0",
    ["696"]="Deltascape V2.0",
    ["697"]="Deltascape V3.0",
    ["698"]="Deltascape V4.0",
    ["699"]="Coerthas Central Highlands",
    ["700"]="Foundation",
    ["701"]="Seal Rock",
    ["702"]="Aetherochemical Research Facility",
    ["703"]="The Fringes",
    ["704"]="Dalamud's Shadow",
    ["705"]="Ul'dah - Steps of Thal",
    ["706"]="Ul'dah - Steps of Thal",
    ["707"]="The Weeping City of Mhach",
    ["708"]="Rhotano Sea",
    ["709"]="Coerthas Western Highlands",
    ["710"]="Kugane",
    ["711"]="The Ruby Sea",
    ["712"]="The Lost Canals of Uznair",
    ["713"]="The Azim Steppe",
    ["714"]="Bardam's Mettle",
    ["715"]="The Churning Mists",
    ["716"]="The Peaks",
    ["717"]="Wolves' Den Pier",
    ["718"]="The Azim Steppe",
    ["719"]="Emanation",
    ["720"]="Emanation",
    ["721"]="Amdapor Keep",
    ["722"]="The Lost City of Amdapor",
    ["723"]="The Azim Steppe",
    ["724"]="The Interdimensional Rift",
    ["725"]="The Lost Canals of Uznair",
    ["726"]="The Ruby Sea",
    ["727"]="The Royal Menagerie",
    ["728"]="Mordion Gaol",
    ["729"]="Astragalos",
    ["730"]="Transparency",
    ["731"]="The Drowned City of Skalla",
    ["732"]="Eureka Anemos",
    ["733"]="The Binding Coil of Bahamut",
    ["734"]="The Royal City of Rabanastre",
    ["735"]="The <Emphasis>Prima Vista</Emphasis> Tiring Room",
    ["736"]="The <Emphasis>Prima Vista</Emphasis> Bridge",
    ["737"]="Royal Palace",
    ["738"]="The Resonatorium",
    ["739"]="The Doman Enclave",
    ["740"]="The Royal Menagerie",
    ["741"]="Sanctum of the Twelve",
    ["742"]="Hells' Lid",
    ["743"]="The Fractal Continuum",
    ["744"]="Kienkan",
    ["745"]="",
    ["746"]="The Jade Stoa",
    ["747"]="",
    ["748"]="Sigmascape V1.0",
    ["749"]="Sigmascape V2.0",
    ["750"]="Sigmascape V3.0",
    ["751"]="Sigmascape V4.0",
    ["752"]="Sigmascape V1.0",
    ["753"]="Sigmascape V2.0",
    ["754"]="Sigmascape V3.0",
    ["755"]="Sigmascape V4.0",
    ["756"]="The Interdimensional Rift",
    ["757"]="The Ruby Sea",
    ["758"]="The Jade Stoa",
    ["759"]="The Doman Enclave",
    ["760"]="The Fringes",
    ["761"]="The Great Hunt",
    ["762"]="The Great Hunt",
    ["763"]="Eureka Pagos",
    ["764"]="Reisen Temple",
    ["765"]="",
    ["766"]="",
    ["767"]="",
    ["768"]="The Swallow's Compass",
    ["769"]="The Burn",
    ["770"]="Heaven-on-High",
    ["771"]="Heaven-on-High",
    ["772"]="Heaven-on-High",
    ["773"]="Heaven-on-High",
    ["774"]="Heaven-on-High",
    ["775"]="Heaven-on-High",
    ["776"]="The Ridorana Lighthouse",
    ["777"]="Ultimacy",
    ["778"]="Castrum Fluminis",
    ["779"]="Castrum Fluminis",
    ["780"]="Heaven-on-High",
    ["781"]="Reisen Temple Road",
    ["782"]="Heaven-on-High",
    ["783"]="Heaven-on-High",
    ["784"]="Heaven-on-High",
    ["785"]="Heaven-on-High",
    ["786"]="Castrum Fluminis",
    ["787"]="The Ridorana Cataract",
    ["788"]="Saint Mocianne's Arboretum",
    ["789"]="The Burn",
    ["790"]="Ul'dah - Steps of Nald",
    ["791"]="Hidden Gorge",
    ["792"]="The Fall of Belah'dia",
    ["793"]="The Ghimlyt Dark",
    ["794"]="The Shifting Altars of Uznair",
    ["795"]="Eureka Pyros",
    ["796"]="Blue Sky",
    ["797"]="The Azim Steppe",
    ["798"]="Psiscape V1.0",
    ["799"]="Psiscape V2.0",
    ["800"]="The Interdimensional Rift",
    ["801"]="The Interdimensional Rift",
    ["802"]="Psiscape V1.0",
    ["803"]="Psiscape V2.0",
    ["804"]="The Interdimensional Rift",
    ["805"]="The Interdimensional Rift",
    ["806"]="Kugane Ohashi",
    ["807"]="The Interdimensional Rift",
    ["808"]="The Interdimensional Rift",
    ["809"]="Haunted Manor",
    ["810"]="Hells' Kier",
    ["811"]="Hells' Kier",
    ["812"]="The Interdimensional Rift",
    ["813"]="Lakeland",
    ["814"]="Kholusia",
    ["815"]="Amh Araeng",
    ["816"]="Il Mheg",
    ["817"]="The Rak'tika Greatwood",
    ["818"]="The Tempest",
    ["819"]="The Crystarium",
    ["820"]="Eulmore",
    ["821"]="Dohn Mheg",
    ["822"]="Mt. Gulg",
    ["823"]="The Qitana Ravel",
    ["824"]="The Wreath of Snakes",
    ["825"]="The Wreath of Snakes",
    ["826"]="The Orbonne Monastery",
    ["827"]="Eureka Hydatos",
    ["828"]="The <Emphasis>Prima Vista</Emphasis> Tiring Room",
    ["829"]="Eorzean Alliance Headquarters",
    ["830"]="The Ghimlyt Dark",
    ["831"]="The Manderville Tables",
    ["832"]="The Gold Saucer",
    ["833"]="The Howling Eye",
    ["834"]="The Howling Eye",
    ["835"]="",
    ["836"]="Malikah's Well",
    ["837"]="Holminster Switch",
    ["838"]="Amaurot",
    ["839"]="East Shroud",
    ["840"]="The Twinning",
    ["841"]="Akadaemia Anyder",
    ["842"]="The Syrcus Trench",
    ["843"]="The Pendants Personal Suite",
    ["844"]="The Ocular",
    ["845"]="The Dancing Plague",
    ["846"]="The Crown of the Immaculate",
    ["847"]="The Dying Gasp",
    ["848"]="The Crown of the Immaculate",
    ["849"]="The Core",
    ["850"]="The Halo",
    ["851"]="The Nereus Trench",
    ["852"]="Atlas Peak",
    ["853"]="The Core",
    ["854"]="The Halo",
    ["855"]="The Nereus Trench",
    ["856"]="Atlas Peak",
    ["857"]="The Core",
    ["858"]="The Dancing Plague",
    ["859"]="The Confessional of Toupasa the Elder",
    ["860"]="Amh Araeng",
    ["861"]="Lakeland",
    ["862"]="Lakeland",
    ["863"]="Eulmore",
    ["864"]="Kholusia",
    ["865"]="Old Gridania",
    ["866"]="Coerthas Western Highlands",
    ["867"]="Eastern La Noscea",
    ["868"]="The Peaks",
    ["869"]="Il Mheg",
    ["870"]="Kholusia",
    ["871"]="The Rak'tika Greatwood",
    ["872"]="Amh Araeng",
    ["873"]="The Dancing Plague",
    ["874"]="The Rak'tika Greatwood",
    ["875"]="The Rak'tika Greatwood",
    ["876"]="The Nabaath Mines",
    ["877"]="Lakeland",
    ["878"]="The Empty",
    ["879"]="The Dungeons of Lyhe Ghiah",
    ["880"]="The Crown of the Immaculate",
    ["881"]="The Dying Gasp",
    ["882"]="The Copied Factory",
    ["883"]="",
    ["884"]="The Grand Cosmos",
    ["885"]="The Dying Gasp",
    ["886"]="The Firmament",
    ["887"]="Liminal Space",
    ["888"]="Onsal Hakair",
    ["889"]="Lyhe Mheg",
    ["890"]="Lyhe Mheg",
    ["891"]="Lyhe Mheg",
    ["892"]="Lyhe Mheg",
    ["893"]="The Imperial Palace",
    ["894"]="Lyhe Mheg",
    ["895"]="Excavation Tunnels",
    ["896"]="The Copied Factory",
    ["897"]="Cinder Drift",
    ["898"]="Anamnesis Anyder",
    ["899"]="The Falling City of Nym",
    ["900"]="The <Emphasis>Endeavor</Emphasis>",
    ["901"]="The Diadem",
    ["902"]="The Gandof Thunder Plains",
    ["903"]="Ashfall",
    ["904"]="The Halo",
    ["905"]="Great Glacier",
    ["906"]="The Gandof Thunder Plains",
    ["907"]="Ashfall",
    ["908"]="The Halo",
    ["909"]="Great Glacier",
    ["910"]="",
    ["911"]="Cid's Memory",
    ["912"]="Cinder Drift",
    ["913"]="Transmission Control",
    ["914"]="Trial's Threshold",
    ["915"]="Gangos",
    ["916"]="The Heroes' Gauntlet",
    ["917"]="The Puppets' Bunker",
    ["918"]="Anamnesis Anyder",
    ["919"]="Terncliff",
    ["920"]="Bozjan Southern Front",
    ["921"]="Frondale's Home for Friendless Foundlings",
    ["922"]="The Seat of Sacrifice",
    ["923"]="The Seat of Sacrifice",
    ["924"]="The Shifting Oubliettes of Lyhe Ghiah",
    ["925"]="Terncliff Bay",
    ["926"]="Terncliff Bay",
    ["927"]="",
    ["928"]="The Puppets' Bunker",
    ["929"]="The Diadem",
    ["930"]="",
    ["931"]="The Seat of Sacrifice",
    ["932"]="The Tempest",
    ["933"]="Matoya's Relict",
    ["934"]="Castrum Marinum Drydocks",
    ["935"]="Castrum Marinum Drydocks",
    ["936"]="Delubrum Reginae",
    ["937"]="Delubrum Reginae",
    ["938"]="Paglth'an",
    ["939"]="The Diadem",
    ["940"]="The Battlehall",
    ["941"]="The Battlehall",
    ["942"]="Sphere of Naught",
    ["943"]="Laxan Loft",
    ["944"]="Bygone Gaol",
    ["945"]="The Garden of Nowhere",
    ["946"]="Sphere of Naught",
    ["947"]="Laxan Loft",
    ["948"]="Bygone Gaol",
    ["949"]="The Garden of Nowhere",
    ["950"]="G-Savior Deck",
    ["951"]="G-Savior Deck",
    ["952"]="The Tower of Zot",
    ["953"]="",
    ["954"]="The Navel",
    ["955"]="The Last Trace",
    ["956"]="Labyrinthos",
    ["957"]="Thavnair",
    ["958"]="Garlemald",
    ["959"]="Mare Lamentorum",
    ["960"]="Ultima Thule",
    ["961"]="Elpis",
    ["962"]="Old Sharlayan",
    ["963"]="Radz-at-Han",
    ["964"]="The Last Trace",
    ["965"]="The Empty",
    ["966"]="The Tower at Paradigm's Breach",
    ["967"]="Castrum Marinum Drydocks",
    ["968"]="Medias Res",
    ["969"]="The Tower of Babil",
    ["970"]="Vanaspati",
    ["971"]="Lemures Headquarters",
    ["972"]="",
    ["973"]="The Dead Ends",
    ["974"]="Ktisis Hyperboreia",
    ["975"]="Zadnor",
    ["976"]="Smileton",
    ["977"]="Carteneau Flats: Borderland Ruins",
    ["978"]="The Aitiascope",
    ["979"]="Empyreum",
    ["980"]="Private Cottage - Empyreum",
    ["981"]="Private House - Empyreum",
    ["982"]="Private Mansion - Empyreum",
    ["983"]="Private Chambers - Empyreum",
    ["984"]="Company Workshop - Empyreum",
    ["985"]="Ingleside Apartment Lobby",
    ["986"]="The Stigma Dreamscape",
    ["987"]="Main Hall",
    ["988"]="",
    ["989"]="",
    ["990"]="Andron",
    ["991"]="G-Savior Deck",
    ["992"]="The Dark Inside",
    ["993"]="The Dark Inside",
    ["994"]="The Phantoms' Feast",
    ["995"]="The Mothercrystal",
    ["996"]="The Mothercrystal",
    ["997"]="The Final Day",
    ["998"]="The Final Day",
    ["999"]="Ingleside Apartment",
    ["1000"]="The Excitatron 6000",
    ["1001"]="Strategy Room",
    ["1002"]="The Gates of Pandæmonium",
    ["1003"]="The Gates of Pandæmonium",
    ["1004"]="The Stagnant Limbo",
    ["1005"]="The Stagnant Limbo",
    ["1006"]="The Fervid Limbo",
    ["1007"]="The Fervid Limbo",
    ["1008"]="The Sanguine Limbo",
    ["1009"]="The Sanguine Limbo",
    ["1010"]="Magna Glacies",
    ["1011"]="Garlemald",
    ["1012"]="Magna Glacies",
    ["1013"]="Beyond the Stars",
    ["1014"]="Elpis",
    ["1015"]="Central Shroud",
    ["1016"]="Sastasha",
    ["1017"]="The Swallow's Compass",
    ["1018"]="The Vault",
    ["1019"]="The Peaks",
    ["1020"]="Cutter's Cry",
    ["1021"]="Dusk Vigil",
    ["1022"]="Saint Mocianne's Arboretum",
    ["1023"]="The Dravanian Forelands",
    ["1024"]="The Nethergate",
    ["1025"]="The Gates of Pandæmonium",
    ["1026"]="Beyond the Stars",
    ["1027"]="Ultima Thule",
    ["1028"]="The Dark Inside",
    ["1029"]="The Final Day",
    ["1030"]="The Mothercrystal",
    ["1031"]="Propylaion",
    ["1032"]="The Palaistra",
    ["1033"]="The Volcanic Heart",
    ["1034"]="Cloud Nine",
    ["1035"]="",
    ["1036"]="Sastasha",
    ["1037"]="The Tam-Tara Deepcroft",
    ["1038"]="Copperbell Mines",
    ["1039"]="The Thousand Maws of Toto-Rak",
    ["1040"]="Haukke Manor",
    ["1041"]="Brayflox's Longstop",
    ["1042"]="Stone Vigil",
    ["1043"]="Castrum Meridianum",
    ["1044"]="The Praetorium",
    ["1045"]="Bowl of Embers",
    ["1046"]="The Navel",
    ["1047"]="The Howling Eye",
    ["1048"]="Porta Decumana",
    ["1049"]="Western Thanalan",
    ["1050"]="Alzadaal's Legacy",
    ["1051"]="The Tower of Babil",
    ["1052"]="The Porta Decumana",
    ["1053"]="The Porta Decumana",
    ["1054"]="Aglaia",
    ["1055"]="Unnamed Island",
    ["1056"]="Alzadaal's Legacy",
    ["1057"]="Restricted Archives",
    ["1058"]="The Palaistra",
    ["1059"]="The Volcanic Heart",
    ["1060"]="Cloud Nine",
    ["1061"]="The Omphalos",
    ["1062"]="Snowcloak",
    ["1063"]="The Keeper of the Lake",
    ["1064"]="Sohm Al",
    ["1065"]="The Aery",
    ["1066"]="The Vault",
    ["1067"]="Thornmarch",
    ["1068"]="Steps of Faith",
    ["1069"]="The Sil'dihn Subterrane",
    ["1070"]="The Fell Court of Troia",
    ["1071"]="Storm's Crown",
    ["1072"]="Storm's Crown",
    ["1073"]="Elysion",
    ["1074"]="",
    ["1075"]="Another Sil'dihn Subterrane",
    ["1076"]="Another Sil'dihn Subterrane",
    ["1077"]="Zero's Domain",
    ["1078"]="Meghaduta Guest Chambers",
    ["1079"]="The Aitiascope",
    ["1080"]="",
    ["1081"]="The Caustic Purgatory",
    ["1082"]="The Caustic Purgatory",
    ["1083"]="The Pestilent Purgatory",
    ["1084"]="The Pestilent Purgatory",
    ["1085"]="The Hollow Purgatory",
    ["1086"]="The Hollow Purgatory",
    ["1087"]="Stygian Insenescence Cells",
    ["1088"]="Stygian Insenescence Cells",
    ["1089"]="The Fell Court of Troia",
    ["1090"]="",
    ["1091"]="The Fell Court of Troia",
    ["1092"]="Storm's Crown",
    ["1093"]="Stygian Insenescence Cells",
    ["1094"]="Sneaky Hollow",
    ["1095"]="Mount Ordeals",
    ["1096"]="Mount Ordeals",
    ["1097"]="Lapis Manalis",
    ["1098"]="Sylphstep",
    ["1099"]="Eureka Orthos",
    ["1100"]="Eureka Orthos",
    ["1101"]="Eureka Orthos",
    ["1102"]="Eureka Orthos",
    ["1103"]="Eureka Orthos",
    ["1104"]="Eureka Orthos",
    ["1105"]="Eureka Orthos",
    ["1106"]="Eureka Orthos",
    ["1107"]="Eureka Orthos",
    ["1108"]="Eureka Orthos",
    ["1109"]="The Great Gubal Library",
    ["1110"]="Aetherochemical Research Facility",
    ["1111"]="The Antitower",
    ["1112"]="Sohr Khai",
    ["1113"]="Xelphatol",
    ["1114"]="Baelsar's Wall",
    ["1115"]="The Tower of Babil",
    ["1116"]="The Clockwork Castletown",
    ["1117"]="The Clockwork Castletown",
    ["1118"]="Euphrosyne",
    ["1119"]="Lapis Manalis",
    ["1120"]="Garlemald",
    ["1121"]="",
    ["1122"]="The Interdimensional Rift",
    ["1123"]="The Shifting Gymnasion Agonon",
    ["1124"]="Eureka Orthos",
    ["1125"]="Khadga",
    ["1126"]="The Aetherfont",
    ["1127"]="",
    ["1128"]="",
    ["1129"]="",
    ["1130"]="",
    ["1131"]="",
    ["1132"]="",
    ["1133"]="",
    ["1134"]="",
    ["1135"]="",
    ["1136"]="The Gilded Araya",
    ["1137"]="Mount Rokkon",
    ["1138"]="The Red Sands",
    ["1139"]="The Red Sands",
    ["1140"]="The Voidcast Dais",
    ["1141"]="The Voidcast Dais",
    ["1142"]="The Sirensong Sea",
    ["1143"]="Bardam's Mettle",
    ["1144"]="Doma Castle",
    ["1145"]="Castrum Abania",
    ["1146"]="Ala Mhigo",
    ["1147"]="The Aetherial Slough",
    ["1148"]="The Aetherial Slough",
    ["1149"]="The Dæmons' Nest",
    ["1150"]="The Dæmons' Nest",
    ["1151"]="The Chamber of Fourteen",
    ["1152"]="The Chamber of Fourteen",
    ["1153"]="Ascension",
    ["1154"]="Ascension",
    ["1155"]="Another Mount Rokkon",
    ["1156"]="Another Mount Rokkon",
    ["1157"]="",
    ["1158"]="The Dæmons' Nest",
    ["1159"]="The Voidcast Dais",
    ["1160"]="Senatus",
    ["1161"]="Estinien's Chambers",
    ["1162"]="The Red Moon",
    ["1163"]="The <Emphasis>Endeavor</Emphasis>",
    ["1164"]="The Lunar Subterrane",
    ["1165"]="Blunderville",
    ["1166"]="The Memory of Embers",
    ["1167"]="Ihuykatumu",
    ["1168"]="The Abyssal Fracture",
    ["1169"]="The Abyssal Fracture",
    ["1170"]="Sunperch",
    ["1171"]="Earthen Sky Hideout",
    ["1172"]="The Drowned City of Skalla",
    ["1173"]="The Burn",
    ["1174"]="The Ghimlyt Dark",
    ["1175"]="",
    ["1176"]="Aloalo Island",
    ["1177"]="The Aetherfont",
    ["1178"]="Thaleia",
    ["1179"]="Another Aloalo Island",
    ["1180"]="Another Aloalo Island",
    ["1181"]="The Abyssal Fracture",
    ["1182"]="Thaleia",
    ["1183"]="The Gilded Araya",
    ["1184"]="The Lunar Subterrane",
    ["1185"]="Tuliyollal",
    ["1186"]="Solution Nine",
    ["1187"]="Urqopacha",
    ["1188"]="Kozama'uka",
    ["1189"]="Yak T'el",
    ["1190"]="Shaaloani",
    ["1191"]="Heritage Found",
    ["1192"]="Living Memory",
    ["1193"]="Worqor Zormor",
    ["1194"]="The Skydeep Cenote",
    ["1195"]="Worqor Lar Dor",
    ["1196"]="Worqor Lar Dor",
    ["1197"]="Blunderville Square",
    ["1198"]="Vanguard",
    ["1199"]="Alexandria",
    ["1200"]="Summit of Everkeep",
    ["1201"]="Summit of Everkeep",
    ["1202"]="Interphos",
    ["1203"]="Tender Valley",
    ["1204"]="Strayborough",
    ["1205"]="The For'ard Cabins",
    ["1206"]="Main Deck",
    ["1207"]="The Backroom",
    ["1208"]="Origenics",
    ["1209"]="Cenote Ja Ja Gural",
    ["1210"]="Sunperch",
    ["1211"]="Yak T'el",
    ["1212"]="Yak T'el",
    ["1213"]="Solution Nine",
    ["1214"]="The Sea of Clouds",
    ["1215"]="Brayflox's Longstop",
    ["1216"]="Bardam's Mettle",
    ["1217"]="Ala Mhigo",
    ["1218"]="Khadga",
    ["1219"]="Vanguard",
    ["1220"]="Summit of Everkeep",
    ["1221"]="Interphos",
    ["1222"]="Skydeep Cenote Inner Chamber",
    ["1223"]="Tritails Training",
    ["1224"]="Greenroom",
    ["1225"]="Scratching Ring",
    ["1226"]="Scratching Ring",
    ["1227"]="Lovely Lovering",
    ["1228"]="Lovely Lovering",
    ["1229"]="Blasting Ring",
    ["1230"]="Blasting Ring",
    ["1231"]="The Thundering",
    ["1232"]="The Thundering",
    ["1233"]="Manor Basement",
    ["1234"]="Dreamlike Palace",
    ["1235"]="Central Thanalan",
    ["1236"]="Southern Thanalan",
    ["1237"]="",
    ["1238"]="",
    ["1239"]="",
    ["1240"]="",
    ["1241"]=""
  }

-- Aetheryte overrides for zones where Lifestream defaults to wrong destination
-- Key: Zone name, Value: Aetheryte name to use instead
local AetheryteOverrides = {
    ["Coerthas Central Highlands"] = "Camp Dragonhead",
    ["Southern Thanalan"] = "Little Ala Mhigo",
    ["Middle La Noscea"] = "Zephyr Gate",
    -- Add more overrides here as needed
    -- Lifestream accepts aethernet gate names directly (e.g., "Zephyr Gate")
}


-------------------------------------------------
-- MOB DATA (embedded)
-------------------------------------------------
    local monster_data = {
        JobRanks = {
            ["1"] = {
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63036,
                                    Id = 49,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 267.96899414063,
                                            yCoord = 54.97074508667,
                                            zCoord = 124.23870849609
                                        }
                                    },
                                    Name = "Little Ladybug"
                                }
                            },
                            Name = "Gladiator 01"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63028,
                                    Id = 262,
                                    Locations = {
                                        {
                                            Map = 21,
                                            Terri = 141,
                                            Zone = 0,
                                            xCoord = 20.0,
                                            yCoord = 27.0
                                        }
                                    },
                                    Name = "Star Marmot"
                                }
                            },
                            Name = "Gladiator 02"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63073,
                                    Id = 287,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 27.0,
                                            yCoord = 24.0
                                        }
                                    },
                                    Name = "Cactuar"
                                }
                            },
                            Name = "Gladiator 03"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63089,
                                    Id = 318,
                                    Locations = {
                                        {
                                            Map = 21,
                                            Terri = 141,
                                            Zone = 0,
                                            xCoord = 25.0,
                                            yCoord = 31.0
                                        }
                                    },
                                    Name = "Snapping Shrew"
                                }
                            },
                            Name = "Gladiator 04"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63070,
                                    Id = 282,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 22.0
                                        }
                                    },
                                    Name = "Hammer Beak"
                                }
                            },
                            Name = "Gladiator 05"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63076,
                                    Id = 294,
                                    Locations = {
                                        {
                                            Map = 21,
                                            Terri = 141,
                                            Zone = 0,
                                            xCoord = 17.0,
                                            yCoord = 15.0
                                        }
                                    },
                                    Name = "Antling Worker"
                                }
                            },
                            Name = "Gladiator 06"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63055,
                                    Id = 113,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 17.9,
                                            yCoord = 28.5
                                        }
                                    },
                                    Name = "Earth Sprite"
                                }
                            },
                            Name = "Gladiator 07"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63087,
                                    Id = 317,
                                    Locations = {
                                        {
                                            Map = 21,
                                            Terri = 141,
                                            Zone = 0,
                                            xCoord = 16.0,
                                            yCoord = 23.0
                                        }
                                    },
                                    Name = "Spriggan Graverobber"
                                }
                            },
                            Name = "Gladiator 08"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63060,
                                    Id = 266,
                                    Locations = {
                                        {
                                            Map = 21,
                                            Terri = 141,
                                            Zone = 0,
                                            xCoord = 17.0,
                                            yCoord = 19.0
                                        }
                                    },
                                    Name = "Qiqirn Shellsweeper"
                                }
                            },
                            Name = "Gladiator 09"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63076,
                                    Id = 292,
                                    Locations = {
                                        {
                                            Map = 21,
                                            Terri = 141,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 19.0
                                        }
                                    },
                                    Name = "Antling Soldier"
                                },
                                {
                                    Count = 3,
                                    Icon = 63052,
                                    Id = 302,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 22.9,
                                            yCoord = 21.8
                                        }
                                    },
                                    Name = "Dusty Mongrel"
                                }
                            },
                            Name = "Gladiator 10"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63086,
                                    Id = 316,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 27.6,
                                            yCoord = 16.7
                                        }
                                    },
                                    Name = "Bomb"
                                },
                                {
                                    Count = 3,
                                    Icon = 63092,
                                    Id = 277,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 27.0,
                                            yCoord = 17.0
                                        }
                                    },
                                    Name = "Copper Coblyn"
                                }
                            },
                            Name = "Gladiator 11"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63073,
                                    Id = 288,
                                    Locations = {
                                        {
                                            Map = 21,
                                            Terri = 141,
                                            Zone = 0,
                                            xCoord = 23.7,
                                            yCoord = 19.6
                                        }
                                    },
                                    Name = "Cochineal Cactuar"
                                }
                            },
                            Name = "Gladiator 12"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63043,
                                    Id = 326,
                                    Locations = {
                                        {
                                            Map = 21,
                                            Terri = 141,
                                            Zone = 0,
                                            xCoord = 24.0,
                                            yCoord = 21.0
                                        }
                                    },
                                    Name = "Quiveron Guard"
                                }
                            },
                            Name = "Gladiator 13"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63001,
                                    Id = 244,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 21.7,
                                            yCoord = 26.7
                                        }
                                    },
                                    Name = "Giant Tortoise"
                                }
                            },
                            Name = "Gladiator 14"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63032,
                                    Id = 636,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 16.4,
                                            yCoord = 16.0
                                        }
                                    },
                                    Name = "Thickshell"
                                }
                            },
                            Name = "Gladiator 15"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63031,
                                    Id = 635,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 17.1,
                                            yCoord = 14.7
                                        }
                                    },
                                    Name = "Scaphite"
                                }
                            },
                            Name = "Gladiator 16"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63082,
                                    Id = 306,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 11.0,
                                            yCoord = 19.0
                                        }
                                    },
                                    Name = "Tuco-tuco"
                                }
                            },
                            Name = "Gladiator 17"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63093,
                                    Id = 273,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 18.4,
                                            yCoord = 22.6
                                        }
                                    },
                                    Name = "Myotragus Billy"
                                }
                            },
                            Name = "Gladiator 18"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63004,
                                    Id = 1198,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 14.6,
                                            yCoord = 18.5
                                        }
                                    },
                                    Name = "Vandalous Imp"
                                }
                            },
                            Name = "Gladiator 19"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63014,
                                    Id = 322,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 14.8,
                                            yCoord = 16.8
                                        }
                                    },
                                    Name = "Rotting Noble"
                                },
                                {
                                    Count = 3,
                                    Icon = 63084,
                                    Id = 309,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 13.2,
                                            yCoord = 11.8
                                        }
                                    },
                                    Name = "Bloated Bogy"
                                }
                            },
                            Name = "Gladiator 20"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63032,
                                    Id = 638,
                                    Locations = {
                                        {
                                            Map = 19,
                                            Terri = 139,
                                            Zone = 0,
                                            xCoord = 14.0,
                                            yCoord = 24.5
                                        }
                                    },
                                    Name = "Stoneshell"
                                },
                                {
                                    Count = 3,
                                    Icon = 63023,
                                    Id = 23,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 20.1,
                                            yCoord = 20.6
                                        }
                                    },
                                    Name = "Kedtrap"
                                }
                            },
                            Name = "Gladiator 21"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63092,
                                    Id = 278,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 13.8,
                                            yCoord = 10.6
                                        }
                                    },
                                    Name = "Lead Coblyn"
                                }
                            },
                            Name = "Gladiator 22"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63007,
                                    Id = 215,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 18.1,
                                            yCoord = 18.9
                                        }
                                    },
                                    Name = "Overgrown Offering"
                                }
                            },
                            Name = "Gladiator 23"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63061,
                                    Id = 28,
                                    Locations = {
                                        {
                                            Map = 19,
                                            Terri = 139,
                                            Zone = 0,
                                            xCoord = 9.5,
                                            yCoord = 21.5
                                        }
                                    },
                                    Name = "Coeurl Pup"
                                }
                            },
                            Name = "Gladiator 24"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63086,
                                    Id = 17,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = 17.1,
                                            yCoord = 28.7
                                        }
                                    },
                                    Name = "Balloon"
                                }
                            },
                            Name = "Gladiator 25"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63073,
                                    Id = 286,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 17.1,
                                            yCoord = 15.7
                                        }
                                    },
                                    Name = "Sabotender"
                                }
                            },
                            Name = "Gladiator 26"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63060,
                                    Id = 268,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 24.0,
                                            yCoord = 23.0
                                        }
                                    },
                                    Name = "Qiqirn Roerunner"
                                }
                            },
                            Name = "Gladiator 27"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63009,
                                    Id = 50,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 27.8,
                                            yCoord = 21.1
                                        }
                                    },
                                    Name = "Goblin Thug"
                                }
                            },
                            Name = "Gladiator 28"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63042,
                                    Id = 169,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 28.8,
                                            yCoord = 21.7
                                        }
                                    },
                                    Name = "Coeurlclaw Cutter"
                                }
                            },
                            Name = "Gladiator 29"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63050,
                                    Id = 341,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 30.0,
                                            yCoord = 35.0
                                        }
                                    },
                                    Name = "Apkallu"
                                },
                                {
                                    Count = 3,
                                    Icon = 63081,
                                    Id = 62,
                                    Locations = {
                                        {
                                            Map = 30,
                                            Terri = 180,
                                            Zone = 0,
                                            xCoord = 14.9,
                                            yCoord = 18.4
                                        }
                                    },
                                    Name = "Pteroc"
                                }
                            },
                            Name = "Gladiator 30"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63049,
                                    Id = 207,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 11.0,
                                            yCoord = 23.0
                                        }
                                    },
                                    Name = "Floating Eye"
                                },
                                {
                                    Count = 3,
                                    Icon = 63091,
                                    Id = 415,
                                    Locations = {
                                        {
                                            Map = 19,
                                            Terri = 139,
                                            Zone = 0,
                                            xCoord = 35.3,
                                            yCoord = 24.1
                                        }
                                    },
                                    Name = "Mamool Ja Sophist"
                                }
                            },
                            Name = "Gladiator 31"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63031,
                                    Id = 643,
                                    Locations = {
                                        {
                                            Map = 19,
                                            Terri = 139,
                                            Zone = 0,
                                            xCoord = 29.0,
                                            yCoord = 24.0
                                        }
                                    },
                                    Name = "Uragnite"
                                },
                                {
                                    Count = 3,
                                    Icon = 63001,
                                    Id = 34,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 17.0,
                                            yCoord = 30.0
                                        }
                                    },
                                    Name = "Adamantoise"
                                }
                            },
                            Name = "Gladiator 32"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63094,
                                    Id = 290,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 17.0,
                                            yCoord = 33.0
                                        }
                                    },
                                    Name = "Sandworm"
                                }
                            },
                            Name = "Gladiator 33"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63078,
                                    Id = 55,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 16.7,
                                            yCoord = 22.5
                                        }
                                    },
                                    Name = "Deathgaze"
                                }
                            },
                            Name = "Gladiator 34"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63027,
                                    Id = 412,
                                    Locations = {
                                        {
                                            Map = 30,
                                            Terri = 180,
                                            Zone = 0,
                                            xCoord = 19.0,
                                            yCoord = 15.0
                                        }
                                    },
                                    Name = "Velociraptor"
                                }
                            },
                            Name = "Gladiator 35"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63014,
                                    Id = 324,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 20.0,
                                            yCoord = 37.0
                                        }
                                    },
                                    Name = "Fallen Wizard"
                                }
                            },
                            Name = "Gladiator 36"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63052,
                                    Id = 659,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 28.3,
                                            yCoord = 14.5
                                        }
                                    },
                                    Name = "Snow Wolf Pup"
                                }
                            },
                            Name = "Gladiator 37"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63018,
                                    Id = 24,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 22.0,
                                            yCoord = 26.0
                                        }
                                    },
                                    Name = "Treant"
                                }
                            },
                            Name = "Gladiator 38"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63097,
                                    Id = 658,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 27.4,
                                            yCoord = 14.6
                                        }
                                    },
                                    Name = "Vodoriga"
                                }
                            },
                            Name = "Gladiator 39"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63067,
                                    Id = 790,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 10.0,
                                            yCoord = 19.0
                                        }
                                    },
                                    Name = "Hippocerf"
                                },
                                {
                                    Count = 3,
                                    Icon = 63086,
                                    Id = 270,
                                    Locations = {
                                        {
                                            Map = 30,
                                            Terri = 180,
                                            Zone = 0,
                                            xCoord = 22.5,
                                            yCoord = 13.5
                                        }
                                    },
                                    Name = "Grenade"
                                }
                            },
                            Name = "Gladiator 40"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63114,
                                    Id = 1852,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 15.8,
                                            yCoord = 34.6
                                        }
                                    },
                                    Name = "Preying Mantis"
                                },
                                {
                                    Count = 2,
                                    Icon = 63005,
                                    Id = 1853,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 12.3,
                                            yCoord = 35.7
                                        }
                                    },
                                    Name = "Lammergeyer"
                                }
                            },
                            Name = "Gladiator 41"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63018,
                                    Id = 233,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 27.0,
                                            yCoord = 22.0
                                        }
                                    },
                                    Name = "Old-growth Treant"
                                },
                                {
                                    Count = 2,
                                    Icon = 63118,
                                    Id = 59,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 29.0,
                                            yCoord = 21.0
                                        }
                                    },
                                    Name = "3rd Cohort Eques"
                                }
                            },
                            Name = "Gladiator 42"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63029,
                                    Id = 1854,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 15.5,
                                            yCoord = 35.4
                                        }
                                    },
                                    Name = "Dead Man's Moan"
                                },
                                {
                                    Count = 2,
                                    Icon = 63090,
                                    Id = 237,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 21.0
                                        }
                                    },
                                    Name = "Morbol"
                                }
                            },
                            Name = "Gladiator 43"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63010,
                                    Id = 645,
                                    Locations = {
                                        {
                                            Map = 25,
                                            Terri = 156,
                                            Zone = 0,
                                            xCoord = 13.0,
                                            yCoord = 11.0
                                        }
                                    },
                                    Name = "Mudpuppy"
                                }
                            },
                            Name = "Gladiator 44"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63041,
                                    Id = 1851,
                                    Locations = {
                                        {
                                            Map = 25,
                                            Terri = 156,
                                            Zone = 0,
                                            xCoord = 27.6,
                                            yCoord = 13.1
                                        }
                                    },
                                    Name = "Lake Cobra"
                                }
                            },
                            Name = "Gladiator 45"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63098,
                                    Id = 786,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 14.3,
                                            yCoord = 27.2
                                        }
                                    },
                                    Name = "Giant Lugger"
                                }
                            },
                            Name = "Gladiator 46"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63043,
                                    Id = 339,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 22.0,
                                            yCoord = 18.7
                                        }
                                    },
                                    Name = "Tempered Orator"
                                }
                            },
                            Name = "Gladiator 47"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63017,
                                    Id = 29,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = 22.9,
                                            yCoord = 20.0
                                        }
                                    },
                                    Name = "Dullahan"
                                }
                            },
                            Name = "Gladiator 48"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63080,
                                    Id = 304,
                                    Locations = {
                                        {
                                            Map = 24,
                                            Terri = 147,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 23.0
                                        }
                                    },
                                    Name = "Basilisk"
                                }
                            },
                            Name = "Gladiator 49"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63107,
                                    Id = 649,
                                    Locations = {
                                        {
                                            Map = 25,
                                            Terri = 156,
                                            Zone = 0,
                                            xCoord = 33.2,
                                            yCoord = 16.0
                                        }
                                    },
                                    Name = "Gigas Bhikkhu"
                                },
                                {
                                    Count = 5,
                                    Icon = 63118,
                                    Id = 1821,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 27.2,
                                            yCoord = 21.1
                                        }
                                    },
                                    Name = "2nd Cohort Hoplomachus"
                                }
                            },
                            Name = "Gladiator 50"
                        }
                    }
                }
            },
            ["10001"] = {
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63051,
                                    Id = 250,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = -80.29598236084,
                                            yCoord = -27.650894165039,
                                            zCoord = 285.94311523438
                                        }
                                    },
                                    Name = "Amalj'aa Hunter"
                                }
                            },
                            Name = "Maelstrom 01"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63075,
                                    Id = 231,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = -92.464347839355,
                                            yCoord = 19.927898406982,
                                            zCoord = 7.45729637146
                                        }
                                    },
                                    Name = "Sylvan Groan"
                                }
                            },
                            Name = "Maelstrom 05"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63075,
                                    Id = 230,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = -101.07299804688,
                                            yCoord = 19.362714767456,
                                            zCoord = 9.0598754882813
                                        }
                                    },
                                    Name = "Sylvan Sough"
                                }
                            },
                            Name = "Maelstrom 06"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63071,
                                    Id = 370,
                                    Locations = {
                                        {
                                            Map = 19,
                                            Terri = 139,
                                            Zone = 0,
                                            xCoord = -482.37164,
                                            yCoord = 29.963614,
                                            zCoord = 46.991257
                                        }
                                    },
                                    Name = "Kobold Pickman"
                                }
                            },
                            Name = "Maelstrom 07"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63051,
                                    Id = 256,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 170.29815673828,
                                            yCoord = 12.940721511841,
                                            zCoord = -51.579971313477
                                        }
                                    },
                                    Name = "Amalj'aa Bruiser"
                                }
                            },
                            Name = "Maelstrom 08"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63003,
                                    Id = 210,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = 50.256702423096,
                                            yCoord = -39.827217102051,
                                            zCoord = 329.69573974609
                                        }
                                    },
                                    Name = "Ixali Straightbeak"
                                }
                            },
                            Name = "Maelstrom 09"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 1,
                                    Icon = 63003,
                                    Id = 660,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 446.21493530273,
                                            yCoord = 232.42643737793,
                                            zCoord = 323.13607788086
                                        }
                                    },
                                    Name = "Ixali Wildtalon"
                                }
                            },
                            Name = "Maelstrom 10"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63051,
                                    Id = 260,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 315.80978393555,
                                            yCoord = 7.5545597076416,
                                            zCoord = 645.75024414063
                                        }
                                    },
                                    Name = "Amalj'aa Divinator"
                                }
                            },
                            Name = "Maelstrom 11"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63071,
                                    Id = 369,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 333.7028503418,
                                            yCoord = 35.613327026367,
                                            zCoord = 223.26969909668
                                        }
                                    },
                                    Name = "Kobold Pitman"
                                }
                            },
                            Name = "Maelstrom 12"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63071,
                                    Id = 375,
                                    Locations = {
                                        {
                                            Map = 30,
                                            Terri = 180,
                                            Zone = 0,
                                            xCoord = 77.071411132813,
                                            yCoord = 55.627197265625,
                                            zCoord = -464.68310546875
                                        }
                                    },
                                    Name = "Kobold Bedesman"
                                }
                            },
                            Name = "Maelstrom 16"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 1,
                                    Icon = 63071,
                                    Id = 371,
                                    Locations = {
                                        {
                                            Map = 30,
                                            Terri = 180,
                                            Zone = 0,
                                            xCoord = 86.873229980469,
                                            yCoord = 55.608974456787,
                                            zCoord = -464.75595092773
                                        }
                                    },
                                    Name = "Kobold Priest"
                                }
                            },
                            Name = "Maelstrom 17"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63075,
                                    Id = 65,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 73.532669067383,
                                            yCoord = 10.686767578125,
                                            zCoord = -18.615756988525
                                        }
                                    },
                                    Name = "Sylvan Sigh"
                                }
                            },
                            Name = "Maelstrom 18"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63095,
                                    Id = 386,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = -150.08683776855,
                                            yCoord = -36.641159057617,
                                            zCoord = -18.89920425415
                                        }
                                    },
                                    Name = "Shelfscale Sahagin"
                                }
                            },
                            Name = "Maelstrom 19"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63051,
                                    Id = 253,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = -103.77094268799,
                                            yCoord = 12.615503311157,
                                            zCoord = 79.087837219238
                                        }
                                    },
                                    Name = "Amalj'aa Pugilist"
                                }
                            },
                            Name = "Maelstrom 20"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63003,
                                    Id = 103,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = -116.77834320068,
                                            yCoord = -9.3316307067871,
                                            zCoord = -81.372146606445
                                        }
                                    },
                                    Name = "Ixali Boldwing"
                                }
                            },
                            Name = "Maelstrom 21"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63075,
                                    Id = 67,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 532.83673095703,
                                            yCoord = -22.896978378296,
                                            zCoord = -346.36309814453
                                        }
                                    },
                                    Name = "Sylpheed Screech"
                                }
                            },
                            Name = "Maelstrom 22"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63071,
                                    Id = 1834,
                                    Locations = {
                                        {
                                            Map = 30,
                                            Terri = 180,
                                            Zone = 0,
                                            xCoord = 80.275772094727,
                                            yCoord = 39.958393096924,
                                            zCoord = -573.056640625
                                        }
                                    },
                                    Name = "U'Ghamaro Bedesman"
                                }
                            },
                            Name = "Maelstrom 23"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63095,
                                    Id = 565,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = -72.242607116699,
                                            yCoord = -26.004175186157,
                                            zCoord = -72.850128173828
                                        }
                                    },
                                    Name = "Trenchtooth Sahagin"
                                }
                            },
                            Name = "Maelstrom 24"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63095,
                                    Id = 1828,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = -276.33615112305,
                                            yCoord = -41.868183135986,
                                            zCoord = -348.77963256836
                                        }
                                    },
                                    Name = "Sapsa Shelfclaw"
                                }
                            },
                            Name = "Maelstrom 25"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63051,
                                    Id = 1838,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 265.67340087891,
                                            yCoord = 10.866530418396,
                                            zCoord = -13.621644973755
                                        }
                                    },
                                    Name = "Zahar'ak Archer"
                                }
                            },
                            Name = "Maelstrom 26"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63003,
                                    Id = 1845,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 656.34484863281,
                                            yCoord = 286.48809814453,
                                            zCoord = 44.241111755371
                                        }
                                    },
                                    Name = "Natalan Fogcaller"
                                }
                            },
                            Name = "Maelstrom 27"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63003,
                                    Id = 1843,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 656.06488037109,
                                            yCoord = 303.0471496582,
                                            zCoord = -38.165336608887
                                        }
                                    },
                                    Name = "Natalan Boldwing"
                                }
                            },
                            Name = "Maelstrom 28"
                        }
                    }
                }
            },
            ["10002"] = {
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63051,
                                    Id = 247,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = -77.746406555176,
                                            yCoord = -27.418830871582,
                                            zCoord = 286.34729003906
                                        }
                                    },
                                    Name = "Amalj'aa Javelinier"
                                }
                            },
                            Name = "Order of the Twin Adder 01"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63075,
                                    Id = 229,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = -114.44561767578,
                                            yCoord = 16.697059631348,
                                            zCoord = 15.040746688843
                                        }
                                    },
                                    Name = "Sylvan Scream"
                                }
                            },
                            Name = "Order of the Twin Adder 05"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63071,
                                    Id = 370,
                                    Locations = {
                                        {
                                            Map = 19,
                                            Terri = 139,
                                            Zone = 0,
                                            xCoord = -475.02124023438,
                                            yCoord = 28.735013961792,
                                            zCoord = 53.085304260254
                                        }
                                    },
                                    Name = "Kobold Pickman"
                                }
                            },
                            Name = "Order of the Twin Adder 06"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63051,
                                    Id = 256,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 170.29815673828,
                                            yCoord = 12.940721511841,
                                            zCoord = -51.579971313477
                                        }
                                    },
                                    Name = "Amalj'aa Bruiser"
                                }
                            },
                            Name = "Order of the Twin Adder 07"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63003,
                                    Id = 209,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = 58.506439208984,
                                            yCoord = -39.071338653564,
                                            zCoord = 327.64761352539
                                        }
                                    },
                                    Name = "Ixali Deftalon"
                                }
                            },
                            Name = "Order of the Twin Adder 08"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63051,
                                    Id = 251,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 183.23175048828,
                                            yCoord = 11.39147567749,
                                            zCoord = -33.88793182373
                                        }
                                    },
                                    Name = "Amalj'aa Ranger"
                                }
                            },
                            Name = "Order of the Twin Adder 09"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 1,
                                    Icon = 63003,
                                    Id = 663,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 533.18719482422,
                                            yCoord = 235.22831726074,
                                            zCoord = 306.44104003906
                                        }
                                    },
                                    Name = "Ixali Fearcaller"
                                }
                            },
                            Name = "Order of the Twin Adder 10"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63051,
                                    Id = 252,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 217.35272216797,
                                            yCoord = 10.009443283081,
                                            zCoord = 656.79742431641
                                        }
                                    },
                                    Name = "Amalj'aa Sniper"
                                }
                            },
                            Name = "Order of the Twin Adder 11"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63071,
                                    Id = 373,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 325.74618530273,
                                            yCoord = 36.531806945801,
                                            zCoord = 228.31265258789
                                        }
                                    },
                                    Name = "Kobold Missionary"
                                }
                            },
                            Name = "Order of the Twin Adder 12"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63071,
                                    Id = 376,
                                    Locations = {
                                        {
                                            Map = 19,
                                            Terri = 139,
                                            Zone = 0,
                                            xCoord = 266.43844604492,
                                            yCoord = 26.179088592529,
                                            zCoord = -100.91185760498
                                        }
                                    },
                                    Name = "Kobold Sidesman"
                                }
                            },
                            Name = "Order of the Twin Adder 13"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63071,
                                    Id = 377,
                                    Locations = {
                                        {
                                            Map = 30,
                                            Terri = 180,
                                            Zone = 0,
                                            xCoord = 25.03670501709,
                                            yCoord = 48.303039550781,
                                            zCoord = -351.33093261719
                                        }
                                    },
                                    Name = "Kobold Roundsman"
                                }
                            },
                            Name = "Order of the Twin Adder 16"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63075,
                                    Id = 66,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 75.27025604248,
                                            yCoord = 10.434731483459,
                                            zCoord = -20.423789978027
                                        }
                                    },
                                    Name = "Sylvan Snarl"
                                }
                            },
                            Name = "Order of the Twin Adder 17"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63095,
                                    Id = 384,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = -194.34175109863,
                                            yCoord = -40.384712219238,
                                            zCoord = -80.416831970215
                                        }
                                    },
                                    Name = "Shelfclaw Sahagin"
                                }
                            },
                            Name = "Order of the Twin Adder 18"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63051,
                                    Id = 245,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = -16.744487762451,
                                            yCoord = 2.4013848304749,
                                            zCoord = -35.940933227539
                                        }
                                    },
                                    Name = "Amalj'aa Lancer"
                                }
                            },
                            Name = "Order of the Twin Adder 19"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63071,
                                    Id = 1832,
                                    Locations = {
                                        {
                                            Map = 30,
                                            Terri = 180,
                                            Zone = 0,
                                            xCoord = 112.647315979,
                                            yCoord = 23.395093917847,
                                            zCoord = -608.58044433594
                                        }
                                    },
                                    Name = "U'Ghamaro Roundsman"
                                }
                            },
                            Name = "Order of the Twin Adder 20"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63003,
                                    Id = 436,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = -114.58248138428,
                                            yCoord = -9.3070678710938,
                                            zCoord = -77.048751831055
                                        }
                                    },
                                    Name = "Ixali Windtalon"
                                }
                            },
                            Name = "Order of the Twin Adder 21"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63075,
                                    Id = 69,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 539.86553955078,
                                            yCoord = -23.619871139526,
                                            zCoord = -349.07073974609
                                        }
                                    },
                                    Name = "Sylpheed Snarl"
                                }
                            },
                            Name = "Order of the Twin Adder 22"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63071,
                                    Id = 1833,
                                    Locations = {
                                        {
                                            Map = 30,
                                            Terri = 180,
                                            Zone = 0,
                                            xCoord = 81.84302520752,
                                            yCoord = 23.714502334595,
                                            zCoord = -675.27337646484
                                        }
                                    },
                                    Name = "U'Ghamaro Quarryman"
                                }
                            },
                            Name = "Order of the Twin Adder 23"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63095,
                                    Id = 1830,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = -320.47064208984,
                                            yCoord = -39.843852996826,
                                            zCoord = -307.01806640625
                                        }
                                    },
                                    Name = "Sapsa Shelftooth"
                                }
                            },
                            Name = "Order of the Twin Adder 24"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63051,
                                    Id = 1839,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 232.1410369873,
                                            yCoord = 8.0,
                                            zCoord = -18.306968688965
                                        }
                                    },
                                    Name = "Zahar'ak Pugilist"
                                }
                            },
                            Name = "Order of the Twin Adder 25"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63003,
                                    Id = 1844,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 639.39154052734,
                                            yCoord = 288.88107299805,
                                            zCoord = 23.064405441284
                                        }
                                    },
                                    Name = "Natalan Swiftbeak"
                                }
                            },
                            Name = "Order of the Twin Adder 26"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63003,
                                    Id = 1843,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 34.7,
                                            yCoord = 20.8
                                        }
                                    },
                                    Name = "Natalan Boldwing"
                                }
                            },
                            Name = "Order of the Twin Adder 27"
                        }
                    }
                }
            },
            ["10003"] = {
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63051,
                                    Id = 250,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = -80.29598236084,
                                            yCoord = -27.650894165039,
                                            zCoord = 285.94311523438
                                        }
                                    },
                                    Name = "Amalj'aa Hunter"
                                }
                            },
                            Name = "Immortal Flames 01"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63075,
                                    Id = 230,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = -101.07299804688,
                                            yCoord = 19.362714767456,
                                            zCoord = 9.0598754882813
                                        }
                                    },
                                    Name = "Sylvan Sough"
                                }
                            },
                            Name = "Immortal Flames 05"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63071,
                                    Id = 380,
                                    Locations = {
                                        {
                                            Map = 19,
                                            Terri = 139,
                                            Zone = 0,
                                            xCoord = -486.6770324707,
                                            yCoord = -2.3133111000061,
                                            zCoord = 21.108375549316
                                        }
                                    },
                                    Name = "Kobold Footman"
                                }
                            },
                            Name = "Immortal Flames 06"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63071,
                                    Id = 370,
                                    Locations = {
                                        {
                                            Map = 19,
                                            Terri = 139,
                                            Zone = 0,
                                            xCoord = -475.02124023438,
                                            yCoord = 28.735013961792,
                                            zCoord = 53.085304260254
                                        }
                                    },
                                    Name = "Kobold Pickman"
                                }
                            },
                            Name = "Immortal Flames 07"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63051,
                                    Id = 259,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = -18.096021652222,
                                            yCoord = 15.659177780151,
                                            zCoord = -293.35949707031
                                        }
                                    },
                                    Name = "Amalj'aa Seer"
                                }
                            },
                            Name = "Immortal Flames 08"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63003,
                                    Id = 208,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = 52.15368270874,
                                            yCoord = -39.775424957275,
                                            zCoord = 330.80755615234
                                        }
                                    },
                                    Name = "Ixali Lightwing"
                                }
                            },
                            Name = "Immortal Flames 09"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 1,
                                    Icon = 63003,
                                    Id = 662,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 534.42889404297,
                                            yCoord = 235.30220031738,
                                            zCoord = 302.60968017578
                                        }
                                    },
                                    Name = "Ixali Boundwing"
                                }
                            },
                            Name = "Immortal Flames 10"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63051,
                                    Id = 248,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 203.26782226563,
                                            yCoord = 10.282114028931,
                                            zCoord = 652.63092041016
                                        }
                                    },
                                    Name = "Amalj'aa Halberdier"
                                }
                            },
                            Name = "Immortal Flames 11"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63071,
                                    Id = 373,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 325.74618530273,
                                            yCoord = 36.531806945801,
                                            zCoord = 228.31265258789
                                        }
                                    },
                                    Name = "Kobold Missionary"
                                }
                            },
                            Name = "Immortal Flames 12"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63071,
                                    Id = 376,
                                    Locations = {
                                        {
                                            Map = 19,
                                            Terri = 139,
                                            Zone = 0,
                                            xCoord = 266.43844604492,
                                            yCoord = 26.179088592529,
                                            zCoord = -100.91185760498
                                        }
                                    },
                                    Name = "Kobold Sidesman"
                                }
                            },
                            Name = "Immortal Flames 13"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63071,
                                    Id = 562,
                                    Locations = {
                                        {
                                            Map = 30,
                                            Terri = 180,
                                            Zone = 0,
                                            xCoord = 114.39206504822,
                                            yCoord = 72.275981903076,
                                            zCoord = -263.65783691406
                                        }
                                    },
                                    Name = "Kobold Quarryman"
                                }
                            },
                            Name = "Immortal Flames 17"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63075,
                                    Id = 64,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = -12.130096435547,
                                            yCoord = 19.91993522644,
                                            zCoord = -2.7961874008179
                                        }
                                    },
                                    Name = "Sylvan Screech"
                                }
                            },
                            Name = "Immortal Flames 18"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63095,
                                    Id = 389,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = -158.73106384277,
                                            yCoord = -32.404228210449,
                                            zCoord = 2.3584578037262
                                        }
                                    },
                                    Name = "Shelfspine Sahagin"
                                }
                            },
                            Name = "Immortal Flames 19"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63051,
                                    Id = 249,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = -75.999084075928,
                                            yCoord = 11.840239181519,
                                            zCoord = 107.72562805176
                                        }
                                    },
                                    Name = "Amalj'aa Archer"
                                }
                            },
                            Name = "Immortal Flames 20"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63003,
                                    Id = 436,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = -114.58248138428,
                                            yCoord = -9.3070678710938,
                                            zCoord = -77.048751831055
                                        }
                                    },
                                    Name = "Ixali Windtalon"
                                }
                            },
                            Name = "Immortal Flames 21"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63075,
                                    Id = 68,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 539.65753173828,
                                            yCoord = -23.592895507813,
                                            zCoord = -352.49411010742
                                        }
                                    },
                                    Name = "Sylpheed Sigh"
                                }
                            },
                            Name = "Immortal Flames 22"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63071,
                                    Id = 1835,
                                    Locations = {
                                        {
                                            Map = 30,
                                            Terri = 180,
                                            Zone = 0,
                                            xCoord = 23.957487106323,
                                            yCoord = 21.50196647644,
                                            zCoord = -771.61029052734
                                        }
                                    },
                                    Name = "U'Ghamaro Priest"
                                }
                            },
                            Name = "Immortal Flames 23"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63095,
                                    Id = 1829,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = -285.72274780273,
                                            yCoord = -41.867427825928,
                                            zCoord = -336.45138549805
                                        }
                                    },
                                    Name = "Sapsa Shelfspine"
                                }
                            },
                            Name = "Immortal Flames 24"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63051,
                                    Id = 1840,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 345.58450317383,
                                            yCoord = 8.7354640960693,
                                            zCoord = -35.065048217773
                                        }
                                    },
                                    Name = "Zahar'ak Thaumaturge"
                                }
                            },
                            Name = "Immortal Flames 25"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63003,
                                    Id = 1842,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 650.88909912109,
                                            yCoord = 287.23934936523,
                                            zCoord = 32.890659332275
                                        }
                                    },
                                    Name = "Natalan Windtalon"
                                }
                            },
                            Name = "Immortal Flames 26"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63003,
                                    Id = 1843,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 34.7,
                                            yCoord = 20.8
                                        }
                                    },
                                    Name = "Natalan Boldwing"
                                }
                            },
                            Name = "Immortal Flames 27"
                        }
                    }
                }
            },
            ["2"] = {
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63048,
                                    Id = 632,
                                    Locations = {
                                        {
                                            Map = 21,
                                            Terri = 141,
                                            Zone = 0,
                                            xCoord = 21.0,
                                            yCoord = 26.0
                                        }
                                    },
                                    Name = "Huge Hornet"
                                }
                            },
                            Name = "Pugilist 01"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63028,
                                    Id = 262,
                                    Locations = {
                                        {
                                            Map = 21,
                                            Terri = 141,
                                            Zone = 0,
                                            xCoord = 20.0,
                                            yCoord = 27.0
                                        }
                                    },
                                    Name = "Star Marmot"
                                }
                            },
                            Name = "Pugilist 02"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63073,
                                    Id = 287,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 27.0,
                                            yCoord = 24.0
                                        }
                                    },
                                    Name = "Cactuar"
                                }
                            },
                            Name = "Pugilist 03"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63089,
                                    Id = 318,
                                    Locations = {
                                        {
                                            Map = 21,
                                            Terri = 141,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 27.0
                                        }
                                    },
                                    Name = "Snapping Shrew"
                                }
                            },
                            Name = "Pugilist 04"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63083,
                                    Id = 308,
                                    Locations = {
                                        {
                                            Map = 21,
                                            Terri = 141,
                                            Zone = 0,
                                            xCoord = 21.0,
                                            yCoord = 24.0
                                        }
                                    },
                                    Name = "Orobon"
                                }
                            },
                            Name = "Pugilist 05"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63005,
                                    Id = 299,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 21.0,
                                            yCoord = 25.0
                                        },
                                        {
                                            Map = 16,
                                            Terri = 135,
                                            Zone = 0,
                                            xCoord = 32.4,
                                            yCoord = 15.7
                                        }
                                    },
                                    Name = "Nesting Buzzard"
                                }
                            },
                            Name = "Pugilist 06"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63087,
                                    Id = 317,
                                    Locations = {
                                        {
                                            Map = 21,
                                            Terri = 141,
                                            Zone = 0,
                                            xCoord = 17.0,
                                            yCoord = 23.0
                                        }
                                    },
                                    Name = "Spriggan Graverobber"
                                }
                            },
                            Name = "Pugilist 07"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63009,
                                    Id = 283,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 18.8,
                                            yCoord = 26.0
                                        }
                                    },
                                    Name = "Goblin Mugger"
                                }
                            },
                            Name = "Pugilist 08"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63059,
                                    Id = 265,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 23.8,
                                            yCoord = 23.2
                                        }
                                    },
                                    Name = "Sandtoad"
                                }
                            },
                            Name = "Pugilist 09"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 2,
                                    Icon = 63080,
                                    Id = 305,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 24.0,
                                            yCoord = 20.0
                                        }
                                    },
                                    Name = "Desert Peiste"
                                },
                                {
                                    Count = 2,
                                    Icon = 63012,
                                    Id = 298,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 17.0,
                                            yCoord = 15.0
                                        }
                                    },
                                    Name = "Sun Midge Swarm"
                                },
                                {
                                    Count = 2,
                                    Icon = 63010,
                                    Id = 289,
                                    Locations = {
                                        {
                                            Map = 21,
                                            Terri = 141,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 18.0
                                        }
                                    },
                                    Name = "Eft"
                                }
                            },
                            Name = "Pugilist 10"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63086,
                                    Id = 316,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 27.6,
                                            yCoord = 16.7
                                        }
                                    },
                                    Name = "Bomb"
                                }
                            },
                            Name = "Pugilist 11"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63073,
                                    Id = 288,
                                    Locations = {
                                        {
                                            Map = 21,
                                            Terri = 141,
                                            Zone = 0,
                                            xCoord = 23.7,
                                            yCoord = 19.6
                                        }
                                    },
                                    Name = "Cochineal Cactuar"
                                }
                            },
                            Name = "Pugilist 12"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63076,
                                    Id = 293,
                                    Locations = {
                                        {
                                            Map = 21,
                                            Terri = 141,
                                            Zone = 0,
                                            xCoord = 16.0,
                                            yCoord = 14.0
                                        }
                                    },
                                    Name = "Antling Sentry"
                                }
                            },
                            Name = "Pugilist 13"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63001,
                                    Id = 244,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 21.7,
                                            yCoord = 26.7
                                        }
                                    },
                                    Name = "Giant Tortoise"
                                }
                            },
                            Name = "Pugilist 14"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 2,
                                    Icon = 63005,
                                    Id = 13,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 17.0,
                                            yCoord = 16.0
                                        },
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 30.0
                                        },
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 31.6,
                                            yCoord = 29.7
                                        }
                                    },
                                    Name = "Arbor Buzzard"
                                },
                                {
                                    Count = 2,
                                    Icon = 63032,
                                    Id = 636,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 16.4,
                                            yCoord = 16.0
                                        }
                                    },
                                    Name = "Thickshell"
                                },
                                {
                                    Count = 2,
                                    Icon = 63031,
                                    Id = 635,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 17.1,
                                            yCoord = 14.7
                                        }
                                    },
                                    Name = "Scaphite"
                                }
                            },
                            Name = "Pugilist 15"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63082,
                                    Id = 306,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 15.0,
                                            yCoord = 20.0
                                        }
                                    },
                                    Name = "Tuco-tuco"
                                }
                            },
                            Name = "Pugilist 16"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63093,
                                    Id = 274,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 18.4,
                                            yCoord = 22.6
                                        }
                                    },
                                    Name = "Myotragus Nanny"
                                }
                            },
                            Name = "Pugilist 17"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63012,
                                    Id = 1199,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 11.0,
                                            yCoord = 22.0
                                        }
                                    },
                                    Name = "Blowfly Swarm"
                                }
                            },
                            Name = "Pugilist 18"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63004,
                                    Id = 1198,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 14.6,
                                            yCoord = 18.5
                                        }
                                    },
                                    Name = "Vandalous Imp"
                                }
                            },
                            Name = "Pugilist 19"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 2,
                                    Icon = 63014,
                                    Id = 319,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 14.8,
                                            yCoord = 16.8
                                        }
                                    },
                                    Name = "Rotting Corpse"
                                },
                                {
                                    Count = 2,
                                    Icon = 63014,
                                    Id = 322,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 14.8,
                                            yCoord = 16.8
                                        }
                                    },
                                    Name = "Rotting Noble"
                                },
                                {
                                    Count = 2,
                                    Icon = 63084,
                                    Id = 309,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 13.2,
                                            yCoord = 11.8
                                        }
                                    },
                                    Name = "Bloated Bogy"
                                }
                            },
                            Name = "Pugilist 20"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63007,
                                    Id = 214,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 29.0
                                        }
                                    },
                                    Name = "Overgrown Ivy"
                                }
                            },
                            Name = "Pugilist 21"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63083,
                                    Id = 234,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 16.0,
                                            yCoord = 18.0
                                        }
                                    },
                                    Name = "Smallmouth Orobon"
                                }
                            },
                            Name = "Pugilist 22"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63026,
                                    Id = 381,
                                    Locations = {
                                        {
                                            Map = 19,
                                            Terri = 139,
                                            Zone = 0,
                                            xCoord = 11.1,
                                            yCoord = 21.3
                                        }
                                    },
                                    Name = "Forest Yarzon"
                                }
                            },
                            Name = "Pugilist 23"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63061,
                                    Id = 28,
                                    Locations = {
                                        {
                                            Map = 19,
                                            Terri = 139,
                                            Zone = 0,
                                            xCoord = 9.5,
                                            yCoord = 21.5
                                        }
                                    },
                                    Name = "Coeurl Pup"
                                }
                            },
                            Name = "Pugilist 24"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63010,
                                    Id = 228,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 18.1,
                                            yCoord = 24.5
                                        }
                                    },
                                    Name = "Bark Eft"
                                },
                                {
                                    Count = 3,
                                    Icon = 63013,
                                    Id = 40,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = 17.0,
                                            yCoord = 27.0
                                        }
                                    },
                                    Name = "Shroud Hare"
                                },
                                {
                                    Count = 3,
                                    Icon = 63014,
                                    Id = 323,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 19.0,
                                            yCoord = 17.0
                                        }
                                    },
                                    Name = "Fallen Mage"
                                }
                            },
                            Name = "Pugilist 25"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63070,
                                    Id = 224,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = 16.0,
                                            yCoord = 27.5
                                        }
                                    },
                                    Name = "Ziz"
                                }
                            },
                            Name = "Pugilist 26"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63045,
                                    Id = 331,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 24.0,
                                            yCoord = 9.0
                                        }
                                    },
                                    Name = "Corpse Brigade Knuckledancer"
                                }
                            },
                            Name = "Pugilist 27"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63069,
                                    Id = 30,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = 17.9,
                                            yCoord = 28.3
                                        }
                                    },
                                    Name = "Clay Golem"
                                }
                            },
                            Name = "Pugilist 28"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63030,
                                    Id = 139,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 28.8,
                                            yCoord = 21.7
                                        }
                                    },
                                    Name = "Coeurlclaw Hunter"
                                }
                            },
                            Name = "Pugilist 29"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63050,
                                    Id = 341,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 30.0,
                                            yCoord = 35.0
                                        }
                                    },
                                    Name = "Apkallu"
                                },
                                {
                                    Count = 3,
                                    Icon = 63027,
                                    Id = 130,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 13.0,
                                            yCoord = 19.0
                                        }
                                    },
                                    Name = "Lindwurm"
                                },
                                {
                                    Count = 3,
                                    Icon = 63083,
                                    Id = 235,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 18.0,
                                            yCoord = 30.0
                                        }
                                    },
                                    Name = "Bigmouth Orobon"
                                }
                            },
                            Name = "Pugilist 30"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63091,
                                    Id = 414,
                                    Locations = {
                                        {
                                            Map = 19,
                                            Terri = 139,
                                            Zone = 0,
                                            xCoord = 35.3,
                                            yCoord = 24.1
                                        }
                                    },
                                    Name = "Mamool Ja Breeder"
                                }
                            },
                            Name = "Pugilist 31"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63026,
                                    Id = 204,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 14.0,
                                            yCoord = 32.0
                                        }
                                    },
                                    Name = "Russet Yarzon"
                                }
                            },
                            Name = "Pugilist 32"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63086,
                                    Id = 132,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 19.0,
                                            yCoord = 34.0
                                        }
                                    },
                                    Name = "Smoke Bomb"
                                }
                            },
                            Name = "Pugilist 33"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63078,
                                    Id = 55,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 17.7,
                                            yCoord = 22.2
                                        }
                                    },
                                    Name = "Deathgaze"
                                }
                            },
                            Name = "Pugilist 34"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63062,
                                    Id = 353,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 17.0,
                                            yCoord = 31.0
                                        }
                                    },
                                    Name = "Goobbue"
                                },
                                {
                                    Count = 3,
                                    Icon = 63061,
                                    Id = 352,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 18.0,
                                            yCoord = 28.0
                                        }
                                    },
                                    Name = "Jungle Coeurl"
                                },
                                {
                                    Count = 3,
                                    Icon = 63069,
                                    Id = 365,
                                    Locations = {
                                        {
                                            Map = 30,
                                            Terri = 180,
                                            Zone = 0,
                                            xCoord = 13.6,
                                            yCoord = 15.1
                                        }
                                    },
                                    Name = "Basalt Golem"
                                }
                            },
                            Name = "Pugilist 35"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63027,
                                    Id = 412,
                                    Locations = {
                                        {
                                            Map = 30,
                                            Terri = 180,
                                            Zone = 0,
                                            xCoord = 19.0,
                                            yCoord = 15.0
                                        }
                                    },
                                    Name = "Velociraptor"
                                }
                            },
                            Name = "Pugilist 36"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63062,
                                    Id = 1612,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 29.0
                                        }
                                    },
                                    Name = "Highland Goobbue"
                                }
                            },
                            Name = "Pugilist 37"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63108,
                                    Id = 784,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 22.0
                                        }
                                    },
                                    Name = "Feral Croc"
                                }
                            },
                            Name = "Pugilist 38"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63058,
                                    Id = 794,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 12.0
                                        }
                                    },
                                    Name = "Redhorn Ogre"
                                }
                            },
                            Name = "Pugilist 39"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63062,
                                    Id = 1611,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 17.0
                                        }
                                    },
                                    Name = "Snowstorm Goobbue"
                                },
                                {
                                    Count = 3,
                                    Icon = 63007,
                                    Id = 33,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 21.0
                                        }
                                    },
                                    Name = "Ochu"
                                },
                                {
                                    Count = 3,
                                    Icon = 63070,
                                    Id = 222,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 26.5,
                                            yCoord = 24.6
                                        }
                                    },
                                    Name = "Molted Ziz"
                                }
                            },
                            Name = "Pugilist 40"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 6,
                                    Icon = 63092,
                                    Id = 275,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 31.0,
                                            yCoord = 26.0
                                        }
                                    },
                                    Name = "Quartz Doblyn"
                                }
                            },
                            Name = "Pugilist 41"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 6,
                                    Icon = 63029,
                                    Id = 1854,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 15.0,
                                            yCoord = 35.0
                                        }
                                    },
                                    Name = "Dead Man's Moan"
                                }
                            },
                            Name = "Pugilist 42"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 2,
                                    Icon = 63118,
                                    Id = 61,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 32.5,
                                            yCoord = 20.5
                                        }
                                    },
                                    Name = "3rd Cohort Signifer"
                                }
                            },
                            Name = "Pugilist 43"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 6,
                                    Icon = 63024,
                                    Id = 15,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 31.0,
                                            yCoord = 25.0
                                        }
                                    },
                                    Name = "Wild Hog"
                                }
                            },
                            Name = "Pugilist 44"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63014,
                                    Id = 651,
                                    Locations = {
                                        {
                                            Map = 25,
                                            Terri = 156,
                                            Zone = 0,
                                            xCoord = 17.0,
                                            yCoord = 16.0
                                        }
                                    },
                                    Name = "Raging Harrier"
                                },
                                {
                                    Count = 3,
                                    Icon = 63053,
                                    Id = 788,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 11.0,
                                            yCoord = 29.0
                                        }
                                    },
                                    Name = "Biast"
                                },
                                {
                                    Count = 3,
                                    Icon = 63107,
                                    Id = 647,
                                    Locations = {
                                        {
                                            Map = 25,
                                            Terri = 156,
                                            Zone = 0,
                                            xCoord = 27.0,
                                            yCoord = 11.0
                                        }
                                    },
                                    Name = "Gigas Shramana"
                                }
                            },
                            Name = "Pugilist 45"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 6,
                                    Icon = 63052,
                                    Id = 653,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 16.0,
                                            yCoord = 32.0
                                        }
                                    },
                                    Name = "Snow Wolf"
                                }
                            },
                            Name = "Pugilist 46"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 6,
                                    Icon = 63118,
                                    Id = 1809,
                                    Locations = {
                                        {
                                            Map = 25,
                                            Terri = 156,
                                            Zone = 0,
                                            xCoord = 12.0,
                                            yCoord = 12.0
                                        }
                                    },
                                    Name = "5th Cohort Hoplomachus"
                                }
                            },
                            Name = "Pugilist 47"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 6,
                                    Icon = 63059,
                                    Id = 164,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 27.0,
                                            yCoord = 18.0
                                        }
                                    },
                                    Name = "Dreamtoad"
                                }
                            },
                            Name = "Pugilist 48"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 6,
                                    Icon = 63058,
                                    Id = 793,
                                    Locations = {
                                        {
                                            Map = 25,
                                            Terri = 156,
                                            Zone = 0,
                                            xCoord = 31.0,
                                            yCoord = 5.0
                                        }
                                    },
                                    Name = "Hapalit"
                                }
                            },
                            Name = "Pugilist 49"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63053,
                                    Id = 1841,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 29.5,
                                            yCoord = 19.5
                                        }
                                    },
                                    Name = "Zahar'ak Battle Drake"
                                },
                                {
                                    Count = 3,
                                    Icon = 63080,
                                    Id = 304,
                                    Locations = {
                                        {
                                            Map = 24,
                                            Terri = 147,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 23.0
                                        }
                                    },
                                    Name = "Basilisk"
                                },
                                {
                                    Count = 4,
                                    Icon = 63119,
                                    Id = 345,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 13.7,
                                            yCoord = 16.7
                                        }
                                    },
                                    Name = "Shelfclaw Reaver"
                                }
                            },
                            Name = "Pugilist 50"
                        }
                    }
                }
            },
            ["26"] = {
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63036,
                                    Id = 49,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 267.96899414063,
                                            yCoord = 54.97074508667,
                                            zCoord = 124.23870849609
                                        }
                                    },
                                    Name = "Little Ladybug"
                                }
                            },
                            Name = "Arcanist 01"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63028,
                                    Id = 417,
                                    Locations = {
                                        {
                                            Map = 15,
                                            Terri = 134,
                                            Zone = 0,
                                            xCoord = 21.0,
                                            yCoord = 23.0
                                        }
                                    },
                                    Name = "Wharf Rat"
                                }
                            },
                            Name = "Arcanist 02"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63074,
                                    Id = 392,
                                    Locations = {
                                        {
                                            Map = 15,
                                            Terri = 134,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 24.0
                                        }
                                    },
                                    Name = "Lost Lamb"
                                }
                            },
                            Name = "Arcanist 03"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63056,
                                    Id = 115,
                                    Locations = {
                                        {
                                            Map = 16,
                                            Terri = 135,
                                            Zone = 0,
                                            xCoord = 29.8,
                                            yCoord = 21.0
                                        }
                                    },
                                    Name = "Wind Sprite"
                                }
                            },
                            Name = "Arcanist 04"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63081,
                                    Id = 401,
                                    Locations = {
                                        {
                                            Map = 15,
                                            Terri = 134,
                                            Zone = 0,
                                            xCoord = 20.0,
                                            yCoord = 19.0
                                        }
                                    },
                                    Name = "Puk Hatchling"
                                }
                            },
                            Name = "Arcanist 05"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63005,
                                    Id = 299,
                                    Locations = {
                                        {
                                            Map = 16,
                                            Terri = 135,
                                            Zone = 0,
                                            xCoord = 32.4,
                                            yCoord = 15.7
                                        },
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 21.0,
                                            yCoord = 25.0
                                        }
                                    },
                                    Name = "Nesting Buzzard"
                                }
                            },
                            Name = "Arcanist 06"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63084,
                                    Id = 404,
                                    Locations = {
                                        {
                                            Map = 15,
                                            Terri = 134,
                                            Zone = 0,
                                            xCoord = 20.0,
                                            yCoord = 19.0
                                        }
                                    },
                                    Name = "Bogy"
                                }
                            },
                            Name = "Arcanist 07"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63020,
                                    Id = 364,
                                    Locations = {
                                        {
                                            Map = 16,
                                            Terri = 135,
                                            Zone = 0,
                                            xCoord = 27.1,
                                            yCoord = 16.2
                                        }
                                    },
                                    Name = "Cave Bat"
                                },
                                {
                                    Count = 3,
                                    Icon = 63008,
                                    Id = 408,
                                    Locations = {
                                        {
                                            Map = 16,
                                            Terri = 135,
                                            Zone = 0,
                                            xCoord = 29.0,
                                            yCoord = 14.0
                                        }
                                    },
                                    Name = "Galago"
                                }
                            },
                            Name = "Arcanist 08"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63045,
                                    Id = 421,
                                    Locations = {
                                        {
                                            Map = 15,
                                            Terri = 134,
                                            Zone = 0,
                                            xCoord = 20.3,
                                            yCoord = 16.9
                                        }
                                    },
                                    Name = "Grounded Pirate"
                                }
                            },
                            Name = "Arcanist 09"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63057,
                                    Id = 117,
                                    Locations = {
                                        {
                                            Map = 16,
                                            Terri = 135,
                                            Zone = 0,
                                            xCoord = 20.0,
                                            yCoord = 32.0
                                        }
                                    },
                                    Name = "Lightning Sprite"
                                }
                            },
                            Name = "Arcanist 10"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63089,
                                    Id = 410,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 33.9,
                                            yCoord = 28.9
                                        }
                                    },
                                    Name = "Sewer Mole"
                                }
                            },
                            Name = "Arcanist 11"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63062,
                                    Id = 354,
                                    Locations = {
                                        {
                                            Map = 16,
                                            Terri = 135,
                                            Zone = 0,
                                            xCoord = 23.3,
                                            yCoord = 23.3
                                        }
                                    },
                                    Name = "Mossless Goobbue"
                                }
                            },
                            Name = "Arcanist 12"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63079,
                                    Id = 394,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 34.2,
                                            yCoord = 29.4
                                        }
                                    },
                                    Name = "Fat Dodo"
                                }
                            },
                            Name = "Arcanist 13"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63005,
                                    Id = 13,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 31.6,
                                            yCoord = 29.7
                                        },
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 17.0,
                                            yCoord = 16.0
                                        },
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 30.0
                                        }
                                    },
                                    Name = "Arbor Buzzard"
                                }
                            },
                            Name = "Arcanist 14"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63060,
                                    Id = 350,
                                    Locations = {
                                        {
                                            Map = 16,
                                            Terri = 135,
                                            Zone = 0,
                                            xCoord = 18.5,
                                            yCoord = 34.9
                                        }
                                    },
                                    Name = "Qiqirn Eggdigger"
                                }
                            },
                            Name = "Arcanist 15"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63020,
                                    Id = 363,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 28.5,
                                            yCoord = 22.9
                                        }
                                    },
                                    Name = "Dusk Bat"
                                }
                            },
                            Name = "Arcanist 16"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63081,
                                    Id = 401,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 27.4,
                                            yCoord = 24.3
                                        }
                                    },
                                    Name = "Puk Hatchling"
                                }
                            },
                            Name = "Arcanist 17"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63082,
                                    Id = 403,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 26.7,
                                            yCoord = 23.4
                                        }
                                    },
                                    Name = "Hedgemole"
                                },
                                {
                                    Count = 3,
                                    Icon = 63070,
                                    Id = 1181,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 24.3,
                                            yCoord = 23.0
                                        }
                                    },
                                    Name = "Rothlyt Pelican"
                                }
                            },
                            Name = "Arcanist 18"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63033,
                                    Id = 644,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 22.5,
                                            yCoord = 20.8
                                        }
                                    },
                                    Name = "Killer Mantis"
                                }
                            },
                            Name = "Arcanist 19"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63021,
                                    Id = 296,
                                    Locations = {
                                        {
                                            Map = 19,
                                            Terri = 139,
                                            Zone = 0,
                                            xCoord = 12.7,
                                            yCoord = 24.1
                                        }
                                    },
                                    Name = "Bumble Beetle"
                                }
                            },
                            Name = "Arcanist 20"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63007,
                                    Id = 214,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 29.0
                                        }
                                    },
                                    Name = "Overgrown Ivy"
                                }
                            },
                            Name = "Arcanist 21"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63092,
                                    Id = 278,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 13.8,
                                            yCoord = 10.6
                                        }
                                    },
                                    Name = "Lead Coblyn"
                                }
                            },
                            Name = "Arcanist 22"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63023,
                                    Id = 23,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 20.1,
                                            yCoord = 20.6
                                        }
                                    },
                                    Name = "Kedtrap"
                                }
                            },
                            Name = "Arcanist 23"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63061,
                                    Id = 28,
                                    Locations = {
                                        {
                                            Map = 19,
                                            Terri = 139,
                                            Zone = 0,
                                            xCoord = 9.5,
                                            yCoord = 21.5
                                        }
                                    },
                                    Name = "Coeurl Pup"
                                }
                            },
                            Name = "Arcanist 24"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63002,
                                    Id = 4,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 20.0
                                        }
                                    },
                                    Name = "Antelope Stag"
                                }
                            },
                            Name = "Arcanist 25"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63086,
                                    Id = 17,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = 17.1,
                                            yCoord = 28.7
                                        }
                                    },
                                    Name = "Balloon"
                                },
                                {
                                    Count = 2,
                                    Icon = 63005,
                                    Id = 301,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 22.0,
                                            yCoord = 20.0
                                        }
                                    },
                                    Name = "Chasm Buzzard"
                                }
                            },
                            Name = "Arcanist 26"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63070,
                                    Id = 281,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 25.9,
                                            yCoord = 17.7
                                        }
                                    },
                                    Name = "Axe Beak"
                                }
                            },
                            Name = "Arcanist 27"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63069,
                                    Id = 30,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = 17.9,
                                            yCoord = 28.3
                                        }
                                    },
                                    Name = "Clay Golem"
                                },
                                {
                                    Count = 2,
                                    Icon = 63069,
                                    Id = 280,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 22.0,
                                            yCoord = 11.0
                                        }
                                    },
                                    Name = "Sandstone Golem"
                                }
                            },
                            Name = "Arcanist 28"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63070,
                                    Id = 221,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 15.0,
                                            yCoord = 20.0
                                        }
                                    },
                                    Name = "Brood Ziz"
                                }
                            },
                            Name = "Arcanist 29"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63027,
                                    Id = 130,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 13.0,
                                            yCoord = 19.0
                                        }
                                    },
                                    Name = "Lindwurm"
                                }
                            },
                            Name = "Arcanist 30"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63060,
                                    Id = 351,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 32.0
                                        }
                                    },
                                    Name = "Qiqirn Gullroaster"
                                }
                            },
                            Name = "Arcanist 31"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63027,
                                    Id = 411,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 16.6,
                                            yCoord = 26.1
                                        }
                                    },
                                    Name = "Grass Raptor"
                                }
                            },
                            Name = "Arcanist 32"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63059,
                                    Id = 26,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 18.9,
                                            yCoord = 26.2
                                        }
                                    },
                                    Name = "Gigantoad"
                                }
                            },
                            Name = "Arcanist 33"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63053,
                                    Id = 264,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 25.0,
                                            yCoord = 38.0
                                        }
                                    },
                                    Name = "Sundrake"
                                }
                            },
                            Name = "Arcanist 34"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63034,
                                    Id = 639,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 30.0,
                                            yCoord = 24.0
                                        }
                                    },
                                    Name = "Colibri"
                                }
                            },
                            Name = "Arcanist 35"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63061,
                                    Id = 106,
                                    Locations = {
                                        {
                                            Map = 30,
                                            Terri = 180,
                                            Zone = 0,
                                            xCoord = 14.0,
                                            yCoord = 14.0
                                        }
                                    },
                                    Name = "Coeurl"
                                },
                                {
                                    Count = 1,
                                    Icon = 63062,
                                    Id = 355,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 17.0,
                                            yCoord = 32.0
                                        }
                                    },
                                    Name = "Mildewed Goobbue"
                                }
                            },
                            Name = "Arcanist 36"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63052,
                                    Id = 659,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 28.3,
                                            yCoord = 14.5
                                        }
                                    },
                                    Name = "Snow Wolf Pup"
                                }
                            },
                            Name = "Arcanist 37"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63108,
                                    Id = 784,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 22.0
                                        }
                                    },
                                    Name = "Feral Croc"
                                },
                                {
                                    Count = 2,
                                    Icon = 63018,
                                    Id = 25,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 25.0
                                        }
                                    },
                                    Name = "Dryad"
                                }
                            },
                            Name = "Arcanist 38"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63109,
                                    Id = 1182,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 32.5,
                                            yCoord = 12.5
                                        }
                                    },
                                    Name = "Taurus"
                                }
                            },
                            Name = "Arcanist 39"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63070,
                                    Id = 222,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 26.5,
                                            yCoord = 24.6
                                        }
                                    },
                                    Name = "Molted Ziz"
                                }
                            },
                            Name = "Arcanist 40"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63092,
                                    Id = 275,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 29.2,
                                            yCoord = 25.3
                                        }
                                    },
                                    Name = "Quartz Doblyn"
                                }
                            },
                            Name = "Arcanist 41"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63005,
                                    Id = 1853,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 12.3,
                                            yCoord = 35.7
                                        }
                                    },
                                    Name = "Lammergeyer"
                                }
                            },
                            Name = "Arcanist 42"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 2,
                                    Icon = 63118,
                                    Id = 58,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 29.0,
                                            yCoord = 21.0
                                        }
                                    },
                                    Name = "3rd Cohort Laquearius"
                                }
                            },
                            Name = "Arcanist 43"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63059,
                                    Id = 27,
                                    Locations = {
                                        {
                                            Map = 25,
                                            Terri = 156,
                                            Zone = 0,
                                            xCoord = 19.0,
                                            yCoord = 9.0
                                        }
                                    },
                                    Name = "Nix"
                                },
                                {
                                    Count = 2,
                                    Icon = 63010,
                                    Id = 645,
                                    Locations = {
                                        {
                                            Map = 25,
                                            Terri = 156,
                                            Zone = 0,
                                            xCoord = 13.0,
                                            yCoord = 11.0
                                        }
                                    },
                                    Name = "Mudpuppy"
                                }
                            },
                            Name = "Arcanist 44"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63024,
                                    Id = 15,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 31.0,
                                            yCoord = 25.0
                                        }
                                    },
                                    Name = "Wild Hog"
                                }
                            },
                            Name = "Arcanist 45"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63052,
                                    Id = 174,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = 20.5,
                                            yCoord = 18.6
                                        }
                                    },
                                    Name = "Watchwolf"
                                },
                                {
                                    Count = 2,
                                    Icon = 63118,
                                    Id = 1810,
                                    Locations = {
                                        {
                                            Map = 25,
                                            Terri = 156,
                                            Zone = 0,
                                            xCoord = 12.0,
                                            yCoord = 12.0
                                        }
                                    },
                                    Name = "5th Cohort Laquearius"
                                }
                            },
                            Name = "Arcanist 46"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63052,
                                    Id = 653,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 16.0,
                                            yCoord = 32.0
                                        }
                                    },
                                    Name = "Snow Wolf"
                                }
                            },
                            Name = "Arcanist 47"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63052,
                                    Id = 1846,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 33.0,
                                            yCoord = 20.6
                                        }
                                    },
                                    Name = "Natalan Watchwolf"
                                },
                                {
                                    Count = 2,
                                    Icon = 63010,
                                    Id = 1831,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 13.9,
                                            yCoord = 15.5
                                        }
                                    },
                                    Name = "Axolotl"
                                }
                            },
                            Name = "Arcanist 48"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63053,
                                    Id = 1841,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 29.5,
                                            yCoord = 19.5
                                        }
                                    },
                                    Name = "Zahar'ak Battle Drake"
                                }
                            },
                            Name = "Arcanist 49"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63100,
                                    Id = 1820,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 12.0,
                                            yCoord = 7.0
                                        }
                                    },
                                    Name = "4th Cohort Vanguard"
                                }
                            },
                            Name = "Arcanist 50"
                        }
                    }
                }
            },
            ["29"] = {
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63028,
                                    Id = 417,
                                    Locations = {
                                        {
                                            Map = 15,
                                            Terri = 134,
                                            Zone = 0,
                                            xCoord = 21.0,
                                            yCoord = 23.0
                                        }
                                    },
                                    Name = "Wharf Rat"
                                }
                            },
                            Name = "Rogue 01"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63074,
                                    Id = 392,
                                    Locations = {
                                        {
                                            Map = 15,
                                            Terri = 134,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 24.0
                                        }
                                    },
                                    Name = "Lost Lamb"
                                }
                            },
                            Name = "Rogue 02"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63064,
                                    Id = 563,
                                    Locations = {
                                        {
                                            Map = 16,
                                            Terri = 135,
                                            Zone = 0,
                                            xCoord = 25.2,
                                            yCoord = 26.7
                                        }
                                    },
                                    Name = "Aurelia"
                                }
                            },
                            Name = "Rogue 03"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63079,
                                    Id = 393,
                                    Locations = {
                                        {
                                            Map = 16,
                                            Terri = 135,
                                            Zone = 0,
                                            xCoord = 29.6,
                                            yCoord = 19.8
                                        }
                                    },
                                    Name = "Wild Dodo"
                                }
                            },
                            Name = "Rogue 04"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 2,
                                    Icon = 63038,
                                    Id = 640,
                                    Locations = {
                                        {
                                            Map = 15,
                                            Terri = 134,
                                            Zone = 0,
                                            xCoord = 21.5,
                                            yCoord = 22.4
                                        }
                                    },
                                    Name = "Pugil"
                                },
                                {
                                    Count = 1,
                                    Icon = 63009,
                                    Id = 367,
                                    Locations = {
                                        {
                                            Map = 15,
                                            Terri = 134,
                                            Zone = 0,
                                            xCoord = 23.6,
                                            yCoord = 21.6
                                        }
                                    },
                                    Name = "Goblin Fisher"
                                }
                            },
                            Name = "Rogue 05"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63088,
                                    Id = 405,
                                    Locations = {
                                        {
                                            Map = 15,
                                            Terri = 134,
                                            Zone = 0,
                                            xCoord = 22.0,
                                            yCoord = 18.0
                                        }
                                    },
                                    Name = "Tiny Mandragora"
                                }
                            },
                            Name = "Rogue 06"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63020,
                                    Id = 364,
                                    Locations = {
                                        {
                                            Map = 16,
                                            Terri = 135,
                                            Zone = 0,
                                            xCoord = 27.1,
                                            yCoord = 16.2
                                        }
                                    },
                                    Name = "Cave Bat"
                                }
                            },
                            Name = "Rogue 07"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63008,
                                    Id = 408,
                                    Locations = {
                                        {
                                            Map = 16,
                                            Terri = 135,
                                            Zone = 0,
                                            xCoord = 29.0,
                                            yCoord = 14.0
                                        }
                                    },
                                    Name = "Galago"
                                }
                            },
                            Name = "Rogue 08"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 1,
                                    Icon = 63045,
                                    Id = 421,
                                    Locations = {
                                        {
                                            Map = 15,
                                            Terri = 134,
                                            Zone = 0,
                                            xCoord = 20.3,
                                            yCoord = 16.9
                                        }
                                    },
                                    Name = "Grounded Pirate"
                                },
                                {
                                    Count = 1,
                                    Icon = 63045,
                                    Id = 418,
                                    Locations = {
                                        {
                                            Map = 15,
                                            Terri = 134,
                                            Zone = 0,
                                            xCoord = 20.0,
                                            yCoord = 17.0
                                        }
                                    },
                                    Name = "Grounded Raider"
                                }
                            },
                            Name = "Rogue 09"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63065,
                                    Id = 561,
                                    Locations = {
                                        {
                                            Map = 15,
                                            Terri = 134,
                                            Zone = 0,
                                            xCoord = 14.0,
                                            yCoord = 13.0
                                        }
                                    },
                                    Name = "Megalocrab"
                                }
                            },
                            Name = "Rogue 10"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63052,
                                    Id = 399,
                                    Locations = {
                                        {
                                            Map = 16,
                                            Terri = 135,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 34.0
                                        }
                                    },
                                    Name = "Wild Jackal"
                                }
                            },
                            Name = "Rogue 11"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 1,
                                    Icon = 63023,
                                    Id = 400,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 34.0,
                                            yCoord = 30.0
                                        }
                                    },
                                    Name = "Roseling"
                                },
                                {
                                    Count = 2,
                                    Icon = 63089,
                                    Id = 410,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 33.0,
                                            yCoord = 28.0
                                        }
                                    },
                                    Name = "Sewer Mole"
                                }
                            },
                            Name = "Rogue 12"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63079,
                                    Id = 394,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 32.0,
                                            yCoord = 27.0
                                        }
                                    },
                                    Name = "Fat Dodo"
                                }
                            },
                            Name = "Rogue 13"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63089,
                                    Id = 409,
                                    Locations = {
                                        {
                                            Map = 16,
                                            Terri = 135,
                                            Zone = 0,
                                            xCoord = 21.0,
                                            yCoord = 34.0
                                        }
                                    },
                                    Name = "Moraby Mole"
                                }
                            },
                            Name = "Rogue 14"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63060,
                                    Id = 350,
                                    Locations = {
                                        {
                                            Map = 16,
                                            Terri = 135,
                                            Zone = 0,
                                            xCoord = 18.0,
                                            yCoord = 35.0
                                        }
                                    },
                                    Name = "Qiqirn Eggdigger"
                                }
                            },
                            Name = "Rogue 15"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63081,
                                    Id = 401,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 28.0,
                                            yCoord = 22.0
                                        }
                                    },
                                    Name = "Puk Hatchling"
                                }
                            },
                            Name = "Rogue 16"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63070,
                                    Id = 1181,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 24.0,
                                            yCoord = 22.0
                                        }
                                    },
                                    Name = "Rothlyt Pelican"
                                }
                            },
                            Name = "Rogue 17"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 2,
                                    Icon = 63033,
                                    Id = 644,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 21.0,
                                            yCoord = 22.0
                                        }
                                    },
                                    Name = "Killer Mantis"
                                },
                                {
                                    Count = 1,
                                    Icon = 63082,
                                    Id = 403,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 23.0
                                        }
                                    },
                                    Name = "Hedgemole"
                                }
                            },
                            Name = "Rogue 18"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63052,
                                    Id = 1180,
                                    Locations = {
                                        {
                                            Map = 19,
                                            Terri = 139,
                                            Zone = 0,
                                            xCoord = 13.0,
                                            yCoord = 26.0
                                        }
                                    },
                                    Name = "Wild Wolf"
                                }
                            },
                            Name = "Rogue 19"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63021,
                                    Id = 296,
                                    Locations = {
                                        {
                                            Map = 19,
                                            Terri = 139,
                                            Zone = 0,
                                            xCoord = 12.0,
                                            yCoord = 23.0
                                        }
                                    },
                                    Name = "Bumble Beetle"
                                }
                            },
                            Name = "Rogue 20"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63020,
                                    Id = 38,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 16.6,
                                            yCoord = 23.5
                                        }
                                    },
                                    Name = "Black Bat"
                                }
                            },
                            Name = "Rogue 21"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63019,
                                    Id = 2157,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 22.0,
                                            yCoord = 30.0
                                        }
                                    },
                                    Name = "Gall Gnat"
                                }
                            },
                            Name = "Rogue 22"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63007,
                                    Id = 214,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 22.0,
                                            yCoord = 29.0
                                        }
                                    },
                                    Name = "Overgrown Ivy"
                                }
                            },
                            Name = "Rogue 23"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63010,
                                    Id = 228,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 18.1,
                                            yCoord = 24.5
                                        }
                                    },
                                    Name = "Bark Eft"
                                }
                            },
                            Name = "Rogue 24"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 2,
                                    Icon = 63042,
                                    Id = 172,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 18.0
                                        }
                                    },
                                    Name = "Redbelly Larcener"
                                },
                                {
                                    Count = 2,
                                    Icon = 63042,
                                    Id = 52,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 18.0
                                        }
                                    },
                                    Name = "Redbelly Lookout"
                                }
                            },
                            Name = "Rogue 25"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63002,
                                    Id = 4,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 26.4,
                                            yCoord = 18.6
                                        }
                                    },
                                    Name = "Antelope Stag"
                                }
                            },
                            Name = "Rogue 26"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63026,
                                    Id = 226,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 22.0
                                        }
                                    },
                                    Name = "River Yarzon"
                                }
                            },
                            Name = "Rogue 27"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 2,
                                    Icon = 63045,
                                    Id = 331,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 24.0,
                                            yCoord = 11.0
                                        }
                                    },
                                    Name = "Corpse Brigade Knuckledancer"
                                },
                                {
                                    Count = 2,
                                    Icon = 63046,
                                    Id = 332,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 24.0,
                                            yCoord = 11.0
                                        }
                                    },
                                    Name = "Corpse Brigade Firedancer"
                                }
                            },
                            Name = "Rogue 28"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 2,
                                    Icon = 63042,
                                    Id = 169,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 28.8,
                                            yCoord = 21.7
                                        }
                                    },
                                    Name = "Coeurlclaw Cutter"
                                },
                                {
                                    Count = 2,
                                    Icon = 63030,
                                    Id = 139,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 28.8,
                                            yCoord = 21.7
                                        }
                                    },
                                    Name = "Coeurlclaw Hunter"
                                }
                            },
                            Name = "Rogue 29"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63069,
                                    Id = 280,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 22.0,
                                            yCoord = 12.0
                                        }
                                    },
                                    Name = "Sandstone Golem"
                                }
                            },
                            Name = "Rogue 30"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63063,
                                    Id = 1313,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 28.0,
                                            yCoord = 30.0
                                        }
                                    },
                                    Name = "Large Buffalo"
                                }
                            },
                            Name = "Rogue 31"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63027,
                                    Id = 411,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 16.6,
                                            yCoord = 26.1
                                        }
                                    },
                                    Name = "Grass Raptor"
                                }
                            },
                            Name = "Rogue 32"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 2,
                                    Icon = 63060,
                                    Id = 351,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 27.0,
                                            yCoord = 33.0
                                        }
                                    },
                                    Name = "Qiqirn Gullroaster"
                                },
                                {
                                    Count = 2,
                                    Icon = 63034,
                                    Id = 639,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 31.0,
                                            yCoord = 24.0
                                        }
                                    },
                                    Name = "Colibri"
                                }
                            },
                            Name = "Rogue 33"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 1,
                                    Icon = 63061,
                                    Id = 106,
                                    Locations = {
                                        {
                                            Map = 30,
                                            Terri = 180,
                                            Zone = 0,
                                            xCoord = 14.0,
                                            yCoord = 14.0
                                        }
                                    },
                                    Name = "Coeurl"
                                },
                                {
                                    Count = 2,
                                    Icon = 63005,
                                    Id = 398,
                                    Locations = {
                                        {
                                            Map = 30,
                                            Terri = 180,
                                            Zone = 0,
                                            xCoord = 17.0,
                                            yCoord = 16.0
                                        }
                                    },
                                    Name = "Highland Condor"
                                }
                            },
                            Name = "Rogue 34"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63069,
                                    Id = 365,
                                    Locations = {
                                        {
                                            Map = 30,
                                            Terri = 180,
                                            Zone = 0,
                                            xCoord = 13.6,
                                            yCoord = 15.1
                                        }
                                    },
                                    Name = "Basalt Golem"
                                }
                            },
                            Name = "Rogue 35"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63027,
                                    Id = 412,
                                    Locations = {
                                        {
                                            Map = 30,
                                            Terri = 180,
                                            Zone = 0,
                                            xCoord = 19.0,
                                            yCoord = 15.0
                                        }
                                    },
                                    Name = "Velociraptor"
                                }
                            },
                            Name = "Rogue 36"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 2,
                                    Icon = 63062,
                                    Id = 1612,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 25.0,
                                            yCoord = 20.0
                                        }
                                    },
                                    Name = "Highland Goobbue"
                                },
                                {
                                    Count = 2,
                                    Icon = 63108,
                                    Id = 784,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 22.0
                                        }
                                    },
                                    Name = "Feral Croc"
                                }
                            },
                            Name = "Rogue 37"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63058,
                                    Id = 794,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 12.0
                                        }
                                    },
                                    Name = "Redhorn Ogre"
                                }
                            },
                            Name = "Rogue 38"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63109,
                                    Id = 1182,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 32.5,
                                            yCoord = 12.5
                                        }
                                    },
                                    Name = "Taurus"
                                }
                            },
                            Name = "Rogue 39"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 2,
                                    Icon = 63028,
                                    Id = 2156,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 15.0,
                                            yCoord = 20.0
                                        }
                                    },
                                    Name = "Chinchilla"
                                },
                                {
                                    Count = 2,
                                    Icon = 63005,
                                    Id = 1183,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 18.0,
                                            yCoord = 18.0
                                        }
                                    },
                                    Name = "Bateleur"
                                }
                            },
                            Name = "Rogue 40"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63068,
                                    Id = 271,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 25.0
                                        }
                                    },
                                    Name = "Golden Fleece"
                                }
                            },
                            Name = "Rogue 41"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63092,
                                    Id = 275,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 30.0,
                                            yCoord = 25.0
                                        }
                                    },
                                    Name = "Quartz Doblyn"
                                }
                            },
                            Name = "Rogue 42"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63059,
                                    Id = 27,
                                    Locations = {
                                        {
                                            Map = 25,
                                            Terri = 156,
                                            Zone = 0,
                                            xCoord = 19.0,
                                            yCoord = 9.0
                                        }
                                    },
                                    Name = "Nix"
                                }
                            },
                            Name = "Rogue 43"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63010,
                                    Id = 645,
                                    Locations = {
                                        {
                                            Map = 25,
                                            Terri = 156,
                                            Zone = 0,
                                            xCoord = 13.0,
                                            yCoord = 11.0
                                        }
                                    },
                                    Name = "Mudpuppy"
                                }
                            },
                            Name = "Rogue 44"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 2,
                                    Icon = 63014,
                                    Id = 650,
                                    Locations = {
                                        {
                                            Map = 25,
                                            Terri = 156,
                                            Zone = 0,
                                            xCoord = 17.0,
                                            yCoord = 16.0
                                        }
                                    },
                                    Name = "Daring Harrier"
                                },
                                {
                                    Count = 2,
                                    Icon = 63014,
                                    Id = 651,
                                    Locations = {
                                        {
                                            Map = 25,
                                            Terri = 156,
                                            Zone = 0,
                                            xCoord = 17.0,
                                            yCoord = 16.0
                                        }
                                    },
                                    Name = "Raging Harrier"
                                }
                            },
                            Name = "Rogue 45"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 2,
                                    Icon = 63107,
                                    Id = 647,
                                    Locations = {
                                        {
                                            Map = 25,
                                            Terri = 156,
                                            Zone = 0,
                                            xCoord = 27.0,
                                            yCoord = 11.0
                                        }
                                    },
                                    Name = "Gigas Shramana"
                                },
                                {
                                    Count = 2,
                                    Icon = 63107,
                                    Id = 648,
                                    Locations = {
                                        {
                                            Map = 25,
                                            Terri = 156,
                                            Zone = 0,
                                            xCoord = 27.0,
                                            yCoord = 11.0
                                        }
                                    },
                                    Name = "Gigas Sozu"
                                }
                            },
                            Name = "Rogue 46"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63067,
                                    Id = 789,
                                    Locations = {
                                        {
                                            Map = 25,
                                            Terri = 156,
                                            Zone = 0,
                                            xCoord = 27.0,
                                            yCoord = 8.0
                                        }
                                    },
                                    Name = "Hippogryph"
                                }
                            },
                            Name = "Rogue 47"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63058,
                                    Id = 793,
                                    Locations = {
                                        {
                                            Map = 25,
                                            Terri = 156,
                                            Zone = 0,
                                            xCoord = 31.0,
                                            yCoord = 5.0
                                        }
                                    },
                                    Name = "Hapalit"
                                }
                            },
                            Name = "Rogue 48"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 2,
                                    Icon = 63118,
                                    Id = 1823,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 29.0,
                                            yCoord = 20.0
                                        }
                                    },
                                    Name = "2nd Cohort Eques"
                                },
                                {
                                    Count = 2,
                                    Icon = 63118,
                                    Id = 1825,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 29.0,
                                            yCoord = 20.0
                                        }
                                    },
                                    Name = "2nd Cohort Signifer"
                                }
                            },
                            Name = "Rogue 49"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 2,
                                    Icon = 63118,
                                    Id = 1824,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 30.0,
                                            yCoord = 19.0
                                        }
                                    },
                                    Name = "2nd Cohort Secutor"
                                },
                                {
                                    Count = 2,
                                    Icon = 63100,
                                    Id = 1826,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 30.0,
                                            yCoord = 19.0
                                        }
                                    },
                                    Name = "2nd Cohort Vanguard"
                                }
                            },
                            Name = "Rogue 50"
                        }
                    }
                }
            },
            ["3"] = {
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63036,
                                    Id = 49,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 267.96899414063,
                                            yCoord = 54.97074508667,
                                            zCoord = 124.23870849609
                                        }
                                    },
                                    Name = "Little Ladybug"
                                }
                            },
                            Name = "Marauder 01"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63028,
                                    Id = 417,
                                    Locations = {
                                        {
                                            Map = 15,
                                            Terri = 134,
                                            Zone = 0,
                                            xCoord = 21.0,
                                            yCoord = 23.0
                                        }
                                    },
                                    Name = "Wharf Rat"
                                }
                            },
                            Name = "Marauder 02"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63064,
                                    Id = 563,
                                    Locations = {
                                        {
                                            Map = 16,
                                            Terri = 135,
                                            Zone = 0,
                                            xCoord = 25.2,
                                            yCoord = 26.7
                                        }
                                    },
                                    Name = "Aurelia"
                                }
                            },
                            Name = "Marauder 03"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63012,
                                    Id = 395,
                                    Locations = {
                                        {
                                            Map = 15,
                                            Terri = 134,
                                            Zone = 0,
                                            xCoord = 18.0,
                                            yCoord = 18.0
                                        }
                                    },
                                    Name = "Bee Cloud"
                                }
                            },
                            Name = "Marauder 04"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63079,
                                    Id = 393,
                                    Locations = {
                                        {
                                            Map = 16,
                                            Terri = 135,
                                            Zone = 0,
                                            xCoord = 29.6,
                                            yCoord = 19.8
                                        }
                                    },
                                    Name = "Wild Dodo"
                                }
                            },
                            Name = "Marauder 05"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63088,
                                    Id = 405,
                                    Locations = {
                                        {
                                            Map = 15,
                                            Terri = 134,
                                            Zone = 0,
                                            xCoord = 22.0,
                                            yCoord = 18.0
                                        }
                                    },
                                    Name = "Tiny Mandragora"
                                }
                            },
                            Name = "Marauder 06"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63084,
                                    Id = 404,
                                    Locations = {
                                        {
                                            Map = 15,
                                            Terri = 134,
                                            Zone = 0,
                                            xCoord = 20.0,
                                            yCoord = 19.0
                                        }
                                    },
                                    Name = "Bogy"
                                }
                            },
                            Name = "Marauder 07"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63063,
                                    Id = 358,
                                    Locations = {
                                        {
                                            Map = 15,
                                            Terri = 134,
                                            Zone = 0,
                                            xCoord = 18.0,
                                            yCoord = 17.0
                                        }
                                    },
                                    Name = "Wounded Aurochs"
                                }
                            },
                            Name = "Marauder 08"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63045,
                                    Id = 418,
                                    Locations = {
                                        {
                                            Map = 15,
                                            Terri = 134,
                                            Zone = 0,
                                            xCoord = 20.0,
                                            yCoord = 17.0
                                        }
                                    },
                                    Name = "Grounded Raider"
                                }
                            },
                            Name = "Marauder 09"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63065,
                                    Id = 561,
                                    Locations = {
                                        {
                                            Map = 15,
                                            Terri = 134,
                                            Zone = 0,
                                            xCoord = 14.0,
                                            yCoord = 13.0
                                        }
                                    },
                                    Name = "Megalocrab"
                                }
                            },
                            Name = "Marauder 10"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63011,
                                    Id = 129,
                                    Locations = {
                                        {
                                            Map = 16,
                                            Terri = 135,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 37.0
                                        },
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 19.0,
                                            yCoord = 27.0
                                        }
                                    },
                                    Name = "Firefly"
                                }
                            },
                            Name = "Marauder 11"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63062,
                                    Id = 354,
                                    Locations = {
                                        {
                                            Map = 16,
                                            Terri = 135,
                                            Zone = 0,
                                            xCoord = 22.0,
                                            yCoord = 24.0
                                        }
                                    },
                                    Name = "Mossless Goobbue"
                                }
                            },
                            Name = "Marauder 12"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63079,
                                    Id = 394,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 32.0,
                                            yCoord = 27.0
                                        }
                                    },
                                    Name = "Fat Dodo"
                                }
                            },
                            Name = "Marauder 13"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63089,
                                    Id = 409,
                                    Locations = {
                                        {
                                            Map = 16,
                                            Terri = 135,
                                            Zone = 0,
                                            xCoord = 21.0,
                                            yCoord = 34.0
                                        }
                                    },
                                    Name = "Moraby Mole"
                                }
                            },
                            Name = "Marauder 14"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63060,
                                    Id = 350,
                                    Locations = {
                                        {
                                            Map = 16,
                                            Terri = 135,
                                            Zone = 0,
                                            xCoord = 18.0,
                                            yCoord = 35.0
                                        }
                                    },
                                    Name = "Qiqirn Eggdigger"
                                }
                            },
                            Name = "Marauder 15"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63045,
                                    Id = 420,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 33.0,
                                            yCoord = 27.0
                                        }
                                    },
                                    Name = "Rhotano Buccaneer"
                                }
                            },
                            Name = "Marauder 16"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63020,
                                    Id = 363,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 28.0,
                                            yCoord = 24.0
                                        }
                                    },
                                    Name = "Dusk Bat"
                                },
                                {
                                    Count = 3,
                                    Icon = 63081,
                                    Id = 401,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 28.0,
                                            yCoord = 24.0
                                        }
                                    },
                                    Name = "Puk Hatchling"
                                },
                                {
                                    Count = 2,
                                    Icon = 63082,
                                    Id = 403,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 23.0
                                        }
                                    },
                                    Name = "Hedgemole"
                                }
                            },
                            Name = "Marauder 17"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63070,
                                    Id = 1181,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 24.0,
                                            yCoord = 22.0
                                        }
                                    },
                                    Name = "Rothlyt Pelican"
                                }
                            },
                            Name = "Marauder 18"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63033,
                                    Id = 644,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 21.0,
                                            yCoord = 22.0
                                        }
                                    },
                                    Name = "Killer Mantis"
                                }
                            },
                            Name = "Marauder 19"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63052,
                                    Id = 1180,
                                    Locations = {
                                        {
                                            Map = 19,
                                            Terri = 139,
                                            Zone = 0,
                                            xCoord = 13.0,
                                            yCoord = 26.0
                                        }
                                    },
                                    Name = "Wild Wolf"
                                }
                            },
                            Name = "Marauder 20"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63032,
                                    Id = 638,
                                    Locations = {
                                        {
                                            Map = 19,
                                            Terri = 139,
                                            Zone = 0,
                                            xCoord = 14.0,
                                            yCoord = 24.5
                                        }
                                    },
                                    Name = "Stoneshell"
                                }
                            },
                            Name = "Marauder 21"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63018,
                                    Id = 232,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 17.0,
                                            yCoord = 23.0
                                        }
                                    },
                                    Name = "Diseased Treant"
                                }
                            },
                            Name = "Marauder 22"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63026,
                                    Id = 227,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 14.1,
                                            yCoord = 8.9
                                        }
                                    },
                                    Name = "Yarzon Scavenger"
                                }
                            },
                            Name = "Marauder 23"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63042,
                                    Id = 172,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 19.0
                                        }
                                    },
                                    Name = "Redbelly Larcener"
                                }
                            },
                            Name = "Marauder 24"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63013,
                                    Id = 40,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = 17.0,
                                            yCoord = 27.0
                                        }
                                    },
                                    Name = "Shroud Hare"
                                }
                            },
                            Name = "Marauder 25"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63073,
                                    Id = 286,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 17.1,
                                            yCoord = 15.7
                                        }
                                    },
                                    Name = "Sabotender"
                                }
                            },
                            Name = "Marauder 26"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63086,
                                    Id = 17,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = 17.1,
                                            yCoord = 28.7
                                        }
                                    },
                                    Name = "Balloon"
                                },
                                {
                                    Count = 3,
                                    Icon = 63068,
                                    Id = 272,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 22.0,
                                            yCoord = 21.0
                                        }
                                    },
                                    Name = "Phurble"
                                },
                                {
                                    Count = 2,
                                    Icon = 63080,
                                    Id = 303,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 19.0,
                                            yCoord = 10.0
                                        }
                                    },
                                    Name = "Sandskin Peiste"
                                }
                            },
                            Name = "Marauder 27"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63070,
                                    Id = 281,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 27.0,
                                            yCoord = 17.0
                                        }
                                    },
                                    Name = "Axe Beak"
                                }
                            },
                            Name = "Marauder 28"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63022,
                                    Id = 48,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 14.0,
                                            yCoord = 17.0
                                        }
                                    },
                                    Name = "Toadstool"
                                }
                            },
                            Name = "Marauder 29"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63049,
                                    Id = 207,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 11.0,
                                            yCoord = 23.0
                                        }
                                    },
                                    Name = "Floating Eye"
                                }
                            },
                            Name = "Marauder 30"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63090,
                                    Id = 238,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 13.0,
                                            yCoord = 22.0
                                        }
                                    },
                                    Name = "Stroper"
                                }
                            },
                            Name = "Marauder 31"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63001,
                                    Id = 34,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 15.0,
                                            yCoord = 29.0
                                        }
                                    },
                                    Name = "Adamantoise"
                                },
                                {
                                    Count = 3,
                                    Icon = 63086,
                                    Id = 132,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 19.0,
                                            yCoord = 34.0
                                        }
                                    },
                                    Name = "Smoke Bomb"
                                },
                                {
                                    Count = 2,
                                    Icon = 63027,
                                    Id = 411,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 16.6,
                                            yCoord = 26.1
                                        }
                                    },
                                    Name = "Grass Raptor"
                                }
                            },
                            Name = "Marauder 32"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63065,
                                    Id = 560,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 31.0,
                                            yCoord = 35.0
                                        }
                                    },
                                    Name = "Snipper"
                                }
                            },
                            Name = "Marauder 33"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63064,
                                    Id = 361,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 31.0,
                                            yCoord = 26.0
                                        }
                                    },
                                    Name = "Bloodshore Bell"
                                }
                            },
                            Name = "Marauder 34"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63061,
                                    Id = 352,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 18.0,
                                            yCoord = 28.0
                                        }
                                    },
                                    Name = "Jungle Coeurl"
                                }
                            },
                            Name = "Marauder 35"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63052,
                                    Id = 659,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 28.3,
                                            yCoord = 14.5
                                        }
                                    },
                                    Name = "Snow Wolf Pup"
                                }
                            },
                            Name = "Marauder 36"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63074,
                                    Id = 795,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 25.0,
                                            yCoord = 19.0
                                        }
                                    },
                                    Name = "Ornery Karakul"
                                },
                                {
                                    Count = 3,
                                    Icon = 63062,
                                    Id = 1612,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 25.0,
                                            yCoord = 19.0
                                        }
                                    },
                                    Name = "Highland Goobbue"
                                },
                                {
                                    Count = 2,
                                    Icon = 63058,
                                    Id = 794,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 24.0,
                                            yCoord = 13.0
                                        }
                                    },
                                    Name = "Redhorn Ogre"
                                }
                            },
                            Name = "Marauder 37"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63105,
                                    Id = 1849,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 10.0
                                        }
                                    },
                                    Name = "Downy Aevis"
                                }
                            },
                            Name = "Marauder 38"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63062,
                                    Id = 1611,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 19.0,
                                            yCoord = 17.0
                                        }
                                    },
                                    Name = "Snowstorm Goobbue"
                                }
                            },
                            Name = "Marauder 39"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63086,
                                    Id = 270,
                                    Locations = {
                                        {
                                            Map = 30,
                                            Terri = 180,
                                            Zone = 0,
                                            xCoord = 22.5,
                                            yCoord = 13.5
                                        }
                                    },
                                    Name = "Grenade"
                                }
                            },
                            Name = "Marauder 40"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63070,
                                    Id = 222,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 26.5,
                                            yCoord = 24.6
                                        }
                                    },
                                    Name = "Molted Ziz"
                                }
                            },
                            Name = "Marauder 41"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63092,
                                    Id = 275,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 31.0,
                                            yCoord = 26.0
                                        }
                                    },
                                    Name = "Quartz Doblyn"
                                },
                                {
                                    Count = 3,
                                    Icon = 63029,
                                    Id = 1854,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 15.0,
                                            yCoord = 35.0
                                        }
                                    },
                                    Name = "Dead Man's Moan"
                                },
                                {
                                    Count = 2,
                                    Icon = 63090,
                                    Id = 237,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 21.0
                                        }
                                    },
                                    Name = "Morbol"
                                }
                            },
                            Name = "Marauder 42"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 1,
                                    Icon = 63069,
                                    Id = 131,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 11.0,
                                            yCoord = 17.0
                                        }
                                    },
                                    Name = "Crater Golem"
                                }
                            },
                            Name = "Marauder 43"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63024,
                                    Id = 15,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 31.0,
                                            yCoord = 25.0
                                        }
                                    },
                                    Name = "Wild Hog"
                                }
                            },
                            Name = "Marauder 44"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63053,
                                    Id = 788,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 16.0,
                                            yCoord = 30.0
                                        }
                                    },
                                    Name = "Biast"
                                }
                            },
                            Name = "Marauder 45"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63118,
                                    Id = 1813,
                                    Locations = {
                                        {
                                            Map = 25,
                                            Terri = 156,
                                            Zone = 0,
                                            xCoord = 9.0,
                                            yCoord = 14.0
                                        }
                                    },
                                    Name = "5th Cohort Signifer"
                                }
                            },
                            Name = "Marauder 46"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63092,
                                    Id = 1836,
                                    Locations = {
                                        {
                                            Map = 30,
                                            Terri = 180,
                                            Zone = 0,
                                            xCoord = 22.0,
                                            yCoord = 6.0
                                        }
                                    },
                                    Name = "Synthetic Doblyn"
                                },
                                {
                                    Count = 3,
                                    Icon = 63052,
                                    Id = 174,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = 20.5,
                                            yCoord = 18.6
                                        }
                                    },
                                    Name = "Watchwolf"
                                },
                                {
                                    Count = 2,
                                    Icon = 63001,
                                    Id = 243,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 19.0,
                                            yCoord = 23.0
                                        }
                                    },
                                    Name = "Iron Tortoise"
                                }
                            },
                            Name = "Marauder 47"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63007,
                                    Id = 165,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 24.0,
                                            yCoord = 17.0
                                        }
                                    },
                                    Name = "Milkroot Cluster"
                                }
                            },
                            Name = "Marauder 48"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63118,
                                    Id = 1818,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 10.0,
                                            yCoord = 6.0
                                        }
                                    },
                                    Name = "4th Cohort Secutor"
                                }
                            },
                            Name = "Marauder 49"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63118,
                                    Id = 1822,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 28.0,
                                            yCoord = 21.0
                                        }
                                    },
                                    Name = "2nd Cohort Laquearius"
                                }
                            },
                            Name = "Marauder 50"
                        }
                    }
                }
            },
            ["4"] = {
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63036,
                                    Id = 49,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 267.96899414063,
                                            yCoord = 54.97074508667,
                                            zCoord = 124.23870849609
                                        }
                                    },
                                    Name = "Little Ladybug"
                                }
                            },
                            Name = "Lancer 01"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63028,
                                    Id = 37,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 22.0,
                                            yCoord = 17.0
                                        }
                                    },
                                    Name = "Ground Squirrel"
                                }
                            },
                            Name = "Lancer 02"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63022,
                                    Id = 47,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 25.0,
                                            yCoord = 19.0
                                        }
                                    },
                                    Name = "Forest Funguar"
                                }
                            },
                            Name = "Lancer 03"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63015,
                                    Id = 9,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 26.0
                                        }
                                    },
                                    Name = "Miteling"
                                }
                            },
                            Name = "Lancer 04"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63008,
                                    Id = 5,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = 27.0,
                                            yCoord = 24.0
                                        }
                                    },
                                    Name = "Opo-opo"
                                }
                            },
                            Name = "Lancer 05"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63007,
                                    Id = 32,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 22.0
                                        }
                                    },
                                    Name = "Microchu"
                                }
                            },
                            Name = "Lancer 06"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63010,
                                    Id = 196,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 20.0
                                        }
                                    },
                                    Name = "Black Eft"
                                },
                                {
                                    Count = 3,
                                    Icon = 63026,
                                    Id = 197,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 24.0,
                                            yCoord = 24.0
                                        }
                                    },
                                    Name = "Bog Yarzon"
                                }
                            },
                            Name = "Lancer 07"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63024,
                                    Id = 195,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 30.0,
                                            yCoord = 23.0
                                        }
                                    },
                                    Name = "Hoglet"
                                }
                            },
                            Name = "Lancer 08"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63027,
                                    Id = 120,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 31.0,
                                            yCoord = 20.0
                                        }
                                    },
                                    Name = "Anole"
                                },
                                {
                                    Count = 3,
                                    Icon = 63015,
                                    Id = 10,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 18.0,
                                            yCoord = 19.0
                                        }
                                    },
                                    Name = "Diremite"
                                }
                            },
                            Name = "Lancer 09"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63013,
                                    Id = 39,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 13.0,
                                            yCoord = 26.0
                                        }
                                    },
                                    Name = "Tree Slug"
                                }
                            },
                            Name = "Lancer 10"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63005,
                                    Id = 13,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 30.0
                                        },
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 17.0,
                                            yCoord = 16.0
                                        },
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 31.6,
                                            yCoord = 29.7
                                        }
                                    },
                                    Name = "Arbor Buzzard"
                                }
                            },
                            Name = "Lancer 11"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63018,
                                    Id = 128,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 27.5,
                                            yCoord = 15.5
                                        }
                                    },
                                    Name = "Treant Sapling"
                                }
                            },
                            Name = "Lancer 12"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63088,
                                    Id = 107,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 14.0,
                                            yCoord = 25.0
                                        }
                                    },
                                    Name = "Mandragora"
                                }
                            },
                            Name = "Lancer 13"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63024,
                                    Id = 14,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 13.0,
                                            yCoord = 23.0
                                        }
                                    },
                                    Name = "Wild Hoglet"
                                }
                            },
                            Name = "Lancer 14"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63008,
                                    Id = 6,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 15.0,
                                            yCoord = 27.0
                                        }
                                    },
                                    Name = "Lemur"
                                },
                                {
                                    Count = 3,
                                    Icon = 63021,
                                    Id = 36,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 15.0,
                                            yCoord = 27.0
                                        }
                                    },
                                    Name = "Boring Weevil"
                                }
                            },
                            Name = "Lancer 15"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63022,
                                    Id = 220,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 19.0,
                                            yCoord = 28.5
                                        }
                                    },
                                    Name = "Faerie Funguar"
                                }
                            },
                            Name = "Lancer 16"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63019,
                                    Id = 7,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 19.0,
                                            yCoord = 27.0
                                        }
                                    },
                                    Name = "Giant Gnat"
                                },
                                {
                                    Count = 3,
                                    Icon = 63030,
                                    Id = 240,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 19.0,
                                            yCoord = 30.0
                                        }
                                    },
                                    Name = "Boar Poacher"
                                }
                            },
                            Name = "Lancer 17"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63070,
                                    Id = 223,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 20.0,
                                            yCoord = 25.0
                                        }
                                    },
                                    Name = "Ziz Gorlin"
                                }
                            },
                            Name = "Lancer 18"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63060,
                                    Id = 219,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 15.6,
                                            yCoord = 17.8
                                        }
                                    },
                                    Name = "Qiqirn Beater"
                                },
                                {
                                    Count = 3,
                                    Icon = 63020,
                                    Id = 38,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 16.6,
                                            yCoord = 23.5
                                        }
                                    },
                                    Name = "Black Bat"
                                }
                            },
                            Name = "Lancer 19"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63002,
                                    Id = 3,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 18.0,
                                            yCoord = 22.0
                                        }
                                    },
                                    Name = "Antelope Doe"
                                }
                            },
                            Name = "Lancer 20"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63032,
                                    Id = 638,
                                    Locations = {
                                        {
                                            Map = 19,
                                            Terri = 139,
                                            Zone = 0,
                                            xCoord = 14.0,
                                            yCoord = 24.5
                                        }
                                    },
                                    Name = "Stoneshell"
                                }
                            },
                            Name = "Lancer 21"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63083,
                                    Id = 234,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 16.0,
                                            yCoord = 18.0
                                        }
                                    },
                                    Name = "Smallmouth Orobon"
                                }
                            },
                            Name = "Lancer 22"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63026,
                                    Id = 227,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 14.1,
                                            yCoord = 8.9
                                        }
                                    },
                                    Name = "Yarzon Scavenger"
                                }
                            },
                            Name = "Lancer 23"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63042,
                                    Id = 52,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 24.0,
                                            yCoord = 18.0
                                        }
                                    },
                                    Name = "Redbelly Lookout"
                                }
                            },
                            Name = "Lancer 24"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63039,
                                    Id = 314,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 17.0,
                                            yCoord = 6.0
                                        }
                                    },
                                    Name = "Moondrip Piledriver"
                                },
                                {
                                    Count = 4,
                                    Icon = 63002,
                                    Id = 4,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 20.0
                                        }
                                    },
                                    Name = "Antelope Stag"
                                }
                            },
                            Name = "Lancer 25"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63073,
                                    Id = 286,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 17.1,
                                            yCoord = 15.7
                                        }
                                    },
                                    Name = "Sabotender"
                                }
                            },
                            Name = "Lancer 26"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63080,
                                    Id = 303,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 15.0,
                                            yCoord = 13.0
                                        }
                                    },
                                    Name = "Sandskin Peiste"
                                },
                                {
                                    Count = 3,
                                    Icon = 63009,
                                    Id = 50,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 27.8,
                                            yCoord = 21.1
                                        }
                                    },
                                    Name = "Goblin Thug"
                                }
                            },
                            Name = "Lancer 27"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63046,
                                    Id = 332,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 24.0,
                                            yCoord = 9.0
                                        }
                                    },
                                    Name = "Corpse Brigade Firedancer"
                                }
                            },
                            Name = "Lancer 28"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63044,
                                    Id = 140,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 30.2,
                                            yCoord = 20.7
                                        }
                                    },
                                    Name = "Coeurlclaw Poacher"
                                },
                                {
                                    Count = 3,
                                    Icon = 63050,
                                    Id = 341,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 30.0,
                                            yCoord = 35.0
                                        }
                                    },
                                    Name = "Apkallu"
                                }
                            },
                            Name = "Lancer 29"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63005,
                                    Id = 566,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 17.0,
                                            yCoord = 26.0
                                        }
                                    },
                                    Name = "Midland Condor"
                                }
                            },
                            Name = "Lancer 30"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63049,
                                    Id = 207,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 11.0,
                                            yCoord = 23.0
                                        }
                                    },
                                    Name = "Floating Eye"
                                }
                            },
                            Name = "Lancer 31"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63063,
                                    Id = 1313,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 28.0,
                                            yCoord = 30.0
                                        }
                                    },
                                    Name = "Large Buffalo"
                                }
                            },
                            Name = "Lancer 32"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63053,
                                    Id = 264,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 25.0,
                                            yCoord = 38.0
                                        }
                                    },
                                    Name = "Sundrake"
                                },
                                {
                                    Count = 3,
                                    Icon = 63086,
                                    Id = 132,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 19.0,
                                            yCoord = 34.0
                                        }
                                    },
                                    Name = "Smoke Bomb"
                                }
                            },
                            Name = "Lancer 33"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63087,
                                    Id = 91,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 12.0,
                                            yCoord = 16.0
                                        }
                                    },
                                    Name = "Spriggan"
                                }
                            },
                            Name = "Lancer 34"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63008,
                                    Id = 407,
                                    Locations = {
                                        {
                                            Map = 30,
                                            Terri = 180,
                                            Zone = 0,
                                            xCoord = 15.1,
                                            yCoord = 12.4
                                        }
                                    },
                                    Name = "Ringtail"
                                },
                                {
                                    Count = 3,
                                    Icon = 63069,
                                    Id = 365,
                                    Locations = {
                                        {
                                            Map = 30,
                                            Terri = 180,
                                            Zone = 0,
                                            xCoord = 13.6,
                                            yCoord = 15.1
                                        }
                                    },
                                    Name = "Basalt Golem"
                                }
                            },
                            Name = "Lancer 35"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63074,
                                    Id = 795,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 25.0,
                                            yCoord = 19.0
                                        }
                                    },
                                    Name = "Ornery Karakul"
                                }
                            },
                            Name = "Lancer 36"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63052,
                                    Id = 659,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 28.3,
                                            yCoord = 14.5
                                        }
                                    },
                                    Name = "Snow Wolf Pup"
                                },
                                {
                                    Count = 3,
                                    Icon = 63020,
                                    Id = 112,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 22.5,
                                            yCoord = 26.0
                                        }
                                    },
                                    Name = "Lesser Kalong"
                                }
                            },
                            Name = "Lancer 37"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63018,
                                    Id = 25,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = 22.0,
                                            yCoord = 23.0
                                        }
                                    },
                                    Name = "Dryad"
                                }
                            },
                            Name = "Lancer 38"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63105,
                                    Id = 1849,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 10.0
                                        }
                                    },
                                    Name = "Downy Aevis"
                                },
                                {
                                    Count = 3,
                                    Icon = 63005,
                                    Id = 1183,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 18.0,
                                            yCoord = 18.0
                                        }
                                    },
                                    Name = "Bateleur"
                                }
                            },
                            Name = "Lancer 39"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63040,
                                    Id = 634,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 28.0,
                                            yCoord = 24.0
                                        }
                                    },
                                    Name = "Mirrorknight"
                                }
                            },
                            Name = "Lancer 40"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63037,
                                    Id = 637,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 9.0,
                                            yCoord = 14.0
                                        }
                                    },
                                    Name = "Dragonfly"
                                },
                                {
                                    Count = 4,
                                    Icon = 63108,
                                    Id = 1850,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 4.0,
                                            yCoord = 21.5
                                        }
                                    },
                                    Name = "Baritine Croc"
                                }
                            },
                            Name = "Lancer 41"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63029,
                                    Id = 1854,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 15.0,
                                            yCoord = 35.0
                                        }
                                    },
                                    Name = "Dead Man's Moan"
                                }
                            },
                            Name = "Lancer 42"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63090,
                                    Id = 237,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 21.0
                                        }
                                    },
                                    Name = "Morbol"
                                },
                                {
                                    Count = 2,
                                    Icon = 63118,
                                    Id = 61,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 32.5,
                                            yCoord = 20.5
                                        }
                                    },
                                    Name = "3rd Cohort Signifer"
                                }
                            },
                            Name = "Lancer 43"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63024,
                                    Id = 15,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 31.0,
                                            yCoord = 25.0
                                        }
                                    },
                                    Name = "Wild Hog"
                                }
                            },
                            Name = "Lancer 44"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63014,
                                    Id = 650,
                                    Locations = {
                                        {
                                            Map = 25,
                                            Terri = 156,
                                            Zone = 0,
                                            xCoord = 17.0,
                                            yCoord = 16.0
                                        }
                                    },
                                    Name = "Daring Harrier"
                                },
                                {
                                    Count = 5,
                                    Icon = 63041,
                                    Id = 1851,
                                    Locations = {
                                        {
                                            Map = 25,
                                            Terri = 156,
                                            Zone = 0,
                                            xCoord = 25.0,
                                            yCoord = 12.0
                                        }
                                    },
                                    Name = "Lake Cobra"
                                }
                            },
                            Name = "Lancer 45"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63052,
                                    Id = 653,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 16.0,
                                            yCoord = 32.0
                                        }
                                    },
                                    Name = "Snow Wolf"
                                }
                            },
                            Name = "Lancer 46"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63064,
                                    Id = 360,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 14.0,
                                            yCoord = 17.0
                                        }
                                    },
                                    Name = "Sea Wasp"
                                },
                                {
                                    Count = 4,
                                    Icon = 63100,
                                    Id = 1814,
                                    Locations = {
                                        {
                                            Map = 25,
                                            Terri = 156,
                                            Zone = 0,
                                            xCoord = 10.0,
                                            yCoord = 13.0
                                        }
                                    },
                                    Name = "5th Cohort Vanguard"
                                }
                            },
                            Name = "Lancer 47"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63052,
                                    Id = 1846,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 33.0,
                                            yCoord = 20.6
                                        }
                                    },
                                    Name = "Natalan Watchwolf"
                                }
                            },
                            Name = "Lancer 48"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63018,
                                    Id = 163,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 24.0,
                                            yCoord = 11.0
                                        }
                                    },
                                    Name = "Sylphlands Sentinel"
                                },
                                {
                                    Count = 4,
                                    Icon = 63080,
                                    Id = 304,
                                    Locations = {
                                        {
                                            Map = 24,
                                            Terri = 147,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 23.0
                                        }
                                    },
                                    Name = "Basilisk"
                                }
                            },
                            Name = "Lancer 49"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63118,
                                    Id = 1823,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 30.0,
                                            yCoord = 21.0
                                        }
                                    },
                                    Name = "2nd Cohort Eques"
                                }
                            },
                            Name = "Lancer 50"
                        }
                    }
                }
            },
            ["5"] = {
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63036,
                                    Id = 49,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 267.96899414063,
                                            yCoord = 54.97074508667,
                                            zCoord = 124.23870849609
                                        }
                                    },
                                    Name = "Little Ladybug"
                                }
                            },
                            Name = "Archer 01"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63028,
                                    Id = 37,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 22.0,
                                            yCoord = 17.0
                                        }
                                    },
                                    Name = "Ground Squirrel"
                                }
                            },
                            Name = "Archer 02"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63022,
                                    Id = 47,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 24.0,
                                            yCoord = 18.0
                                        }
                                    },
                                    Name = "Forest Funguar"
                                }
                            },
                            Name = "Archer 03"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63015,
                                    Id = 9,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = 25.0,
                                            yCoord = 27.0
                                        }
                                    },
                                    Name = "Miteling"
                                }
                            },
                            Name = "Archer 04"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63012,
                                    Id = 118,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = 27.0,
                                            yCoord = 21.0
                                        }
                                    },
                                    Name = "Midge Swarm"
                                }
                            },
                            Name = "Archer 05"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63006,
                                    Id = 56,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 25.0,
                                            yCoord = 21.0
                                        }
                                    },
                                    Name = "Water Sprite"
                                }
                            },
                            Name = "Archer 06"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63010,
                                    Id = 196,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 19.0
                                        }
                                    },
                                    Name = "Black Eft"
                                }
                            },
                            Name = "Archer 07"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63027,
                                    Id = 120,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 30.0,
                                            yCoord = 20.0
                                        }
                                    },
                                    Name = "Anole"
                                }
                            },
                            Name = "Archer 08"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63004,
                                    Id = 21,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 25.0
                                        }
                                    },
                                    Name = "Trickster Imp"
                                }
                            },
                            Name = "Archer 09"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63023,
                                    Id = 22,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 22.0,
                                            yCoord = 26.0
                                        }
                                    },
                                    Name = "Roselet"
                                }
                            },
                            Name = "Archer 10"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63012,
                                    Id = 54,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 25.0
                                        }
                                    },
                                    Name = "Hornet Swarm"
                                }
                            },
                            Name = "Archer 11"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63005,
                                    Id = 13,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 30.0
                                        },
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 17.0,
                                            yCoord = 16.0
                                        },
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 31.6,
                                            yCoord = 29.7
                                        }
                                    },
                                    Name = "Arbor Buzzard"
                                }
                            },
                            Name = "Archer 12"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 1,
                                    Icon = 63009,
                                    Id = 225,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 13.0,
                                            yCoord = 27.0
                                        }
                                    },
                                    Name = "Goblin Hunter"
                                },
                                {
                                    Count = 1,
                                    Icon = 63018,
                                    Id = 128,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 27.5,
                                            yCoord = 15.5
                                        }
                                    },
                                    Name = "Treant Sapling"
                                },
                                {
                                    Count = 1,
                                    Icon = 63029,
                                    Id = 20,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 19.3,
                                            yCoord = 27.6
                                        }
                                    },
                                    Name = "Magicked Bones"
                                },
                                {
                                    Count = 1,
                                    Icon = 63088,
                                    Id = 107,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 14.0,
                                            yCoord = 25.0
                                        }
                                    },
                                    Name = "Mandragora"
                                }
                            },
                            Name = "Archer 13"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63024,
                                    Id = 14,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 13.0,
                                            yCoord = 23.0
                                        }
                                    },
                                    Name = "Wild Hoglet"
                                }
                            },
                            Name = "Archer 14"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63008,
                                    Id = 6,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 20.0,
                                            yCoord = 29.0
                                        }
                                    },
                                    Name = "Lemur"
                                }
                            },
                            Name = "Archer 15"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63022,
                                    Id = 220,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 19.0,
                                            yCoord = 28.5
                                        }
                                    },
                                    Name = "Faerie Funguar"
                                }
                            },
                            Name = "Archer 16"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63019,
                                    Id = 7,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 19.0,
                                            yCoord = 27.0
                                        }
                                    },
                                    Name = "Giant Gnat"
                                }
                            },
                            Name = "Archer 17"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63044,
                                    Id = 239,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 19.5,
                                            yCoord = 30.0
                                        }
                                    },
                                    Name = "Raptor Poacher"
                                }
                            },
                            Name = "Archer 18"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63002,
                                    Id = 3,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 15.0,
                                            yCoord = 18.0
                                        }
                                    },
                                    Name = "Antelope Doe"
                                }
                            },
                            Name = "Archer 19"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63024,
                                    Id = 16,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 16.0,
                                            yCoord = 23.0
                                        }
                                    },
                                    Name = "Wild Boar"
                                }
                            },
                            Name = "Archer 20"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63032,
                                    Id = 638,
                                    Locations = {
                                        {
                                            Map = 19,
                                            Terri = 139,
                                            Zone = 0,
                                            xCoord = 14.0,
                                            yCoord = 24.5
                                        }
                                    },
                                    Name = "Stoneshell"
                                }
                            },
                            Name = "Archer 21"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63018,
                                    Id = 232,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 17.0,
                                            yCoord = 23.0
                                        }
                                    },
                                    Name = "Diseased Treant"
                                }
                            },
                            Name = "Archer 22"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 2,
                                    Icon = 63026,
                                    Id = 381,
                                    Locations = {
                                        {
                                            Map = 19,
                                            Terri = 139,
                                            Zone = 0,
                                            xCoord = 11.1,
                                            yCoord = 21.3
                                        }
                                    },
                                    Name = "Forest Yarzon"
                                },
                                {
                                    Count = 2,
                                    Icon = 63026,
                                    Id = 227,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 14.1,
                                            yCoord = 8.9
                                        }
                                    },
                                    Name = "Yarzon Scavenger"
                                },
                                {
                                    Count = 2,
                                    Icon = 63007,
                                    Id = 215,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 18.1,
                                            yCoord = 18.9
                                        }
                                    },
                                    Name = "Overgrown Offering"
                                },
                                {
                                    Count = 2,
                                    Icon = 63016,
                                    Id = 44,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 16.0,
                                            yCoord = 21.0
                                        }
                                    },
                                    Name = "Jumping Djigga"
                                }
                            },
                            Name = "Archer 23"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63030,
                                    Id = 83,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 19.0
                                        }
                                    },
                                    Name = "Redbelly Sharpeye"
                                }
                            },
                            Name = "Archer 24"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63015,
                                    Id = 11,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = 18.0,
                                            yCoord = 26.0
                                        }
                                    },
                                    Name = "Banemite"
                                }
                            },
                            Name = "Archer 25"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63005,
                                    Id = 301,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 22.0,
                                            yCoord = 20.0
                                        }
                                    },
                                    Name = "Chasm Buzzard"
                                }
                            },
                            Name = "Archer 26"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63080,
                                    Id = 303,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 19.0,
                                            yCoord = 10.0
                                        }
                                    },
                                    Name = "Sandskin Peiste"
                                }
                            },
                            Name = "Archer 27"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63070,
                                    Id = 224,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = 16.0,
                                            yCoord = 27.5
                                        }
                                    },
                                    Name = "Ziz"
                                }
                            },
                            Name = "Archer 28"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63022,
                                    Id = 48,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 15.0,
                                            yCoord = 17.0
                                        }
                                    },
                                    Name = "Toadstool"
                                }
                            },
                            Name = "Archer 29"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63050,
                                    Id = 341,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 30.0,
                                            yCoord = 35.0
                                        }
                                    },
                                    Name = "Apkallu"
                                }
                            },
                            Name = "Archer 30"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63049,
                                    Id = 207,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 11.0,
                                            yCoord = 23.0
                                        }
                                    },
                                    Name = "Floating Eye"
                                }
                            },
                            Name = "Archer 31"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63094,
                                    Id = 290,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 32.0
                                        }
                                    },
                                    Name = "Sandworm"
                                }
                            },
                            Name = "Archer 32"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 2,
                                    Icon = 63026,
                                    Id = 204,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 13.0,
                                            yCoord = 32.0
                                        }
                                    },
                                    Name = "Russet Yarzon"
                                },
                                {
                                    Count = 2,
                                    Icon = 63070,
                                    Id = 366,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 20.0,
                                            yCoord = 32.0
                                        }
                                    },
                                    Name = "Giant Pelican"
                                },
                                {
                                    Count = 2,
                                    Icon = 63086,
                                    Id = 132,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 19.0,
                                            yCoord = 34.0
                                        }
                                    },
                                    Name = "Smoke Bomb"
                                },
                                {
                                    Count = 2,
                                    Icon = 63087,
                                    Id = 91,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 12.0,
                                            yCoord = 16.0
                                        }
                                    },
                                    Name = "Spriggan"
                                }
                            },
                            Name = "Archer 33"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63064,
                                    Id = 361,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 31.0,
                                            yCoord = 26.0
                                        }
                                    },
                                    Name = "Bloodshore Bell"
                                }
                            },
                            Name = "Archer 34"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63061,
                                    Id = 352,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 18.0,
                                            yCoord = 28.0
                                        }
                                    },
                                    Name = "Jungle Coeurl"
                                }
                            },
                            Name = "Archer 35"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 2,
                                    Icon = 63008,
                                    Id = 407,
                                    Locations = {
                                        {
                                            Map = 30,
                                            Terri = 180,
                                            Zone = 0,
                                            xCoord = 15.1,
                                            yCoord = 12.4
                                        }
                                    },
                                    Name = "Ringtail"
                                },
                                {
                                    Count = 2,
                                    Icon = 63005,
                                    Id = 398,
                                    Locations = {
                                        {
                                            Map = 30,
                                            Terri = 180,
                                            Zone = 0,
                                            xCoord = 17.0,
                                            yCoord = 16.0
                                        }
                                    },
                                    Name = "Highland Condor"
                                },
                                {
                                    Count = 2,
                                    Icon = 63010,
                                    Id = 391,
                                    Locations = {
                                        {
                                            Map = 19,
                                            Terri = 139,
                                            Zone = 0,
                                            xCoord = 27.0,
                                            yCoord = 24.0
                                        }
                                    },
                                    Name = "Salamander"
                                },
                                {
                                    Count = 2,
                                    Icon = 63014,
                                    Id = 321,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 21.0,
                                            yCoord = 38.0
                                        }
                                    },
                                    Name = "Fallen Pikeman"
                                }
                            },
                            Name = "Archer 36"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63096,
                                    Id = 114,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 20.0,
                                            yCoord = 31.0
                                        }
                                    },
                                    Name = "Ice Sprite"
                                }
                            },
                            Name = "Archer 37"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63108,
                                    Id = 784,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 22.0
                                        }
                                    },
                                    Name = "Feral Croc"
                                }
                            },
                            Name = "Archer 38"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63097,
                                    Id = 658,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 27.4,
                                            yCoord = 14.6
                                        }
                                    },
                                    Name = "Vodoriga"
                                }
                            },
                            Name = "Archer 39"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63108,
                                    Id = 1850,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 4.0,
                                            yCoord = 21.5
                                        }
                                    },
                                    Name = "Baritine Croc"
                                }
                            },
                            Name = "Archer 40"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63067,
                                    Id = 790,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 10.0,
                                            yCoord = 19.0
                                        }
                                    },
                                    Name = "Hippocerf"
                                }
                            },
                            Name = "Archer 41"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63037,
                                    Id = 637,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 9.0,
                                            yCoord = 14.0
                                        }
                                    },
                                    Name = "Dragonfly"
                                }
                            },
                            Name = "Archer 42"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 2,
                                    Icon = 63005,
                                    Id = 1853,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 12.3,
                                            yCoord = 35.7
                                        }
                                    },
                                    Name = "Lammergeyer"
                                },
                                {
                                    Count = 2,
                                    Icon = 63029,
                                    Id = 1854,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 15.0,
                                            yCoord = 35.0
                                        }
                                    },
                                    Name = "Dead Man's Moan"
                                },
                                {
                                    Count = 2,
                                    Icon = 63018,
                                    Id = 233,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 27.0,
                                            yCoord = 22.0
                                        }
                                    },
                                    Name = "Old-growth Treant"
                                },
                                {
                                    Count = 2,
                                    Icon = 63090,
                                    Id = 237,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 21.0
                                        }
                                    },
                                    Name = "Morbol"
                                }
                            },
                            Name = "Archer 43"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63010,
                                    Id = 645,
                                    Locations = {
                                        {
                                            Map = 25,
                                            Terri = 156,
                                            Zone = 0,
                                            xCoord = 13.0,
                                            yCoord = 11.0
                                        }
                                    },
                                    Name = "Mudpuppy"
                                }
                            },
                            Name = "Archer 44"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63020,
                                    Id = 112,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 29.3,
                                            yCoord = 24.3
                                        }
                                    },
                                    Name = "Lesser Kalong"
                                }
                            },
                            Name = "Archer 45"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 2,
                                    Icon = 63098,
                                    Id = 787,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 13.0,
                                            yCoord = 28.0
                                        }
                                    },
                                    Name = "Giant Reader"
                                },
                                {
                                    Count = 2,
                                    Icon = 63067,
                                    Id = 789,
                                    Locations = {
                                        {
                                            Map = 25,
                                            Terri = 156,
                                            Zone = 0,
                                            xCoord = 27.0,
                                            yCoord = 8.0
                                        }
                                    },
                                    Name = "Hippogryph"
                                },
                                {
                                    Count = 2,
                                    Icon = 63118,
                                    Id = 1812,
                                    Locations = {
                                        {
                                            Map = 25,
                                            Terri = 156,
                                            Zone = 0,
                                            xCoord = 11.0,
                                            yCoord = 13.0
                                        }
                                    },
                                    Name = "5th Cohort Secutor"
                                },
                                {
                                    Count = 2,
                                    Icon = 63042,
                                    Id = 337,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 21.5,
                                            yCoord = 19.5
                                        }
                                    },
                                    Name = "Tempered Gladiator"
                                }
                            },
                            Name = "Archer 46"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63005,
                                    Id = 567,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 27.5,
                                            yCoord = 16.0
                                        }
                                    },
                                    Name = "Sylphlands Condor"
                                }
                            },
                            Name = "Archer 47"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63023,
                                    Id = 162,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 23.5,
                                            yCoord = 14.5
                                        }
                                    },
                                    Name = "Milkroot Sapling"
                                }
                            },
                            Name = "Archer 48"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63049,
                                    Id = 242,
                                    Locations = {
                                        {
                                            Map = 24,
                                            Terri = 147,
                                            Zone = 0,
                                            xCoord = 25.0,
                                            yCoord = 21.0
                                        }
                                    },
                                    Name = "Ahriman"
                                }
                            },
                            Name = "Archer 49"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63119,
                                    Id = 559,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 13.7,
                                            yCoord = 16.7
                                        }
                                    },
                                    Name = "Shelfeye Reaver"
                                }
                            },
                            Name = "Archer 50"
                        }
                    }
                }
            },
            ["6"] = {
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63036,
                                    Id = 49,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 267.96899414063,
                                            yCoord = 54.97074508667,
                                            zCoord = 124.23870849609
                                        }
                                    },
                                    Name = "Little Ladybug"
                                }
                            },
                            Name = "Conjurer 01"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63028,
                                    Id = 37,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 17.0
                                        }
                                    },
                                    Name = "Ground Squirrel"
                                }
                            },
                            Name = "Conjurer 02"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63022,
                                    Id = 47,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 25.0,
                                            yCoord = 18.0
                                        }
                                    },
                                    Name = "Forest Funguar"
                                }
                            },
                            Name = "Conjurer 03"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63015,
                                    Id = 9,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = 25.4,
                                            yCoord = 27.8
                                        }
                                    },
                                    Name = "Miteling"
                                }
                            },
                            Name = "Conjurer 04"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63016,
                                    Id = 43,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 24.0,
                                            yCoord = 21.0
                                        }
                                    },
                                    Name = "Chigoe"
                                }
                            },
                            Name = "Conjurer 05"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63006,
                                    Id = 56,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 24.0,
                                            yCoord = 21.0
                                        }
                                    },
                                    Name = "Water Sprite"
                                }
                            },
                            Name = "Conjurer 06"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63012,
                                    Id = 118,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = 25.7,
                                            yCoord = 21.6
                                        }
                                    },
                                    Name = "Midge Swarm"
                                }
                            },
                            Name = "Conjurer 07"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63007,
                                    Id = 32,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 22.0
                                        }
                                    },
                                    Name = "Microchu"
                                }
                            },
                            Name = "Conjurer 08"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63012,
                                    Id = 41,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 27.4,
                                            yCoord = 23.1
                                        }
                                    },
                                    Name = "Syrphid Swarm"
                                }
                            },
                            Name = "Conjurer 09"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63005,
                                    Id = 12,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 14.0,
                                            yCoord = 27.0
                                        }
                                    },
                                    Name = "Northern Vulture"
                                }
                            },
                            Name = "Conjurer 10"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63013,
                                    Id = 39,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 13.1,
                                            yCoord = 26.9
                                        }
                                    },
                                    Name = "Tree Slug"
                                }
                            },
                            Name = "Conjurer 11"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63005,
                                    Id = 13,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 28.9,
                                            yCoord = 30.2
                                        },
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 17.0,
                                            yCoord = 16.0
                                        },
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 31.6,
                                            yCoord = 29.7
                                        }
                                    },
                                    Name = "Arbor Buzzard"
                                },
                                {
                                    Count = 2,
                                    Icon = 63009,
                                    Id = 225,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 13.3,
                                            yCoord = 27.7
                                        }
                                    },
                                    Name = "Goblin Hunter"
                                }
                            },
                            Name = "Conjurer 12"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63011,
                                    Id = 129,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 19.0,
                                            yCoord = 27.0
                                        },
                                        {
                                            Map = 16,
                                            Terri = 135,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 37.0
                                        }
                                    },
                                    Name = "Firefly"
                                }
                            },
                            Name = "Conjurer 13"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63088,
                                    Id = 107,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 14.2,
                                            yCoord = 25.6
                                        }
                                    },
                                    Name = "Mandragora"
                                }
                            },
                            Name = "Conjurer 14"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63021,
                                    Id = 36,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 20.0,
                                            yCoord = 28.0
                                        }
                                    },
                                    Name = "Boring Weevil"
                                }
                            },
                            Name = "Conjurer 15"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63022,
                                    Id = 220,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 19.6,
                                            yCoord = 28.7
                                        }
                                    },
                                    Name = "Faerie Funguar"
                                }
                            },
                            Name = "Conjurer 16"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63019,
                                    Id = 7,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 19.1,
                                            yCoord = 27.0
                                        }
                                    },
                                    Name = "Giant Gnat"
                                }
                            },
                            Name = "Conjurer 17"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63042,
                                    Id = 241,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 19.7,
                                            yCoord = 30.2
                                        }
                                    },
                                    Name = "Wolf Poacher"
                                }
                            },
                            Name = "Conjurer 18"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63060,
                                    Id = 219,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 15.6,
                                            yCoord = 17.8
                                        }
                                    },
                                    Name = "Qiqirn Beater"
                                }
                            },
                            Name = "Conjurer 19"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63020,
                                    Id = 38,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 16.6,
                                            yCoord = 23.5
                                        }
                                    },
                                    Name = "Black Bat"
                                }
                            },
                            Name = "Conjurer 20"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63032,
                                    Id = 638,
                                    Locations = {
                                        {
                                            Map = 19,
                                            Terri = 139,
                                            Zone = 0,
                                            xCoord = 14.0,
                                            yCoord = 24.5
                                        }
                                    },
                                    Name = "Stoneshell"
                                }
                            },
                            Name = "Conjurer 21"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63018,
                                    Id = 232,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 17.0,
                                            yCoord = 23.0
                                        }
                                    },
                                    Name = "Diseased Treant"
                                },
                                {
                                    Count = 2,
                                    Icon = 63092,
                                    Id = 278,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 13.8,
                                            yCoord = 10.6
                                        }
                                    },
                                    Name = "Lead Coblyn"
                                },
                                {
                                    Count = 2,
                                    Icon = 63059,
                                    Id = 217,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 15.3,
                                            yCoord = 6.7
                                        }
                                    },
                                    Name = "Laughing Toad"
                                }
                            },
                            Name = "Conjurer 22"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63010,
                                    Id = 228,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 18.1,
                                            yCoord = 24.5
                                        }
                                    },
                                    Name = "Bark Eft"
                                }
                            },
                            Name = "Conjurer 23"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63011,
                                    Id = 211,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 16.0,
                                            yCoord = 21.0
                                        }
                                    },
                                    Name = "Glowfly"
                                }
                            },
                            Name = "Conjurer 24"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63002,
                                    Id = 4,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 26.4,
                                            yCoord = 18.4
                                        }
                                    },
                                    Name = "Antelope Stag"
                                }
                            },
                            Name = "Conjurer 25"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63073,
                                    Id = 286,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 17.1,
                                            yCoord = 15.7
                                        }
                                    },
                                    Name = "Sabotender"
                                }
                            },
                            Name = "Conjurer 26"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63060,
                                    Id = 268,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 24.0,
                                            yCoord = 23.0
                                        }
                                    },
                                    Name = "Qiqirn Roerunner"
                                }
                            },
                            Name = "Conjurer 27"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63009,
                                    Id = 50,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 27.8,
                                            yCoord = 21.1
                                        }
                                    },
                                    Name = "Goblin Thug"
                                }
                            },
                            Name = "Conjurer 28"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63022,
                                    Id = 48,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 14.0,
                                            yCoord = 17.0
                                        }
                                    },
                                    Name = "Toadstool"
                                }
                            },
                            Name = "Conjurer 29"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63050,
                                    Id = 341,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 30.0,
                                            yCoord = 35.0
                                        }
                                    },
                                    Name = "Apkallu"
                                }
                            },
                            Name = "Conjurer 30"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63027,
                                    Id = 130,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 13.0,
                                            yCoord = 19.0
                                        }
                                    },
                                    Name = "Lindwurm"
                                }
                            },
                            Name = "Conjurer 31"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63083,
                                    Id = 235,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 18.0,
                                            yCoord = 30.0
                                        }
                                    },
                                    Name = "Bigmouth Orobon"
                                },
                                {
                                    Count = 2,
                                    Icon = 63091,
                                    Id = 416,
                                    Locations = {
                                        {
                                            Map = 19,
                                            Terri = 139,
                                            Zone = 0,
                                            xCoord = 35.3,
                                            yCoord = 24.1
                                        }
                                    },
                                    Name = "Mamool Ja Infiltrator"
                                },
                                {
                                    Count = 2,
                                    Icon = 63059,
                                    Id = 26,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 17.3,
                                            yCoord = 27.0
                                        }
                                    },
                                    Name = "Gigantoad"
                                },
                                {
                                    Count = 1,
                                    Icon = 63094,
                                    Id = 290,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 22.0,
                                            yCoord = 34.0
                                        }
                                    },
                                    Name = "Sandworm"
                                }
                            },
                            Name = "Conjurer 32"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63084,
                                    Id = 236,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 11.9,
                                            yCoord = 20.2
                                        }
                                    },
                                    Name = "Revenant"
                                }
                            },
                            Name = "Conjurer 33"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63064,
                                    Id = 361,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 31.8,
                                            yCoord = 26.1
                                        }
                                    },
                                    Name = "Bloodshore Bell"
                                }
                            },
                            Name = "Conjurer 34"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63074,
                                    Id = 795,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 25.0,
                                            yCoord = 19.0
                                        }
                                    },
                                    Name = "Ornery Karakul"
                                }
                            },
                            Name = "Conjurer 35"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63028,
                                    Id = 170,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 25.9,
                                            yCoord = 22.3
                                        }
                                    },
                                    Name = "Deepvoid Deathmouse"
                                }
                            },
                            Name = "Conjurer 36"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63018,
                                    Id = 25,
                                    Locations = {
                                        {
                                            Map = 7,
                                            Terri = 154,
                                            Zone = 0,
                                            xCoord = 22.4,
                                            yCoord = 23.1
                                        }
                                    },
                                    Name = "Dryad"
                                }
                            },
                            Name = "Conjurer 37"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63105,
                                    Id = 1849,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 10.0
                                        }
                                    },
                                    Name = "Downy Aevis"
                                }
                            },
                            Name = "Conjurer 38"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63011,
                                    Id = 45,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 24.0,
                                            yCoord = 25.0
                                        }
                                    },
                                    Name = "Will-o'-the-wisp"
                                }
                            },
                            Name = "Conjurer 39"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63037,
                                    Id = 637,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 9.0,
                                            yCoord = 14.0
                                        }
                                    },
                                    Name = "Dragonfly"
                                }
                            },
                            Name = "Conjurer 40"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63068,
                                    Id = 271,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 25.0
                                        }
                                    },
                                    Name = "Golden Fleece"
                                }
                            },
                            Name = "Conjurer 41"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63086,
                                    Id = 270,
                                    Locations = {
                                        {
                                            Map = 30,
                                            Terri = 180,
                                            Zone = 0,
                                            xCoord = 22.5,
                                            yCoord = 13.5
                                        }
                                    },
                                    Name = "Grenade"
                                },
                                {
                                    Count = 2,
                                    Icon = 63067,
                                    Id = 790,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 10.0,
                                            yCoord = 19.0
                                        }
                                    },
                                    Name = "Hippocerf"
                                },
                                {
                                    Count = 2,
                                    Icon = 63005,
                                    Id = 1853,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 12.3,
                                            yCoord = 35.7
                                        }
                                    },
                                    Name = "Lammergeyer"
                                },
                                {
                                    Count = 1,
                                    Icon = 63029,
                                    Id = 1854,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 15.0,
                                            yCoord = 35.0
                                        }
                                    },
                                    Name = "Dead Man's Moan"
                                }
                            },
                            Name = "Conjurer 42"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 2,
                                    Icon = 63118,
                                    Id = 53,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 29.0,
                                            yCoord = 21.0
                                        }
                                    },
                                    Name = "3rd Cohort Hoplomachus"
                                }
                            },
                            Name = "Conjurer 43"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63020,
                                    Id = 112,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 29.3,
                                            yCoord = 24.3
                                        }
                                    },
                                    Name = "Lesser Kalong"
                                }
                            },
                            Name = "Conjurer 44"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63052,
                                    Id = 653,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 16.0,
                                            yCoord = 32.0
                                        }
                                    },
                                    Name = "Snow Wolf"
                                }
                            },
                            Name = "Conjurer 45"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63118,
                                    Id = 1811,
                                    Locations = {
                                        {
                                            Map = 25,
                                            Terri = 156,
                                            Zone = 0,
                                            xCoord = 12.0,
                                            yCoord = 17.0
                                        }
                                    },
                                    Name = "5th Cohort Eques"
                                }
                            },
                            Name = "Conjurer 46"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63064,
                                    Id = 360,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 14.0,
                                            yCoord = 17.0
                                        }
                                    },
                                    Name = "Sea Wasp"
                                }
                            },
                            Name = "Conjurer 47"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63022,
                                    Id = 166,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 13.0
                                        }
                                    },
                                    Name = "Sylph Bonnet"
                                }
                            },
                            Name = "Conjurer 48"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63049,
                                    Id = 242,
                                    Locations = {
                                        {
                                            Map = 24,
                                            Terri = 147,
                                            Zone = 0,
                                            xCoord = 25.0,
                                            yCoord = 21.0
                                        }
                                    },
                                    Name = "Ahriman"
                                }
                            },
                            Name = "Conjurer 49"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63100,
                                    Id = 1826,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 29.0,
                                            yCoord = 21.0
                                        }
                                    },
                                    Name = "2nd Cohort Vanguard"
                                }
                            },
                            Name = "Conjurer 50"
                        }
                    }
                }
            },
            ["7"] = {
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63036,
                                    Id = 49,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 267.96899414063,
                                            yCoord = 54.97074508667,
                                            zCoord = 124.23870849609
                                        }
                                    },
                                    Name = "Little Ladybug"
                                }
                            },
                            Name = "Thaumaturge 01"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63048,
                                    Id = 632,
                                    Locations = {
                                        {
                                            Map = 21,
                                            Terri = 141,
                                            Zone = 0,
                                            xCoord = 22.0,
                                            yCoord = 27.0
                                        }
                                    },
                                    Name = "Huge Hornet"
                                }
                            },
                            Name = "Thaumaturge 02"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63073,
                                    Id = 287,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 27.0,
                                            yCoord = 24.0
                                        }
                                    },
                                    Name = "Cactuar"
                                }
                            },
                            Name = "Thaumaturge 03"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63089,
                                    Id = 318,
                                    Locations = {
                                        {
                                            Map = 21,
                                            Terri = 141,
                                            Zone = 0,
                                            xCoord = 24.0,
                                            yCoord = 30.0
                                        }
                                    },
                                    Name = "Snapping Shrew"
                                }
                            },
                            Name = "Thaumaturge 04"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63012,
                                    Id = 201,
                                    Locations = {
                                        {
                                            Map = 21,
                                            Terri = 141,
                                            Zone = 0,
                                            xCoord = 18.0,
                                            yCoord = 21.0
                                        }
                                    },
                                    Name = "Syrphid Cloud"
                                }
                            },
                            Name = "Thaumaturge 05"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63026,
                                    Id = 284,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 24.0,
                                            yCoord = 27.0
                                        }
                                    },
                                    Name = "Yarzon Feeder"
                                }
                            },
                            Name = "Thaumaturge 06"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63092,
                                    Id = 276,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 20.0,
                                            yCoord = 28.0
                                        }
                                    },
                                    Name = "Rusty Coblyn"
                                }
                            },
                            Name = "Thaumaturge 07"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63087,
                                    Id = 317,
                                    Locations = {
                                        {
                                            Map = 21,
                                            Terri = 141,
                                            Zone = 0,
                                            xCoord = 18.0,
                                            yCoord = 23.0
                                        }
                                    },
                                    Name = "Spriggan Graverobber"
                                }
                            },
                            Name = "Thaumaturge 08"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63060,
                                    Id = 266,
                                    Locations = {
                                        {
                                            Map = 21,
                                            Terri = 141,
                                            Zone = 0,
                                            xCoord = 17.0,
                                            yCoord = 19.0
                                        }
                                    },
                                    Name = "Qiqirn Shellsweeper"
                                }
                            },
                            Name = "Thaumaturge 09"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63020,
                                    Id = 279,
                                    Locations = {
                                        {
                                            Map = 21,
                                            Terri = 141,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 18.0
                                        }
                                    },
                                    Name = "Sun Bat"
                                }
                            },
                            Name = "Thaumaturge 10"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63086,
                                    Id = 316,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 27.6,
                                            yCoord = 16.7
                                        }
                                    },
                                    Name = "Bomb"
                                },
                                {
                                    Count = 2,
                                    Icon = 63092,
                                    Id = 277,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 27.0,
                                            yCoord = 16.0
                                        }
                                    },
                                    Name = "Copper Coblyn"
                                }
                            },
                            Name = "Thaumaturge 11"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63073,
                                    Id = 288,
                                    Locations = {
                                        {
                                            Map = 21,
                                            Terri = 141,
                                            Zone = 0,
                                            xCoord = 23.7,
                                            yCoord = 19.6
                                        }
                                    },
                                    Name = "Cochineal Cactuar"
                                },
                                {
                                    Count = 2,
                                    Icon = 63043,
                                    Id = 330,
                                    Locations = {
                                        {
                                            Map = 21,
                                            Terri = 141,
                                            Zone = 0,
                                            xCoord = 24.0,
                                            yCoord = 21.0
                                        }
                                    },
                                    Name = "Quiveron Attendant"
                                }
                            },
                            Name = "Thaumaturge 12"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63076,
                                    Id = 293,
                                    Locations = {
                                        {
                                            Map = 21,
                                            Terri = 141,
                                            Zone = 0,
                                            xCoord = 19.1,
                                            yCoord = 16.5
                                        }
                                    },
                                    Name = "Antling Sentry"
                                },
                                {
                                    Count = 2,
                                    Icon = 63001,
                                    Id = 244,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 21.7,
                                            yCoord = 26.7
                                        }
                                    },
                                    Name = "Giant Tortoise"
                                }
                            },
                            Name = "Thaumaturge 13"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63032,
                                    Id = 636,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 16.4,
                                            yCoord = 16.0
                                        }
                                    },
                                    Name = "Thickshell"
                                }
                            },
                            Name = "Thaumaturge 14"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63059,
                                    Id = 216,
                                    Locations = {
                                        {
                                            Map = 21,
                                            Terri = 141,
                                            Zone = 0,
                                            xCoord = 27.0,
                                            yCoord = 18.0
                                        }
                                    },
                                    Name = "Toxic Toad"
                                }
                            },
                            Name = "Thaumaturge 15"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63082,
                                    Id = 306,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 15.0,
                                            yCoord = 24.0
                                        }
                                    },
                                    Name = "Tuco-tuco"
                                }
                            },
                            Name = "Thaumaturge 16"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63093,
                                    Id = 274,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 18.4,
                                            yCoord = 22.6
                                        }
                                    },
                                    Name = "Myotragus Nanny"
                                }
                            },
                            Name = "Thaumaturge 17"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63012,
                                    Id = 1199,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 12.0,
                                            yCoord = 21.0
                                        }
                                    },
                                    Name = "Blowfly Swarm"
                                }
                            },
                            Name = "Thaumaturge 18"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63014,
                                    Id = 319,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 14.8,
                                            yCoord = 16.8
                                        }
                                    },
                                    Name = "Rotting Corpse"
                                }
                            },
                            Name = "Thaumaturge 19"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63084,
                                    Id = 309,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 13.2,
                                            yCoord = 11.8
                                        }
                                    },
                                    Name = "Bloated Bogy"
                                }
                            },
                            Name = "Thaumaturge 20"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63007,
                                    Id = 214,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 29.0
                                        }
                                    },
                                    Name = "Overgrown Ivy"
                                },
                                {
                                    Count = 2,
                                    Icon = 63023,
                                    Id = 23,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 20.1,
                                            yCoord = 20.6
                                        }
                                    },
                                    Name = "Kedtrap"
                                }
                            },
                            Name = "Thaumaturge 21"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63026,
                                    Id = 381,
                                    Locations = {
                                        {
                                            Map = 19,
                                            Terri = 139,
                                            Zone = 0,
                                            xCoord = 11.1,
                                            yCoord = 21.3
                                        }
                                    },
                                    Name = "Forest Yarzon"
                                },
                                {
                                    Count = 2,
                                    Icon = 63026,
                                    Id = 227,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 14.1,
                                            yCoord = 8.9
                                        }
                                    },
                                    Name = "Yarzon Scavenger"
                                }
                            },
                            Name = "Thaumaturge 22"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63059,
                                    Id = 217,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 15.3,
                                            yCoord = 6.7
                                        }
                                    },
                                    Name = "Laughing Toad"
                                },
                                {
                                    Count = 2,
                                    Icon = 63010,
                                    Id = 228,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 18.1,
                                            yCoord = 24.5
                                        }
                                    },
                                    Name = "Bark Eft"
                                }
                            },
                            Name = "Thaumaturge 23"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63016,
                                    Id = 44,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 16.0,
                                            yCoord = 21.0
                                        }
                                    },
                                    Name = "Jumping Djigga"
                                },
                                {
                                    Count = 2,
                                    Icon = 63011,
                                    Id = 211,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 16.0,
                                            yCoord = 21.0
                                        }
                                    },
                                    Name = "Glowfly"
                                }
                            },
                            Name = "Thaumaturge 24"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63026,
                                    Id = 226,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 22.0
                                        }
                                    },
                                    Name = "River Yarzon"
                                }
                            },
                            Name = "Thaumaturge 25"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63012,
                                    Id = 564,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 20.0,
                                            yCoord = 16.0
                                        }
                                    },
                                    Name = "Potter Wasp Swarm"
                                }
                            },
                            Name = "Thaumaturge 26"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63068,
                                    Id = 272,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 20.0
                                        }
                                    },
                                    Name = "Phurble"
                                }
                            },
                            Name = "Thaumaturge 27"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63045,
                                    Id = 331,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 24.0,
                                            yCoord = 9.0
                                        }
                                    },
                                    Name = "Corpse Brigade Knuckledancer"
                                }
                            },
                            Name = "Thaumaturge 28"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63054,
                                    Id = 116,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 13.0,
                                            yCoord = 20.0
                                        }
                                    },
                                    Name = "Fire Sprite"
                                }
                            },
                            Name = "Thaumaturge 29"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 4,
                                    Icon = 63090,
                                    Id = 238,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 13.0,
                                            yCoord = 22.0
                                        }
                                    },
                                    Name = "Stroper"
                                }
                            },
                            Name = "Thaumaturge 30"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63091,
                                    Id = 413,
                                    Locations = {
                                        {
                                            Map = 19,
                                            Terri = 139,
                                            Zone = 0,
                                            xCoord = 35.3,
                                            yCoord = 24.1
                                        }
                                    },
                                    Name = "Mamool Ja Executioner"
                                },
                                {
                                    Count = 2,
                                    Icon = 63001,
                                    Id = 34,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 16.0,
                                            yCoord = 30.0
                                        }
                                    },
                                    Name = "Adamantoise"
                                }
                            },
                            Name = "Thaumaturge 31"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63026,
                                    Id = 204,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 14.0,
                                            yCoord = 32.0
                                        }
                                    },
                                    Name = "Russet Yarzon"
                                },
                                {
                                    Count = 2,
                                    Icon = 63084,
                                    Id = 236,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 12.0,
                                            yCoord = 20.0
                                        }
                                    },
                                    Name = "Revenant"
                                }
                            },
                            Name = "Thaumaturge 32"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63086,
                                    Id = 132,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 19.0,
                                            yCoord = 34.0
                                        }
                                    },
                                    Name = "Smoke Bomb"
                                },
                                {
                                    Count = 2,
                                    Icon = 63012,
                                    Id = 396,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 18.0,
                                            yCoord = 28.0
                                        }
                                    },
                                    Name = "Dung Midge Swarm"
                                }
                            },
                            Name = "Thaumaturge 33"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63059,
                                    Id = 26,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 18.0,
                                            yCoord = 26.0
                                        }
                                    },
                                    Name = "Gigantoad"
                                },
                                {
                                    Count = 2,
                                    Icon = 63087,
                                    Id = 91,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 12.0,
                                            yCoord = 16.0
                                        }
                                    },
                                    Name = "Spriggan"
                                }
                            },
                            Name = "Thaumaturge 34"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63010,
                                    Id = 391,
                                    Locations = {
                                        {
                                            Map = 19,
                                            Terri = 139,
                                            Zone = 0,
                                            xCoord = 28.0,
                                            yCoord = 24.0
                                        }
                                    },
                                    Name = "Salamander"
                                }
                            },
                            Name = "Thaumaturge 35"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63011,
                                    Id = 46,
                                    Locations = {
                                        {
                                            Map = 30,
                                            Terri = 180,
                                            Zone = 0,
                                            xCoord = 25.0,
                                            yCoord = 18.0
                                        }
                                    },
                                    Name = "Plasmoid"
                                }
                            },
                            Name = "Thaumaturge 36"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63096,
                                    Id = 114,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 20.0,
                                            yCoord = 31.0
                                        }
                                    },
                                    Name = "Ice Sprite"
                                }
                            },
                            Name = "Thaumaturge 37"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63108,
                                    Id = 784,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 26.0,
                                            yCoord = 22.0
                                        }
                                    },
                                    Name = "Feral Croc"
                                }
                            },
                            Name = "Thaumaturge 38"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63011,
                                    Id = 45,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 24.0,
                                            yCoord = 25.0
                                        }
                                    },
                                    Name = "Will-o'-the-wisp"
                                }
                            },
                            Name = "Thaumaturge 39"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 5,
                                    Icon = 63068,
                                    Id = 271,
                                    Locations = {
                                        {
                                            Map = 22,
                                            Terri = 145,
                                            Zone = 0,
                                            xCoord = 27.0,
                                            yCoord = 24.0
                                        }
                                    },
                                    Name = "Golden Fleece"
                                }
                            },
                            Name = "Thaumaturge 40"
                        }
                    }
                },
                {
                    Tasks = {
                        {
                            Monsters = {
                                {
                                    Count = 6,
                                    Icon = 63037,
                                    Id = 637,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 9.0,
                                            yCoord = 14.0
                                        }
                                    },
                                    Name = "Dragonfly"
                                },
                                {
                                    Count = 2,
                                    Icon = 63018,
                                    Id = 233,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 27.0,
                                            yCoord = 22.0
                                        }
                                    },
                                    Name = "Old-growth Treant"
                                }
                            },
                            Name = "Thaumaturge 41"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 6,
                                    Icon = 63029,
                                    Id = 1854,
                                    Locations = {
                                        {
                                            Map = 18,
                                            Terri = 138,
                                            Zone = 0,
                                            xCoord = 15.0,
                                            yCoord = 35.0
                                        }
                                    },
                                    Name = "Dead Man's Moan"
                                },
                                {
                                    Count = 1,
                                    Icon = 63069,
                                    Id = 131,
                                    Locations = {
                                        {
                                            Map = 4,
                                            Terri = 148,
                                            Zone = 0,
                                            xCoord = 10.0,
                                            yCoord = 18.0
                                        }
                                    },
                                    Name = "Crater Golem"
                                }
                            },
                            Name = "Thaumaturge 42"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 6,
                                    Icon = 63090,
                                    Id = 237,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 23.0,
                                            yCoord = 21.0
                                        }
                                    },
                                    Name = "Morbol"
                                },
                                {
                                    Count = 2,
                                    Icon = 63118,
                                    Id = 60,
                                    Locations = {
                                        {
                                            Map = 5,
                                            Terri = 152,
                                            Zone = 0,
                                            xCoord = 32.0,
                                            yCoord = 20.0
                                        }
                                    },
                                    Name = "3rd Cohort Secutor"
                                }
                            },
                            Name = "Thaumaturge 43"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 6,
                                    Icon = 63059,
                                    Id = 27,
                                    Locations = {
                                        {
                                            Map = 25,
                                            Terri = 156,
                                            Zone = 0,
                                            xCoord = 19.0,
                                            yCoord = 9.0
                                        }
                                    },
                                    Name = "Nix"
                                },
                                {
                                    Count = 2,
                                    Icon = 63020,
                                    Id = 112,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 29.3,
                                            yCoord = 24.3
                                        }
                                    },
                                    Name = "Lesser Kalong"
                                }
                            },
                            Name = "Thaumaturge 44"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 3,
                                    Icon = 63098,
                                    Id = 785,
                                    Locations = {
                                        {
                                            Map = 53,
                                            Terri = 155,
                                            Zone = 0,
                                            xCoord = 13.0,
                                            yCoord = 26.0
                                        }
                                    },
                                    Name = "Giant Logger"
                                },
                                {
                                    Count = 2,
                                    Icon = 63107,
                                    Id = 648,
                                    Locations = {
                                        {
                                            Map = 25,
                                            Terri = 156,
                                            Zone = 0,
                                            xCoord = 29.0,
                                            yCoord = 14.0
                                        }
                                    },
                                    Name = "Gigas Sozu"
                                }
                            },
                            Name = "Thaumaturge 45"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 6,
                                    Icon = 63001,
                                    Id = 243,
                                    Locations = {
                                        {
                                            Map = 23,
                                            Terri = 146,
                                            Zone = 0,
                                            xCoord = 19.0,
                                            yCoord = 23.0
                                        }
                                    },
                                    Name = "Iron Tortoise"
                                }
                            },
                            Name = "Thaumaturge 46"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 6,
                                    Icon = 63092,
                                    Id = 1836,
                                    Locations = {
                                        {
                                            Map = 30,
                                            Terri = 180,
                                            Zone = 0,
                                            xCoord = 22.0,
                                            yCoord = 6.0
                                        }
                                    },
                                    Name = "Synthetic Doblyn"
                                }
                            },
                            Name = "Thaumaturge 47"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 6,
                                    Icon = 63019,
                                    Id = 8,
                                    Locations = {
                                        {
                                            Map = 6,
                                            Terri = 153,
                                            Zone = 0,
                                            xCoord = 32.0,
                                            yCoord = 24.0
                                        }
                                    },
                                    Name = "Ked"
                                }
                            },
                            Name = "Thaumaturge 48"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 6,
                                    Icon = 63118,
                                    Id = 1815,
                                    Locations = {
                                        {
                                            Map = 20,
                                            Terri = 140,
                                            Zone = 0,
                                            xCoord = 12.0,
                                            yCoord = 7.0
                                        }
                                    },
                                    Name = "4th Cohort Hoplomachus"
                                }
                            },
                            Name = "Thaumaturge 49"
                        },
                        {
                            Monsters = {
                                {
                                    Count = 6,
                                    Icon = 63118,
                                    Id = 1825,
                                    Locations = {
                                        {
                                            Map = 17,
                                            Terri = 137,
                                            Zone = 0,
                                            xCoord = 27.0,
                                            yCoord = 21.0
                                        }
                                    },
                                    Name = "2nd Cohort Signifer"
                                }
                            },
                            Name = "Thaumaturge 50"
                        }
                    }
                }
            }
        }
    }



-------------------------------------------------
-- Class names for hunt log display
-------------------------------------------------
local ClassNames = {
    [0] = "GLA",  -- Gladiator
    [1] = "PGL",  -- Pugilist
    [2] = "MRD",  -- Marauder
    [3] = "LNC",  -- Lancer
    [4] = "ARC",  -- Archer
    [5] = "ROG",  -- Rogue
    [6] = "CNJ",  -- Conjurer
    [7] = "THM",  -- Thaumaturge
    [8] = "ACN",  -- Arcanist
    [9] = "GC"    -- Grand Company
}

-------------------------------------------------
-- Build mob lookup table (name -> location)
-------------------------------------------------
Debug("Building mob database...")

local mobLookup = {}
for jobId, ranks in pairs(monster_data.JobRanks) do
    for rankIdx, rank in ipairs(ranks) do
        if rank.Tasks then
            for _, task in ipairs(rank.Tasks) do
                if task.Monsters then
                    for _, monster in ipairs(task.Monsters) do
                        if monster.Name and monster.Locations and #monster.Locations > 0 then
                            mobLookup[monster.Name] = monster.Locations[1]
                        end
                    end
                end
            end
        end
    end
end

-------------------------------------------------
-- Helper: Read hunt log and get incomplete mobs
-------------------------------------------------
local function GetIncompleteMobs()
    local addon = Addons.GetAddon("MonsterNote")
    if addon and addon.Ready then
        yield("/callback MonsterNote true -1")
        Sleep(0.3)
    end
    yield("/huntinglog")
    Sleep(0.5)

    local waitCount = 0
    repeat
        Sleep(0.2)
        addon = Addons.GetAddon("MonsterNote")
        waitCount = waitCount + 1
    until (addon and addon.Ready) or waitCount > 15

    if not addon or not addon.Ready then
        return nil
    end

    -- Select the correct class tab based on settings
    local targetClass = Settings.hunt_type == "gc" and 9 or GetCurrentClassIndex()
    if not targetClass then
        Debug("ERROR: Current job has no hunt log!")
        return nil
    end
    yield("/callback MonsterNote true 0 " .. targetClass)
    Sleep(0.3)

    yield("/callback MonsterNote true 2 2")  -- Filter incomplete
    Sleep(0.5)  -- Longer wait for filter to apply

    -- Get current class for display
    local className = ClassNames[targetClass] or "Unknown"
    Debug("Scanning " .. className .. " hunt log...")

    local mobs = {}
    local totalFound = 0
    for nameIdx = 79, 130 do
        local atkVal = addon:GetAtkValue(nameIdx)
        if atkVal and atkVal.ValueString and atkVal.ValueString ~= "" then
            totalFound = totalFound + 1
            local mobName = atkVal.ValueString
            local progressVal = addon:GetAtkValue(nameIdx + 80)
            local progressStr = progressVal and progressVal.ValueString or "0/0"

            local current, total = progressStr:match("(%d+)/(%d+)")
            current = tonumber(current) or 0
            total = tonumber(total) or 0
            local remaining = total - current

            if remaining > 0 then
                table.insert(mobs, {
                    name = mobName,
                    current = current,
                    total = total,
                    remaining = remaining
                })
            end
        end
    end

    Debug("Found " .. #mobs .. " incomplete mobs")

    yield("/callback MonsterNote true -1")  -- Close
    Sleep(0.2)

    return mobs
end

-------------------------------------------------
-- Helper: Navigate to location
-------------------------------------------------
local function NavigateTo(location, targetMobName)
    local ZONE_ID = location.Terri
    local MAP_ID = location.Map
    local X = location.xCoord
    local Y = location.yCoord
    local Z = location.zCoord

    local zoneName = Territories[tostring(ZONE_ID)] or "Unknown"

    -- Teleport if needed
    local currentZone = Svc.ClientState.TerritoryType
    if currentZone ~= ZONE_ID then
        -- Wait for combat to end before teleporting
        if Svc.Condition[26] then
            Debug("In combat, fighting before teleport...")
            yield("/battletarget")
            Sleep(0.3)
            yield("/rotation manual")
            while Svc.Condition[26] do
                yield("/battletarget")
                Sleep(1.0)
            end
            yield("/rotation cancel")
            Sleep(1.0)  -- Extra buffer after combat
        end

        -- Check for aetheryte override (e.g., Camp Dragonhead instead of Foundation for Coerthas)
        local teleportDest = AetheryteOverrides[zoneName] or zoneName
        Debug("Teleporting to " .. teleportDest .. "...")
        yield("/li " .. teleportDest)
        Sleep(1.0)

        local tpWait = 0
        while Svc.ClientState.TerritoryType ~= ZONE_ID and tpWait < 60 do
            -- Check if combat interrupted teleport
            if Svc.Condition[26] then
                Debug("Combat interrupted teleport, fighting...")
                yield("/battletarget")
                Sleep(0.3)
                yield("/rotation manual")
                while Svc.Condition[26] do
                    yield("/battletarget")
                    Sleep(1.0)
                end
                yield("/rotation cancel")
                Sleep(1.0)
                -- Retry teleport
                Debug("Retrying teleport to " .. teleportDest .. "...")
                yield("/li " .. teleportDest)
                Sleep(1.0)
            end
            Sleep(1.0)
            tpWait = tpWait + 1
        end

        while not Player.Available do
            Sleep(0.3)
        end
        Sleep(0.5)

        -- Check for combat after zone load
        if Svc.Condition[26] then
            Debug("In combat after teleport, fighting...")
            yield("/battletarget")
            Sleep(0.3)
            yield("/rotation manual")
            while Svc.Condition[26] do
                yield("/battletarget")
                Sleep(1.0)
            end
            yield("/rotation cancel")
            Sleep(1.0)
        end

        if Svc.ClientState.TerritoryType ~= ZONE_ID then
            Debug("ERROR: Teleport failed")
            return false
        end
    end

    -- Wait for navmesh
    local navWait = 0
    while not IPC.vnavmesh.IsReady() and navWait < 30 do
        Sleep(1.0)
        navWait = navWait + 1
    end

    if not IPC.vnavmesh.IsReady() then
        Debug("ERROR: Navmesh not ready")
        return false
    end

    -- Navigate
    if Z then
        -- 3D world coords
        Debug("Moving to spawn (3D)...")
        yield("/vnav moveto " .. X .. " " .. Y .. " " .. Z)
    else
        -- 2D map coords - convert to raw
        local scale = 1
        local rawX = (X * 50) - 25 - (1024 / scale)
        local rawY = (Y * 50) - 25 - (1024 / scale)
        Debug("Moving to spawn (2D)...")
        Instances.Map.Flag:SetFlagMapMarker(ZONE_ID, MAP_ID, rawX, rawY)
        Sleep(0.3)
        yield("/vnav moveflag")
    end

    -- Mount
    if not Svc.Condition[4] then
        yield("/gaction \"Mount Roulette\"")
        Sleep(1.0)
        if not Svc.Condition[4] then
            yield("/mount \"Company Chocobo\"")
            Sleep(1.0)
        end
    end

    -- Wait for arrival with anti-stuck detection
    Sleep(0.5)
    local moveWait = 0
    local lastX, lastZ = Entity.Player.Position.X, Entity.Player.Position.Z
    local stuckTime = 0
    local stuckRetries = 0
    local maxStuckRetries = 5

    while moveWait < 120 do
        -- Check if vnav stopped (arrived or failed)
        if not IPC.vnavmesh.IsRunning() then
            -- Give it a moment to see if it's just between commands
            Sleep(0.5)
            if not IPC.vnavmesh.IsRunning() then
                Debug("Navigation stopped (arrived or path ended)")
                break
            end
        end

        Sleep(1.0)
        moveWait = moveWait + 1

        -- Check if stuck (position unchanged for 2+ seconds)
        local currX, currZ = Entity.Player.Position.X, Entity.Player.Position.Z
        local moved = math.abs(currX - lastX) > 0.5 or math.abs(currZ - lastZ) > 0.5

        if moved then
            stuckTime = 0
            lastX, lastZ = currX, currZ
        else
            stuckTime = stuckTime + 1
            if stuckTime >= 2 then
                stuckRetries = stuckRetries + 1
                Debug("Stuck detected (attempt " .. stuckRetries .. "/" .. maxStuckRetries .. ")")

                -- Give up after max retries
                if stuckRetries >= maxStuckRetries then
                    IPC.vnavmesh.Stop()
                    Debug("Stuck " .. maxStuckRetries .. " times, giving up on this location")
                    return false
                end

                -- First few attempts: just jump while vnav keeps moving us forward
                if stuckRetries <= 3 then
                    Debug("Attempting unstick: jump (vnav still moving)")
                    yield("/gaction Jump")
                    Sleep(0.8)
                    stuckTime = 0
                    lastX, lastZ = Entity.Player.Position.X, Entity.Player.Position.Z
                else
                    -- After 3 failed jumps: stop, reload navmesh, and restart
                    Debug("Jump didn't help, reloading navmesh...")
                    IPC.vnavmesh.Stop()
                    Sleep(0.3)

                    -- Dismount to check for nearby target
                    if Svc.Condition[4] then
                        yield("/gaction Dismount")
                        Sleep(0.5)
                    end

                    -- Check if target mob is nearby
                    if targetMobName then
                        yield("/target \"" .. targetMobName .. "\"")
                        Sleep(0.3)
                        if Entity.Target and Entity.Target.Name == targetMobName then
                            Debug("Target found nearby! Stopping navigation.")
                            return true  -- Success - mob is close enough
                        end
                    end

                    -- Reload navmesh to find a different path
                    yield("/vnav reload")
                    Sleep(1.0)

                    -- Remount
                    if not Svc.Condition[4] then
                        yield("/gaction \"Mount Roulette\"")
                        Sleep(1.5)
                        if not Svc.Condition[4] then
                            yield("/mount \"Company Chocobo\"")
                            Sleep(1.5)
                        end
                    end

                    -- Restart navigation
                    Debug("Restarting navigation...")
                    if Z then
                        yield("/vnav moveto " .. X .. " " .. Y .. " " .. Z)
                    else
                        yield("/vnav moveflag")
                    end

                    -- Wait for vnav to actually start
                    local startWait = 0
                    while not IPC.vnavmesh.IsRunning() and startWait < 5 do
                        Sleep(0.5)
                        startWait = startWait + 1
                    end

                    if not IPC.vnavmesh.IsRunning() then
                        Debug("Navigation failed to restart, rebuilding navmesh...")
                        yield("/vnav rebuild")
                        Sleep(2.0)
                        if Z then
                            yield("/vnav moveto " .. X .. " " .. Y .. " " .. Z)
                        else
                            yield("/vnav moveflag")
                        end
                        Sleep(1.0)
                    end

                    stuckTime = 0
                    lastX, lastZ = Entity.Player.Position.X, Entity.Player.Position.Z
                end
            end
        end
    end

    -- Dismount
    if Svc.Condition[4] then
        yield("/gaction Dismount")
        Sleep(0.5)
    end

    return true
end

-------------------------------------------------
-- Helper: Kill mobs
-------------------------------------------------
local function KillMobs(mobName, count)
    Debug("Killing " .. count .. "x " .. mobName .. "...")

    yield("/rotation manual")
    Sleep(0.3)

    local killCount = 0
    local noTargetCount = 0

    while killCount < count do
        -- Check if we're being attacked but have no target
        if Svc.Condition[26] and not Entity.Target then
            Debug("  In combat but no target, targeting attacker...")
            yield("/targetenemy")
            Sleep(0.3)
        end

        -- Try to target our hunt mob
        if not Entity.Target or (Entity.Target and Entity.Target.Name ~= mobName) then
            yield("/target \"" .. mobName .. "\"")
            Sleep(0.3)
        end

        if not Entity.Target then
            noTargetCount = noTargetCount + 1
            if noTargetCount > 10 then
                Debug("No targets found after 10 tries, moving on...")
                break
            end
            Sleep(2.0)
        else
            noTargetCount = 0

            -- Move closer if too far (melee needs ~3y, ranged ~25y, use 5y as safe threshold)
            local targetDist = Entity.Target.DistanceTo
            if targetDist and targetDist > 5 then
                Debug("  Target at " .. string.format("%.1f", targetDist) .. "y, moving closer...")
                local tX = Entity.Target.Position.X
                local tY = Entity.Target.Position.Y
                local tZ = Entity.Target.Position.Z
                yield("/vnav moveto " .. tX .. " " .. tY .. " " .. tZ)
                Sleep(0.5)
                local closeWait = 0
                while IPC.vnavmesh.IsRunning() and Entity.Target and Entity.Target.DistanceTo > 3 and closeWait < 15 do
                    Sleep(0.5)
                    closeWait = closeWait + 1
                end
                IPC.vnavmesh.Stop()
                Sleep(0.3)
            end

            -- Ensure RSR is on
            yield("/rotation manual")

            -- Wait for combat to start
            local combatWait = 0
            while not Svc.Condition[26] and Entity.Target and combatWait < 10 do
                Sleep(0.3)
                combatWait = combatWait + 1
                -- Re-trigger RSR if combat not starting
                if combatWait == 5 then
                    yield("/rotation manual")
                end
                -- If still not in combat after a few tries, move even closer
                if combatWait == 7 and Entity.Target then
                    local dist = Entity.Target.DistanceTo
                    if dist and dist > 3 then
                        Debug("  Combat not starting, moving closer...")
                        yield("/vnav movetarget")
                        Sleep(1.0)
                        IPC.vnavmesh.Stop()
                    end
                end
            end

            -- Wait for kill
            local fightWait = 0
            while Entity.Target and fightWait < 60 do
                Sleep(0.5)
                fightWait = fightWait + 1
                -- Re-enable RSR periodically in case it turned off
                if fightWait % 10 == 0 then
                    yield("/rotation manual")
                end
            end

            -- Check if target was lost mid-fight (not actually dead)
            if not Entity.Target then
                -- If still in combat, target might have just been lost - try to retarget
                if Svc.Condition[26] then
                    Debug("  Target lost but still in combat, retargeting...")
                    yield("/target \"" .. mobName .. "\"")
                    Sleep(0.3)
                    if not Entity.Target then
                        -- Try targeting any enemy
                        yield("/targetenemy")
                        Sleep(0.3)
                    end
                    -- Don't count as kill, loop will continue
                else
                    -- Out of combat = mob is dead
                    killCount = killCount + 1
                    Debug("  Kill " .. killCount .. "/" .. count)
                end
            end
            Sleep(0.5)
        end
    end

    yield("/rotation cancel")
    Sleep(0.3)

    return killCount
end

-------------------------------------------------
-- GC & DUNGEON SUPPORT
-------------------------------------------------

-- GC Quest IDs for rank requirements
local GCQuestData = {
    -- Rank 8 unlock quests ("Shadows Uncast" equivalents)
    rank8Quests = {
        [1] = 66664,  -- Maelstrom
        [2] = 66665,  -- Twin Adders
        [3] = 66666   -- Immortal Flames
    },
    -- Rank 9 unlock quests ("Gilding the Bilious" equivalents)
    rank9Quests = {
        [1] = 66667,  -- Maelstrom
        [2] = 66668,  -- Twin Adders
        [3] = 66669   -- Immortal Flames
    },
    -- Extra dungeon quests (Dzemael Darkhold / Aurum Vale)
    extraQuests = {
        [1] = {1128, 1131},  -- Maelstrom
        [2] = {1129, 1132},  -- Twin Adders
        [3] = {1130, 1133}   -- Immortal Flames
    }
}

-- Dungeon data per hunt log rank
local GCDungeonData = {
    [1] = {
        default = "Halatali",
        contentId = 1245,              -- AutoDuty content ID
        unlockQuest = 66233,           -- Game quest ID for completion check
        unlockQuestQst = 697,          -- Questionable quest ID for /qst command
        unlockQuestName = "Hallo Halatali"
    },
    [2] = {
        default = "The Sunken Temple of Qarn",
        flames = "Cutter's Cry",  -- Immortal Flames uses different dungeon
        contentId = 1267,              -- AutoDuty content ID for Qarn
        flamesContentId = 1303,        -- AutoDuty content ID for Cutter's Cry
        unlockQuest = 66300,           -- Game quest ID for Braving New Depths
        unlockQuestQst = 764,
        unlockQuestName = "Braving New Depths",
        flamesUnlockQuest = 66457,     -- Game quest ID for Dishonor Before Death
        flamesUnlockQuestQst = 921,
        flamesUnlockQuestName = "Dishonor Before Death"
    },
    [3] = {
        default = "The Wanderer's Palace",
        contentId = nil,               -- Not available in AutoDuty yet
        unlockQuest = 66406,           -- Game quest ID for Trauma Queen
        unlockQuestQst = 870,          -- Questionable quest ID
        unlockQuestName = "Trauma Queen"
    }
}

-- Extra dungeons for rank 9
local ExtraDungeons = {
    {name = "Dzemael Darkhold", contentId = 1330},
    {name = "The Aurum Vale", contentId = 1331}
}

-- Get current GC rank
local function GetGCRank()
    local gc = Player.GrandCompany
    if gc == 1 then return Player.GCRankMaelstrom
    elseif gc == 2 then return Player.GCRankTwinAdders
    elseif gc == 3 then return Player.GCRankImmortalFlames
    end
    return 0
end

-- Check if a hunt log rank is complete (reads from UI)
-- class: 0-8 for jobs, 9 for GC
-- rank: 0-4 for jobs, 0-2 for GC (0-indexed)
local function IsHuntLogComplete(class, rank)
    -- Open hunt log to the specific class/rank
    yield("/huntinglog")
    Sleep(0.5)

    local addon = Addons.GetAddon("MonsterNote")
    local waitCount = 0
    while (not addon or not addon.Ready) and waitCount < 15 do
        Sleep(0.2)
        addon = Addons.GetAddon("MonsterNote")
        waitCount = waitCount + 1
    end

    if not addon or not addon.Ready then
        Debug("Hunt log not ready")
        return false
    end

    -- Select the class tab (callback to switch)
    yield("/callback MonsterNote true 0 " .. class)
    Sleep(0.5)  -- Wait longer for tab switch

    -- Re-get addon after tab switch
    addon = Addons.GetAddon("MonsterNote")
    Sleep(0.3)

    -- Read the rank completion text (node 33, rank index, child 3)
    -- Format is "X/Y" where X is completed entries, Y is total
    local rankNode = addon:GetNode(33, rank, 3)
    local rankText = rankNode and rankNode.Text or ""

    -- Debug: if empty, try alternate node paths
    if rankText == "" then
        Debug("Node 33," .. rank .. ",3 returned empty, trying alternates...")
        -- Try without child index
        rankNode = addon:GetNode(33, rank)
        if rankNode then
            rankText = rankNode.Text or ""
            Debug("Node 33," .. rank .. " text: " .. rankText)
        end
        -- Try different parent nodes
        for nodeId = 30, 36 do
            local testNode = addon:GetNode(nodeId, rank, 3)
            if testNode and testNode.Text and testNode.Text ~= "" then
                Debug("Found text at node " .. nodeId .. "," .. rank .. ",3: " .. testNode.Text)
            end
        end
    end

    -- Close hunt log
    yield("/callback MonsterNote true -1")
    Sleep(0.2)

    -- Parse "X/Y" format
    local completed, total = rankText:match("(%d+)/(%d+)")
    local classNameDisplay = ClassNames[class] or ("class" .. class)
    if completed and total and completed == total then
        Debug(classNameDisplay .. " rank " .. (rank + 1) .. " is COMPLETE (" .. rankText .. ")")
        return true
    else
        Debug(classNameDisplay .. " rank " .. (rank + 1) .. " incomplete (" .. rankText .. ")")
        return false
    end
end

-- Get the next incomplete GC hunt log rank by checking which mobs are incomplete
-- Uses the same GetIncompleteMobs() logic that already works
local function GetNextIncompleteGCRank()
    local gcRank = GetGCRank()

    -- Get incomplete mobs (reuses the working GetIncompleteMobs logic)
    local incompleteMobs = GetIncompleteMobs()

    if not incompleteMobs or #incompleteMobs == 0 then
        Debug("No incomplete mobs found - all GC ranks complete")
        return nil
    end

    Debug("Found " .. #incompleteMobs .. " incomplete mobs, determining rank...")

    -- Check which rank has incomplete mobs by looking at the mob names
    -- We need to check against the GC dungeon data to see which rank needs dungeons
    for _, mob in ipairs(incompleteMobs) do
        local loc = mobLookup[mob.name]
        if not loc then
            -- This is a dungeon mob (no overworld location)
            -- Check which dungeon/rank it belongs to by name matching
            Debug("Dungeon mob found: " .. mob.name)
        end
    end

    -- For now, if there are incomplete mobs with no location, determine rank by GC rank
    -- Rank 1 dungeons at GC rank 4, Rank 2 dungeons at GC rank 5-8, Rank 3 at 9+
    if gcRank < 5 then
        return 1
    elseif gcRank < 9 then
        return 2
    else
        return 3
    end
end

-- Check if rank 8 quest is complete
local function IsRank8QuestComplete()
    local gc = Player.GrandCompany
    if gc == 0 then return false end
    return Quests.IsQuestComplete(GCQuestData.rank8Quests[gc])
end

-- Check if rank 9 quest is complete
local function IsRank9QuestComplete()
    local gc = Player.GrandCompany
    if gc == 0 then return false end
    return Quests.IsQuestComplete(GCQuestData.rank9Quests[gc])
end

-- Get the dungeon needed for a specific hunt log rank
local function GetDungeonForRank(rank)
    local gc = Player.GrandCompany
    local data = GCDungeonData[rank]
    if not data then return nil end

    -- Immortal Flames uses Cutter's Cry for rank 2
    if rank == 2 and gc == 3 then
        return data.flames, data.flamesTerritoryId
    end
    return data.default, data.territoryId
end

-- Check if AutoDuty is available
local function IsAutoDutyAvailable()
    if not IPC.AutoDuty then
        Debug("AutoDuty IPC not available")
        return false
    end
    return true
end

-- Run a dungeon via AutoDuty
local function RunDungeon(dungeonName, contentId)
    if not IsAutoDutyAvailable() then return false end

    Debug("Starting dungeon: " .. dungeonName .. " (content ID " .. tostring(contentId) .. ")")

    -- Check if AutoDuty has a path for this content
    if contentId and IPC.AutoDuty.ContentHasPath then
        local hasPath = IPC.AutoDuty.ContentHasPath(contentId)
        Debug("AutoDuty has path for " .. contentId .. ": " .. tostring(hasPath))
        if not hasPath then
            Debug("WARNING: AutoDuty does not have a path for this dungeon!")
        end
    end

    -- Start AutoDuty for the dungeon using chat command
    -- Format: /autoduty run <mode> <duty_id> <loops>
    if contentId then
        Debug("Using /autoduty run support " .. contentId .. " 1")
        yield("/autoduty run support " .. contentId .. " 1")
    else
        -- Fallback to dungeon name if no content ID
        Debug("No content ID, using dungeon name")
        yield("/autoduty run support \"" .. dungeonName .. "\" 1")
    end
    Sleep(3.0)

    -- Check if AutoDuty started
    if IPC.AutoDuty.IsStopped then
        local isStopped = IPC.AutoDuty.IsStopped()
        Debug("AutoDuty IsStopped: " .. tostring(isStopped))
    end

    -- Wait for duty to start
    local waitCount = 0
    while not Svc.Condition[34] and waitCount < 120 do  -- Condition 34 = In Duty
        Sleep(1.0)
        waitCount = waitCount + 1
        if waitCount % 30 == 0 then
            Debug("Waiting for duty queue... (" .. waitCount .. "s)")
        end
    end

    if not Svc.Condition[34] then
        Debug("Failed to enter dungeon")
        return false
    end

    Debug("Entered dungeon, AutoDuty running...")

    -- Wait for duty to complete
    while Svc.Condition[34] or Svc.Condition[56] do  -- 34=InDuty, 56=InDutyQueue
        Sleep(5.0)
    end

    -- Wait for zone transition
    Sleep(3.0)
    while not Player.Available do
        Sleep(0.5)
    end

    Debug("Dungeon complete!")
    return true
end

-- Start a quest via Questionable
-- questId: Game quest ID (for completion check)
-- qstId: Questionable internal quest ID (for /qst command)
-- questName: Quest name (for logging)
local function StartQuestViaQuestionable(questId, qstId, questName)
    Debug("StartQuestViaQuestionable: game ID=" .. questId .. ", qst ID=" .. tostring(qstId) .. " (" .. (questName or "no name") .. ")")

    if Quests.IsQuestComplete(questId) then
        Debug("Quest " .. questId .. " already complete")
        return true
    end

    -- Check if we have a Questionable quest ID
    if not qstId then
        Debug("No Questionable quest ID provided for " .. (questName or questId) .. " - cannot proceed")
        return false
    end

    -- Check if Questionable IPC is available (safely)
    local hasQuestionable = pcall(function() return IPC.Questionable end)
    if not hasQuestionable or not IPC.Questionable then
        Debug("Questionable plugin not available - cannot start quest " .. questId)
        return false
    end

    -- Set the quest for Questionable using IPC with Questionable's ID
    Debug("Setting quest priority via IPC with qstId " .. qstId)
    local success, err = pcall(function()
        IPC.Questionable.AddQuestPriority(tostring(qstId))
    end)
    if success then
        Debug("AddQuestPriority called successfully")
    else
        Debug("AddQuestPriority failed: " .. tostring(err) .. " - falling back to /qst next")
        yield("/qst next " .. qstId)
    end
    Sleep(0.5)

    Debug("Starting Questionable...")
    yield("/qst start")
    Sleep(2.0)

    -- Verify Questionable started (safely)
    local isRunning = pcall(function() return IPC.Questionable.IsRunning() end)
    if not isRunning then
        Debug("Questionable did not start, retrying...")
        yield("/qst reload")
        Sleep(1.0)
        yield("/qst start")
        Sleep(2.0)
    end

    -- Wait for Questionable to complete the quest
    local waitCount = 0
    local maxWait = 600  -- 10 minutes max
    while waitCount < maxWait do
        -- Check if quest is complete
        if Quests.IsQuestComplete(questId) then
            Debug("Quest " .. questId .. " complete!")
            -- Stop Questionable and wait for it to fully stop
            yield("/qst stop")
            Sleep(1.0)
            -- Verify it stopped
            local stopWait = 0
            while IPC.Questionable.IsRunning() and stopWait < 10 do
                Debug("Waiting for Questionable to stop...")
                yield("/qst stop")
                Sleep(1.0)
                stopWait = stopWait + 1
            end
            Debug("Questionable stopped, ready for dungeon")
            return true
        end

        -- Check if Questionable is still running
        if not IPC.Questionable.IsRunning() then
            Debug("Questionable stopped unexpectedly, restarting...")
            yield("/qst start")
            Sleep(2.0)
        end

        Sleep(5.0)
        waitCount = waitCount + 5
        if waitCount % 60 == 0 then
            Debug("Quest in progress... (" .. waitCount .. "s)")
        end
    end

    Debug("Quest " .. questId .. " timed out")
    -- Stop Questionable
    yield("/qst stop")
    Sleep(1.0)
    local stopWait = 0
    while IPC.Questionable.IsRunning() and stopWait < 10 do
        yield("/qst stop")
        Sleep(1.0)
        stopWait = stopWait + 1
    end
    return false
end

-- Do GC dungeon for current hunt log rank
local function DoGCDungeon(rank)
    local gc = Player.GrandCompany
    local data = GCDungeonData[rank]
    if not data then
        Debug("No dungeon data for rank " .. rank)
        return false
    end

    -- Get dungeon name, content ID, and unlock quest based on GC
    local dungeonName, contentId, unlockQuest, unlockQuestQst, unlockQuestName
    if rank == 2 and gc == 3 then  -- Immortal Flames rank 2
        dungeonName = data.flames
        contentId = data.flamesContentId
        unlockQuest = data.flamesUnlockQuest
        unlockQuestQst = data.flamesUnlockQuestQst
        unlockQuestName = data.flamesUnlockQuestName
    else
        dungeonName = data.default
        contentId = data.contentId
        unlockQuest = data.unlockQuest
        unlockQuestQst = data.unlockQuestQst
        unlockQuestName = data.unlockQuestName
    end

    -- Check if dungeon is unlocked
    Debug("Checking unlock quest " .. tostring(unlockQuest) .. " (" .. (unlockQuestName or "?") .. ")")
    if unlockQuest then
        local isComplete = Quests.IsQuestComplete(unlockQuest)
        Debug("Quest " .. unlockQuest .. " complete: " .. tostring(isComplete))
        if not isComplete then
            Debug("Dungeon " .. dungeonName .. " not unlocked, starting unlock quest...")
            local unlockSuccess = StartQuestViaQuestionable(unlockQuest, unlockQuestQst, unlockQuestName)
            if not unlockSuccess then
                Debug("Failed to complete unlock quest")
                return false
            end
        else
            Debug("Dungeon already unlocked, skipping Questionable")
        end
    else
        Debug("No unlock quest required for " .. dungeonName)
    end

    Debug("GC Dungeon for rank " .. rank .. ": " .. dungeonName)
    return RunDungeon(dungeonName, contentId)
end

-- Check what's blocking GC rank up
local function CheckRankUpRequirements()
    local gc = Player.GrandCompany
    local rank = GetGCRank()
    local nextRank = rank + 1

    Debug("Current GC: " .. gc .. ", Rank: " .. rank .. ", Next: " .. nextRank)

    if nextRank == 5 then
        -- Need hunt log 1 complete
        Debug("Rank 5 requires GC hunt log 1 complete")
    elseif nextRank == 8 then
        if not IsRank8QuestComplete() then
            Debug("Rank 8 requires 'Shadows Uncast' quest (ID: " .. GCQuestData.rank8Quests[gc] .. ")")
            return false, "rank8quest"
        end
    elseif nextRank == 9 then
        if not IsRank9QuestComplete() then
            Debug("Rank 9 requires 'Gilding the Bilious' quest (ID: " .. GCQuestData.rank9Quests[gc] .. ")")
            return false, "rank9quest"
        end
        -- Also need hunt log 2 complete
        Debug("Rank 9 also requires GC hunt log 2 complete")
    end

    return true, nil
end

-- Do extra dungeons (Dzemael Darkhold / Aurum Vale) for rank 9
local function DoExtraDungeons()
    local gc = Player.GrandCompany
    local extraQuestIds = GCQuestData.extraQuests[gc]

    for i, dungeon in ipairs(ExtraDungeons) do
        local questId = extraQuestIds[i]
        if not Quests.IsQuestComplete(questId) then
            Debug("Need to complete: " .. dungeon.name .. " (Quest " .. questId .. ")")

            -- Start quest if not accepted
            if not Quests.IsQuestAccepted(questId) then
                StartQuestViaQuestionable(questId)
            end

            -- Run the dungeon
            RunDungeon(dungeon.name, dungeon.contentId)
        else
            Debug(dungeon.name .. " quest already complete")
        end
    end
end

-------------------------------------------------
-- MAIN LOOP
-------------------------------------------------
Debug("Starting hunt log automation...")

local totalKills = 0
local mobsCompleted = 0

while true do
    -- Get current incomplete mobs
    local incompleteMobs = GetIncompleteMobs()

    if not incompleteMobs or #incompleteMobs == 0 then
        Debug("All hunt log entries complete!")
        break
    end


    -- Find first mob with known location
    local targetMob = nil
    local targetLocation = nil

    for _, mob in ipairs(incompleteMobs) do
        local loc = mobLookup[mob.name]
        if loc then
            targetMob = mob
            targetLocation = loc
            break
        else
        end
    end

    if not targetMob then
        Debug("No mobs with known locations remaining")
        break
    end

    Debug("")
    Debug("=== Target: " .. targetMob.name .. " [" .. targetMob.current .. "/" .. targetMob.total .. "] ===")

    -- Navigate to spawn
    if not NavigateTo(targetLocation, targetMob.name) then
        Debug("Navigation failed, skipping...")
    else
        -- Kill mobs
        local kills = KillMobs(targetMob.name, targetMob.remaining)
        totalKills = totalKills + kills
        if kills >= targetMob.remaining then
            mobsCompleted = mobsCompleted + 1
        end
    end

    Sleep(1.0)
end

Debug("")
Debug("=== Overworld Hunting Complete ===")
Debug("Mobs completed: " .. mobsCompleted)
Debug("Total kills: " .. totalKills)

-------------------------------------------------
-- GC DUNGEON PHASE
-------------------------------------------------
-- Only runs for GC hunt logs when Settings.do_dungeons is enabled

if Settings.hunt_type == "gc" and Settings.do_dungeons and Player.GrandCompany > 0 then
    Debug("")
    Debug("=== Checking GC Dungeon Requirements ===")

    local incompleteRank = GetNextIncompleteGCRank()

    if incompleteRank and (not Settings.stop_at_rank_two or incompleteRank <= 2) then
        Debug("GC hunt log rank " .. incompleteRank .. " still incomplete, checking dungeon...")

        -- DoGCDungeon handles unlock quests and running the dungeon
        local success = DoGCDungeon(incompleteRank)
        if success then
            Debug("Dungeon complete!")
        else
            Debug("Dungeon failed or was skipped")
        end
    else
        if incompleteRank then
            Debug("GC rank " .. incompleteRank .. " incomplete but stop_at_rank_two is enabled")
        else
            Debug("All accessible GC hunt log ranks complete!")
        end
    end
end

-------------------------------------------------
-- GC RANK UP PHASE
-------------------------------------------------
if Settings.hunt_type == "gc" and Settings.do_rankup and Player.GrandCompany > 0 then
    Debug("")
    Debug("=== Checking GC Rank Up ===")
    local canRankUp, blocker = CheckRankUpRequirements()
    if canRankUp then
        Debug("Ready to rank up! (Manual rank-up required for now)")
        -- TODO: Implement auto rank-up via GC officer
    else
        Debug("Cannot rank up yet: " .. (blocker or "unknown blocker"))
    end
end

-------------------------------------------------
-- EXTRA DUNGEONS (Rank 9)
-------------------------------------------------
if Settings.do_extra_dungeons and Player.GrandCompany > 0 then
    local gcRank = GetGCRank()

    -- Only do extra dungeons if we're at rank 9+ (rank 2 log must be complete to reach rank 9)
    if gcRank >= 9 then
        Debug("")
        Debug("=== Extra Dungeons for Rank 9 ===")
        DoExtraDungeons()
    end
end

Debug("")
Debug("=== AutoHuntLog Complete ===")
