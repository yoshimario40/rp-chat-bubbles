-- Author      : Christopher Tse
-- Create Date : 3/28/2020 11:43:45 AM

local ADDON_NAME, Import = ...;

local ChatBubblePool = Import.ChatBubblePool
local settings;

function RPChatBubbles_OnLoad(self, event,...) 
	self:SetClampedToScreen(true);
    self:RegisterEvent("ADDON_LOADED");
end

function RPChatBubbles_OnEvent(self, event, ...) 
     if event == "ADDON_LOADED" and ... == ADDON_NAME then
		Import:initSettings();
		settings = Import.settings;
		self:RegisterForDrag("LeftButton");
		self:SetScript("OnDragStart", function(self)
			self:StartMoving();
		end);
		self:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing();
		end);
		for moduleName, moduleStructure in pairs(Import.modules) do
			moduleStructure:OnStart();
		end
		SetVisibility(self, settings.isFrameVisible);
		initColorDropdown();
	end
end

function RPChatBubbles_createChatBubble()
	local bubble = ChatBubblePool.getChatBubble();
	local textColor = settings.textColor;
	local selectedColor = settings.selectedColor;
	bubble:SetTextColor(textColor.r,textColor.g,textColor.b);
end

function RPChatBubbles_toggleVisibility()
	if settings.isFrameVisible then
		settings.isFrameVisible = false;
	else
		settings.isFrameVisible = true
	end
	SetVisibility(MainFrame, settings.isFrameVisible);
end

function RPChatBubbles_showSettingsPanel(self, event, ...)
	Import.ShowSettingsPanel();
end

function initColorDropdown()
	local dropdown = ColorDropdownButton;
	UIDropDownMenu_SetWidth(dropdown, 28);
	UIDropDownMenu_Initialize(dropdown, function(self, menu, level)
		addMenuItem("Say",ChatTypeInfo["SAY"]);
		addMenuItem("Say (NPC)",ChatTypeInfo["MONSTER_SAY"]);
		addMenuItem("Yell",ChatTypeInfo["YELL"]);
		addMenuItem("Whisper",ChatTypeInfo["WHISPER"]);
		addMenuItem("Custom",nil,true);
	end)
	local rgb = settings.textColor;
	if rgb then
		ColorSwatchTex:SetColorTexture(rgb.r,rgb.g,rgb.b);
	end
end

function addMenuItem(text, color, custom)
	local info = UIDropDownMenu_CreateInfo();
	info.text, info.arg1, info.arg2 = text, text, color;
	if custom then
		info.hasColorSwatch = true;
		local rgb = settings.customColor;
		info.r, info.g, info.b = rgb.r, rgb.g, rgb.b;
		info.swatchFunc = setCustomColor;
		info.cancelFunc = cancelCustomColor;
		info.func = startCustomColorPicking;
	else
		info.colorCode = "|cFF" .. rgbToHex(color);
		info.func = selectColor
	end
	if settings.selectedColor == text then
		info.checked = true;
	end
	UIDropDownMenu_AddButton(info);
end

function rgbToHex(color)
	return string.format("%02x%02x%02x", color.r*255, color.g*255, color.b*255)
end

function selectColor(self,channelColor,rgb,checked)
	settings.selectedColor = channelColor;
	settings.textColor = rgb;
	ColorSwatchTex:SetColorTexture(rgb.r,rgb.g,rgb.b);
end

function startCustomColorPicking(self)
	previousSelection = settings.selectedColor;
	previousColor = settings.textColor;
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
	settings.customColor = rgb;
end

function cancelCustomColor()
	settings.selectedColor = previousSelection;
	settings.textColor = previousColor;
end

function SetVisibility(self, visible)
	if visible then
		self:SetAlpha(1.0);
		removeVisibilityScripts(MainFrame);
		removeVisibilityScripts(CreateButton);
		removeVisibilityScripts(SettingsButton);
		removeVisibilityScripts(HideButton);
		removeVisibilityScripts(ColorDropdownButton);
		HideButtonTexture:SetTexture("Interface/Addons/RoleplayChatBubbles/button/UI-hideButton");
	else
		self:SetAlpha(0.5);
		addVisibilityScripts(MainFrame);
		addVisibilityScripts(CreateButton);
		addVisibilityScripts(SettingsButton);
		addVisibilityScripts(HideButton);
		addVisibilityScripts(ColorDropdownButton);
		HideButtonTexture:SetTexture("Interface/Addons/RoleplayChatBubbles/button/UI-showButton");
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