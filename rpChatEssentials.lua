Methods = {}

local enableLocalChat = true
local enableNickNames = true

local localChatCellRadius = 1 -- 0 means only the players in the same cell can hear eachother

local globalChatHeader = "[OOC] "
local globalChatHeaderColor = color.Gray

local localOOCChatHeader = "[LOOC] "
local localOOCChatHeaderColor = color.Gray

local actionMsgSymbol = "*"
local actionMsgColor = color.DarkGray

local nickNames = {}
local nickNameColor = color.Cyan
local nickNameMinCharLength = 3
local nickNameMaxCharLength = 15

local styles = {}
local playerStyles = {}

Methods.Init = function()
	
	local home = os.getenv("MOD_DIR").."/style/"
    local file = io.open(home .. "prefix.json", "r")
	if file ~= nil then
		io.close()
		styles = jsonInterface.load("style/prefix.json")
	else
		styles.admin = color.Red.."[Admin]"..color.Default
		styles.moderator = color.BlueViolet.."[Mod]"..color.Default
		
		jsonInterface.save("style/prefix.json", styles)
	end

end

function loadPlayerStyle(pid)
	-- Replace characters not allowed in filenames
    local acc = string.upper(Players[pid].name)
    acc = string.gsub(acc, patterns.invalidFileCharacters, "_")
    acc = acc .. ".json"
	
	local style = {}
	style.nameColor = color.Default
	style.prefix = {}
	
	local home = os.getenv("MOD_DIR").."/style/players/"
    local file = io.open(home .. acc, "r")
	if file ~= nil then
		io.close()
		style = jsonInterface.load("style/players/"..acc)
	else
		style.nameColor = color.Default
		style.prefix = {}
		jsonInterface.save("style/players/"..acc, style)
	end
	
	return style
end



function savePlayerStyle(pid)
	-- Replace characters not allowed in filenames
    local acc = string.upper(Players[pid].name)
    acc = string.gsub(acc, patterns.invalidFileCharacters, "_")
    acc = acc .. ".json"
	
	jsonInterface.save("style/players/"..acc, playerStyles[pid])
end



Methods.OnPlayerSendMessage = function(pid, message)
	if enableLocalChat == true then
		Methods.SendLocalMessage(pid, message, true)
	else
		Methods.SendGlobalMessage(pid, message, true)
	end
	return HIDE_DEFAULT_CHAT
end



Methods.OnPlayerSendCommand = function(pid, cmd, message)

	local admin = false
    local moderator = false
    if Players[pid]:IsAdmin() then
        admin = true
        moderator = true
    elseif Players[pid]:IsModerator() then
        moderator = true
    end

	
	if cmd[1] == "me" then
	
		Methods.SendActionMsg(pid, message)
		
		return COMMAND_EXECUTED
		
	elseif cmd[1] == "nick" then
	
		Methods.SetNickName(pid, message)
		
		return COMMAND_EXECUTED
		
	elseif cmd[1] == "/" then
	
		message = string.sub(message, 3)
		Methods.SendGlobalOOCMessage(pid, message)
		
		return COMMAND_EXECUTED
		
	elseif cmd[1] == "//" then
	
		message = string.sub(message, 4)
		Methods.SendLocalOOCMessage(pid, message)
		
		return COMMAND_EXECUTED
	
	elseif cmd[1] == "ncolor" and moderator then
		
		if cmd[2] ~= nil and cmd[3] ~= nil then
			if myMod.CheckPlayerValidity(pid, cmd[2]) then
				tes3mp.SendMessage(pid, Methods.SetNameColor(tonumber(cmd[2]), "#"..cmd[3]), false)
			end
		else
			tes3mp.SendMessage(pid, "Invalid arguments expected /ncolor PID ColorCode\n", false)
		end
		
		return COMMAND_EXECUTED
	
	elseif cmd[1] == "prefix" and moderator then
		
		if cmd[2] ~= nil and cmd[3] ~= nil and cmd[4] ~= nil then
			if cmd[2] == "add" then
				if styles[cmd[3]] ~= nil and myMod.CheckPlayerValidity(pid, tonumber(cmd[4])) then
					tes3mp.SendMessage(pid, Methods.AddPrefix(tonumber(cmd[4]), cmd[3]), false)
				end
			elseif cmd[2] == "remove" then
				if styles[cmd[3]] ~= nil and myMod.CheckPlayerValidity(pid, tonumber(cmd[4])) then
					tes3mp.SendMessage(pid, Methods.RemovePrefix(tonumber(cmd[4]), cmd[3]), false)
				end
			else
				tes3mp.SendMessage(pid, "Expected add/remove in argument #2.\n", false)
			end
		else
			tes3mp.SendMessage(pid, "Use /prefix add/remove description PID\n", false)
		end
		
		return COMMAND_EXECUTED
		
	end
	return DO_NOTHING
