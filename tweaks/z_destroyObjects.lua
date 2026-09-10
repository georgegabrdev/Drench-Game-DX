function setup()
	if
		gNetworkPlayers[0].currLevelNum == LEVEL_DS_FORT
		or gNetworkPlayers[0].currLevelNum == LEVEL_STAIR
		or gNetworkPlayers[0].currLevelNum == LEVEL_BOWSER_2
		or gNetworkPlayers[0].currLevelNum == LEVEL_BOWSER_1
	then
		hook_behavior(id_bhvRedCoin, OBJ_LIST_LEVEL, true, function() end, function()
			bhv_hidden_object_loop()
		end)

		hook_behavior(id_bhvCoinFormationSpawn, OBJ_LIST_LEVEL, true, function() end, function()
			bhv_hidden_object_loop()
		end)

		hook_behavior(id_bhvCoinFormation, OBJ_LIST_LEVEL, true, function() end, function()
			bhv_hidden_object_loop()
		end)

		hook_behavior(id_bhvRedCoinStarMarker, OBJ_LIST_LEVEL, true, function() end, function()
			bhv_hidden_object_loop()
		end)

		hook_behavior(id_bhvFish, OBJ_LIST_LEVEL, true, function() end, function()
			bhv_hidden_object_loop()
		end)

		hook_behavior(id_bhvFishGroup, OBJ_LIST_LEVEL, true, function() end, function()
			bhv_hidden_object_loop()
		end)

		hook_behavior(id_bhvFishSpawner, OBJ_LIST_LEVEL, true, function() end, function()
			bhv_hidden_object_loop()
		end)

		hook_behavior(id_bhvSmallWaterWave, OBJ_LIST_LEVEL, true, function() end, function()
			bhv_hidden_object_loop()
		end)

		hook_behavior(id_bhvBowser, OBJ_LIST_LEVEL, true, function() end, function()
			bhv_hidden_object_loop()
		end)

		hook_behavior(id_bhvBowserBomb, OBJ_LIST_LEVEL, true, function() end, function()
			bhv_hidden_object_loop()
		end)

		hook_behavior(id_bhvStaticObject, OBJ_LIST_LEVEL, true, function() end, function()
			bhv_hidden_object_loop()
		end)

		hook_behavior(id_bhvGoomba, OBJ_LIST_LEVEL, true, function() end, function()
			bhv_hidden_object_loop()
		end)

		hook_behavior(id_bhvBobomb, OBJ_LIST_LEVEL, true, function() end, function()
			bhv_hidden_object_loop()
		end)

		hook_behavior(id_bhvChuckya, OBJ_LIST_LEVEL, true, function() end, function()
			bhv_hidden_object_loop()
		end)

		hook_behavior(id_bhvChuckyaAnchorMario, OBJ_LIST_LEVEL, true, function() end, function()
			bhv_hidden_object_loop()
		end)

		hook_behavior(id_bhvFlyGuy, OBJ_LIST_LEVEL, true, function() end, function()
			bhv_hidden_object_loop()
		end)

		hook_behavior(id_bhvMessagePanel, OBJ_LIST_LEVEL, true, function() end, function()
			bhv_hidden_object_loop()
		end)

		hook_behavior(id_bhvBreakableBox, OBJ_LIST_LEVEL, true, function() end, function()
			bhv_hidden_object_loop()
		end)

		hook_behavior(id_bhvBobBowlingBallSpawner, OBJ_LIST_LEVEL, true, function() end, function()
			bhv_hidden_object_loop()
		end)

		hook_behavior(id_bhvBowlingBall, OBJ_LIST_LEVEL, true, function() end, function()
			bhv_hidden_object_loop()
		end)

		hook_behavior(id_bhvKoopa, OBJ_LIST_LEVEL, true, function() end, function()
			bhv_hidden_object_loop()
		end)

		hook_behavior(id_bhvSmallWhomp, OBJ_LIST_LEVEL, true, function() end, function()
			bhv_hidden_object_loop()
		end)

		hook_behavior(id_bhvPiranhaPlant, OBJ_LIST_LEVEL, true, function() end, function()
			bhv_hidden_object_loop()
		end)

		hook_behavior(id_bhvPiranhaPlantBubble, OBJ_LIST_LEVEL, true, function() end, function()
			bhv_hidden_object_loop()
		end)
	end
end

hook_event(HOOK_ON_LEVEL_INIT, setup)
