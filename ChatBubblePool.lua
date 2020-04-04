-- Author      : Christopher Tse
-- Create Date : 3/28/2020 1:37:28 PM

local ADDON_NAME, Import = ...;

local pool = {}

Import.ChatBubblePool = {};
local ChatBubblePool = Import.ChatBubblePool

local function adjustChatBubbleWidth(chatBubble)
	local editBox = chatBubble.editBox;
	local strWidth = editBox.stringMeasure:GetStringWidth();
	local bg = editBox.background;
	local padding = bg.padding;
	local nameBox = chatBubble.nameBox
	local nameBoxWidth = nameBox:GetFullWidth();
	local minWidth = 64;
	if ( nameBoxWidth ~= nil) then
		local nameBoxMargin = nameBox.margin.L + nameBox.margin.R;
		minWidth = max(64, nameBoxWidth + nameBoxMargin);
	end
	local maxWidth = chatBubble:GetWidth()
	if ( strWidth < minWidth ) then
		bg:SetWidth(minWidth + padding)
	elseif ( minWidth < strWidth and strWidth < maxWidth ) then
		bg:SetWidth(strWidth + padding)
	else
		bg:SetWidth(maxWidth + padding ) 
	end
end

local function adjustNameBoxWidth(chatBubble)
	local nameBox = chatBubble.nameBox;
	local nameBoxBg = nameBox.background;
	local strWidth = nameBox.stringMeasure:GetStringWidth();
	local minWidth = 32;
	local padding = nameBox.padding.L + nameBox.padding.R;
	--The max width usually won't be reached because of the character limit on the name box
	local maxWidth = chatBubble:GetWidth() - padding - nameBox.margin.L
	if ( strWidth < minWidth ) then
		nameBoxBg:SetWidth(minWidth + padding);
	elseif ( minWidth < strWidth and strWidth < maxWidth ) then
		nameBoxBg:SetWidth(strWidth + padding);
	else
		nameBoxBg:SetWidth(maxWidth + padding);
	end
end

local function pickNameColor(chatBubble)
	local r, g, b = chatBubble:GetNameColor()
	ColorPickerFrame.hasOpacity = false;
	ColorPickerFrame.func = function(self) chatBubble:SetNameColor(ColorPickerFrame:GetColorRGB()) end;
	ColorPickerFrame.cancelFunc = function(self) chatBubble:SetNameColor(r,g,b) end;
	ColorPickerFrame:SetColorRGB(r,g,b);
	ColorPickerFrame:Show();
end

local function closeBubble(chatBubble)
	chatBubble:Hide();
	chatBubble:SetMessage("");
	chatBubble:SetName("");

	chatBubble.nameBox:SetAlpha(0.01)
	chatBubble:ClearAllPoints();
	chatBubble:ResetNameColor();
	chatBubble:SetPoint("TOPLEFT",WorldFrame,"CENTER",-chatBubble.center.x,-chatBubble.center.y);
	chatBubble.isAvailable = true;
end

local function getClosestEdge(tail,bubble,cursorX,cursorY)
	local centerX, centerY = bubble:GetCenter()
	local bubbleGradient = bubble:GetHeight() / bubble:GetWidth();
	--This calculates the vector from the center of the bubble to the cursor co-oridinates. 
	local localCursorX, localCursorY = cursorX - centerX, cursorY - centerY;
	if localCursorX >= 0 and localCursorX * bubbleGradient > math.abs(localCursorY) then
		return "RIGHT", "BOTTOMLEFT", "BOTTOMRIGHT";
	elseif localCursorX < 0 and -localCursorX * bubbleGradient > math.abs(localCursorY) then
		return "LEFT", "BOTTOMRIGHT", "BOTTOMLEFT";
	elseif localCursorY >= 0 and localCursorY > math.abs(localCursorX) * bubbleGradient then
		return "TOP", "BOTTOMLEFT","TOPLEFT";
	else
		return "BOTTOM", "TOPLEFT", "BOTTOMLEFT";
	end