end



Methods.OnPlayerConnect = function(pid)
	playerStyles[pid] = loadPlayerStyle(pid)
end



Methods.OnPlayerDisconnect = function(pid)
	playerStyles[pid] = nil
	nickNames[pid] = nil
end



---------------------------------------------------------
--				Start of RP functions				   --
---------------------------------------------------------

Methods.GetFullName = function(pid, enforceRealName)
	local playerName = Players[pid].name
	
	if enforceRealName == true then
		return playerName
	else
	
		local prefix = ""
		for i,tag in pairs(playerStyles[pid].prefix) do
			if styles[tag] ~= nil then
				prefix = prefix..styles[tag].." "
			end
		end
	
		if nickNames[pid] ~= nil and enableNickNames == true then
			return prefix..nickNameColor..nickNames[pid]..color.Default
		else
			return prefix..playerStyles[pid].nameColor..playerName..color.Default
		end
	end
end

Methods.SetNickName = function(pid, name)
	if enableNickNames == true then
		if name ~= nil then
			name = string.sub(name, 7)
			if name:len() >= nickNameMinCharLength and name:len() <= nickNameMaxCharLength then
				nickNames[pid] = name
				tes3mp.SendMessage(pid, "Your nickname has been set to: "..name.."\n", false)
			else
				nickNames[pid] = nil
				tes3mp.SendMessage(pid, "Your nickname has been reset.\n(Nicknames must be "..nickNameMinCharLength.."-"..nickNameMaxCharLength.." characters long)\n", false)
			end
		end
	else
		tes3mp.SendMessage(pid, "Nicknames are not enabled on this server.\n", false)
	end
end

Methods.AddPrefix = function(pid, description)

	if styles[description] ~= nil then
		for i,d in pairs(playerStyles[pid].prefix) do
			if d == description then
				return "That player already has the prefix \""..description.."\".\n"
			end
		end
		
		table.insert(playerStyles[pid].prefix, description)
		
		savePlayerStyle(pid)
		
		return "Prefix \""..description.."\" added to "..Methods.GetFullName(pid, true)..".\n"
		
	else
		return "The prefix \""..description.."\" does not exist.\n"
	end

end

Methods.RemovePrefix = function(pid, description)

	if styles[description] ~= nil then
	
		local index = 0
		
		for i,d in pairs(playerStyles[pid].prefix) do
			if d == description then
				index = i
			end
		end
		
		if index > 0 then
			table.remove(playerStyles[pid].prefix, index)
		end
		
		savePlayerStyle(pid)
		
		return "Removed prefix \""..description.."\" from player "..Methods.GetFullName(pid, true)..".\n"
		
	else
		return "The prefix \""..description.."\" does not exist.\n"
	end

end

Methods.SetNameColor = function(pid, color)
	if string.len(color) == 7 then
		if string.byte(string.sub(color, 1, 1)) == 35 then
			for i=2,7,1 do
				local b = string.byte(string.sub(color, i, i))
				if (b < 48 or b > 57) and (b < 65 or b > 70) then
					return "Incorrect color code format 0-9 / A-F (ie: FFFFFF).\n"
				end
			end
			
			if playerStyles[pid] ~= nil then
				playerStyles[pid].nameColor = color
				savePlayerStyle(pid)
				return "Player "..Methods.GetFullName(pid, true).."'s name color has been set.\n"
			else
				return "Player "..pid.." does not exist."
			end
		end
		return "Incorrect color code format 0-9 / A-F (ie: FFFFFF)."
	else
		return "Color codes have to be 7 characters long (ie: FFFFFF)."
	end

