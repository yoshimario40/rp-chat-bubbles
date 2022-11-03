-- Author      : Christopher Tse
-- Create Date : 3/28/2020 11:43:45 AM

local ADDON_NAME, Import = ...;

local ChatBubblePool = Import.ChatBubblePool;
local settings;

local smartTargetColoringActive = false;
local savedColor;
local savedRGB;

Import.SharedFunctions = {};

function RPChatBubbles_OnLoad(self, event,...) 
	self:SetClampedToScreen(true);
    self:RegisterEvent("ADDON_LOADED");
	self:RegisterEvent("MODIFIER_STATE_CHANGED");
	self:RegisterEvent("PLAYER_TARGET_CHANGED");
	self:SetBackdrop(BACKDROP_DIALOG_32_32);
	self:OnBackdropLoaded();
end

function RPChatBubbles_OnEvent(self, event, ...) 
	if event == "ADDON_LOADED" and ... == ADDON_NAME then
		Import:initSettings();
		settings = Import.settings;
		sharedFunctions = Import.SharedFunctions;
		initMainFrame(self);
		ChatBubblePool:OnStart();
		for moduleName, moduleStructure in pairs(Import.modules) do
			moduleStructure:OnStart();
		end
		initColorDropdown();
	elseif event == "MODIFIER_STATE_CHANGED" then
		handleKeyPress();
	elseif event == "PLAYER_TARGET_CHANGED" then
		checkSmartTargetColoring();
	end
end

function RPChatBubbles_createChatBubble()
	PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON);
	local bubble = ChatBubblePool.getChatBubble();
	local textColor = settings.get("SELECTED_COLOR_RGB");
	local selectedColor = settings.get("SELECTED_COLOR");
	local GetUnitNameAndColor = Import.SharedFunctions.GetUnitNameAndColor;

	local unitID = nil;

	if IsShiftKeyDown() then
		unitID = "player";
	elseif IsControlKeyDown() then
		unitID = "target";
	end

	bubble:SetTextColor(textColor.r,textColor.g,textColor.b);

	--If we are trying to populate the name field using shift or control, then enter this block. 
	--The method used will depend on whether TotalRP3 is installed or not
	if unitID then
		local name, color = GetUnitNameAndColor(unitID);
		if name then
			bubble:SetName(name);
			-- The Color will only be populated if TotalRP3 is enabled. 
			-- The variable type is the Ellyb Color() class.
			if color then
				bubble:SetNameColor(color:GetRGB());
			end
		else
			bubble:SetName("");
		end
	end
end

function RPChatBubbles_toggleVisibility()
	if settings.get("IS_FRAME_VISIBLE") then
		settings.set("IS_FRAME_VISIBLE", false);
	else
		settings.set("IS_FRAME_VISIBLE", true);
	end
	PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON);
	SetVisibility(MainFrame, settings.get("IS_FRAME_VISIBLE"));
end

function RPChatBubbles_showSettingsPanel(self, event, ...)
	Import.ShowSettingsPanel();
end

function Import.SharedFunctions.GetUnitNameAndColor(unitID)
	return UnitName(unitID), nil;
end

----------------------------------------------------------

function initMainFrame(self)
	self:RegisterForDrag("LeftButton");
	self:SetScript("OnDragStart", function(self)
		self:StartMoving();
	end);
	self:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing();
	end);
	SetVisibility(self, settings.get("IS_FRAME_VISIBLE"), true);
end

function handleKeyPress()
	if settings.get("CREATE_BUTTON_EXTRA_TEXT") then
		if IsShiftKeyDown() then
			CreateButton:SetText("Create (Self)");
		elseif IsControlKeyDown() then
			CreateButton:SetText("Create (Target)");		
		else
			CreateButton:SetText("Create");
		end
	end
	checkSmartTargetColoring();
end

function checkSmartTargetColoring()
	if not settings.get("SMART_COLORING") then
		return
	end
	if (IsShiftKeyDown() or IsControlKeyDown()) and SayColorSelected() then
		if not smartTargetColoringActive then
			smartTargetColoringActive = true;
			savedColor = settings.get("SELECTED_COLOR");
			savedRGB = settings.get("SELECTED_COLOR_RGB");
		end

		if IsControlKeyDown() and UnitExists("target") then
			if UnitIsPlayer("target") then
				selectColor(nil,"Say",ChatTypeInfo["SAY"],nil);
			else
				selectColor(nil,"Say (NPC)",ChatTypeInfo["MONSTER_SAY"],nil);
			end
		elseif IsShiftKeyDown() then
			selectColor(nil,"Say",ChatTypeInfo["SAY"],nil);
		else
			selectColor(nil,savedColor,savedRGB,nil);
		end
	elseif smartTargetColoringActive and not IsControlKeyDown() then
		smartTargetColoringActive = false;
		selectColor(nil,savedColor,savedRGB,nil);
	end
