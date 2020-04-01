-- Author      : Chrono
-- Create Date : 3/30/2020 8:27:47 PM

local ADDON_NAME, Import = ...

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

local function getChatBubbleText(chatBubble)
	for i = 1, chatBubble:GetNumRegions() do
		local region = select(i, chatBubble:GetRegions())
		if region:GetObjectType() == "FontString" then
			return region:GetText()
		end
	end
end 

local function getNamedPoint(chatBubble,pointName)
	for i = 1, chatBubble:GetNumPoints() do
		local point, relativeTo, relativePoint, xOfs, yOfs = chatBubble:GetPoint(i);
		if point == pointName then
			return relativeTo, relativePoint, xOfs, yOfs;
		end 
	end 
end

local function skinBubble(chatBubble)
	local message = getChatBubbleText(chatBubble);
	local name = messageToSender[message]

	local NameText = CreateFrame("EditBox","BlizzBoxNameText",chatBubble);
	NameText:SetFrameStrata("MEDIUM"); --This is the default but better to be explicit
	--NameText:SetMultiLine(true);
	NameText:SetAutoFocus(false);
	NameText:EnableMouse(false);
	NameText:SetSize(700,11);
	--NameText:SetPoint("CENTER");
	NameText:SetPoint("BOTTOMLEFT",chatBubble,"TOPLEFT",13,2);
	NameText:SetFontObject("GameFontNormal");
	NameText:SetText(name);
	--local tex = NameText:CreateTexture(nil,"ARTWORK");
	--tex:SetAllPoints()
	--tex:SetTexture(255,255,255);
	NameText.stringMeasure = NameText:CreateFontString(nil,"OVERLAY","GameFontNormal");
	NameText.stringMeasure:SetText(name);

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
	--chatBubble.string:SetJustifyH("LEFT");
	chatBubble.defaultXOfs = xOfs;
	chatBubble.fixWidth = function(self)
		local nameWidth = NameText.stringMeasure:GetWidth();
		NameBg:SetWidth(nameWidth);
		local stringWidth = self.string:GetWidth();
		local expectedWidth = stringWidth + 32;
		local requiredWidthForName = nameWidth + 13 + 2 + 16;
		local defaultXOfs = self.defaultXOfs;
		local relativeTo, relativePoint, xOfs, yOfs = getNamedPoint(self,"BOTTOMRIGHT");
		local currHeight = self:GetHeight();
		if ( expectedWidth < requiredWidthForName ) then
			local adj = (requiredWidthForName - expectedWidth)/2;
			self:SetPoint("TOPLEFT",relativeTo,"TOPLEFT",-(defaultXOfs+adj),-yOfs);
			self:SetPoint("BOTTOMRIGHT",relativeTo,"BOTTOMRIGHT",defaultXOfs+adj,yOfs);
		else
			self:SetPoint("TOPLEFT",relativeTo,"TOPLEFT",-defaultXOfs,-yOfs);
			self:SetPoint("BOTTOMRIGHT",relativeTo,relativePoint,defaultXOfs,yOfs);
		end
	end
	chatBubble:fixWidth();

	chatBubble.nameText = NameText;
	chatBubble.SetName = function(self,text)
		NameText:SetText(text) 
		NameText.stringMeasure:SetText(text);
		self:fixWidth();
	end;
	chatBubble.rpSkinned = true;
	numBubbles = numBubbles + 1;
end

local function checkBubbles(chatBubbles)
	--chatBubbles is an indexed array of frames
	for _, chatBubble in pairs(chatBubbles) do
		if not chatBubble.rpSkinned then
			skinBubble(chatBubble)
		else
			local message = getChatBubbleText(chatBubble)
			chatBubble:SetName(messageToSender[message])
		end
	end
end

Timer:SetScript("OnUpdate", function(self, elapsed)
	self.elapsed = self.elapsed + elapsed
	-- 0.01 Seconds after the chat message happened...
	if self.elapsed > 0.01 then
		self:Stop();
		--This returns all chat bubbles created through default Blizz's UI. Custom chat bubbles aren't seen here
		chatBubbles = C_ChatBubbles:GetAllChatBubbles()
		checkBubbles(chatBubbles)
	end
end)

local function onChatMessage(_, event, message, sender, ...)
	local name = GetColoredName(event, message, sender, ...);
	messageToSender[message] = name;
	--At the time of the chat event, the chat bubble hasn't been created yet. So we'll wait 0.01 seconds before looking for chat bubbles to skin.
	Timer:Start();
	return false, message, sender, ...
end

local function resetChatHandler(self)
	for _, channel in pairs(MANAGED_CHANNELS) do
		ChatFrame_RemoveMessageEventFilter(channel, onChatMessage)
		ChatFrame_AddMessageEventFilter(channel, onChatMessage);
	end
end

local function onStart(self)
	for _, channel in pairs(MANAGED_CHANNELS) do
		ChatFrame_AddMessageEventFilter(channel, onChatMessage);
	end
end

Import.modules.BlizzChatIntegration = {};
Import.modules.BlizzChatIntegration.name = "BlizzChatIntegration";
Import.modules.BlizzChatIntegration.OnStart = onStart;
Import.modules.BlizzChatIntegration.ResetChatHandler = resetChatHandler