end

Methods.SendGlobalMessage = function(pid, message, useName)
	if useName == true then
		tes3mp.SendMessage(pid, Methods.GetFullName(pid, false)..": "..message.."\n", true)
	else
		tes3mp.SendMessage(pid, message.."\n", true)
	end
end

Methods.SendLocalMessage = function(pid, message, useName)
	local playerName = Players[pid].name
	
	-- Get top left cell from our cell
	local myCellDescription = Players[pid].data.location.cell
	
	if myCellDescription ~= nil and myCellDescription ~= '' then
		if tes3mp.IsInExterior(pid) == true then
			local cellX = tonumber(string.sub(myCellDescription, 1, string.find(myCellDescription, ",") - 1))
			local cellY = tonumber(string.sub(myCellDescription, string.find(myCellDescription, ",") + 2))

			local firstCellX = cellX - localChatCellRadius
			local firstCellY = cellY + localChatCellRadius

			local length = localChatCellRadius * 2

			for x = 0, length, 1 do
				for y = 0, length, 1 do
					-- loop through all y inside of x
					local tempCell = (x+firstCellX)..", "..(firstCellY-y)
					-- send message to each player in cell
					if LoadedCells[tempCell] ~= nil then
						if useName == true then
								SendMessageToAllInCell(tempCell, Methods.GetFullName(pid, false)..": "..message.."\n")
						else
							SendMessageToAllInCell(tempCell, message.."\n")
						end
					end
				end
			end
		else
			if useName == true then
				SendMessageToAllInCell(myCellDescription, Methods.GetFullName(pid, false)..": "..message.."\n")
			else
				SendMessageToAllInCell(myCellDescription, message.."\n")
			end
		end
	end
end

function SendMessageToAllInCell(cellDescription, message)
	for index,pid in pairs(LoadedCells[cellDescription].visitors) do
		if Players[pid].data.location.cell == cellDescription then
			tes3mp.SendMessage(pid, message, false)
		end
	end
end

Methods.SendLocalOOCMessage = function(pid, message)
	if enableLocalChat == true then
		local msg = localOOCChatHeaderColor..localOOCChatHeader..color.Default..Methods.GetFullName(pid, true).." ("..pid.."):"..message
		Methods.SendLocalMessage(pid, msg, false)
	else
		tes3mp.SendMessage(pid, "You cannot send a local OOC with local chat disabled.\n")
	end
end

Methods.SendGlobalOOCMessage = function(pid, message)
	if message:len() > 1 then
		local msg = globalChatHeaderColor..globalChatHeader..color.Default..Methods.GetFullName(pid, true).." ("..pid.."):"..message
		Methods.SendGlobalMessage(pid, msg, false)
	else
		tes3mp.SendMessage(pid, "Your message cannot be empty.\n", false)
	end
end

Methods.SendActionMsg = function(pid, message)
	local msg
	if message:len() > 1 then
		if nickNames[Players[pid].name] ~= nil and enableNickNames == true then
			msg = actionMsgColor..actionMsgSymbol..nickNames[Players[pid].name]..string.sub(message, 4)..actionMsgSymbol..color.Default
		else
			msg = actionMsgColor..actionMsgSymbol..Players[pid].name..string.sub(message, 4)..actionMsgSymbol..color.Default
		end
			
		if enableLocalChat == true then
			Methods.SendLocalMessage(pid, msg, false)
		else 
			Methods.SendGlobalMessage(pid, msg, false)
		end
	else
		tes3mp.SendMessage(pid, "Your message cannot be empty.\n", false)
	end
end

Methods.IsLocalChatEnabled = function()
	return enableLocalChat
end

return Methods
