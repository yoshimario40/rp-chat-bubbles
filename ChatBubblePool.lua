-- Author      : Christopher Tse
-- Create Date : 3/28/2020 1:37:28 PM

local ADDON_NAME, Import = ...;

local pool = {}

Import.ChatBubblePool = {};
local ChatBubblePool = Import.ChatBubblePool

local function setChatBubbleWidth(chatBubbleBg, parent, width)
	chatBubbleBg:SetPoint("TOPLEFT",parent,"TOP",-width/2,16);
	chatBubbleBg:SetPoint("BOTTOMLEFT",parent,"BOTTOM",-width/2,-16);
	chatBubbleBg:SetWidth(width);
end 

local function adjustChatBubbleWidth(chatBubble)
	local editBox = chatBubble.editBox;
	local strWidth = editBox.stringMeasure:GetStringWidth();
	local bg = editBox.background;
	local padding = bg.padding;
	local nameBox = chatBubble.nameBox
	local nameBoxWidth = nameBox:GetFullWidth();
	local minWidth = 64;
	if ( nameBoxWidth ~= nil) then
		local nameBoxMargin = nameBox.margin.L + nameBox.margin.R - nameBox.padding.L - 5;
		minWidth = max(64, nameBoxWidth + nameBoxMargin);
	end
	local maxWidth = chatBubble:GetWidth()
	if ( strWidth < minWidth ) then
		setChatBubbleWidth(bg, editBox, minWidth + padding);
	elseif ( minWidth < strWidth and strWidth < maxWidth ) then
		setChatBubbleWidth(bg, editBox, strWidth + padding);
	else
		setChatBubbleWidth(bg, editBox, maxWidth + padding);
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
	chatBubble:SetPoint("TOP",WorldFrame,"CENTER",0,-chatBubble.center.y);
	chatBubble.tail:Reset();
	chatBubble.isAvailable = true;
end

local function getClosestEdge(tail,bubble,cursorX,cursorY)
	local centerX, centerY = bubble:GetCenter()
	local bubbleGradient = bubble:GetHeight() / bubble:GetWidth();
	--This calculates the vector from the center of the bubble to the cursor co-oridinates. 
	local localCursorX, localCursorY = cursorX - centerX, cursorY - centerY;
	if localCursorX >= 0 and localCursorX * bubbleGradient > math.abs(localCursorY) then
		return "RIGHT", "TOPLEFT", "TOPRIGHT";
	elseif localCursorX < 0 and -localCursorX * bubbleGradient > math.abs(localCursorY) then
		return "LEFT", "TOPRIGHT", "TOPLEFT";
	elseif localCursorY >= 0 and localCursorY > math.abs(localCursorX) * bubbleGradient then
		return "TOP", "BOTTOMLEFT","TOPLEFT";
	else
		return "BOTTOM", "TOPLEFT", "BOTTOMLEFT";
	end
end

local function getAnchoringPointCoords(bubble,anchoringPoint)
	if anchoringPoint == "BOTTOMLEFT" then
		return { x=bubble:GetLeft(), y=bubble:GetBottom() };
	elseif anchoringPoint == "BOTTOMRIGHT" then
		return { x=bubble:GetRight(), y=bubble:GetBottom() };
	elseif anchoringPoint == "TOPLEFT" then
		return { x=bubble:GetLeft(), y=bubble:GetTop() };
	else
		return { x=bubble:GetRight(), y=bubble:GetTop() };
	end 
end

local function addVector(a, b)
	return { x=a.x + b.x, y=a.y + b.y };
end

local function subtractVector(a, b)
	return { x=a.x - b.x, y=a.y - b.y};
end

local function closeBubbles()
	for _, bubble in pairs(pool) do
		closeBubble(bubble);
	end
end 

local function hideBubbles()
	for _, bubble in pairs(pool) do
		bubble:Hide()
	end 
end 

local function showBubbles()
	for _, bubble in pairs(pool) do
		if not bubble.isAvailable then
			bubble:Show()
		end
	end
end

