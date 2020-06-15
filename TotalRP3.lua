-- Author      : Chrono
-- Create Date : 3/29/2020 4:39:46 PM


local _, Import = ...;

local ellyb, loc, Color, ColorManager;
local NPC_TALK_PATTERNS;
local settings;


local function makeBubbleForNPCChat(_, event, message, ...)
	if event == "CHAT_MSG_EMOTE" then
		local senderGUID = select(11, ...);
		local playerGUID = UnitGUID("player");
		local npcName = TRP3_API.chat.getNPCMessageName()
		if senderGUID == playerGUID or settings.generateTotalRP3BubblesForOtherPlayers then
		if npcName then
				for talkType, talkChannel in pairs(NPC_TALK_PATTERNS) do
					if message:find(talkType) then
						local color;
						local myMessage = message;
						local normalColor = ColorManager.getChatColorForChannel(talkChannel);
						local normalColorAsString = normalColor:GetColorCodeStartSequence();
						local nameColor;

						--Detect colour alterations. We need to remove it temporarily to remove the start.
						if myMessage:sub(1,2) == "|c" then
							color = myMessage:sub(1,10); --Save this to prepend back later
							myMessage = myMessage:sub(11);
						end

						--If the name is not in the default color scheme, save it to be set later
						--Otherwise, we'll highlight it with ChatBubble's default name colour.
						if npcName:sub(1,10) ~= normalColorAsString and npcName:sub(-2) == "|r" then
							nameColor = Color.static.CreateFromHexa(npcName:sub(1,10));
						else
							--Strip out the |c and |r tags so they don't get in the way of SetName()
							npcName = npcName:sub(11);
							npcName = npcName:sub(1,-3);
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
							local chatBubble = RPChatBubbles_createChatBubble()
							print(string.gsub(npcName,"|","||"));
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
	Color = ellyb.Color;
	ColorManager = ellyb.ColorManager;
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
		for _, channel in pairs(POSSIBLE_CHANNELS) do
			ChatFrame_RemoveMessageEventFilter(channel, makeBubbleForNPCChat);
			if settings.generateTotalRP3Bubbles then
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

--Import.modules["TotalRP3"] = {
--	name="TotalRP3",
--	onStart = TotalRP3_onStart;
--}

POSSIBLE_CHANNELS = {
	"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE",
	"CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
	"CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM"
};


local MODULE_STRUCTURE = {
	["name"] = "Roleplay Chat Bubbles",
	["description"] = "Module for integrating TotalRP3's chatframe system with Roleplay Chat Bubbles.",
	["version"] = 1.000,
	["id"] = "rp_chatBubbles",
	["onStart"] = TotalRP3_onStart,
	["minVersion"] = 3,
};

if TRP3_API then
	TRP3_API.module.registerModule(MODULE_STRUCTURE);
end
