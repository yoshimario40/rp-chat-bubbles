-- Author      : Chrono
-- Create Date : 3/30/2020 8:27:47 PM

local ADDON_NAME, Import = ...

local settings;

--This is an invisible frame that is created to receive OnUpdate calls
--Attached to the WorldFrame so it receives events even when the UI is hidden
local Timer = CreateFrame("Frame","RPChatBubble-Timer",WorldFrame)
Timer:SetFrameStrata("TOOLTIP") -- higher strata is called last

--Alias functions 
Timer.Start = Timer.Show
Timer.Stop = function(self) 
	Timer:Hide()
	Timer.elapsed = 0
end

Timer:Stop()

local numBubbles = 0;
local messageToSender = {};

local MANAGED_CHANNELS = {
	"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL"
};

local function getPadding(numSpaces)
	local str = ">";
	for i=1,numSpaces,1 do
		str = "-" .. str
	end 
	return str
end 

local function printTable(t, depth)
	local padding = getPadding(depth)
	for key, value in pairs(t) do
		if type(value) == "table" then
			print(padding .. key .. " = (table):");
			printTable(value, depth + 1);
		else 
			print(padding .. key .. " ("..type(value)..") = " .. tostring(value) );
		end 
	end
end 

local function getChatBubbleFontString(chatBubble)
	--9.0.1 put frame data into a child of the bubble. I think this is a part of the backdrop api change. But anyway,
	--we're just going to assume that the frame data is the first element of the chat bubble table. 
	chatBubbleFrame = select(1,chatBubble:GetChildren());
	for i = 1, chatBubbleFrame:GetNumRegions() do
		local region = select(i, chatBubbleFrame:GetRegions())
		if region:GetObjectType() == "FontString" then
			return region
		end
	end
end 

local function getNamedPoint(chatBubble,pointName)
	local chatBubbleFrame = select(1, chatBubble:GetChildren());
	for i = 1, chatBubbleFrame:GetNumPoints() do
		local point, relativeTo, relativePoint, xOfs, yOfs = chatBubbleFrame:GetPoint(i);
		if point == pointName then
			return relativeTo, relativePoint, xOfs, yOfs;
		end 
	end 
end

local function skinBubble(chatBubble)
	local fontString = getChatBubbleFontString(chatBubble);
	local message = fontString:GetText()
	local name = messageToSender[message]
	local fontSize = settings.get("FONT_SIZE");
	if (name == nil) then
		name = "";
	end

	local NameText = CreateFrame("EditBox","BlizzBoxNameText",chatBubble);
	NameText:SetFrameStrata("MEDIUM"); --This is the default but better to be explicit
	NameText:SetAutoFocus(false);
	NameText:EnableMouse(false);
	NameText:SetSize(700,11);
	NameText:SetPoint("BOTTOMLEFT",chatBubble,"TOPLEFT",13,2);
	NameText:SetFontObject("GameFontNormal");
	NameText.stringMeasure = NameText:CreateFontString(nil,"OVERLAY","GameFontNormal");

	local NameBg = CreateFrame("Frame","BlizzBubbleNameBG",NameText);
	NameBg:SetPoint("TOPLEFT",-1,14);
	NameBg:SetPoint("BOTTOMLEFT",-1,-2);
	NameBg:SetWidth(NameText.stringMeasure:GetStringWidth());
	NameBg:SetFrameStrata("BACKGROUND");
	
	local midTex = NameBg:CreateTexture("nameBoxBackgroundTex-middle","BACKGROUND");
	midTex:SetTexture("Interface/CHATFRAME/ChatFrameTab-BGMid.blp");
	midTex:SetPoint("TOPLEFT",8,0);
	midTex:SetPoint("BOTTOMRIGHT",-7,0);
	local leftTex = NameBg:CreateTexture("nameBoxBackgroundTex-left","BACKGROUND");
	leftTex:SetTexture("Interface/CHATFRAME/ChatFrameTab-BGLeft.blp");
	leftTex:SetPoint("TOPRIGHT",midTex,"TOPLEFT");
	leftTex:SetPoint("BOTTOMRIGHT",midTex,"BOTTOMLEFT");
	local rightTex = NameBg:CreateTexture("nameBoxBackgroundTex-right","BACKGROUND");
	rightTex:SetTexture("Interface/CHATFRAME/ChatFrameTab-BGRight.blp");
	rightTex:SetPoint("TOPLEFT",midTex,"TOPRIGHT");
	rightTex:SetPoint("BOTTOMLEFT",midTex,"BOTTOMRIGHT");

	local relativeTo, relativePoint, xOfs, yOfs = getNamedPoint(chatBubble,"BOTTOMRIGHT");
	chatBubble.string = relativeTo;
	chatBubble.defaultXOfs = xOfs;
	chatBubble.fixWidth = function(self)
		local nameWidth = NameText.stringMeasure:GetWidth();
		NameBg:SetWidth(nameWidth);
		local stringWidth = self.string:GetWidth();
		local expectedWidth = stringWidth + 32;
		local requiredWidthForName = nameWidth + 32; 
		local defaultXOfs = self.defaultXOfs;
		local relativeTo, relativePoint, xOfs, yOfs = getNamedPoint(self,"BOTTOMRIGHT");
		local currHeight = self:GetHeight();
		local frame = select(1, chatBubble:GetChildren()); 
		if ( expectedWidth < requiredWidthForName ) then
			local adj = (requiredWidthForName - expectedWidth)/2;
			frame:SetPoint("TOPLEFT",relativeTo,"TOPLEFT",-(defaultXOfs+adj),-yOfs);
			frame:SetPoint("BOTTOMRIGHT",relativeTo,"BOTTOMRIGHT",defaultXOfs+adj,yOfs);
		else
			frame:SetPoint("TOPLEFT",relativeTo,"TOPLEFT",-defaultXOfs,-yOfs);
			frame:SetPoint("BOTTOMRIGHT",relativeTo,"BOTTOMRIGHT",defaultXOfs,yOfs);
		end
		local _, _, newX, newY = getNamedPoint(self,"BOTTOMRIGHT");
	end

	chatBubble.nameText = NameText;
	chatBubble.SetName = function(self,text)
		NameText:SetText(text) 
		NameText.stringMeasure:SetText(text);
		if (text == "") then
			NameText:SetAlpha(0);
		else
			NameText:SetAlpha(1);
		end
		self:fixWidth();
	end;
	chatBubble:SetName(name);
	chatBubble.rpSkinned = true;
	numBubbles = numBubbles + 1;