local function moveTail(tail)
	--Note: Since the chat bubble is anchored to the WorldFrame, we shouldn't adjust for UIParent's scale
	local cursorX, cursorY = GetCursorPosition();  
	local origPoint = tail.origPoint;
	local bubble = tail:GetParent();
	local tailWidth, tailHeight = tail:GetWidth(), tail:GetHeight();
	local bubbleWidth, bubbleHeight = bubble:GetWidth(), bubble:GetHeight();
	local closestEdge, point, anchoringPoint = getClosestEdge(tail, bubble, cursorX, cursorY);
	local anchoringPointCoords = getAnchoringPointCoords(bubble, anchoringPoint);
	local oldAnchoringPointCoords = getAnchoringPointCoords(bubble, origPoint.relativeP);
	local origPointWorldCoords = addVector(origPoint, oldAnchoringPointCoords);
	if closestEdge == "BOTTOM" or closestEdge == "TOP" then
		local cursorOffset = cursorX - tail.origCursorLoc.x;
		local newXinWorldCoords = origPointWorldCoords.x + cursorOffset;
		local newX = newXinWorldCoords - anchoringPointCoords.x
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
		local cursorOffset = cursorY - tail.origCursorLoc.y
		local newYinWorldCoords = origPointWorldCoords.y + cursorOffset
		local newY = -(newYinWorldCoords - anchoringPointCoords.y);
		if newY < tail.minY then
			newY = tail.minY
		elseif newY > bubbleHeight - tailHeight - tail.minY then
			newY = bubbleHeight - tailHeight - tail.minY
		end
		local xOffset = 0;
		if closestEdge == "LEFT" then
			xOffset = tail.leftOffset;
			tail.tex:SetRotation( math.pi * 1.5 ); 
		else 
			xOffset = tail.rightOffset;
			tail.tex:SetRotation( math.pi * 0.5 );
		end
		tail:ClearAllPoints();
		tail:SetPoint(point,bubble,anchoringPoint,xOffset,-newY);
	end
	tail.side = closestEdge
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

local function checkTailBounds(chatBubble)
	local tail = chatBubble.tail;
	local point, chatBubbleBg, relativePoint, x, y = tail:GetPoint(1);
	if tail.side == "RIGHT" or tail.side == "LEFT" then
		y = -y; --Reverse Y because the point goes from top down.
		local maxY = chatBubbleBg:GetHeight() - tail:GetHeight() - tail.minY
		if ( y > maxY ) then
			tail:SetPoint(point, chatBubbleBg, relativePoint, x, -maxY);
		end 
	else
		local maxX = chatBubbleBg:GetWidth() - tail:GetWidth() - tail.minX;
		if ( x > maxX ) then
			tail:SetPoint(point, chatBubbleBg, relativePoint, maxX, y);
		end
	end 
end

