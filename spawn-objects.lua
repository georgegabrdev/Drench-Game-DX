--
-- - Because of sm64coopdxn limits, max 1200 objects can be spawned, included
-- the one already spawned with the map
-- - Submarine center is at the right of visible object position, so a special
-- function is needed to delete it

-- Parameters
local COOLDOWN_FRAMES = 50
local COOLDOWN_FRAMES_DEL
if network_is_server() then
	COOLDOWN_FRAMES_DEL = 10
else
	COOLDOWN_FRAMES_DEL = 20
end

local SPEED_MULTIPLIER = 5.0 -- Adjusts object spawn position based on Mario speed

-- local TARGET_LEVEL = LEVEL_BOB
-- local TARGET_LEVEL = LEVEL_RR
local TARGET_LEVEL = LEVEL_CASTLE_GROUNDS
local TARGET_AREA = 1
local TARGET_WARP = 0
local PACKET_DELOBJ = 0
local PACKET_DELALL = 1
local usedPlayerIds = {}
local next_object_id = 1 -- id of tracked objects
local recentObjs = {}
local MAX_RECENT = 25

local spawnMenu = false

local amt = 1
local MAX_AMOUNT = 999

-- List of object lists
local lists = {
	OBJ_LIST_DESTRUCTIVE,
	OBJ_LIST_GENACTOR,
	OBJ_LIST_PUSHABLE, -- Goombas, Koopas, etc.
	OBJ_LIST_LEVEL,
	OBJ_LIST_DEFAULT, -- Lots of generic powerups, platforms, hazards, and misc are here
	OBJ_LIST_SURFACE, -- Thwomp, Dorrie, Submarine, many platforms
	OBJ_LIST_POLELIKE, -- Trees, Tweester, etc.
	OBJ_LIST_SPAWNER, -- objects whose job is to spawn other things (coin formations, tumbling bridge pieces, etc.)
	-- OBJ_LIST_UNIMPORTANT,
}

-- This two together form the id of an object
define_custom_obj_fields({
	oModPlayerId = "u32",
	oModObjNum = "u32",
	-- oModLvlNum = "u32",
})

-- Menu: allow guest object deletion
gGlobalSyncTable.allowGuestDeletion = true
local function on_guest_deletion_toggle(index, value)
	if network_is_server() then
		gGlobalSyncTable.allowGuestDeletion = value
	end
end
if network_is_server() then
	--hook_mod_menu_checkbox("Allow Guest Object Deletion", true, on_guest_deletion_toggle)
end

-- Menu: spawn objects always upright?
local spawnObjectsUpright = mod_storage_load_bool("spawn_objects_upright") or true
local function onUprightToggle(index, value)
	spawnObjectsUpright = value
	mod_storage_save_bool("spawn_objects_upright", value)
end
--hook_mod_menu_checkbox("Spawn Objects Upright", spawnObjectsUpright, onUprightToggle)

