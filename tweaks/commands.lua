local WI = require("b-wins")
local MWI = require("c-mWins")

function on_chat_message(msg)
	WI.reset_wins()
	MWI.reset_m_wins()
end

hook_chat_command("reset_wins", "Resets your wins and minigame wins. (DONT DO THIS)", on_chat_message)

function end_round()
	if not network_is_server() and not network_is_moderator() then
		djui_chat_message_create(
			"\\#ff5050\\You have permission to perform this command... or DO you?\n(No, you don't have moderator)"
		)
		return
	end
	gGlobalSyncTable.gameState = GAME_STATE_MINI_END
end

hook_chat_command("end", "Ends the round", end_round)

function download_link()
	djui_chat_message_create("\\#00ffff\\Download link: \\#ffffff\\https://github.com/georgegabrdev/Drench-Game-DX")
end

hook_chat_command("download", "Provides a link to download the mod", download_link)
