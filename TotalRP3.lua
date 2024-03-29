-- Author      : Chrono
-- Create Date : 3/29/2020 4:39:46 PM


local _, Import = ...;

local ellyb, loc, Color, ColorManager;
local NPC_TALK_PATTERNS;
local settings;
local ChatBubblePool = Import.ChatBubblePool

local function makeBubbleForNPCChat(_, event, message, ...)
	if event == "CHAT_MSG_EMOTE" then
		local senderGUID = select(11, ...);
		local playerGUID = UnitGUID("player");
		local npcName = TRP3_API.chat.getNPCMessageName()
		if senderGUID == playerGUID or settings.get("GENERATE_TOTAL_RP3_BUBBLES_FOR_OTHER_PLAYERS") then
			if npcName then
				for talkType, talkChannel in pairs(NPC_TALK_PATTERNS) do
					if message:find(talkType) then
						local color;
						local myMessage = message;
						local normalColor = TRP3_API.GetChatTypeColor(talkChannel);
						local normalColorAsString = normalColor:GenerateHexColor();
						local nameColor;

						--Detect colour alterations. We need to remove it temporarily to remove the start.
						if myMessage:sub(1,2) == "|c" then
							color = myMessage:sub(1,10); --Save this to prepend back later
							myMessage = myMessage:sub(11);
						end

						if npcName:sub(1,2) == "|c" and npcName:sub(-2) == "|r" then
							--If the name is not in the default color scheme, save it to be set later
							--Otherwise, we'll replace the name color with ChatBubble's default name colour.
							if npcName:sub(3,10) ~= normalColorAsString then
								nameColor = TRP3_API.CreateColorFromHexMarkup(npcName:sub(1,10));
							else
								--Strip out the |c and |r tags so they don't get in the way of SetName()
								npcName = npcName:sub(11);
								npcName = npcName:sub(1,-3);
							end
						end
						local len = talkType:len();
						--Remove the "says:" from the beginning of the message. 
						if myMessage:sub(1, len) == talkType then
							local actualMessage = myMessage:sub(len+1);

							--Remove leading spaces if any
							if actualMessage:sub(1,1) == " " then
								actualMessage = actualMessage:sub(2);
							end

							actualMessage = color .. actualMessage;
							local chatBubble = ChatBubblePool.getChatBubble()
							chatBubble:SetName(npcName);
							chatBubble:SetMessage(actualMessage);
							if nameColor then
								chatBubble:SetNameColor(nameColor:GetRGBA())
							end
						end
						break;
					end 
				end
			end  
		end
	end 
	return false, message, ...
end

function initTRP3Vars(self)
	ellyb = TRP3_API.Ellyb;
	loc = TRP3_API.loc;

	NPC_TALK_PATTERNS = {
		[loc.NPC_TALK_SAY_PATTERN] = "MONSTER_SAY",
		[loc.NPC_TALK_YELL_PATTERN] = "MONSTER_YELL",
		[loc.NPC_TALK_WHISPER_PATTERN] = "MONSTER_WHISPER",
	};
end

function TotalRP3_onStart()
	settings = Import.settings;
	if TRP3_API then
		initTRP3Vars();
		Import.SharedFunctions.GetUnitNameAndColor = GetNameAndColorFromTotalRP3;
		for _, channel in pairs(POSSIBLE_CHANNELS) do
			ChatFrame_RemoveMessageEventFilter(channel, makeBubbleForNPCChat);
			if settings.get("GENERATE_TOTAL_RP3_BUBBLES") then
				ChatFrame_AddMessageEventFilter(channel, makeBubbleForNPCChat);
			end
		end 
		--Don't re-queue BCI's chat handler. It's important for BCI's handler to go first before 
		--  TotalRP3 as TotalRP3's modifications to the chat message (e.g. colouring)
		--  are not propagated to the chat bubble, and BlizzChatIntegration.lua relies on 
		--  using the message as a common key between the chat message and chat bubble 
		--  to map the chat bubble to a character name.  
		--Import.modules.BlizzChatIntegration:ResetChatHandler()
	end
end

function GetNameAndColorFromTotalRP3(unitId)
	if unitId == "player" then
		trp3Name, color = getPlayerTRP3NameAndColor();
	elseif unitId == "target" then
		trp3Name, color = getTargetTRP3NameAndColor();
	end
	if trp3Name ~= nil then
		return trp3Name, color;
	end
	--Fallback to UnitName
	return UnitName(unitId), nil;
end