local function clearFocusAndSelection(editBox)
	editBox:ClearFocus()
	editBox:HighlightText(0,0);
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
	editBox:SetJustifyH("CENTER");
	editBox:SetScript("OnEnterPressed", function(self) if IsShiftKeyDown() then self:Insert("\n") else self:ClearFocus() end end);
	editBox:SetScript("OnEscapePressed",clearFocusAndSelection);
	--Apparently, the below code stops the user from being able to change the cursor location
	--editBox:EnableMouse(true)
	--editBox:SetScript("OnMouseDown", function(self) newChatBubble:StartMoving() end )
	--editBox:SetScript("OnMouseUp", function(self) newChatBubble:StopMovingOrSizing() end )

	newChatBubble.editBox = editBox;

	local chatBubbleBackground = CreateFrame("Button",frameName.."Background",editBox);
	chatBubbleBackground:SetBackdrop({
		bgFile="Interface\\Tooltips\\CHATBUBBLE-BACKGROUND.BLP", 
		edgeFile="Interface\\Tooltips\\CHATBUBBLE-BACKDROP.BLP", 
		tile=true, tileSize=16, edgeSize=16, 
		insets={left=16, right=16, top=16, bottom=16}
	})
	chatBubbleBackground:SetPoint("TOPLEFT",editBox,"CENTER",-16,16);
	chatBubbleBackground:SetPoint("BOTTOMLEFT",editBox,"CENTER",-16,-16);
	chatBubbleBackground.padding = 32;
	chatBubbleBackground:SetWidth(64 + chatBubbleBackground.padding);
	chatBubbleBackground:SetFrameStrata("BACKGROUND");
	chatBubbleBackground:SetScript("OnMouseDown", function(self) newChatBubble:StartMoving() end )
	chatBubbleBackground:SetScript("OnMouseUp", function(self) newChatBubble:StopMovingOrSizing() end )
	chatBubbleBackground:SetScript("OnClick", function(self) editBox:SetFocus() end);
	editBox.background = chatBubbleBackground;

	--This part of the code makes the editbox and the background grow up to 300px as the text grows.
	--We use an invisible FontString to measure the length of the text inside the edit box.
	editBox.stringMeasure = editBox:CreateFontString(nil,"OVERLAY","ChatBubbleFont");
	editBox.stringMeasure:SetAlpha(0);
	editBox:SetScript("OnTextChanged", function(self) 
	    editBox.stringMeasure:SetText(self:GetText());
		adjustChatBubbleWidth(newChatBubble);
		checkTailBounds(newChatBubble);
	end)

	--This is a hack that centers the newChatBubble using the center of the editbox
	newChatBubble.center = { x=chatBubbleBackground:GetWidth()/2, y=chatBubbleBackground:GetHeight()/2 };
	newChatBubble:SetPoint("TOP",WorldFrame,"CENTER",0,newChatBubble.center.y);


	local closeButton = CreateFrame("Button",frameName.."-CloseButton",chatBubbleBackground,"UIPanelCloseButton")
	closeButton:SetFrameStrata("LOW");
	closeButton:SetPoint("CENTER",chatBubbleBackground,"TOPRIGHT",-4,-4);
	closeButton:SetScript("OnClick",function(self) closeBubble(newChatBubble) end);
	closeButton:SetScript("OnEnter",function(self) closeButton:SetAlpha(1) end);
	closeButton:SetScript("OnLeave",function(self) closeButton:SetAlpha(0) end);
	closeButton:SetAlpha(0);

	local nameBoxFrame = CreateFrame("Frame",frameName.."-NameBoxFrame",newChatBubble)
	nameBoxFrame:SetSize(250,18);
	nameBoxFrame:SetPoint("BOTTOMLEFT",chatBubbleBackground,"TOPLEFT");
	
	local nameBox = CreateFrame("EditBox",frameName.."-NameBox",nameBoxFrame);
	nameBox:SetFontObject("GameFontNormal");
	nameBox:SetMaxLetters(25);
	nameBox.margin = {L=10, R=0, T=4, D=4};
	nameBox.padding = {L=10, R=10};
	nameBox:SetPoint("BOTTOMRIGHT",nameBoxFrame,-nameBox.margin.R,nameBox.margin.D);
	nameBox:SetPoint("TOPLEFT",nameBoxFrame,nameBox.margin.L,-nameBox.margin.T);
	nameBox:SetAutoFocus(false);
	nameBox:SetMultiLine(true); --It's not actually multiline, but this stops the name from scrolling off if the user selects too much of the text. 
								--The max letters should prevent the edit box from ever reaching more than one line
	nameBox:SetScript("OnEnterPressed",clearFocusAndSelection);
	nameBox:SetScript("OnTabPressed",function(self) editBox:SetFocus() end);
	nameBox:SetScript("OnEscapePressed",clearFocusAndSelection);
	nameBox:SetAlpha(0);
	nameBox:SetScript("OnEditFocusGained", function(self) self:SetAlpha(1) end);
	nameBox:SetScript("OnEditFocusLost", function(self) if self:GetText() == "" then self:SetAlpha(0.01) end end);
	--nameBox:SetScript("OnClick", function(self) nameBox:SetFocus() end);
	nameBox:SetScript("OnEnter", function(self) if nameBox:GetText() == "" and not nameBox:HasFocus() then nameBox:SetAlpha(0.5) end end);
	nameBox:SetScript("OnLeave", function(self) if nameBox:GetText() == "" and not nameBox:HasFocus() then nameBox:SetAlpha(0) end end);
	newChatBubble.nameBox = nameBox;

	local nameBoxBackground = CreateFrame("Button",frameName.."-NameBoxBackground",nameBox);
	local paddingL = nameBox.padding.L;
	nameBoxBackground:SetPoint("BOTTOMLEFT",nameBox,"BOTTOMLEFT",-paddingL,-nameBox.margin.D)
	nameBoxBackground:SetPoint("TOPLEFT",nameBox,"TOPLEFT",-paddingL,nameBox.margin.T + 12);
	nameBoxBackground:SetWidth(32);
	nameBoxBackground:SetFrameStrata("BACKGROUND");
	nameBoxBackground:SetScript("OnClick", function(self) nameBox:SetFocus() end);
	nameBoxBackground:SetScript("OnMouseDown", function(self) newChatBubble:StartMoving() end )
	nameBoxBackground:SetScript("OnMouseUp", function(self) newChatBubble:StopMovingOrSizing() end )
	nameBoxBackground:SetScript("OnEnter", function(self) if nameBox:GetText() == "" and not nameBox:HasFocus() then nameBox:SetAlpha(0.5) end end);
	nameBoxBackground:SetScript("OnLeave", function(self) if nameBox:GetText() == "" and not nameBox:HasFocus() then nameBox:SetAlpha(0) end end);
	nameBox.background = nameBoxBackground

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
	nameBoxColorPicker:EnableMouse(false);
	nameBoxColorPicker:SetScript("OnEnter", function(self) if nameBox:GetText() ~= "" then self:SetAlpha(1); end; end);
	nameBoxColorPicker:SetScript("OnLeave", function(self) self:SetAlpha(0.01) end);
	nameBoxColorPicker:SetScript("OnClick", function(self) if nameBox:GetText() ~= "" then pickNameColor(newChatBubble) end; end);

	local chatBubbleTail = CreateFrame("Frame",frameName.."-tail",chatBubbleBackground)
	chatBubbleTail:SetSize(16,16)
	chatBubbleTail:SetPoint("TOPLEFT",chatBubbleBackground,"BOTTOMLEFT",8,3)
	chatBubbleTail.tex = chatBubbleTail:CreateTexture(frameName.."-tailTexture","BACKGROUND");
	chatBubbleTail.tex:SetTexture("Interface\\Tooltips\\CHATBUBBLE-TAIL.BLP");
	chatBubbleTail.tex:SetAllPoints();
	chatBubbleTail.bottomOffset = 3;
	chatBubbleTail.topOffset = -3;
	chatBubbleTail.leftOffset = 3;
	chatBubbleTail.rightOffset = -3;
	chatBubbleTail.minX = 8;
	chatBubbleTail.minY = 8;
	chatBubbleTail.side = "BOTTOM";
	chatBubbleTail.Reset = function(self) 
		self.tex:SetRotation(0);
		self:ClearAllPoints();
		self:SetPoint("TOPLEFT",chatBubbleBackground,"BOTTOMLEFT",8,3);
		self.tail = "BOTTOM"
	end

	local chatBubbleTailCatcher = CreateFrame("Button",frameName.."-tailButtonCatcher",chatBubbleTail);
	chatBubbleTailCatcher:SetAllPoints();
	chatBubbleTailCatcher:SetScript("OnMouseDown",function(self, button) startMovingTail(chatBubbleTail, button) end);
	chatBubbleTailCatcher:SetScript("OnMouseUp",function(self, button) stopMovingTail(chatBubbleTail, button) end);
	chatBubbleTailCatcher:SetFrameStrata("HIGH");

	newChatBubble.tail = chatBubbleTail;

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

local function doEvent(self, event, ...)
	if event == "PLAY_MOVIE" then
		closeBubbles()
	elseif event == "CINEMATIC_START" then
		hideBubbles()
	elseif event == "CINEMATIC_STOP" then
		showBubbles()
	end
end

local frame = CreateFrame("FRAME","ChatBubbleEventHandler");
frame:RegisterEvent("PLAY_MOVIE");
frame:RegisterEvent("CINEMATIC_START");
frame:RegisterEvent("CINEMATIC_STOP");
frame:SetScript("OnEvent",doEvent);