end

function SayColorSelected() 
	selectedColor = settings.get("SELECTED_COLOR");
	return selectedColor == "Say" or selectedColor == "Say (NPC)";
end 

function initColorDropdown()
	local dropdown = ColorDropdownButton;
	UIDropDownMenu_SetWidth(dropdown, 28);
	UIDropDownMenu_Initialize(dropdown, function(self, menu, level)
		addMenuItem("Say",ChatTypeInfo["SAY"]);
		addMenuItem("Say (NPC)",ChatTypeInfo["MONSTER_SAY"]);
		addMenuItem("Emote",ChatTypeInfo["EMOTE"]);
		addMenuItem("Yell",ChatTypeInfo["YELL"]);
		addMenuItem("Whisper",ChatTypeInfo["WHISPER"]);
		addMenuItem("Custom",nil,true);
	end)
	local rgb = settings.get("SELECTED_COLOR_RGB");
	if rgb then
		ColorSwatchTex:SetColorTexture(rgb.r,rgb.g,rgb.b);
	end
end

function addMenuItem(text, color, custom)
	local info = UIDropDownMenu_CreateInfo();
	info.text, info.arg1, info.arg2 = text, text, color;
	if custom then
		info.hasColorSwatch = true;
		local rgb = settings.get("CUSTOM_COLOR");
		info.r, info.g, info.b = rgb.r, rgb.g, rgb.b;
		info.swatchFunc = setCustomColor;
		info.cancelFunc = cancelCustomColor;
		info.func = startCustomColorPicking;
	else
		info.colorCode = "|cFF" .. rgbToHex(color);
		info.func = selectColor
	end
	if settings.get("SELECTED_COLOR") == text then
		info.checked = true;
	end
	UIDropDownMenu_AddButton(info);
end

function rgbToHex(color)
	return string.format("%02x%02x%02x", color.r*255, color.g*255, color.b*255)
end

function selectColor(self,channelColor,rgb,checked)
	settings.set("SELECTED_COLOR", channelColor);
	settings.set("SELECTED_COLOR_RGB", rgb);
	ColorSwatchTex:SetColorTexture(rgb.r,rgb.g,rgb.b);
end

function startCustomColorPicking(self)
	previousSelection = settings.get("SELECTED_COLOR");
	previousColor = settings.get("SELECTED_COLOR_RGB");
	UIDropDownMenuButton_OpenColorPicker(self);
end

function setCustomColor(previousSelection)
	local rgb = {}
	if previousSelection then
		rgb = previousSelection
	else
		rgb.r, rgb.g, rgb.b = ColorPickerFrame:GetColorRGB() 
	end
	selectColor(nil,"Custom",rgb);
	settings.set("CUSTOM_COLOR", rgb);
end

function cancelCustomColor()
	settings.set("SELECTED_COLOR", previousSelection);
	settings.set("SELECTED_COLOR_RGB", previousColor);
end

function SetVisibility(self, visible, init)
	if visible then
		self:SetAlpha(1.0);
		removeVisibilityScripts(MainFrame);
		removeVisibilityScripts(CreateButton);
		removeVisibilityScripts(SettingsButton);
		removeVisibilityScripts(HideButton);
		removeVisibilityScripts(ColorDropdownButton);
		HideButtonTexture:SetTexture("Interface/Addons/RoleplayChatBubbles/button/UI-showButton");
	else
		local showShadow = (not init) or settings.get("SHADOW_LOAD");
		self:SetAlpha(showShadow and 0.5 or 0);
		addVisibilityScripts(MainFrame);
		addVisibilityScripts(CreateButton);
		addVisibilityScripts(SettingsButton);
		addVisibilityScripts(HideButton);
		addVisibilityScripts(ColorDropdownButton);
		HideButtonTexture:SetTexture("Interface/Addons/RoleplayChatBubbles/button/UI-hideButton");
	end
end

function removeVisibilityScripts(frame)
	frame:SetScript("OnEnter",nil);
	frame:SetScript("OnLeave",nil);
end

function addVisibilityScripts(frame)
	frame:SetScript("OnEnter",ShowRPCMainFrame);
	frame:SetScript("OnLeave",HideRPCMainFrame);
end


function ShowRPCMainFrame(self, event, ...)
	MainFrame:SetAlpha(0.5);
end

function HideRPCMainFrame(self, event, ...)
	MainFrame:SetAlpha(0);
end

Import.modules = {};