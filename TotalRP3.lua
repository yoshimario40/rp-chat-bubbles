-- Author      : Chrono
-- Create Date : 3/29/2020 4:39:46 PM


local _, Import = ...;

local ellyb, loc, Color, ColorManager;
local NPC_TALK_PATTERNS;


local function makeBubbleForNPCChat(_, event, message, ...)
	if event == "CHAT_MSG_EMOTE" then
		local npcName = TRP3_API.chat.getNPCMessageName()
		if npcName then
			for talkType, talkChannel in pairs(NPC_TALK_PATTERNS) do
				if message:find(talkType) then
					local color;
					local myMessage = message;
					local normalColor = ColorManager.getChatColorForChannel(talkChannel);
					local normalColorAsString = normalColor:GetColorCodeStartSequence();
					local nameColor;

					--Detect colour alterations
					if myMessage:sub(1,2) == "|c" then
						color = myMessage:sub(1,10); --Save this to prepend back later
						myMessage = myMessage:sub(11);
					end

					--If the name is in the default color scheme, remove it for titling emphasis
					if npcName:sub(1,10) ~= normalColorAsString then
						nameColor = Color.static.CreateFromHexa(npcName:sub(1,10));
					end
					npcName = npcName:sub(11);

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
						print("NPC Talk Found! npcName="..npcName);
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

function TotalRP3_onStart(self)
	if TRP3_API then
		initTRP3Vars();
		for _, channel in pairs(POSSIBLE_CHANNELS) do
			ChatFrame_RemoveMessageEventFilter(channel, makeBubbleForNPCChat);
			ChatFrame_AddMessageEventFilter(channel, makeBubbleForNPCChat);
		end 
		Import.modules.BlizzChatIntegration:ResetChatHandler()
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