end

local function moveTail(tail)
	--Note: Since the chat bubble is anchored to the WorldFrame, we shouldn't adjust for UIParent's scale
	local cursorX, cursorY = GetCursorPosition();  
	local origPoint = tail.origPoint;
	local bubble = tail:GetParent();
	local tailWidth, tailHeight = tail:GetWidth(), tail:GetHeight();
	local bubbleWidth, bubbleHeight = bubble:GetWidth(), bubble:GetHeight();
	local closestEdge, point, anchoringPoint = getClosestEdge(tail,bubble,cursorX,cursorY);
	if closestEdge == "BOTTOM" or closestEdge == "TOP" then
		local offset = cursorX - tail.origCursorLoc.x
		local newX = origPoint.x + offset;
		if newX < tail.minX  then
			newX = tail.minX
		elseif newX > bubbleWidth - tailWidth - tail.minX then
			newX = bubbleWidth - tailWidth - tail.minX
		end
		local yOffset = 0;
		if closestEdge == "BOTTOM" then
			yOffset = tail.bottomOffset;
			tail.tex:SetRotation(0);
		else
			yOffset = tail.topOffset;
			tail.tex:SetRotation(math.pi)
		end 
		tail:ClearAllPoints();
		tail:SetPoint(point,bubble,anchoringPoint,newX,yOffset);
	else
		local offset = cursorY - tail.origCursorLoc.y
		local newY = origPoint.y + offset;
		if newY < tail.minY then
			newY = tail.minY
		elseif newY > bubbleHeight - tailHeight - tail.minY then
			newY = bubbleHeight - tailHeight - tail.minY
		end
		local xOffset = 0;
		if closestEdge == "LEFT" then
			xOffset = tail.leftOffset;
			tail.tex:SetRotation(math.pi * 1.5 ); 
		else 
			xOffset = tail.rightOffset;
			tail.tex:SetRotation(math.pi * 0.5);
		end
		tail:ClearAllPoints();
		tail:SetPoint(point,bubble,anchoringPoint,xOffset,newY);
	end
end 

local function startMovingTail(self, button)
	if button == "LeftButton" then
		local origCursor = {};
		local origPoint = {};
		origCursor.x, origCursor.y = GetCursorPosition();
		origPoint.p, origPoint.relative, origPoint.relativeP, origPoint.x, origPoint.y = self:GetPoint(1);
		self.origPoint = origPoint;
		self.origCursorLoc = origCursor;
		self:SetScript("OnUpdate",moveTail);
	end
end

local function stopMovingTail(self,button)
	if button == "LeftButton" then
		self:SetScript("OnUpdate",nil);
	end 
end