-- Menu: Changes control scheme so that it does not use DPAD up and down
if network_is_server() then
	if gGlobalSyncTable.dpadUDFree == nil then
		gGlobalSyncTable.dpadUDFree = false
	end

	-- hook_mod_menu_checkbox("Free buttons DPAD up and down", false, function(index, value)
	--hook_mod_menu_checkbox("Free buttons DPAD up and down", gGlobalSyncTable.dpadUDFree, function(index, value)
	-- gGlobalSyncTable.dpadUDFree = value
	-- end)
end
-- This sends a notification to infrom of controls change
hook_on_sync_table_change(gGlobalSyncTable, "dpadUDFree", "dpadUDFree", function(tag, oldVal, newVal)
	if oldVal ~= nil and newVal ~= oldVal then
		djui_popup_create(translate("host_changed_control_scheme"), 2)
	end
end)

-- Menu: Disable cooldown for all players
-- This mod already disables cooldown when only host connected, this option
-- always removes cooldown where other players connected.
-- WARNING: connected players may abuse leading to server crash or all-players
-- lag
if network_is_server() then
	if gGlobalSyncTable.noCooldown == nil then
		gGlobalSyncTable.noCooldown = false
	end

	gGlobalSyncTable.noCooldown = true

	-- hook_mod_menu_checkbox("No cooldown for all players (WARNING: players may abuse)", gGlobalSyncTable.noCooldown, function(index, value)
	-- gGlobalSyncTable.noCooldown = value
	-- end)
end

-- Menu categories and subcategories
local categories = {
	{
		name = "Recents",
		items = recentObjs,
	},
	{
		name = "Powerups",
		items = {
			{
				behavior = id_bhvKoopaShell,
				model = E_MODEL_KOOPA_SHELL,
				name = "Shell",
				spawnOffset = 0,
				spawnYaw = 0,
				spawnPitch = 0,
				spawnRoll = 0,
			},
			{ behavior = id_bhvRecoveryHeart, model = E_MODEL_HEART, name = "Recovery Heart", spawnYOffset = 100 },
			{ name = "Ten coins spawn", model = E_MODEL_YELLOW_COIN, behavior = id_bhvTenCoinsSpawn },
			{ name = "1UP", behavior = id_bhv1Up, model = E_MODEL_1UP },
			{ behavior = id_bhvWingCap, model = E_MODEL_TOADS_WING_CAP, name = "Wing Cap", spawnOffset = 200 },
			{ behavior = id_bhvMetalCap, model = E_MODEL_TOADS_METAL_CAP, name = "Metal Cap", spawnOffset = 200 },
			{ behavior = id_bhvVanishCap, model = E_MODEL_TOADS_CAP, name = "Vanish Cap", spawnOffset = 200 },
			-- { name = "Jumping 1UP", behavior = id_bhv1upJumpOnApproach, model = E_MODEL_1UP },
			-- {name = "Hidden 1up", model = E_MODEL_1UP, behavior = id_bhvHidden1up},
			{ name = "Hidden 1up pole", model = E_MODEL_1UP, behavior = id_bhvHidden1upInPole },
			{
				name = "Coin formation (front)",
				behavior = id_bhvCoinFormation,
				model = E_MODEL_YELLOW_COIN,
				spawnOffset = 480,
			},
			{
				name = "Coin formation (vertical)",
				behavior = id_bhvCoinFormation,
				model = E_MODEL_YELLOW_COIN,
				spawnYOffset = 0,
				param2nd = 1,
			},
			{
				name = "Coin formation (ring)",
				behavior = id_bhvCoinFormation,
				model = E_MODEL_YELLOW_COIN,
				spawnOffset = 0,
				param2nd = 2,
			},
			{
				name = "Coin formation (ring flying)",
				behavior = id_bhvCoinFormation,
				model = E_MODEL_YELLOW_COIN,
				param2nd = 3,
			},
			{
				name = "Coin formation (arrow)",
				behavior = id_bhvCoinFormation,
				model = E_MODEL_YELLOW_COIN,
				spawnOffset = 300,
				param2nd = 4,
			},
			{ name = "Red coin", model = E_MODEL_RED_COIN, behavior = id_bhvRedCoin },
			{ name = "Blue coin jumping", behavior = id_bhvBlueCoinJumping, model = E_MODEL_BLUE_COIN },
			{ name = "Blue coin sliding", behavior = id_bhvBlueCoinSliding, model = E_MODEL_BLUE_COIN },
			{ name = "Marios cap", model = E_MODEL_MARIOS_CAP, behavior = id_bhvNormalCap },
		},
	},
	{
		name = "Platforms",
		items = {
			{
				name = "Wood piece",
				model = E_MODEL_LLL_WOOD_BRIDGE,
				behavior = id_bhvLllWoodPiece,
				spawnYOffset = -100,
			},
			{
				behavior = id_bhvTweester,
				model = E_MODEL_TWEESTER,
				name = "Tweester",
				spawnOffset = 0,
				spawnYOffset = 0,
				spawnYaw = 0,
				spawnPitch = 0,
				spawnRoll = 0,
			},
			{
				name = "Sinking rock block",
				model = E_MODEL_LLL_SINKING_ROCK_BLOCK,
				behavior = id_bhvLllSinkingRockBlock,
				spawnOffset = 200,
				spawnYOffset = -200,
			},
			{
				name = "WDW platform (non rotating)",
				model = E_MODEL_WDW_ROTATING_PLATFORM,
				behavior = id_bhvRotatingPlatform,
				spawnYOffset = -250,
				param2nd = 1,
			},
			{
				name = "Floor trap",
				model = E_MODEL_CASTLE_BOWSER_TRAP,
				behavior = id_bhvFloorTrapInCastle,
				spawnLateralOffset = 180,
			},
			{
				behavior = id_bhvKickableBoard,
				model = E_MODEL_WF_KICKABLE_BOARD,
				name = "Kickable Board",
				-- spawnYOffset = -30,
				spawnYaw = 32768,
			},
			{
				behavior = id_bhvKickableBoard,
				model = E_MODEL_WF_KICKABLE_BOARD,
				name = "Kickable Board (kicked)",
				oAction = 2,
				spawnYaw = 32768,
			},
			{
				behavior = id_bhvKickableBoard,
				model = E_MODEL_WF_KICKABLE_BOARD,
				name = "Kickable Board (unkickable)",
				oAction = 3,
				spawnYaw = 32768,
			},
			{
				behavior = id_bhvTree,
				model = E_MODEL_BUBBLY_TREE,
				name = "Tree",
				spawnOffset = 250,
				spawnYOffset = -100,
			},
			{ name = "Spiky tree", model = E_MODEL_COURTYARD_SPIKY_TREE, behavior = id_bhvTree, spawnYOffset = -100 },
			{ name = "Palm tree", model = E_MODEL_PALM_TREE, behavior = id_bhvTree, spawnYOffset = -100 },
			{ name = "Snow tree", model = E_MODEL_SNOW_TREE, behavior = id_bhvTree, spawnYOffset = -100 },
			{
				name = "Koopa flag",
				model = E_MODEL_KOOPA_FLAG,
				behavior = id_bhvKoopaFlag,
				spawnOffset = 200,
				spawnYOffset = 20,
			},
			-- Koopa flag always goes on the ground, so i make it spawn higher
			-- {name = "Koopa race endpoint", model = E_MODEL_KOOPA_FLAG, behavior = id_bhvKoopaRaceEndpoint},
			{
				name = "Sliding platform (Bits)",
				model = E_MODEL_BITS_SLIDING_PLATFORM,
				behavior = id_bhvSlidingPlatform2,
				spawnOffset = 120,
				spawnYOffset = -300,
				spawnYaw = 16384,
			},
			{
				name = "Arrow Platform still (BitS)",
				behavior = id_bhvActivatedBackAndForthPlatform,
				model = E_MODEL_BITS_ARROW_PLATFORM,
				spawnOffset = 200,
				spawnYOffset = -200,
				spawnYaw = 16384,
			},
			-- Bugged hitbox
			-- {
			--     name = "Sliding platform (RR)",
			--     model = E_MODEL_RR_SLIDING_PLATFORM,
			--     behavior = id_bhvSlidingPlatform2,
			--     spawnYOffset = -300,
			-- },
			{ name = "Pyramid top", model = E_MODEL_SSL_PYRAMID_TOP, behavior = id_bhvPyramidTop },
			{
				name = "Floating platform (JRB)",
				model = E_MODEL_JRB_FLOATING_PLATFORM,
				behavior = id_bhvJrbFloatingPlatform,
			},
			{
				name = "Floating platform (WDW)",
				model = E_MODEL_WDW_RECTANGULAR_FLOATING_PLATFORM,
				behavior = id_bhvWdwRectangularFloatingPlatform,
			},
			{
				name = "Floating platform square (WDW)",
				model = E_MODEL_WDW_SQUARE_FLOATING_PLATFORM,
				behavior = id_bhvWdwSquareFloatingPlatform,
			},
			{
				name = "Staircase step",
				model = E_MODEL_BBH_STAIRCASE_STEP,
				behavior = id_bhvHiddenStaircaseStep,
				spawnOffset = 250,
				spawnYOffset = -350,
			},
			{
				name = "WDW express el platform",
				model = E_MODEL_WDW_EXPRESS_ELEVATOR,
				behavior = id_bhvWdwExpressElevatorPlatform,
				spawnOffset = 0,
				spawnYOffset = -200,
			},
			{
				name = "Checkered platform",
				model = E_MODEL_CHECKERBOARD_PLATFORM,
				behavior = id_bhvStaticCheckeredPlatform,
				spawnOffset = 100,
				spawnYOffset = -100,
			},
			-- Bugged, wrong hitbox
			-- {
			--     name = "Sliding platform (WF)",
			--     model = E_MODEL_WF_TOWER_SQUARE_PLATORM,
			--     behavior = id_bhvWfSlidingPlatform,
			-- },
			{ name = "Pillar base", model = E_MODEL_JRB_FALLING_PILLAR_BASE, behavior = id_bhvPillarBase },
			{
				name = "THI island top",
				model = E_MODEL_THI_HUGE_ISLAND_TOP,
				behavior = id_bhvThiHugeIslandTop,
				spawnYOffset = -100,
				spawnOffset = 50,
			},
		},
	},
	{
		name = "Platforms Moving",
		items = {
			-- Owls disabled because when they go way up, Mario can get stuck in interaction
			-- { behavior = id_bhvHoot, model = E_MODEL_HOOT,name = "Owl", spawnOffset = 0, action = 1},
			{
				name = "Bitfs Tilting inverted pyramid",
				behavior = id_bhvBitfsTiltingInvertedPyramid,
				model = E_MODEL_BITFS_TILTING_SQUARE_PLATFORM,
				spawnYOffset = -300,
			},
			{
				name = "LLL Tilting inverted pyramid",
				model = E_MODEL_LLL_TILTING_SQUARE_PLATFORM,
				behavior = id_bhvLllTiltingInvertedPyramid,
				spawnYOffset = -300,
			},
			{
				behavior = id_bhvSeesawPlatform,
				model = E_MODEL_BITDW_SEESAW_PLATFORM,
				name = "Seesaw BitDW",
				spawnOffset = 200,
				spawnYOffset = -60,
				param2nd = 0,
			},
			{
				behavior = id_bhvSeesawPlatform,
				model = E_MODEL_BITFS_SEESAW_PLATFORM,
				name = "Seesaw BitFS",
				spawnOffset = 200,
				spawnYOffset = -200,
				spawnYaw = 16384,
				param2nd = 4,
			},
			{
				name = "Seesaw RR",
				model = E_MODEL_RR_SEESAW_PLATFORM,
				behavior = id_bhvSeesawPlatform,
				spawnYOffset = -60,
				param2nd = 5,
			},
			{
				name = "Seesaw BOB",
				model = E_MODEL_BOB_SEESAW_PLATFORM,
				behavior = id_bhvSeesawPlatform,
				spawnYOffset = -100,
				param2nd = 3,
			},
			{
				name = "Seesaw Bits",
				model = E_MODEL_BITS_SEESAW_PLATFORM,
				behavior = id_bhvSeesawPlatform,
				spawnYOffset = -100,
				param2nd = 1,
			},
			{
				name = "Moving Pyramid",
				behavior = id_bhvSquarishPathMoving,
				model = E_MODEL_BITDW_SQUARE_PLATFORM,
				spawnOffset = 40,
				spawnYOffset = -80,
			},
			{
				behavior = id_bhvLllDrawbridge,
				model = E_MODEL_LLL_DRAWBRIDGE_PART,
				name = "Drawbridge",
				spawnOffset = -100,
				spawnYOffset = -150,
				spawnYaw = 16384,
				spawnPitch = 0,
			},
			{
				behavior = id_bhvTTCRotatingSolid,
				model = E_MODEL_TTC_ROTATING_CUBE,
				name = "Rotating Cube (TTC)",
				spawnOffset = 120,
				spawnYOffset = -270,
			},
			{
				behavior = id_bhvTTCRotatingSolid,
				model = E_MODEL_TTC_ROTATING_PRISM,
				name = "Rotating Prism (TTC)",
				spawnOffset = 120,
				spawnYOffset = -270,
				param2nd = 1,
			},
			{
				name = "Rotating hexagon (TTC)",
				model = E_MODEL_TTC_ROTATING_HEXAGON,
				behavior = id_bhvTTCCog,
				spawnOffset = 150,
				spawnYOffset = -50,
			},
			{
				name = "Rotating triangle (TTC)",
				model = E_MODEL_TTC_ROTATING_TRIANGLE,
				behavior = id_bhvTTCCog,
				spawnYaw = 32768,
				param2nd = 2,
			},
			{ name = "Treadmill (TTC)", model = E_MODEL_TTC_LARGE_TREADMILL, behavior = id_bhvTTCTreadmill },
			{
				name = "Treadmill small (TTC)",
				model = E_MODEL_TTC_SMALL_TREADMILL,
				behavior = id_bhvTTCTreadmill,
				param2nd = 1,
			},
			{ behavior = id_bhvTTCSpinner, model = E_MODEL_TTC_SPINNER, name = "Spinner (TTC)", spawnOffset = 0 },
			{
				behavior = id_bhvTTC2DRotator,
				model = E_MODEL_TTC_CLOCK_HAND,
				name = "Clock Hand (TTC)",
				spawnOffset = 0,
				spawnYOffset = -60,
			},
			{
				name = "Moving octagon",
				model = E_MODEL_LLL_MOVING_OCTAGONAL_MESH_PLATFORM,
				behavior = id_bhvLllMovingOctagonalMeshPlatform,
				spawnOffset = 200,
				spawnYOffset = -200,
			},
			{
				name = "Tilting floor platform",
				behavior = id_bhvBbhTiltingTrapPlatform,
				model = E_MODEL_BBH_TILTING_FLOOR_PLATFORM,
				spawnYOffset = -200,
			},
			{
				behavior = id_bhvDonutPlatform,
				model = E_MODEL_RR_DONUT_PLATFORM,
				name = "Donut Platform",
				spawnOffset = 200,
				spawnYOffset = -200,
			},
			{
				name = "Checkerboard elevator (swings)",
				behavior = id_bhvCheckerboardPlatformSub,
				model = E_MODEL_CHECKERBOARD_PLATFORM,
				spawnOffset = 140,
				spawnYOffset = -200,
			},
			{ name = "Ferris wheel", model = E_MODEL_BITS_FERRIS_WHEEL_AXLE, behavior = id_bhvFerrisWheelAxle },
			{
				name = "HMC elevator platform",
				model = E_MODEL_HMC_ELEVATOR_PLATFORM,
				behavior = id_bhvHmcElevatorPlatform,
				spawnOffset = 0,
				spawnYOffset = -80,
			},
			{
				name = "RR elevator platform",
				model = E_MODEL_RR_ELEVATOR_PLATFORM,
				behavior = id_bhvRrElevatorPlatform,
			},
			{
				name = "Mesh elevator",
				model = E_MODEL_BBH_MESH_ELEVATOR,
				behavior = id_bhvMeshElevator,
				spawnOffset = 200,
				spawnYOffset = -50,
			},
			{
				behavior = id_bhvCheckerboardElevatorGroup,
				model = E_MODEL_CHECKERBOARD_PLATFORM,
				name = "Checkerboard Elevator Group",
				spawnYOffset = -80,
			},
			{
				name = "WDW express elevator",
				model = E_MODEL_WDW_EXPRESS_ELEVATOR,
				behavior = id_bhvWdwExpressElevator,
				spawnOffset = 0,
				spawnYOffset = -200,
			},
			{
				name = "Sinking cage platform",
				behavior = id_bhvBitfsSinkingCagePlatform,
				model = E_MODEL_BITFS_SINKING_CAGE_PLATFORM,
				spawnOffset = 200,
				spawnYOffset = -150,
				param2nd = 1,
			},
			{
				name = "TTC elevator",
				model = E_MODEL_TTC_ELEVATOR_PLATFORM,
				behavior = id_bhvTTCElevator,
				spawnOffset = 0,
				spawnYOffset = -100,
			},
			{
				name = "Controllable platform",
				behavior = id_bhvControllablePlatform,
				model = E_MODEL_HMC_METAL_PLATFORM,
				spawnYOffset = -100,
			},
			{
				name = "Arrow lift",
				behavior = id_bhvArrowLift,
				model = E_MODEL_WDW_ARROW_LIFT,
				spawnOffset = 0,
				spawnYOffset = -200,
			},
			-- Disable because no one will use these
			-- {
			--     name = "TTC push block",
			--     model = E_MODEL_TTC_PUSH_BLOCK,
			--     behavior = id_bhvTTCMovingBar,
			--     spawnOffset = 300,
			--     spawnYOffset = -200,
			-- },
			-- {
			--     name = "TTC pit block",
			--     model = E_MODEL_TTC_PIT_BLOCK,
			--     behavior = id_bhvTTCPitBlock,
			--     spawnYOffset = -300,
			-- },
			-- Disabled because sometimes Mario gets teleported way out of bounds
			-- {name = "Pyramid elevator", model = E_MODEL_SSL_PYRAMID_ELEVATOR, behavior = id_bhvPyramidElevator},
		},
	},
	{
		name = "Platforms Big",
		items = {
			-- Logs get pitch ~= 0 when saved
			{
				behavior = id_bhvTtmRollingLog,
				model = E_MODEL_TTM_ROLLING_LOG,
				name = "Log TTM (parallel)",
				spawnYOffset = -250,
			},
			{
				behavior = id_bhvTtmRollingLog,
				model = E_MODEL_TTM_ROLLING_LOG,
				name = "Log TTM (perpendicular)",
				spawnOffset = 700,
				spawnYOffset = -250,
				spawnYaw = 16384,
			},
			{
				name = "Log LLL (parallel)",
				model = E_MODEL_LLL_ROLLING_LOG,
				behavior = id_bhvLllRollingLog,
				spawnYOffset = -250,
			},
			{
				name = "Log LLL (perpendicular)",
				model = E_MODEL_LLL_ROLLING_LOG,
				behavior = id_bhvLllRollingLog,
				spawnOffset = 700,
				spawnYOffset = -250,
				spawnYaw = 16384,
			},
			{
				behavior = id_bhvBitfsSinkingPlatforms,
				model = E_MODEL_BITFS_SINKING_PLATFORMS,
				name = "Sinking Platform",
				spawnOffset = 0,
				spawnYOffset = -100,
			},
			{
				name = "Sinking rectangular platform",
				model = E_MODEL_LLL_SINKING_RECTANGULAR_PLATFORM,
				behavior = id_bhvLllSinkingRectangularPlatform,
			},
			{
				name = "Sinking square platforms",
				model = E_MODEL_LLL_SINKING_SQUARE_PLATFORMS,
				behavior = id_bhvLllSinkingSquarePlatforms,
			},
			{
				name = "Octagonal platform (Bits)",
				model = E_MODEL_BITS_OCTAGONAL_PLATFORM,
				behavior = id_bhvOctagonalPlatformRotating,
				spawnYOffset = -300,
			},
			{
				name = "Octagonal platform (RR)",
				model = E_MODEL_RR_OCTAGONAL_PLATFORM,
				behavior = id_bhvOctagonalPlatformRotating,
				spawnYOffset = -300,
				param2 = 1,
			},
			{
				name = "Seesaw S-shaped",
				model = E_MODEL_BITS_TILTING_W_PLATFORM,
				behavior = id_bhvSeesawPlatform,
				spawnOffset = 1000,
				spawnYOffset = -300,
				spawnLateralOffset = 250,
				spawnYaw = 16384,
				-- spawnYaw = -16384,
				param2nd = 2,
			},
			{
				name = "Rotating bridge platform (RR)",
				model = E_MODEL_RR_ROTATING_BRIDGE_PLATFORM,
				behavior = id_bhvRrRotatingBridgePlatform,
				spawnYOffset = -700,
			},
			{
				behavior = id_bhvSwingPlatform,
				model = E_MODEL_RR_SWINGING_PLATFORM,
				name = "Swing",
				spawnOffset = 700,
				spawnYOffset = 400,
				spawnLateralOffset = 200,
				spawnYaw = 16384,
			},
			{
				behavior = id_bhvSquishablePlatform,
				model = E_MODEL_BITFS_STRETCHING_PLATFORMS,
				name = "Stretching Platforms",
				spawnOffset = 0,
				spawnYOffset = -120,
				spawnYaw = 16384,
			},
			{
				name = "Merry go round",
				model = E_MODEL_BBH_MERRY_GO_ROUND,
				behavior = id_bhvMerryGoRound,
				spawnOffset = 300,
			},
			-- {name = "Koopa race endpoint", model = E_MODEL_KOOPA_FLAG, behavior = id_bhvKoopaRaceEndpoint},
			{
				behavior = id_bhvBowsersSub,
				model = E_MODEL_DDD_BOWSER_SUB,
				name = "Submarine (perpendicular)",
				spawnOffset = 1600,
				spawnYOffset = -600,
				spawnLateralOffset = 4000,
				cooldown_multiplier = 2,
			},
			{
				behavior = id_bhvBowsersSub,
				model = E_MODEL_DDD_BOWSER_SUB,
				name = "Submarine (parallel)",
				-- spawnOffset = 1800,
				spawnYOffset = -600,
				spawnYaw = 16384,
				spawnOffset = 4200,
				spawnLateralOffset = 300,
				cooldown_multiplier = 2,
			},
			{
				behavior = id_bhvLllRotatingHexagonalRing,
				model = E_MODEL_LLL_ROTATING_HEXAGONAL_RING,
				name = "Rotating Hexagon (LLL)",
				spawnOffset = 1600,
				spawnYOffset = -300,
				cooldown_multiplier = 2,
			},
			{
				behavior = id_bhvDorrie,
				model = E_MODEL_DORRIE,
				name = "Sea Dragon (Dorrie)",
				spawnOffset = -1100,
				spawnYOffset = -400,
			},
			{
				name = "JRB ship (perpendicular)",
				behavior = id_bhvInSunkenShip3,
				parts = {
					-- no behavior means the parent behavior will be used
					{ model = E_MODEL_JRB_SHIP_LEFT_HALF_PART },
					{ model = E_MODEL_JRB_SHIP_BACK_LEFT_PART },
					{ model = E_MODEL_JRB_SHIP_RIGHT_HALF_PART },
					{ model = E_MODEL_JRB_SHIP_BACK_RIGHT_PART },
				},
				spawnYOffset = -1400,
				cooldown_multiplier = 3,
			},
			{
				name = "JRB ship (parallel)",
				behavior = id_bhvInSunkenShip3,
				parts = {
					-- no behavior means the parent behavior will be used
					{ model = E_MODEL_JRB_SHIP_LEFT_HALF_PART },
					{ model = E_MODEL_JRB_SHIP_BACK_LEFT_PART },
					{ model = E_MODEL_JRB_SHIP_RIGHT_HALF_PART },
					{ model = E_MODEL_JRB_SHIP_BACK_RIGHT_PART },
				},
				spawnYOffset = -1400,
				spawnYaw = 16384,
				cooldown_multiplier = 3,
			},
		},
	},
	{
		name = "Hazards",
		items = {
			-- { behavior = id_bhvMontyMoleRock, model = E_MODEL_PEBBLE, name = "Mole rock", spawnOffset = 150 },
			-- { behavior = id_bhvFlameBowser, model = E_MODEL_PEBBLE, name = "Mole rock", spawnOffset = 150 },
			{
				name = "Snow mound",
				model = E_MODEL_SL_SNOW_TRIANGLE,
				behavior = id_bhvSlidingSnowMound,
				spawnYaw = 16384,
			},
			{
				name = "Snow mound pushing you",
				model = E_MODEL_SL_SNOW_TRIANGLE,
				behavior = id_bhvSlidingSnowMound,
				spawnYaw = 16384,
				spawnOffset = -300,
			},
			{ behavior = id_bhvBowserShockWave, model = E_MODEL_BOWSER_WAVE, name = "Shockwave", spawnOffset = 0 },
			{ name = "Explosion", behavior = id_bhvExplosion, model = E_MODEL_EXPLOSION, spawnOffset = 400 },
			{ name = "Wind particle (1)", model = E_MODEL_MIST, behavior = id_bhvStrongWindParticle },
			{
				name = "Snufit ball (1)",
				model = E_MODEL_BOWLING_BALL,
				behavior = id_bhvSnufitBalls,
				spawnOffset = 100,
				spawnYOffset = 80,
			},
			{
				behavior = id_bhvFlame,
				model = E_MODEL_RED_FLAME,
				name = "Red Flame",
				spawnOffset = 200,
				spawnYOffset = 100,
			},
			{ name = "Blue flame", model = E_MODEL_BLUE_FLAME, behavior = id_bhvFlame, spawnYOffset = 100 },
			{
				behavior = id_bhvBigBoulder,
				model = E_MODEL_HMC_ROLLING_ROCK,
				name = "Boulder",
				spawnOffset = 450,
				param2nd = 2,
			},
			{ name = "Bowser flame", model = E_MODEL_RED_FLAME, behavior = id_bhvFlameBowser },
			{
				name = "Bouncing fireball spawn",
				behavior = id_bhvBouncingFireball,
				model = E_MODEL_STAR,
				spawnYOffset = 100,
			},
			-- {name = "Bouncing fireball flame", behavior = id_bhvBouncingFireballFlame, model = E_MODEL_RED_FLAME},
			-- {name = "Moving flames", behavior = id_bhvBetaMovingFlames, model = E_MODEL_RED_FLAME, spawnYOffset = 150},
			-- {name = "Flame bouncing", model = E_MODEL_RED_FLAME, behavior = id_bhvFlameBouncing},
			{
				name = "Flame moving forward growing",
				model = E_MODEL_RED_FLAME,
				behavior = id_bhvFlameMovingForwardGrowing,
			},
			-- On this no yaw, pitch and roll is working. Will always hit the Mario who spawned it
			{ name = "Blue flames group", behavior = id_bhvBlueFlamesGroup, model = E_MODEL_BLUE_FLAME },
			{ behavior = id_bhvThwomp, model = E_MODEL_THWOMP, name = "Thwomp", spawnOffset = 300 },
			-- Don't know the difference with simple Thwomp
			-- { name = "Thwomp 2", model = E_MODEL_THWOMP, behavior = id_bhvThwomp2 },
			{ behavior = id_bhvToxBox, model = E_MODEL_SSL_TOX_BOX, name = "Tox-Box", spawnYOffset = 250 },
			{
				behavior = id_bhvFlamethrower,
				model = E_MODEL_STAR,
				name = "Flamethrower",
				spawnOffset = 200,
				spawnYOffset = 100,
			},
			{
				behavior = id_bhvFlamethrower,
				model = E_MODEL_STAR,
				name = "Flamethrower (upwards)",
				spawnOffset = 200,
				param2nd = 4,
				spawnYOffset = 0,
			},
			{
				behavior = id_bhvFireSpitter,
				model = E_MODEL_BOWLING_BALL,
				name = "Fire Spitter",
				spawnOffset = 200,
				spawnYOffset = 50,
			},
			{
				behavior = id_bhvCirclingAmp,
				model = E_MODEL_AMP,
				name = "Circling Amp",
				spawnOffset = 0,
				spawnYOffset = 50,
			},
			{
				behavior = id_bhvHomingAmp,
				model = E_MODEL_AMP,
				name = "Homing Amp",
				spawnOffset = 300,
				spawnYOffset = 50,
			},
			{ behavior = id_bhvClamShell, model = E_MODEL_CLAM_SHELL, name = "Clam Shell", spawnOffset = 400 },
			{ name = "Bowser bomb", behavior = id_bhvBowserBomb, model = E_MODEL_BOWSER_BOMB, spawnYOffset = 200 },
			-- Always goes in the same direction
			-- { behavior = id_bhvBowlingBall, model = E_MODEL_BOWLING_BALL, name = "Bowling Ball", spawnOffset = 300 },
			{ name = "Bowling ball", model = E_MODEL_BOWLING_BALL, behavior = id_bhvPitBowlingBall },
			{ name = "Bowling ball (still)", model = E_MODEL_BOWLING_BALL, behavior = id_bhvFreeBowlingBall },
			-- hardcoded directions, that's why i commented it
			-- {
			--     name = "Bowling ball spawner",
			--     model = E_MODEL_BOWLING_BALL,
			--     -- behavior = id_bhvThiBowlingBallSpawner,
			--     -- behavior = id_bhvTtmBowlingBallSpawner,
			--     behavior = id_bhvBobBowlingBallSpawner,
			--     spawnYOffset = 150,
			-- },
			{ name = "Grindel", model = E_MODEL_SSL_GRINDEL, behavior = id_bhvGrindel, spawnOffset = 300 },
			{
				behavior = id_bhvHorizontalGrindel,
				model = E_MODEL_SSL_GRINDEL,
				name = "Moving grindel",
				spawnOffset = 400,
			},
			{
				behavior = id_bhvBulletBill,
				model = E_MODEL_BULLET_BILL,
				name = "Bullet Bill spawn",
				spawnOffset = 400,
				spawnYOffset = 110,
			},
			{ behavior = id_bhvLllVolcanoFallingTrap, model = E_MODEL_LLL_VOLCANO_FALLING_TRAP, name = "Wall Trap" },
			{ model = E_MODEL_HAUNTED_CHAIR, behavior = id_bhvHauntedChair, name = "Haunted chair", spawnOffset = 300 },
			{ name = "Cloud", behavior = id_bhvCloud, model = E_MODEL_FWOOSH, spawnYOffset = 100 },
			{
				name = "Falling pillar",
				model = E_MODEL_JRB_FALLING_PILLAR,
				behavior = id_bhvFallingPillar,
				spawnOffset = 400,
			},
			{
				name = "Rotating block with fire",
				model = E_MODEL_LLL_ROTATING_BLOCK_FIRE_BARS,
				behavior = id_bhvLllRotatingBlockWithFireBars,
				spawnOffset = 300,
			},
			{
				name = "JRB sliding box",
				model = E_MODEL_JRB_SLIDING_BOX,
				behavior = id_bhvJrbSlidingBox,
				spawnYOffset = 200,
			},
			{ name = "JRB sliding box (for ship)", model = E_MODEL_JRB_SLIDING_BOX, behavior = id_bhvJrbSlidingBox },
		},
	},
	{
		name = "Enemies",
		items = {
			{ behavior = id_bhvGoomba, model = E_MODEL_GOOMBA, name = "Goomba", spawnOffset = 200 },
			{
				behavior = id_bhvGoomba,
				model = E_MODEL_GOOMBA,
				name = "Goomba (small)",
				spawnOffset = 200,
				param2nd = 2,
			},
			{ name = "Goomba triplet spawner", model = E_MODEL_WOODEN_SIGNPOST, behavior = id_bhvGoombaTripletSpawner },
			{ behavior = id_bhvGoomba, model = E_MODEL_GOOMBA, name = "Goomba (big)", spawnOffset = 300, param2nd = 1 },
			{
				name = "Goomba triplet spawner (big)",
				model = E_MODEL_WOODEN_SIGNPOST,
				behavior = id_bhvGoombaTripletSpawner,
				param2nd = 1,
			},
			-- { name = "Koopa", model = E_MODEL_KOOPA_WITH_SHELL, behavior = id_bhvKoopa, spawnOffset = 200 },
			{ name = "Koopa", model = E_MODEL_KOOPA_WITH_SHELL, behavior = id_bhvKoopa, param2nd = 1 },
			{ name = "Koopa (small)", model = E_MODEL_KOOPA_WITH_SHELL, behavior = id_bhvKoopa, param2nd = 4 },
			{ name = "Bobomb", behavior = id_bhvBobomb, model = E_MODEL_BLACK_BOBOMB, spawnOffset = 100 },
			-- Commented because enemy list is too long
			-- { behavior = id_bhvBobomb, model = E_MODEL_BOBOMB_BUDDY, name = "Bobomb Not-Buddy", spawnOffset = 200 },
			{ behavior = id_bhvSmallBully, model = E_MODEL_BULLY, name = "Bully", spawnOffset = 100 },
			{
				behavior = id_bhvBigBully,
				model = E_MODEL_BULLY_BOSS,
				name = "Bully boss",
				spawnOffset = 400,
				spawnYaw = 32768,
				spawnPitch = 0,
				spawnRoll = 0,
			},
			{ name = "Piranha plant", model = E_MODEL_PIRANHA_PLANT, behavior = id_bhvPiranhaPlant },
			{ name = "Piranha plant fire (small)", model = E_MODEL_PIRANHA_PLANT, behavior = id_bhvFirePiranhaPlant },
			{
				name = "Piranha plant fire (big)",
				model = E_MODEL_PIRANHA_PLANT,
				behavior = id_bhvFirePiranhaPlant,
				param2 = 1,
			},
			{ behavior = id_bhvChainChomp, model = E_MODEL_CHAIN_CHOMP, name = "Chain Chomp", spawnOffset = 400 },
			{ behavior = id_bhvSmallWhomp, model = E_MODEL_WHOMP, name = "Whomp", spawnOffset = 200 },
			{ behavior = id_bhvMadPiano, model = E_MODEL_MAD_PIANO, name = "Piano", spawnOffset = 300 },
			{ behavior = id_bhvChuckya, model = E_MODEL_CHUCKYA, name = "Chuckya", spawnOffset = 200 },
			{ behavior = id_bhvScuttlebug, model = E_MODEL_SCUTTLEBUG, name = "Scuttlebug", spawnOffset = 200 },
			-- param2nd here should mean that it also spit fires
			{ behavior = id_bhvFlyGuy, model = E_MODEL_FLYGUY, name = "Fly Guy", spawnOffset = 300, param2nd = 1 },
			{ behavior = id_bhvEnemyLakitu, model = E_MODEL_LAKITU, name = "Lakitu", spawnYOffset = 50 },
			{ behavior = id_bhvBoo, model = E_MODEL_BOO, name = "Boo", spawnOffset = 300, spawnYOffset = 50 },
			{ behavior = id_bhvBalconyBigBoo, model = E_MODEL_BOO, name = "Boo balcony big", spawnOffset = 300 },
			{ behavior = id_bhvSwoop, model = E_MODEL_SWOOP, name = "Bat", spawnYOffset = 200 },
			-- { behavior = id_bhvSwoop, model = E_MODEL_SWOOP, name = "Bat 1", spawnYOffset = 200, param2nd = 1},
			{ behavior = id_bhvSnufit, model = E_MODEL_SNUFIT, name = "Snufit", spawnYOffset = 200 },
			{ behavior = id_bhvKlepto, model = E_MODEL_KLEPTO, name = "Vulture", spawnOffset = 300 },
			{ behavior = id_bhvUnagi, model = E_MODEL_UNAGI, name = "Eel", spawnOffset = 300 },
			{ behavior = id_bhvBubba, model = E_MODEL_BUBBA, name = "Bubba", spawnOffset = 300 },
			{ name = "Bub", model = E_MODEL_BUB, behavior = id_bhvBub },
			{ behavior = id_bhvHeaveHo, model = E_MODEL_HEAVE_HO, name = "Heave-Ho", spawnOffset = 200 },
			{ name = "Mr. I", model = E_MODEL_MR_I, behavior = id_bhvMrI },
			{ name = "Mr. I boss", model = E_MODEL_MR_I, behavior = id_bhvMrI, param2nd = 1 },
			{ name = "Skeeter", model = E_MODEL_SKEETER, behavior = id_bhvSkeeter, spawnOffset = 400 },
			{ name = "Spindrift", model = E_MODEL_SPINDRIFT, behavior = id_bhvSpindrift },
			{ name = "Book", model = E_MODEL_BOOKEND, behavior = id_bhvFlyingBookend },
			{ name = "Moneybag", model = E_MODEL_MONEYBAG, behavior = id_bhvMoneybagHidden },
			-- param2nd 1 here means the mole also throws rocks
			{
				name = "Mole with hole",
				parts = {
					{ model = E_MODEL_DL_MONTY_MOLE_HOLE, behavior = id_bhvMontyMoleHole },
					{ model = E_MODEL_MONTY_MOLE, behavior = id_bhvMontyMole },
				},
				param2nd = 1,
			},
			{ name = "Mole hole", model = E_MODEL_DL_MONTY_MOLE_HOLE, behavior = id_bhvMontyMoleHole },
			{ name = "Snowman", model = E_MODEL_MR_BLIZZARD, behavior = id_bhvMrBlizzard },
			-- { name = "Pokey (bugged)", model = E_MODEL_POKEY_HEAD, behavior = id_bhvPokey },
			{ name = "Pokey (bugged)", model = E_MODEL_NONE, behavior = id_bhvPokey },
		},
	},
	{
		name = "Misc",
		items = {
			{
				behavior = id_bhvCannon,
				model = E_MODEL_CANNON_BASE,
				name = "Cannon",
				spawnYOffset = 0,
				spawnYaw = -16384,
			},
			{ behavior = id_bhvBreakableBox, model = E_MODEL_BREAKABLE_BOX, name = "Breakable Box" },
			{
				behavior = id_bhvBreakableBox,
				model = E_MODEL_BREAKABLE_BOX,
				name = "Breakable Box (big)",
				param2nd = 3,
			},
			{ name = "Breakable Box (small", behavior = id_bhvBreakableBoxSmall, model = E_MODEL_BREAKABLE_BOX_SMALL },
			{
				behavior = id_bhvPushableMetalBox,
				model = E_MODEL_METAL_BOX,
				name = "Metal Box",
				spawnOffset = 200,
				spawnYOffset = 0,
			},
			{ behavior = id_bhvBreakableBox, model = E_MODEL_ERROR_MODEL, name = "ERROR" },
			{
				name = "JRB floating box",
				model = E_MODEL_JRB_SLIDING_BOX,
				behavior = id_bhvJrbFloatingBox,
				spawnYOffset = 100,
			},
			{
				name = "Chain chomp gate",
				behavior = id_bhvChainChompGate,
				model = E_MODEL_BOB_CHAIN_CHOMP_GATE,
				spawnOffset = 300,
				spawnYaw = 32768,
			},
			{ behavior = id_bhvJumpingBox, model = E_MODEL_BREAKABLE_BOX_SMALL, name = "Jumping Box" },
			{
				name = "Cannonless wall",
				parts = {
					{ model = E_MODEL_WF_BREAKABLE_WALL_LEFT, behavior = id_bhvWfBreakableWallLeft },
					{ model = E_MODEL_WF_BREAKABLE_WALL_RIGHT, behavior = id_bhvWfBreakableWallRight },
				},
				spawnOffset = 400,
				spawnYaw = 16384,
			},
			{ behavior = id_bhvWhirlpool, model = E_MODEL_DL_WHIRLPOOL, name = "Whirlpool" },
			{ behavior = id_bhvSLWalkingPenguin, model = E_MODEL_PENGUIN, name = "Walking Penguin" },
			{ name = "Baby penguin", model = E_MODEL_PENGUIN, behavior = id_bhvPenguinBaby, param2nd = 1 },
			{ behavior = id_bhvUkiki, model = E_MODEL_UKIKI, name = "Monkey" },
			{ name = "Monkey Macro", model = E_MODEL_UKIKI, behavior = id_bhvMacroUkiki },
			-- Commented because this is already part of "Sinking cage platform"
			-- { behavior = id_bhvDDDPole, model = E_MODEL_DDD_POLE, name = "DDD pole" },
			-- { name = "DDD moving pole", behavior = id_bhvDddMovingPole, model = E_MODEL_DDD_POLE },
			-- {name = "Bowser key", behavior = id_bhvBowserKey, model = E_MODEL_BOWSER_KEY},
			-- Questo sotto può essere interessante
			{
				name = "Water level diamond",
				model = E_MODEL_WDW_WATER_LEVEL_DIAMOND,
				behavior = id_bhvWaterLevelDiamond,
			},
			{
				name = "Water level pillar",
				model = E_MODEL_CASTLE_WATER_LEVEL_PILLAR,
				behavior = id_bhvWaterLevelPillar,
				spawnOffset = 300,
				spawnYOffset = 400,
			},
			{
				name = "Switch red",
				model = E_MODEL_CAP_SWITCH,
				behavior = id_bhvCapSwitch,
				param2nd = 0,
			},
			{
				name = "Switch green",
				model = E_MODEL_CAP_SWITCH,
				behavior = id_bhvCapSwitch,
				param2nd = 1,
			},
			{
				name = "Switch blue",
				model = E_MODEL_CAP_SWITCH,
				behavior = id_bhvCapSwitch,
				param2nd = 2,
			},
			{ name = "Holdable object (test)", behavior = id_bhvBetaHoldableObject, model = E_MODEL_BULLY },
			-- { name = "Bobomb buddy", behavior = id_bhvBobombBuddy, model = E_MODEL_BOBOMB_BUDDY },
			{ name = "Bobomb opens cannon", behavior = id_bhvBobombBuddyOpensCannon, model = E_MODEL_BOBOMB_BUDDY },
			-- {
			--   name = "Switch base",
			--   model = E_MODEL_CAP_SWITCH_BASE,
			--   behavior = id_bhvCapSwitchBase
			-- },
			-- USELESS
			-- { name = "Blue coin switch", behavior = id_bhvBlueCoinSwitch, model = E_MODEL_BLUE_COIN_SWITCH },
			-- {
			--     name = "Switch animates object",
			--     model = E_MODEL_PURPLE_SWITCH,
			--     behavior = id_bhvFloorSwitchAnimatesObject,
			-- },
			-- { name = "Switch grills", model = E_MODEL_PURPLE_SWITCH, behavior = id_bhvFloorSwitchGrills },
			-- { name = "Switch hardcoded", model = E_MODEL_PURPLE_SWITCH, behavior = id_bhvFloorSwitchHardcodedModel },
			-- {
			--     name = "Switch hidden objects",
			--     model = E_MODEL_PURPLE_SWITCH,
			--     behavior = id_bhvFloorSwitchHiddenObjects,
			-- },
			-- { name = "Switch hidden boxes", model = E_MODEL_PURPLE_SWITCH, behavior = id_bhvPurpleSwitchHiddenBoxes },
			-- XXX: Exclamation boxes spawns, for a reason or another, are very heavy
			-- computationally, and it gets worse the more there are. Commented
			-- for this reason
			-- {name = "Exclamation box", behavior = id_bhvExclamationBox, model = E_MODEL_EXCLAMATION_BOX},
		},
	},
	{
		name = "Tilted objects",
		items = {
			{
				name = "T. Wood piece",
				model = E_MODEL_LLL_WOOD_BRIDGE,
				behavior = id_bhvLllWoodPiece,
				spawnYOffset = 100,
				spawnPitch = 16384,
				spawnRoll = 32768,
			},
			{
				name = "T. Sinking rock block",
				model = E_MODEL_LLL_SINKING_ROCK_BLOCK,
				behavior = id_bhvLllSinkingRockBlock,
				spawnOffset = 200,
				spawnYOffset = 50,
				spawnPitch = 16384,
				spawnRoll = 32768,
			},
			{
				behavior = id_bhvTtmRollingLog,
				model = E_MODEL_TTM_ROLLING_LOG,
				name = "T. Log TTM",
				spawnOffset = -100,
				spawnYOffset = -1100,
				spawnRoll = 16384,
			},
			{
				name = "T. Log LLL",
				model = E_MODEL_LLL_ROLLING_LOG,
				behavior = id_bhvLllRollingLog,
				spawnOffset = -100,
				spawnYOffset = -1100,
				spawnRoll = 16384,
			},
			{
				behavior = id_bhvBitfsSinkingPlatforms,
				model = E_MODEL_BITFS_SINKING_PLATFORMS,
				name = "T. Sinking Platform",
				spawnOffset = 200,
				spawnYOffset = 200,
				spawnPitch = 49152,
			},
			{
				name = "T. Sinking rectangular platform",
				model = E_MODEL_LLL_SINKING_RECTANGULAR_PLATFORM,
				behavior = id_bhvLllSinkingRectangularPlatform,
				spawnOffset = 200,
				spawnYOffset = 200,
				spawnPitch = -16384,
			},
			{
				name = "T. Sinking square platforms",
				model = E_MODEL_LLL_SINKING_SQUARE_PLATFORMS,
				behavior = id_bhvLllSinkingSquarePlatforms,
				spawnOffset = 200,
				spawnYOffset = 100,
				spawnPitch = -16384,
			},
			{
				name = "T. Pyramid top",
				model = E_MODEL_SSL_PYRAMID_TOP,
				behavior = id_bhvPyramidTop,
				spawnYOffset = -300,
				spawnOffset = 150,
				spawnPitch = 32768,
			},
			{
				name = "T. Rotating bridge platform (RR)",
				model = E_MODEL_RR_ROTATING_BRIDGE_PLATFORM,
				behavior = id_bhvRrRotatingBridgePlatform,
				spawnYOffset = 0,
				spawnRoll = 32768,
			},
			{
				name = "T. Merry go round",
				model = E_MODEL_BBH_MERRY_GO_ROUND,
				behavior = id_bhvMerryGoRound,
				spawnYaw = 32768,
				spawnOffset = 300,
				spawnYOffset = -350,
				spawnLateralOffset = -30,
				spawnPitch = 11500,
			},
			-- NOT WORKING, roll gets reset
			-- {
			--     name = "Bitfs Tilting pyramid",
			--     behavior = id_bhvBitfsTiltingInvertedPyramid,
			--     model = E_MODEL_BITFS_TILTING_SQUARE_PLATFORM,
			--     spawnYOffset = -300,
			--     spawnRoll = 32768
			-- },
			-- {
			--     name = "LLL Tilting pyramid",
			--     model = E_MODEL_LLL_TILTING_SQUARE_PLATFORM,
			--     behavior = id_bhvLllTiltingInvertedPyramid,
			--     spawnYOffset = -300,
			--     spawnRoll = 32768
			-- },
		},
	},
	{
		name = "Decorative",
		items = {
			{ name = "Wooden post", model = E_MODEL_WOODEN_POST, behavior = id_bhvWoodenPost },
			{ name = "Blue fish", behavior = id_bhvBlueFish, model = E_MODEL_FISH, spawnYOffset = 50 },
			-- Commented because it just flies outside of the map
			-- { name = "Bird", behavior = id_bhvBird, model = E_MODEL_BIRDS },
			{ name = "Castle flag", behavior = id_bhvCastleFlagWaving, model = E_MODEL_CASTLE_GROUNDS_FLAG },
			-- {name = "Fish group", model = E_MODEL_FISH, behavior = id_bhvFishGroup},
			{ behavior = id_bhvButterfly, model = E_MODEL_BUTTERFLY, name = "Butterfly" },
			{ name = "Hexagon", model = E_MODEL_LLL_ROTATING_HEXAGONAL_RING, behavior = id_bhvLllHexagonalMesh },
			{ name = "Koopa shell", model = E_MODEL_KOOPA_SHELL, behavior = id_bhvKoopaShellUnderwater },
			{
				name = "Pendulum",
				behavior = id_bhvDecorativePendulum,
				model = E_MODEL_CASTLE_CLOCK_PENDULUM,
				spawnYOffset = 300,
			},
			{
				name = "TTC pendulum (still)",
				model = E_MODEL_TTC_PENDULUM,
				behavior = id_bhvTTCPendulum,
				spawnYOffset = 500,
			},
			{
				name = "Clock hour hand",
				behavior = id_bhvClockHourHand,
				model = E_MODEL_CASTLE_CLOCK_HOUR_HAND,
				spawnYOffset = 200,
				spawnYaw = 32768,
			},
			{
				name = "Clock minute hand",
				behavior = id_bhvClockMinuteHand,
				model = E_MODEL_CASTLE_CLOCK_MINUTE_HAND,
				spawnYOffset = 200,
				spawnYaw = 32768,
			},
			{ name = "Seaweed", model = E_MODEL_SEAWEED, behavior = id_bhvSeaweed },
			{ name = "Boo cage", behavior = id_bhvStaticObject, model = E_MODEL_HAUNTED_CAGE },
			-- Not working, teleports Mario in random places
			-- { name = "Boo cage", behavior = id_bhvBooCage, model = E_MODEL_HAUNTED_CAGE, param2nd = 1},
			{ name = "RR cruiser wing", model = E_MODEL_RR_CRUISER_WING, behavior = id_bhvRrCruiserWing },
			{ name = "Star smiley", model = E_MODEL_TTM_STAR_SMILEY, behavior = id_bhvStaticObject },
			{ name = "Blue smiley", model = E_MODEL_TTM_BLUE_SMILEY, behavior = id_bhvStaticObject },
			{ name = "Yellow smiley", model = E_MODEL_TTM_YELLOW_SMILEY, behavior = id_bhvStaticObject },
			{ name = "Moon smiley", model = E_MODEL_TTM_MOON_SMILEY, behavior = id_bhvStaticObject },
			{ name = "Yellow smiley", model = E_MODEL_TTM_YELLOW_SMILEY, behavior = id_bhvStaticObject },
			{ name = "Water bomb cannon", model = E_MODEL_CANNON_BASE, behavior = id_bhvWaterBombCannon },
			{ name = "HMC red grills", model = E_MODEL_HMC_RED_GRILLS, behavior = id_bhvStaticObject },
			{ name = "Cannon barrel", behavior = id_bhvCannonBarrel, model = E_MODEL_CANNON_BARREL },
			{ name = "Yellow ball", model = E_MODEL_YELLOW_SPHERE, behavior = id_bhvYellowBall, spawnYOffset = 100 },
			{ name = "Yoshi egg", model = E_MODEL_YOSHI_EGG, behavior = id_bhvAnimatedTexture },
			{ name = "Ukiki cage", model = E_MODEL_TTM_STAR_CAGE, behavior = id_bhvUkikiCage, spawnYOffset = 100 },
			{ name = "Chest bottom", behavior = id_bhvBetaChestBottom, model = E_MODEL_TREASURE_CHEST_BASE },
			{ name = "Chest lid", behavior = id_bhvBetaChestLid, model = E_MODEL_TREASURE_CHEST_LID },
			-- {
			--   name = "Chest",
			--   parts = {
			--     {behavior = id_bhvBetaChestBottom, model = E_MODEL_TREASURE_CHEST_BASE},
			--     {behavior = id_bhvBetaChestLid, model = E_MODEL_TREASURE_CHEST_LID},
			--   }
			-- },
			{
				name = "Haunted bookshelf",
				model = E_MODEL_BBH_MOVING_BOOKSHELF,
				behavior = id_bhvHauntedBookshelf,
				spawnOffset = 300,
			},
			{ name = "Boo key", behavior = id_bhvAlphaBooKey, model = E_MODEL_BETA_BOO_KEY },
			{ behavior = id_bhvUnusedFakeStar, model = E_MODEL_STAR, name = "Fake Star", spawnYOffset = 100 },
			{
				name = "Message panel",
				model = E_MODEL_WOODEN_SIGNPOST,
				behavior = id_bhvMessagePanel,
				spawnYaw = 32768,
			},
		},
	},
}

-- Host-only objects
if network_is_server() then
	table.insert(categories, {
		name = "Host only",
		items = {
			-- {name = "Staircase (BitDW)", model = E_MODEL_BITDW_STAIRCASE, behavior = id_bhvStaticObject},
			{
				name = "Bowser arena",
				model = E_MODEL_BOWSER_2_TILTING_ARENA,
				behavior = id_bhvTiltingBowserLavaPlatform,
				spawnYOffset = -1200,
			},
			{
				name = "Snowman Head",
				model = E_MODEL_CCM_SNOWMAN_HEAD,
				behavior = id_bhvSLSnowmanWind,
				spawnOffset = 300,
				spawnYOffset = 200,
				oSubAction = SL_SNOWMAN_WIND_ACT_BLOWING,
			},
			{ name = "Whomp king", model = E_MODEL_WHOMP, behavior = id_bhvWhompKingBoss, spawnOffset = 500 },
			{ name = "king Bobomb", model = E_MODEL_KING_BOBOMB, behavior = id_bhvKingBobomb },
			{ behavior = id_bhvBowser, model = E_MODEL_BOWSER, name = "Bowser", param2nd = 1 },
			{ name = "Bowser2", behavior = id_bhvBowser, model = E_MODEL_BOWSER2, param2nd = 1 },
			{ name = "Blue fish many", model = E_MODEL_FISH, behavior = id_bhvManyBlueFishSpawner },
		},
	})
	table.insert(categories, {
		name = "Bugged (host-only)",
		items = {
			{
				name = "RR Tricky triangles (Bugged)",
				model = E_MODEL_RR_TRICKY_TRIANGLES,
				behavior = id_bhvAnimatesOnFloorSwitchPress,
				param2nd = 2,
			},
			-- {name = "TTC Rotating triangle (bugged)", model = E_MODEL_TTC_ROTATING_TRIANGLE, behavior = id_bhvTTCRotatingSolid, param2nd = 7},
			-- Fix direction, also always goes same direction
			{ name = "Spindel (bugged)", model = E_MODEL_SSL_SPINDEL, behavior = id_bhvSpindel, spawnYOffset = 200 },
			{
				name = "WF Rotating wooden platform (bugged)",
				-- model = E_MODEL_ERROR_MODEL,
				model = E_MODEL_NONE,
				behavior = id_bhvWfRotatingWoodenPlatform,
			},
			-- Makes the game lag
			-- {name = "Pyramid wall", model = E_MODEL_SSL_MOVING_PYRAMID_WALL, behavior = id_bhvSslMovingPyramidWall, spawnYaw = 16384},
			{ name = "WF Tumbling bridge (bugged)", model = E_MODEL_ERROR_MODEL, behavior = id_bhvWfTumblingBridge },
			{
				name = "BITFS Tumbling bridge (bugged)",
				model = E_MODEL_BITFS_TUMBLING_PLATFORM,
				behavior = id_bhvWfTumblingBridge,
			},
			{
				name = "LLL Floating wood bridge (bugged)",
				model = E_MODEL_LLL_WOOD_BRIDGE,
				behavior = id_bhvLllFloatingWoodBridge,
			},
			{
				name = "LLL Floating wood bridge large (bugged)",
				model = E_MODEL_LLL_LARGE_WOOD_BRIDGE,
				behavior = id_bhvLllFloatingWoodBridge,
			},
			{
				name = "Book spawn (bugged)",
				model = E_MODEL_BOOKEND,
				behavior = id_bhvBookendSpawn,
				spawnYOffset = 100,
			},
			{
				name = "BitDW Staircase",
				model = E_MODEL_BITDW_STAIRCASE,
				behavior = id_bhvAnimatesOnFloorSwitchPress,
				param2 = 2,
			},
			{ name = "Puzzle Bowser", model = E_MODEL_NONE, behavior = id_bhvLllBowserPuzzle },
		},
	})
end

local playerData = {}
local selectedCategory = 1
local selectedObjectInCat = {} -- remembers position inside each submenu
local inSubmenu = false

local function get_player_data(playerIndex)
	if not playerData[playerIndex] then
		playerData[playerIndex] = {
			cooldown = 0,
			deletionCooldown = 0,
		}
	end
	return playerData[playerIndex]
end

local holdTimer = 0
local holdDir = 0

-- Menu navigation
function move_selection(m)
	local REPEAT_DELAY = 15 -- 0.5 seconds @ 30 FPS
	local REPEAT_RATE = 2 -- repeat every 2 frames after delay

	local buttons = m.controller.buttonPressed
	local held = m.controller.buttonDown
	local dpadUDFree = gGlobalSyncTable.dpadUDFree

	if inSubmenu then
		-- Initial press
		if buttons & U_CBUTTONS ~= 0 then
			amt = math.min(MAX_AMOUNT, amt + 1)
			play_sound(SOUND_MENU_CHANGE_SELECT, m.marioObj.header.gfx.cameraToObject)
			holdDir = 1
			holdTimer = 0
			return
		elseif buttons & D_CBUTTONS ~= 0 then
			amt = math.max(1, amt - 1)
			play_sound(SOUND_MENU_CHANGE_SELECT, m.marioObj.header.gfx.cameraToObject)
			holdDir = -1
			holdTimer = 0
			return
		end

		-- Holding
		if held & U_CBUTTONS ~= 0 then
			if holdDir ~= 1 then
				holdDir = 1
				holdTimer = 0
			end

			holdTimer = holdTimer + 1
			if holdTimer >= REPEAT_DELAY and (holdTimer - REPEAT_DELAY) % REPEAT_RATE == 0 then
				amt = math.min(MAX_AMOUNT, amt + 1)
				play_sound(SOUND_MENU_CHANGE_SELECT, m.marioObj.header.gfx.cameraToObject)
			end
		elseif held & D_CBUTTONS ~= 0 then
			if holdDir ~= -1 then
				holdDir = -1
				holdTimer = 0
			end

			holdTimer = holdTimer + 1
			if holdTimer >= REPEAT_DELAY and (holdTimer - REPEAT_DELAY) % REPEAT_RATE == 0 then
				amt = math.max(1, amt - 1)
				play_sound(SOUND_MENU_CHANGE_SELECT, m.marioObj.header.gfx.cameraToObject)
			end
		else
			holdDir = 0
			holdTimer = 0
		end
	end

	-- if dpadUDFree == 0 then
	if dpadUDFree == false then
		if spawnMenu then
			if buttons & U_JPAD ~= 0 then
				if inSubmenu then
					selectedObjectInCat[selectedCategory] = (selectedObjectInCat[selectedCategory] or 1) - 1
				else
					selectedCategory = selectedCategory - 1
				end
			elseif buttons & D_JPAD ~= 0 then
				if inSubmenu then
					selectedObjectInCat[selectedCategory] = (selectedObjectInCat[selectedCategory] or 1) + 1
				else
					selectedCategory = selectedCategory + 1
				end
			elseif buttons & L_JPAD ~= 0 then
				if inSubmenu then
					inSubmenu = false
					play_sound(SOUND_MENU_CHANGE_SELECT, m.marioObj.header.gfx.cameraToObject)
					return
				else
					selectedCategory = selectedCategory - 1
				end
			elseif buttons & R_JPAD ~= 0 then
				if not inSubmenu then
					inSubmenu = true
					if not selectedObjectInCat[selectedCategory] then
						selectedObjectInCat[selectedCategory] = 1
					end
					play_sound(SOUND_MENU_CHANGE_SELECT, m.marioObj.header.gfx.cameraToObject)
					return
				else
					selectedObjectInCat[selectedCategory] = (selectedObjectInCat[selectedCategory] or 1) + 5
				end
			else
				return
			end
		end
	-- dpadUDFree == 1 , means that dpad right and left are not used
	else
		if spawnMenu then
			if buttons & R_JPAD ~= 0 then
				if inSubmenu then
					selectedObjectInCat[selectedCategory] = (selectedObjectInCat[selectedCategory] or 1) + 1
				else
					selectedCategory = selectedCategory + 1
				end
			-- elseif buttons & L_JPAD ~= 0 then
			--     if inSubmenu then
			--         inSubmenu = false
			--         play_sound(SOUND_MENU_CHANGE_SELECT, m.marioObj.header.gfx.cameraToObject)
			--         return
			--     else
			--         selectedCategory = selectedCategory - 1
			--     end
			elseif buttons & L_JPAD ~= 0 then
				if inSubmenu then
					selectedObjectInCat[selectedCategory] = (selectedObjectInCat[selectedCategory] or 1) - 1
				else
					selectedCategory = selectedCategory - 1
				end
			elseif buttons & X_BUTTON ~= 0 and not inSubmenu then
				-- X button now enters the submenu (from main menu only)
				inSubmenu = true
				if not selectedObjectInCat[selectedCategory] then
					selectedObjectInCat[selectedCategory] = 1
				end
				play_sound(SOUND_MENU_CHANGE_SELECT, m.marioObj.header.gfx.cameraToObject)
				return
			elseif buttons & Y_BUTTON ~= 0 and inSubmenu then
				inSubmenu = false
				play_sound(SOUND_MENU_CHANGE_SELECT, m.marioObj.header.gfx.cameraToObject)
				return
			else
				return
			end
		end
	end

	if inSubmenu then
		local items = categories[selectedCategory].items
		local numItems = #items
		if numItems > 0 then
			local sel = selectedObjectInCat[selectedCategory] or 1
			selectedObjectInCat[selectedCategory] = ((sel - 1) % numItems) + 1
		end
	else
		local numCats = #categories
		if numCats > 0 then
			selectedCategory = ((selectedCategory - 1) % numCats) + 1
		end
	end
end

-- packets used to:
-- - propagate deletions
-- - tell all player to delete all objects
-- - other (TODO)
hook_event(HOOK_ON_PACKET_RECEIVE, function(packet)
	-- Only if player who deleted is in the same level of the local player
	if packet.type == PACKET_DELOBJ and packet.level == gNetworkPlayers[0].currLevelNum then
		local found = false
		local foundObj
		for _, list in ipairs(lists) do
			local obj = obj_get_first(list)
			while obj ~= nil and found == false do
				if obj and obj.oModPlayerId == packet.oModPlayerId and obj.oModObjNum == packet.oModObjNum then
					found = true
					foundObj = obj
					print("Requested object to delete FOUND")
					-- print("oModPlayerId: " .. obj.oModPlayerId)
					-- print("oModObjNum: " .. obj.oModObjNum)
				end
				obj = obj_get_next(obj)
			end

			if found == true then
				break
			end
		end

		-- Why not use one loop to find both the object and the children given
		-- that i have informations on the main object? Because AFAIK sm64
		-- often does obj.parentObj = obj . Until the main object is not found,
		-- foundObj = nil , so in the children `if` condition we can't do `obj
		-- ~= foundObj`, and we would risk detecting the same object more than
		-- once. We could add `if obj.parentObj ~= obj`, but i don't want to
		-- risk that some object acts differently (for now)

		-- Find all the children of the object to delete
		if foundObj ~= nil then
			local children = {}
			-- local idx = 1
			for _, list in ipairs(lists) do
				local obj = obj_get_first(list)
				while obj ~= nil do
					if obj and obj ~= foundObj and obj.parentObj == foundObj then
						-- print("Found children " .. idx)
						-- idx = idx + 1
						table.insert(children, obj)
					end
					obj = obj_get_next(obj)
				end
			end

			-- Delete all the children of the object
			for _, child in ipairs(children) do
				-- child.parentObj = nil  -- breaks the link so behavior can't re-attach to Mario
				child.activeFlags = 0
				obj_mark_for_deletion(child)
			end

			-- Then delete the main object
			foundObj.activeFlags = 0
			obj_mark_for_deletion(foundObj)
		end
	-- Only if the host (who requested clearall) and the local player are in the same level
	elseif packet.type == PACKET_DELALL and packet.level == gNetworkPlayers[0].currLevelNum then
		-- Delete all objects as well
		clearall()
	end
end)

function spawn_selected(m)
	if spawnMenu then
		if (m.controller.buttonPressed & X_BUTTON == 0) or not inSubmenu then
			return
		end
		local data = get_player_data(m.playerIndex)
		if data.cooldown > 0 then
			return
		end

		local cat = categories[selectedCategory]
		local idx = selectedObjectInCat[selectedCategory] or 1
		local obj = cat.items[idx]
		local name = obj.name

		-- spawn relative to Mario's facing direction + speed bonus + height offset
		-- local baseOffset = obj.spawnOffset or 400
		local baseOffset = obj.spawnOffset or 200
		local forwardVel = m.forwardVel or 0
		local speedBonus = math.max(0, forwardVel) * SPEED_MULTIPLIER
		local finalOffset = baseOffset + speedBonus

		local lateralOffset = obj.spawnLateralOffset or 0
		local spawnY = m.pos.y + (obj.spawnYOffset or 0)

		-- local finalYaw = (m.faceAngle.y + (obj.spawnYaw or 0)) % 0x10000
		local finalYaw = m.faceAngle.y + (obj.spawnYaw or 0)
		local finalPitch
		local finalRoll
		if spawnObjectsUpright then
			finalPitch = obj.spawnPitch or 0
			finalRoll = obj.spawnRoll or 0
		else
			finalPitch = m.faceAngle.x + (obj.spawnPitch or 0)
			finalRoll = m.faceAngle.z + (obj.spawnRoll or 0)
		end

		-- This for is for composite objects spawn. For example, JRB ship is
		-- composed of 4 parts, that should be spawned together
		for i = 1, amt do
			local offset = finalOffset + ((i - 1) * 100)

			local x = m.pos.x + offset * sins(m.faceAngle.y) - lateralOffset * coss(m.faceAngle.y)
			local y = spawnY
			local z = m.pos.z + offset * coss(m.faceAngle.y) + lateralOffset * sins(m.faceAngle.y)

			for _, objPart in ipairs(obj.parts or { { model = obj.model } }) do
				o = spawn_sync_object(objPart.behavior or obj.behavior, objPart.model, x, y, z, function(o)
					-- See KNOWN_BUGS (3) at the top of this file
					-- o.oFlags = o.oFlags & ~OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW
					o.oFlags = o.oFlags | OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
					o.oTimer = 0
					-- o.oOpacity = 255  -- not working for ttc objects
					o.oFaceAngleYaw = finalYaw
					o.header.gfx.angle.y = finalYaw
					o.oMoveAngleYaw = finalYaw

					-- -- -- Hoot not grabbable if this code used, but conversation gets skipped
					-- if obj.behavior == id_bhvHoot then
					--   print('imahoot')
					--   o.oIntangibleTimer = 0
					--   o.header.gfx.node.flags = o.header.gfx.node.flags | GRAPH_RENDER_ACTIVE
					--   o.oHootAvailability = HOOT_AVAIL_READY_TO_FLY
					-- end

					o.oFaceAnglePitch = finalPitch
					o.header.gfx.angle.x = finalPitch
					-- o.oMoveAnglePitch = finalPitch
					o.oFaceAngleRoll = finalRoll
					o.header.gfx.angle.z = finalRoll
					-- o.oMoveAngleRoll = finalRoll

					if obj.param2nd then
						o.oBehParams2ndByte = obj.param2nd
					elseif obj.param1 or obj.param2 or obj.param3 or obj.param4 then
						o.oBehParams = ((obj.param1 or 0) << 24)
							| ((obj.param2 or 0) << 16)
							| ((obj.param3 or 0) << 8)
							| (obj.param4 or 0)
					elseif obj.oAction then
						o.oAction = obj.oAction
					elseif obj.oSubAction then
						o.oSubAction = obj.oSubAction
					elseif obj.behavior == id_bhvCannon then -- Fixes cannon yaw
						o.oBehParams2ndByte = (finalYaw >> 8) & 0xFF
					end

					o.oModPlayerId = gPlayerSyncTable[0].myPlayerId
					o.oModObjNum = next_object_id
					-- print('oModPlayerId: ' .. gPlayerSyncTable[0].myPlayerId)
					-- print('oModObjNum: ' .. next_object_id)
					-- o.oModLvlNum = gNetworkPlayers[0].currLevelNum
				end)

				if o then
					next_object_id = next_object_id + 1
				end
			end
		end

		-- This makes the pendulum move, but also increases the speed of other TTC objects
		-- set_ttc_speed_setting(1)

		-- This section adds spawned object to the recent section
		-- This for is for removing duplicates
		for i = #recentObjs, 1, -1 do
			if recentObjs[i] == obj then
				table.remove(recentObjs, i)
				break
			end
		end

		-- Insert just spawned object in Recent section
		table.insert(recentObjs, 1, obj)

		-- When spawning object from Recent category (selectedCategory == 1),
		-- jump to first position, because spawned object also jumps in first position
		if selectedCategory == 1 then
			selectedObjectInCat[selectedCategory] = 1
		end

		-- No more than MAX_RECENT objects in the Recent section
		if #recentObjs > MAX_RECENT then
			table.remove(recentObjs)
		end

		-- No cooldown when only one player connected (the host)
		if network_player_connected_count() > 1 and gGlobalSyncTable.noCooldown == false then
			data.cooldown = COOLDOWN_FRAMES * (obj.cooldown_multiplier or 1)
		end

		djui_popup_create(string.format(translate("spawned_object"), name), 1)
	end
end

-- used by delete object
local function find_nearest_object(m)
	local nearest = nil
	local minDistSq = 1600 * 1600

	for _, list in ipairs(lists) do
		local obj = obj_get_first(list)
		while obj ~= nil do
			-- TODO: This only works if the Mario who deletes is interacting,
			-- while commented code below for anyone. Anyway delete is already
			-- too heavy, so i would like not to use the code below if possible
			-- ACT_TALKING does not solve problems with conversations
			-- Not allowed to delete the object whose Mario is interacting (Shells, Poles, Trees etc.)
			local isInteracting = false
			if obj == m.riddenObj or obj == m.heldObj or obj == m.heldByObj then
				isInteracting = true
			elseif
				(obj == m.interactObj or obj == m.usedObj)
				and (
					(m.action & ACT_FLAG_ON_POLE) ~= 0
					or (m.action & ACT_FLAG_HANGING) ~= 0
					or m.action == ACT_READING_NPC_DIALOG
					or m.action == ACT_WAITING_FOR_DIALOG
					or m.action == ACT_READING_AUTOMATIC_DIALOG
					or m.action == ACT_READING_SIGN
					or m.action == ACT_IN_CANNON
				)
			then
				isInteracting = true
			end
			--if not isMarioObj and not isDoor then
			--  local isInteracting = false
			--  for i = 0, MAX_PLAYERS - 1 do
			--      local np = gNetworkPlayers[i]
			--      if np and np.connected then
			--          local m = gMarioStates[i]
			--          if m then
			--            if obj == m.riddenObj or obj == m.heldObj or obj == m.heldByObj then
			--                isInteracting = true
			--            elseif (obj == m.interactObj or obj == m.usedObj) and (
			--                    (m.action & ACT_FLAG_ON_POLE) ~= 0
			--                    or (m.action & ACT_FLAG_HANGING) ~= 0
			--                    or m.action == ACT_READING_NPC_DIALOG
			--                    or m.action == ACT_WAITING_FOR_DIALOG
			--                    or m.action == ACT_READING_AUTOMATIC_DIALOG
			--                    or m.action == ACT_READING_SIGN
			--                    or m.action == ACT_IN_CANNON
			--                ) then
			--                isInteracting = true
			--                break
			--            end
			--          end
			--      end
			--  end
			--end
			--

			-- Only objects spawned using the mod are deletable.
			-- This is because vanilla objects can't be identified, unless all
			-- vanilla objects also get an ID assigned
			-- if not isMarioObj and not isDoor and isDeletable and not isInteracting then
			if obj.oModPlayerId > 0 and obj.oModObjNum > 0 and not isInteracting then
				local dx = obj.oPosX - m.pos.x
				local dy = obj.oPosY - m.pos.y
				local dz = obj.oPosZ - m.pos.z

				-- Submarine model is weird. To spawn it correctly we need a
				-- lateralOffset or offset. This code below fixes the submarine center
				-- detection, so that players can delete it while standing on it
				if obj.behavior == get_behavior_from_id(id_bhvBowsersSub) then
					-- print('inside submarine specific')
					local offset = 4000
					local yaw = obj.oFaceAngleYaw
					dx = dx + offset * coss(yaw)
					dz = dz - offset * sins(yaw)
				end

				local distSq = dx * dx + dy * dy + dz * dz
				if distSq < minDistSq then
					minDistSq = distSq
					nearest = obj
				end
			end
			obj = obj_get_next(obj)
		end
	end

	-- children table is needed because, if for example i delete the wheel of a
	-- ferris wheel, the orphaned platforms will start attaching to Mario not
	-- having a parent object anymore
	local children = {} -- holds all children of the nearest object
	for _, list in ipairs(lists) do
		local obj = obj_get_first(list)
		while obj ~= nil do
			if obj ~= nearest and obj.parentObj == nearest then
				-- print("found children")
				table.insert(children, obj)
			end
			obj = obj_get_next(obj)
		end
	end

	return nearest, children

	-- return nearest
end

local function handle_object_deletion(m)
	if (m.controller.buttonPressed & Y_BUTTON) == 0 or (gGlobalSyncTable.dpadUDFree == true and inSubmenu) then
		return
	end

	local data = get_player_data(m.playerIndex)
	-- TODO: Check if a popup is created in this case
	if data.deletionCooldown > 0 then
		return
	end

	local canDelete = network_is_server() or gGlobalSyncTable.allowGuestDeletion
	if not canDelete then
		if m.playerIndex == 0 then
			djui_popup_create(translate("guest_deletion_disabled"), 2)
		end
		return
	end

	-- local nearest = find_nearest_object(m)
	local nearest, children = find_nearest_object(m)
	if spawnMenu then
		if nearest then
			-- -- Hide graphics immediately (not working, leftover shadows still there)
			-- if nearest.header and nearest.header.gfx and nearest.header.gfx.node then
			--     nearest.header.gfx.node.flags = nearest.header.gfx.node.flags | GRAPH_RENDER_INVISIBLE
			-- end

			local oModPlayerId = nearest.oModPlayerId
			local oModObjNum = nearest.oModObjNum

			-- Delete the children first
			for _, child in ipairs(children) do
				-- child.parentObj = nil  -- breaks the link so behavior can't re-attach to Mario
				child.activeFlags = 0
				obj_mark_for_deletion(child)
			end

			nearest.activeFlags = 0
			obj_mark_for_deletion(nearest)

			-- Below here, not using HOOK_ON_SYNC_OBJECT_UNLOAD instead (not even
			-- tried), because it would start also on clearall command, causing a
			-- mess, looping all objects list for every deleted object, and this
			-- would be done multiple times per every user

			-- Tell other Marios to also try to delete the same object
			-- > 0 cause vanilla objects are 0, and they can't be identified
			network_send(true, {
				type = PACKET_DELOBJ,
				level = gNetworkPlayers[0].currLevelNum,
				oModPlayerId = oModPlayerId,
				oModObjNum = oModObjNum,
			})
			print("Sent packet: PACKET_DELOBJ")

			-- Popup only for local player
			-- if m.playerIndex == 0 then
			--     djui_popup_create("\\#ffff00\\Deleted nearest object", 0.5)
			-- end
			djui_popup_create(translate("deleted_nearest_object"), 0.5)
		else
			-- if m.playerIndex == 0 then
			--     djui_popup_create("No nearby object found", 0.5)
			-- end
			djui_popup_create(translate("no_nearby_object"), 0.5)
		end

		-- No cooldown when only one player connected (the host)
		if network_player_connected_count() > 1 and gGlobalSyncTable.noCooldown == false then
			data.deletionCooldown = COOLDOWN_FRAMES_DEL
		end
	end
end

function on_button(m, button)
	local buttons = m.controller.buttonPressed
	return (buttons & button) ~= 0
end

function on_hud_render()
	if spawnMenu then
		if gMarioStates[0].action == ACT_DEATH or gMarioStates[0].action == ACT_GAME_OVER then
			return
		end

		-- #RENDERMENU --
		-- This moves the entire menu up or down
		local offsetY = 70

		djui_hud_set_resolution(RESOLUTION_DJUI)

		-- background
		djui_hud_set_color(0, 0, 0, 200)
		-- djui_hud_render_rect(8, 68, 370, 495)
		djui_hud_render_rect(8, 68 + offsetY, 370, 510)

		-- title
		djui_hud_set_color(255, 100, 0, 255)
		if inSubmenu then
			-- djui_hud_print_text(categories[selectedCategory].name:upper(), 20, 78, 1.2)
			djui_hud_print_text(categories[selectedCategory].name:upper(), 20, 78 + offsetY, 1.2)
		else
			-- djui_hud_print_text("OBJECT SPAWNER", 20, 78, 1.2)
			djui_hud_print_text("OBJECT SPAWNER", 20, 78 + offsetY, 1.2)
		end

		local VISIBLE_ITEMS = 15
		-- local startY = 120
		local startY = 120 + offsetY

		if inSubmenu then
			-- show objects inside the selected category
			local items = categories[selectedCategory].items
			local sel = selectedObjectInCat[selectedCategory] or 1
			local startIdx = math.max(1, sel - 7)
			local endIdx = math.min(#items, startIdx + VISIBLE_ITEMS - 1)

			for i = startIdx, endIdx do
				local y = startY + (i - startIdx) * 24
				local text = items[i].name

				if i == sel then
					djui_hud_set_color(255, 255, 0, 255)
					djui_hud_render_rect(15, y, 355, 29)
					djui_hud_set_color(0, 0, 0, 255)
				else
					djui_hud_set_color(255, 255, 255, 230)
				end
				djui_hud_print_text(text, 22, y, 1.0)
			end
		else
			-- main menu: show categories
			local startIdx = math.max(1, selectedCategory - 7)
			local endIdx = math.min(#categories, startIdx + VISIBLE_ITEMS - 1)

			for i = startIdx, endIdx do
				local y = startY + (i - startIdx) * 24
				local text = categories[i].name

				if i == selectedCategory then
					djui_hud_set_color(255, 255, 0, 255)
					djui_hud_render_rect(15, y, 355, 29)
					djui_hud_set_color(0, 0, 0, 255)
				else
					djui_hud_set_color(255, 255, 255, 230)
				end
				djui_hud_print_text(text, 22, y, 1.0)
			end
		end

		djui_hud_set_color(180, 180, 180, 200)
		if gGlobalSyncTable.dpadUDFree == false then
			djui_hud_print_text("D-PAD L/R = enter main menu/submenu", 25, 490 + offsetY, 0.85)
			djui_hud_print_text("X = spawn", 25, 510 + offsetY, 0.85)
			djui_hud_print_text("Y = delete nearest object", 25, 530 + offsetY, 0.85)
			djui_hud_print_text("Amount: " .. amt, 25, 550 + offsetY, 0.85)
		else
			djui_hud_print_text("D-PAD L/R = next/prev element", 25, 490 + offsetY, 0.85)
			djui_hud_print_text("X = enter submenu/spawn", 25, 510 + offsetY, 0.85)
			djui_hud_print_text("Y = back to main menu/delete nearest", 25, 530 + offsetY, 0.85)
			djui_hud_print_text("Amount: " .. amt, 25, 550 + offsetY, 0.85)
		end

		-- #RENDERCOOLDOWNTIMER --
		local m = gMarioStates[0]
		local data = get_player_data(m.playerIndex)

		if on_button(m, B_BUTTON) then
			spawnMenu = false
		end

		if data.cooldown <= 0 and data.deletionCooldown <= 0 then
			return
		end

		djui_hud_set_resolution(RESOLUTION_N64)

		local scale = 0.32
		local screenWidth = djui_hud_get_screen_width()
		local y = 8

		-- Spawn cooldown
		if data.cooldown > 0 then
			local seconds = math.floor(data.cooldown * 10 / 30) / 10
			local text = "Spawn cooldown " .. tostring(seconds) .. "s"

			local width = djui_hud_measure_text(text) * scale
			local x = (screenWidth - width) / 2.0

			djui_hud_set_color(0, 0, 0, 200)
			djui_hud_render_rect(x - 4, y, width + 8, 18)

			djui_hud_set_color(255, 255, 255, 255)
			djui_hud_print_text(text, x, y, scale)

			y = y + 16 -- move down for the next line
		end

		-- Deletion cooldown
		if data.deletionCooldown > 0 then
			local seconds = math.floor(data.deletionCooldown * 10 / 30) / 10
			local text = "Delete cooldown " .. tostring(seconds) .. "s"

			local width = djui_hud_measure_text(text) * scale
			local x = (screenWidth - width) / 2.0

			djui_hud_set_color(0, 0, 0, 200)
			djui_hud_render_rect(x - 4, y, width + 8, 18)

			djui_hud_set_color(255, 255, 255, 255)
			djui_hud_print_text(text, x, y, scale)
		end
	end
end

function open()
	local m = gMarioStates[0]
	local np = gNetworkPlayers[m.playerIndex]

	if not network_is_server() and not network_is_moderator() and get_my_discord_id() == "980159405674856478" then -- evil >:3
		return
	end

	spawnMenu = not spawnMenu
end

-- respawn
hook_chat_command("spawnmenu", "Opens the spawn menu.", function(msg)
	open()
end)

hook_event(HOOK_ON_HUD_RENDER, on_hud_render)

hook_event(HOOK_MARIO_UPDATE, function(m)
	-- m.health = 0x880   -- or 0x8FF; both are common "full health" values in SM64 Lua mods
	-- m.health = 0xFFF

	-- Invincibility timer (extra safety)
	-- m.invincTimer = 60

	-- Optional: instantly cancel any death action and put Mario back into idle
	-- local deathActions = {
	--     ACT_DEATH_ON_BACK, ACT_DEATH_ON_STOMACH, ACT_DEATH_PLUNGE,
	--     ACT_QUICKSAND_DEATH, ACT_SUFFOCATION, ACT_WATER_DEATH,
	--     ACT_DROWNING, ACT_ELECTROCUTION, ACT_BURNING_JUMP,
	--     ACT_BURNING_FALL
	-- }
	-- for _, act in ipairs(deathActions) do
	--     if m.action == act then
	--         set_mario_action(m, ACT_IDLE, 0)
	--         break
	--     end
	-- end

	-- cooldown for every player
	local data = get_player_data(m.playerIndex)
	if data.cooldown > 0 then
		data.cooldown = data.cooldown - 1
	end
	if data.deletionCooldown > 0 then
		data.deletionCooldown = data.deletionCooldown - 1
	end

	-- only local player (index 0) controls the spawn menu
	if m.playerIndex ~= 0 then
		return
	end

	-- Y-button deletion
	handle_object_deletion(m)

	-- move_selection(m)
	-- spawn_selected(m)
	spawn_selected(m)
	move_selection(m)
end)

-- Gives ferris wheel the blue platform instead of error model
local function fix_ferris_wheel(obj)
	obj_set_model_extended(obj, E_MODEL_BITS_BLUE_PLATFORM)

	if obj.parentObj ~= nil then
		obj.oMoveAngleYaw = obj.parentObj.oFaceAngleYaw
	end
end
hook_behavior(id_bhvFerrisWheelPlatform, OBJ_LIST_SURFACE, false, fix_ferris_wheel, nil)

-- Replace chain chomp metallic balls
local function fix_chain_chomp_ball(obj)
	obj_set_model_extended(obj, E_MODEL_METALLIC_BALL)
end
hook_behavior(id_bhvChainChompChainPart, OBJ_LIST_GENACTOR, false, fix_chain_chomp_ball, nil)
local function fix_wooden_post(obj)
	obj_set_model_extended(obj, E_MODEL_WOODEN_POST)
end
hook_behavior(id_bhvWoodenPost, OBJ_LIST_SURFACE, false, fix_wooden_post, nil)

-- Fix sinking cage platform's invisible DDD pole
local function fix_ddd_pole(obj)
	obj_set_model_extended(obj, E_MODEL_DDD_POLE)
	-- obj_set_model_extended(obj, E_MODEL_BITS_BLUE_PLATFORM)
end
-- hook_behavior(id_bhvDDDPole, OBJ_LIST_POLELIKE, false, fix_ddd_pole, nil)
hook_behavior(id_bhvDddMovingPole, OBJ_LIST_POLELIKE, false, fix_ddd_pole, nil) -- just in case both variants exist

-- Fix Cloud
local function fix_cloud(obj)
	obj_set_model_extended(obj, E_MODEL_MIST)
end
-- hook_behavior(id_bhvCloud, OBJ_LIST_DEFAULT, false, fix_cloud, nil)
hook_behavior(id_bhvCloudPart, OBJ_LIST_DEFAULT, false, fix_cloud, nil)

-- TODO: no head, only body parts
local function fix_pokey_body_part(obj)
	obj_set_model_extended(obj, E_MODEL_POKEY_BODY_PART)
end
hook_behavior(id_bhvPokeyBodyPart, OBJ_LIST_GENACTOR, false, fix_pokey_body_part, nil)

-- Fix Mr. I
local function fix_mr_i_body(obj)
	obj_set_model_extended(obj, E_MODEL_MR_I_IRIS)
end
hook_behavior(id_bhvMrIBody, OBJ_LIST_DEFAULT, false, fix_mr_i_body, nil)
local function fix_mr_i(obj)
	obj_set_model_extended(obj, E_MODEL_MR_I)
end
hook_behavior(id_bhvMrI, OBJ_LIST_GENACTOR, false, fix_mr_i, nil)

local function fix_dorrie(obj)
	if obj.oModPlayerId > 0 and obj.oModObjNum > 0 then
		obj.oPosX = obj.oHomeX
		obj.oPosY = obj.oHomeY
		obj.oPosZ = obj.oHomeZ
	end
end
hook_behavior(id_bhvDorrie, OBJ_LIST_SURFACE, false, fix_dorrie, nil)

-- Not working
-- -- Fix tumbling bridge pieces
-- local function fix_tumbling_bridge(obj)
--     -- obj_set_model_extended(obj, E_MODEL_BITFS_TUMBLING_PLATFORM)
--     obj_set_model_extended(obj, E_MODEL_BITFS_TUMBLING_PLATFORM_PART)
--     obj.oFlags = obj.oFlags | OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
-- end
-- hook_behavior(id_bhvTumblingBridgePlatform, OBJ_LIST_SURFACE, false, fix_tumbling_bridge, nil)

function fix_snow_mound_init(o)
	o.oFlags = OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
	-- Object intangible is collisionData not declared (don't know why)
	o.collisionData = gGlobalObjectCollisionData.sl_seg7_collision_sliding_snow_mound
	o.oCollisionDistance = 1500
end
-- Replace origina behavior so that snow mound goes in the direction Mario is facing
function fix_snow_mound_loop(o)
	local yaw = o.oMoveAngleYaw - 16384

	o.oFlags = o.oFlags | OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
	-- o.oIntangibleTimer = 0

	if o.oAction == 0 then
		local speed = 40.0
		o.oVelX = speed * sins(yaw)
		o.oVelZ = speed * coss(yaw)
		-- o.oPosX = o.oPosX + o.oVelX
		-- o.oPosZ = o.oPosZ + o.oVelZ

		if o.oTimer > 117 then
			o.oAction = 1
		end
	elseif o.oAction == 1 then
		local speed = 5.0
		o.oVelX = speed * sins(yaw)
		o.oVelZ = speed * coss(yaw)
		o.oVelY = -10.0

		-- o.oPosX = o.oPosX + o.oVelX
		-- o.oPosZ = o.oPosZ + o.oVelZ
		-- o.oPosY = o.oPosY + o.oVelY

		if o.oTimer > 50 then
			o.activeFlags = ACTIVE_FLAG_DEACTIVATED
		end
	end

	cur_obj_move_using_vel()
	load_object_collision_model()
end
-- hook_behavior(id_bhvSlidingSnowMound, OBJ_LIST_SURFACE, true, nil, fix_snow_mound_loop)
hook_behavior(id_bhvSlidingSnowMound, OBJ_LIST_SURFACE, true, fix_snow_mound_init, fix_snow_mound_loop)

-- Submarine gets deleted automatically when these conditions are met:
-- if (save_file_get_flags() & (SAVE_FLAG_HAVE_KEY_2 | SAVE_FLAG_UNLOCKED_UPSTAIRS_DOOR))
-- so here we tell do check to condition only if the object is not vanilla
-- beh file: ddd_sub.inc.c
function fix_submarine_init(o)
	o.oFlags = OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
	-- Object intangible is collisionData not declared (don't know why)
	o.collisionData = gGlobalObjectCollisionData.ddd_seg7_collision_submarine
	o.oCollisionDistance = 20000
	-- o.oFlags = OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE | OBJ_FLAG_ACTIVE_FROM_AFAR
end
hook_behavior(id_bhvBowsersSub, OBJ_LIST_SURFACE, true, fix_submarine_init, function(o)
	-- hook only applies to mod spawned objects
	if o.oModPlayerId == 0 and o.oModObjNum == 0 then
		-- TODO: Should verify if this if works with the real submarine in DDD
		if save_file_get_flags() & (SAVE_FLAG_HAVE_KEY_2 | SAVE_FLAG_UNLOCKED_UPSTAIRS_DOOR) ~= 0 then
			obj_mark_for_deletion(o)
		end
	end

	load_object_collision_model()
end)

hook_event(HOOK_ON_OBJECT_LOAD, function(o)
	if o.oModPlayerId and o.oModPlayerId > 0 then
		network_init_object(o, true, {
			"oModPlayerId",
			"oModObjNum",
			-- "oModLvlNum",
		})
	end
end)

-- Used from the hook chat command and also on packet receive PACKET_DELALL
function clearall()
	local parents = {}
	local children = {}

	for _, list in ipairs(lists) do
		local obj = obj_get_first(list)
		while obj ~= nil do
			-- only parents have the ids
			if obj.oModPlayerId > 0 and obj.oModObjNum > 0 then
				table.insert(parents, obj)
			-- elseif obj.parentObj and obj.parentObj.oModPlayerId > 0 and obj.parentObj.oModObjNum > 0 then
			elseif
				obj.parentObj
				and obj.parentObj ~= obj
				and obj.parentObj.oModPlayerId > 0
				and obj.parentObj.oModObjNum > 0
			then
				table.insert(children, obj)
			end
			obj = obj_get_next(obj)
		end
	end

	-- Delete children first
	for _, obj in ipairs(children) do
		obj.activeFlags = 0
		obj_mark_for_deletion(obj)
	end

	-- Then delete parents
	for _, obj in ipairs(parents) do
		-- obj.oModPlayerId = 0
		-- obj.oModObjNum = 0
		obj.activeFlags = 0
		obj_mark_for_deletion(obj)
	end

	djui_popup_create(translate("all_spawned_objects_deleted"), 2)

	return true
end

hook_chat_command("clearall", "Delete all spawned objects on this map", function(unused)
	if not network_is_server() then
		djui_popup_create(translate("only_host_clear_objects"), 2)
		return true
	end

	clearall()

	-- Tell other Marios to also try to delete all spawned objects
	network_send(true, {
		type = PACKET_DELALL,
		level = gNetworkPlayers[0].currLevelNum,
	})
	print("Sent packet: PACKET_DELALL")

	return true
end)

hook_event(HOOK_ON_PLAYER_CONNECTED, function(m)
	-- Assign unique ID every a player connects. It changes even if same player
	-- disconnects and the reconnects
	if network_is_server() and m.playerIndex ~= 0 then
		local newId
		repeat
			newId = math.random(0, 0xFFFFFFFF) -- 32-bit random
		until not usedPlayerIds[newId]

		usedPlayerIds[newId] = true
		gPlayerSyncTable[m.playerIndex].myPlayerId = newId

		print("Assigned player ID " .. newId .. " to just connected player " .. m.playerIndex)
	end
end)
-- hook_event(HOOK_JOINED_GAME, function(m)
-- end)

-- Host always has the id 1
if network_is_server() then
	-- myPlayerId = 1
	gPlayerSyncTable[0].myPlayerId = 1
	usedPlayerIds[0] = true
	usedPlayerIds[1] = true
	print("Host player id: " .. gPlayerSyncTable[0].myPlayerId)
end