function getPlayerTRP3NameAndColor()
	local getTRP3Data = TRP3_API.profile.getData
	local getFullnameUsingChatMethod = TRP3_API.chat.getFullnameUsingChatMethod;
	local playerData = getTRP3Data("player");
	local trp3Name = getFullnameUsingChatMethod(playerData);
	local unitId = "player";
	local nameColor = getPlayerNameColor(trp3Name);
	return trp3Name, nameColor;
end

function getPlayerNameColor()
	local configShowNameCustomColors = TRP3_API.chat.configShowNameCustomColors;
	local guid = UnitGUID("player");
	local player = AddOn_TotalRP3.Player.static.CreateFromGUID(guid)

	if GetCVar("chatClassColorOverride") ~= "1" then
		local _, englishClass = GetPlayerInfoByGUID(guid);
		characterColor = TRP3_API.GetClassDisplayColor(englishClass);
	end

	if configShowNameCustomColors() then
		characterColor = player:GetCustomColorForDisplay() or characterColor;
	end

	return characterColor;
end


function getTargetTRP3NameAndColor()
	local getUnitID = TRP3_API.utils.str.getUnitID;
	local companionIDToInfo = TRP3_API.utils.str.companionIDToInfo;
	local unitIDToInfo = TRP3_API.utils.str.unitIDToInfo;
	local configShowNameCustomColors = TRP3_API.chat.configShowNameCustomColors;

	local targetID = getTargetId("target");
	if targetID == nil then
		return nil;
	end
	local owner, companionID = companionIDToInfo(targetID);
	local profile = getCompanionInfo(owner, companionID, targetID);

	if profile and profile.data then
		local targetName = profile.data.NA or companionID;
		local customColor = nil;
		if configShowNameCustomColors() then
			customColor = getTargetsNameColor(profile);
		end
		return targetName, customColor;
	end
	return nil;
end

--Straight port of TRP3's target_frame.lua:getCompanionInfo() 
function getCompanionInfo(owner, companionID, currentTargetId)
	local profile;
	local Globals = TRP3_API.globals;
	local getCompanionProfile = TRP3_API.companions.player.getCompanionProfile;
	local getCompanionRegisterProfile = TRP3_API.companions.register.getCompanionProfile;
	if owner == Globals.player_id then
		profile = getCompanionProfile(companionID) or EMPTY;
	else
		profile = getCompanionRegisterProfile(currentTargetId);
	end
	return profile;
end

function getTargetsNameColor(profile)
	local customColor = profile.data.NH;

	if customColor then
		local color = TRP3_API.CreateColorFromHexString(customColor);
		color = TRP3_API.GenerateReadableColor(color, TRP3_ReadabilityOptions.TextOnBlackBackground);
		return color;
	end
	return nil;
end

--Basically a straight port of target_frame.lua's onTargetChanged()
function getTargetId()
	local getUnitID = TRP3_API.utils.str.getUnitID;
	local getTargetType, getCompanionFullID = TRP3_API.ui.misc.getTargetType, TRP3_API.ui.misc.getCompanionFullID;
	local TYPE_CHARACTER = TRP3_API.ui.misc.TYPE_CHARACTER;
	local TYPE_PET = TRP3_API.ui.misc.TYPE_PET;
	local TYPE_BATTLE_PET = TRP3_API.ui.misc.TYPE_BATTLE_PET;
	local TYPE_NPC = TRP3_API.ui.misc.TYPE_NPC;

	currentTargetType = getTargetType("target");
	if currentTargetType == TYPE_CHARACTER then
		return getUnitID("target");
	elseif currentTargetType == TYPE_NPC then
		return TRP3_API.utils.str.getUnitNPCID("target");
	end
	
	return getCompanionFullID("target", currentTargetType);
end

POSSIBLE_CHANNELS = {
	"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE",
	"CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
	"CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM"
};


local MODULE_STRUCTURE = {
	["name"] = "Speaker Bee Integration",
	["description"] = "Module for integrating TotalRP3's chatframe system with Speaker Bee.",
	["version"] = 1.000,
	--Note: Be careful of changing the id because this module needs to go after the chatframe module in trp3 
	--Check order of module loading using a print statement in trp3's registerModule method
	["id"] = "trp3_module_speakerBee",
	["onStart"] = TotalRP3_onStart,
	["minVersion"] = 3,
	["requiredDeps"] = {
		{ "trp3_chatframes", 1.100 },
	}
};

if TRP3_API then
	TRP3_API.module.registerModule(MODULE_STRUCTURE);
end