function ChatBubblePool.getChatBubble()
	for index, chatBubble in ipairs(pool) do
		if chatBubble.isAvailable then
			chatBubble:Show()
			chatBubble.isAvailable = false;
			return chatBubble
		end
	end

	-- If we got here, there isn't any available chat bubble so create a new one
	local frameName = "RPChatBubble" .. #pool

	local newChatBubble = CreateFrame("Frame",frameName,nil)
	newChatBubble:SetWidth(300)
	newChatBubble:SetHeight(300)
	newChatBubble:SetMovable(true)
	newChatBubble:SetFrameStrata("LOW")
	newChatBubble.isAvailable = false
	table.insert(pool, newChatBubble);

	--chatBubbleTail:EnableMouse(true)
	--chatBubbleTail:SetMovable(true)
	--chatBubbleTail:RegisterForDrag("LeftButton")
	--chatBubbleTail:SetScript("OnDragStart", function(self) self:StartMoving() end)
	--chatBubbleTail:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

	local editBox = CreateFrame("EditBox",frameName.."-EditBox",newChatBubble);
	editBox:SetPoint("TOPLEFT",newChatBubble);
	editBox:SetPoint("TOPRIGHT",newChatBubble);
	editBox:SetMultiLine(true);
	editBox:SetAutoFocus(false);
	editBox:SetFontObject("ChatBubbleFont");
	editBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end);
	editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end);
	--Apparently, the below code stops the user from being able to change the cursor location
	--editBox:EnableMouse(true)
	--editBox:SetScript("OnMouseDown", function(self) newChatBubble:StartMoving() end )
	--editBox:SetScript("OnMouseUp", function(self) newChatBubble:StopMovingOrSizing() end )

	newChatBubble.editBox = editBox;
	--This is a hack that centers the newChatBubble using the center of the editbox
	newChatBubble.center = { x=editBox:GetWidth()/2, y=editBox:GetHeight()/2 };
	newChatBubble:SetPoint("TOPLEFT",WorldFrame,"CENTER",-newChatBubble.center.x,-newChatBubble.center.y);

	local chatBubbleBackground = CreateFrame("Frame",frameName.."Background",editBox);
	chatBubbleBackground:SetBackdrop({
		bgFile="Interface\\Tooltips\\CHATBUBBLE-BACKGROUND.BLP", 
		edgeFile="Interface\\Tooltips\\CHATBUBBLE-BACKDROP.BLP", 
		tile=true, tileSize=16, edgeSize=16, 
		insets={left=16, right=16, top=16, bottom=16}
	})
	chatBubbleBackground:EnableMouse(true);
	chatBubbleBackground:SetPoint("TOPLEFT",editBox,"TOPLEFT",-16,16);
	chatBubbleBackground:SetPoint("BOTTOMLEFT",editBox,"BOTTOMLEFT",-16,-16);
	chatBubbleBackground.padding = 32;
	chatBubbleBackground:SetWidth(64 + chatBubbleBackground.padding);
	chatBubbleBackground:SetFrameStrata("BACKGROUND");
	chatBubbleBackground:EnableMouse(true);
	chatBubbleBackground:SetScript("OnMouseDown", function(self) newChatBubble:StartMoving() end )
	chatBubbleBackground:SetScript("OnMouseUp", function(self) newChatBubble:StopMovingOrSizing() end )
	editBox.background = chatBubbleBackground;

	--This part of the code makes the editbox and the background grow up to 300px as the text grows.
	--We use an invisible FontString to measure the length of the text inside the edit box.
	editBox.stringMeasure = editBox:CreateFontString(nil,"OVERLAY","ChatBubbleFont");
	editBox.stringMeasure:SetAlpha(0);
	editBox:SetScript("OnTextChanged", function(self) 
	    editBox.stringMeasure:SetText(self:GetText());
		adjustChatBubbleWidth(newChatBubble);
	end)

	local closeButton = CreateFrame("Button",frameName.."-CloseButton",chatBubbleBackground,"UIPanelCloseButton")
	closeButton:SetPoint("CENTER",chatBubbleBackground,"TOPRIGHT",-4,-4);
	closeButton:SetScript("OnClick",function(self) closeBubble(newChatBubble) end);
	closeButton:SetScript("OnEnter",function(self) closeButton:SetAlpha(1) end);
	closeButton:SetScript("OnLeave",function(self) closeButton:SetAlpha(0.1) end);
	closeButton:SetAlpha(0.1);

	local nameBoxFrame = CreateFrame("Frame",frameName.."-NameBoxFrame",newChatBubble)
	nameBoxFrame:SetSize(250,18);
	nameBoxFrame:SetPoint("BOTTOMLEFT",chatBubbleBackground,"TOPLEFT");
	
	local nameBox = CreateFrame("EditBox",frameName.."-NameBox",nameBoxFrame);
	nameBox:SetFontObject("GameFontNormal");
	nameBox:SetMaxLetters(25);
	nameBox.margin = {L=10, R=0, T=4, D=4};
	nameBox.padding = {L=10, R=10};
	nameBox:SetPoint("TOPLEFT",nameBoxFrame,nameBox.margin.L,-nameBox.margin.T);
	nameBox:SetPoint("BOTTOMRIGHT",nameBoxFrame,-nameBox.margin.R,nameBox.margin.D);
	nameBox:SetAutoFocus(false);
	nameBox:SetMultiLine(true); --It's not actually multiline, but this stops the name from scrolling off if the user selects too much of the text. 
								--The max letters should prevent the edit box from ever reaching more than one line
	nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end);
	nameBox:SetScript("OnTabPressed", function(self) editBox:SetFocus() end);
	nameBox:SetAlpha(0);
	nameBox:SetScript("OnEditFocusGained", function(self) self:SetAlpha(1) end);
	nameBox:SetScript("OnEditFocusLost", function(self) if self:GetText() == "" then self:SetAlpha(0.01) end end);
	newChatBubble.nameBox = nameBox;

	local nameBoxBackground = CreateFrame("Frame",frameName.."-NameBoxBackground",nameBox);
	local paddingL = nameBox.padding.L;
	nameBoxBackground:SetPoint("BOTTOMLEFT",nameBox,"BOTTOMLEFT",-paddingL,-nameBox.margin.D)
	nameBoxBackground:SetPoint("TOPLEFT",nameBox,"TOPLEFT",-paddingL,nameBox.margin.T + 12);
	nameBoxBackground:SetWidth(32);
	nameBoxBackground:SetFrameStrata("BACKGROUND");
	nameBox.background = nameBoxBackground

	local nameBoxMouseCatcher = CreateFrame("Button",frameName.."-NameBoxMouseCatcher",nameBox);
	nameBoxMouseCatcher:SetPoint("BOTTOMLEFT",nameBoxBackground);
	nameBoxMouseCatcher:SetPoint("TOPRIGHT",nameBoxBackground);
	nameBoxMouseCatcher:SetScript("OnEnter", function(self) if nameBox:GetText() == "" and not nameBox:HasFocus() then nameBox:SetAlpha(0.5) end end);
	nameBoxMouseCatcher:SetScript("OnLeave", function(self) if nameBox:GetText() == "" and not nameBox:HasFocus() then nameBox:SetAlpha(0) end end);
	nameBoxMouseCatcher:SetScript("OnClick", function(self) nameBox:SetFocus() end);
	nameBoxMouseCatcher:SetScript("OnMouseDown", function(self) newChatBubble:StartMoving() end )
	nameBoxMouseCatcher:SetScript("OnMouseUp", function(self) newChatBubble:StopMovingOrSizing() end )
	
	local nameBoxColorPicker = CreateFrame("Button",frameName.."-ColorPickerButton",newChatBubble);
	nameBoxColorPicker:SetSize(16,16);
	nameBoxColorPicker:SetFrameStrata("MEDIUM") -- Needs to be higher than the EditBox to override it
	nameBox.colorPickerTex = nameBoxColorPicker:CreateTexture(frameName.."-ColorPickerButton-color","ARTWORK")
	nameBox.colorPickerTex:SetPoint("TOPLEFT",2,-2);
	nameBox.colorPickerTex:SetPoint("BOTTOMRIGHT",-2,2);
	nameBox.colorPickerTex:SetColorTexture(nameBox:GetTextColor());
	local cpBorderTex = nameBoxColorPicker:CreateTexture(frameName.."-ColorPickerButton-border","BORDER");
	cpBorderTex:SetAllPoints();
	cpBorderTex:SetColorTexture(0.1,0.1,0.1);
	nameBoxColorPicker:SetPoint("BOTTOMLEFT",nameBoxBackground,"BOTTOMRIGHT");
	nameBoxColorPicker:SetAlpha(0.01);
	nameBoxColorPicker:EnableMouse(true);
	nameBoxColorPicker:SetScript("OnEnter", function(self) if nameBox:GetText() ~= "" then self:SetAlpha(1); end; end);
	nameBoxColorPicker:SetScript("OnLeave", function(self) self:SetAlpha(0.01) end);
	nameBoxColorPicker:SetScript("OnClick", function(self) pickNameColor(newChatBubble) end);

	nameBox.stringMeasure = nameBox:CreateFontString(nil,"OVERLAY","GameFontNormal");
	--nameBox.stringMeasure:SetAlpha(0);
	nameBox.GetFullWidth = function(self)  return nameBoxBackground:GetWidth() end;
	nameBox:SetScript("OnTextChanged", function(self)
		nameBox.stringMeasure:SetText(self:GetText());
		adjustNameBoxWidth(newChatBubble)
		adjustChatBubbleWidth(newChatBubble)
	end);
	
	local midTex = nameBoxBackground:CreateTexture("nameBoxBackgroundTex-middle","BACKGROUND");
	midTex:SetTexture("Interface/CHATFRAME/ChatFrameTab-BGMid.blp");
	midTex:SetPoint("TOPLEFT",16,0);
	midTex:SetPoint("BOTTOMRIGHT",-16,0);
	local leftTex = nameBoxBackground:CreateTexture("nameBoxBackgroundTex-left","BACKGROUND");
	leftTex:SetTexture("Interface/CHATFRAME/ChatFrameTab-BGLeft.blp");
	leftTex:SetPoint("TOPRIGHT",midTex,"TOPLEFT");
	leftTex:SetPoint("BOTTOMRIGHT",midTex,"BOTTOMLEFT");
	local rightTex = nameBoxBackground:CreateTexture("nameBoxBackgroundTex-right","BACKGROUND");
	rightTex:SetTexture("Interface/CHATFRAME/ChatFrameTab-BGRight.blp");
	rightTex:SetPoint("TOPLEFT",midTex,"TOPRIGHT");
	rightTex:SetPoint("BOTTOMLEFT",midTex,"BOTTOMRIGHT");
	
	local chatBubbleTail = CreateFrame("Frame",frameName.."-tail",chatBubbleBackground)
	chatBubbleTail:SetSize(16,16)
	chatBubbleTail:SetPoint("TOPLEFT",chatBubbleBackground,"BOTTOMLEFT",8,3)
	chatBubbleTail.tex = chatBubbleTail:CreateTexture(frameName.."-tailTexture","BACKGROUND");
	chatBubbleTail.tex:SetTexture("Interface\\Tooltips\\CHATBUBBLE-TAIL.BLP");
	chatBubbleTail.tex:SetAllPoints();
	chatBubbleTail:SetScript("OnMouseDown",startMovingTail);
	chatBubbleTail:SetScript("OnMouseUp",stopMovingTail);
	chatBubbleTail.bottomOffset = 3;
	chatBubbleTail.topOffset = -3;
	chatBubbleTail.leftOffset = 3;
	chatBubbleTail.rightOffset = -3;
	chatBubbleTail.minX = 8;
	chatBubbleTail.minY = 8;


	--Functions for outside use
	newChatBubble.GetName = nameBox.GetText;
	newChatBubble.SetName = function(self,name) nameBox:SetText(name); if (name ~= "" ) then nameBox:SetAlpha(1); end; end;
	newChatBubble.GetMessage = editBox.GetText;
	newChatBubble.SetMessage = function(self,message) editBox:SetText(message) end;
	newChatBubble.GetNameColor = function(self) return nameBox:GetTextColor() end;
	newChatBubble.SetNameColor = function(self,r,g,b) nameBox:SetTextColor(r,g,b) nameBox.colorPickerTex:SetColorTexture(r,g,b) end;

	local origR,origG,origB = nameBox:GetTextColor();
	newChatBubble.ResetNameColor = function(self) self:SetNameColor(origR,origG,origB); end;

	return newChatBubble
end