end

local function checkBubbles(chatBubbles)
	--chatBubbles is an indexed array of frames with one or more children bubbles
	for _, chatBubble in pairs(chatBubbles) do
		--7.2.5 disabled chatbubble skinning in dungeons and raids
		if not chatBubble:IsForbidden() then
			if not chatBubble.rpSkinned then
				skinBubble(chatBubble)
			else
				local fontString = getChatBubbleFontString(chatBubble);
				local message = fontString:GetText();
				local sender = messageToSender[message];
				if sender == nil then
					sender = "";
				end
				chatBubble:SetName(sender)
			end
		end
	end
end

Timer:SetScript("OnUpdate", function(self, elapsed)
	self.elapsed = self.elapsed + elapsed
	-- 0.01 Seconds after the chat message happened...
	if self.elapsed > 0.01 then
		self:Stop();
		--This returns all chat bubbles created through default Blizz's UI. Custom chat bubbles aren't seen here
		local chatBubbles = C_ChatBubbles:GetAllChatBubbles();
		checkBubbles(chatBubbles);
	end
end)

local function onChatMessage(_, event, message, sender, ...)
	local name = GetColoredName(event, message, sender, ...);
	local messageInBubble = message:gsub("|c%w%w%w%w%w%w%w%w(.*)|r","%1"); --Replace colours
	messageInBubble = messageInBubble:gsub("|H.*|h%[(.*)%]|h", "%1") --Replace hyperlinks
	messageInBubble = messageInBubble:gsub("{rt[1-8]}","|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%1:0|t"); --Replace raid icons
	messageToSender[messageInBubble] = name;
	--At the time of the chat event, the chat bubble hasn't been created yet. So we'll wait 0.01 seconds before looking for chat bubbles to skin.
	Timer:Start();
	return false, message, sender, ...
end

--This will probably not be needed, but just in case...
--local function resetChatHandler(self)
--	for _, channel in pairs(MANAGED_CHANNELS) do
--		ChatFrame_RemoveMessageEventFilter(channel, onChatMessage)
--		ChatFrame_AddMessageEventFilter(channel, onChatMessage);
--	end
--end

local function onStart(self)
	settings = Import.settings;
	if settings.get("DRESS_BLIZZ_BUBBLE") then
		for _, channel in pairs(MANAGED_CHANNELS) do
			ChatFrame_AddMessageEventFilter(channel, onChatMessage);
		end
	end
end

Import.modules.BlizzChatIntegration = {};
Import.modules.BlizzChatIntegration.name = "BlizzChatIntegration";
Import.modules.BlizzChatIntegration.OnStart = onStart;
--Import.modules.BlizzChatIntegration.ResetChatHandler = resetChatHandler