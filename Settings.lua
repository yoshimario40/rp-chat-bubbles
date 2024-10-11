-- Author      : Chrono
-- Create Date : 6/14/2020 6:22:07 PM

local ADDON_NAME, Import = ...;

defaultValue = {
	IS_FRAME_VISIBLE = true,
	DRESS_BLIZZ_BUBBLE = true,
	SMART_COLORING = true,
	CREATE_BUTTON_EXTRA_TEXT = true,
	SHADOW_LOAD = true,

	SELECTED_COLOR_RGB = { r = 1.0, g = 1.0, b = 1.0 },
	SELECTED_COLOR = "Say",
	CUSTOM_COLOR = { r = 1.0, g = 1.0, b = 1.0 },

	GENERATE_TOTAL_RP3_BUBBLES = true,
	GENERATE_TOTAL_RP3_BUBBLES_FOR_OTHER_PLAYERS = true,

	FONT_SIZE = 13
}

local temporaryValue = {}

restartRequired = false;
CategoryId = -1;

function initSettings()
	if settings == nil then
		settings = {}
	end
	settings.get = function(key)
		if settings[key] == nil then
			settings[key] = defaultValue[key];
		end
		return settings[key];
	end
	settings.set = function(key, value)
		settings[key] = value;
	end
	Import.settings = settings;
	ConstructSettingsUI();
	hooksecurefunc(SettingsPanel, "FinalizeCommit", CommitChanges);
	if (settings.get("DRESS_BLIZZ_BUBBLE")) then
		local fontPath, _, fontFlags = ChatBubbleFont:GetFont();
		ChatBubbleFont:SetFont(fontPath, settings.get("FONT_SIZE"), fontFlags);
	end
end

function CommitChanges()
	for key, value in pairs(temporaryValue) do
		settings[key] = value;
	end
	
	if (restartRequired) then
		ReloadUI();
		restartRequired = false;
	end
	temporaryValue = {}
end

function ConstructSettingsUI() 
	local category, layout = Settings.RegisterVerticalLayoutCategory("Speaker Bee");

	-- layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("General"));
	AddGeneralHeader(layout);
	RegisterFontSize(category);
	RegisterDressBlizzBubble(category);
	RegisterCreateButtonExtraText(category);
	RegisterSmartNameColours(category);
	RegisterShadowLoad(category);
	
	RegisterTotalRP3Settings(layout, category);

	Settings.RegisterAddOnCategory(category)

	CategoryId = category:GetID();
end

function AddGeneralHeader(layout)
	local name = "TotalRP3";
	local data = {name = name};
	local topInitializer = Settings.CreateElementInitializer("SpeakerBeeGeneralHeader", data);
	topInitializer = layout:AddInitializer(topInitializer);
end

function RegisterFontSize(category)
	local variable = "FONT_SIZE";
	local name = "Font Size";
	local tooltip = "Controls the font size of all chat bubbles.";
    local defaultValue = defaultValue[variable];
	local minValue = 8;
	local maxValue = 72;
	local step = 1;
	
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, settings, type(defaultValue), name, defaultValue)
	setting:SetCommitFlags(Settings.CommitFlag.Apply);

	local callback = function(o, setting, value)
		temporaryValue.FONT_SIZE = value;
		if (setting:IsModified()) then
			ToggleRestartRequired();
		end
	end
	Settings.SetOnValueChangedCallback(variable, callback);
	local options = Settings.CreateSliderOptions(minValue, maxValue, step);

	options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right);
	Settings.CreateSlider(category, setting, options, tooltip)
end

function RegisterDressBlizzBubble(category) 
	local variable = "DRESS_BLIZZ_BUBBLE"
    local name = "Dress Chat Bubbles"
    local tooltip = "If checked, this puts the speaking character's name on regular chat bubbles"
    local defaultValue = defaultValue[variable];

	local callback = function(o, setting, value)
		temporaryValue.DRESS_BLIZZ_BUBBLE = value;
		if (setting:IsModified()) then
			ToggleRestartRequired();
		end
	end

	local setting = Settings.RegisterAddOnSetting(category, variable, variable, settings, type(defaultValue), name, defaultValue);
	setting:SetCommitFlags(Settings.CommitFlag.Apply);
	Settings.SetOnValueChangedCallback(variable, callback);
    Settings.CreateCheckbox(category, setting, tooltip);
end

function RegisterCreateButtonExtraText(category) 
	local variable = "CREATE_BUTTON_EXTRA_TEXT"
    local name = "Dynamic Create Button"
    local tooltip = "If checked, the create button text will change to include (target) or (self) when shift or ctrl is held"
    local defaultValue = defaultValue[variable];

	local setting = Settings.RegisterAddOnSetting(category, variable, variable, settings, type(defaultValue), name, defaultValue);
	Settings.SetOnValueChangedCallback(variable, function(o, s, value) temporaryValue.CREATE_BUTTON_EXTRA_TEXT = value; end);
    Settings.CreateCheckbox(category, setting, tooltip);
end

function RegisterSmartNameColours(category)
	local variable = "SMART_COLORING"
    local name = "Smart Name Colouring"
    local tooltip = "If checked, the colour of the name on custom chat bubbles will automatically select npc or player colours when shift or ctrl is held"
    local defaultValue = defaultValue[variable];

	local setting = Settings.RegisterAddOnSetting(category, variable, variable, settings, type(defaultValue), name, defaultValue);
	Settings.SetOnValueChangedCallback(variable, function(o, s, value) temporaryValue.SMART_COLORING = value; end);
    Settings.CreateCheckbox(category, setting, tooltip);
end

function RegisterShadowLoad(category)
	local variable = "SHADOW_LOAD"
	local name = "Load Shadow Frame"
	local tooltip = "If checked and the addon frame is hidden, the frame will show up as a shadow when the game loads until you mouse over it."
    local defaultValue = defaultValue[variable];

	local setting = Settings.RegisterAddOnSetting(category, variable, variable, settings, type(defaultValue), name, defaultValue);
	Settings.SetOnValueChangedCallback(variable, function(o, s, value) temporaryValue.SHADOW_LOAD = value; end);
    Settings.CreateCheckbox(category, setting, tooltip);
end
function RegisterTotalRP3Settings(layout, category)
    local totalRP3Installed = TRP3_API ~= nil;

	local function isModifiable()
		return totalRP3Installed;
	end

	AddTotalRP3Header(layout, totalRP3Installed)
	RegisterGenerateTotalRP3BubbleSetting(category, layout, isModifiable);
end

function AddTotalRP3Header(layout, totalRP3Installed)
	local headerTemplate = totalRP3Installed and "SettingsListSectionHeaderTemplate" or "TotalRP3SectionHeaderDisabled";
	local name = "TotalRP3";
	local data = {name = name};
	layout:AddInitializer(Settings.CreateElementInitializer(headerTemplate, data));
end


function RegisterGenerateTotalRP3BubbleSetting(category, layout, isModifiable)
	local variable = "GENERATE_TOTAL_RP3_BUBBLES"
    local name = "Enable NPC Speech Bubbles"
    local tooltip = "If checked, a chat bubble is created whenever you use the NPC speech feature of TotalRP3"
    local defaultValue = defaultValue[variable];

	local setting = Settings.RegisterAddOnSetting(category, variable, variable, settings, type(defaultValue), name, defaultValue);
	Settings.SetOnValueChangedCallback(variable, function(o, s, value) temporaryValue.GENERATE_TOTAL_RP3_BUBBLES = value; end);
    local initializer = Settings.CreateCheckbox(category, setting, tooltip);
	initializer:AddModifyPredicate(isModifiable);

	RegisterGenerateTotalRP3BubbleForOthersSetting(category, initializer, isModifiable);
end

function RegisterGenerateTotalRP3BubbleSettingForSelf(category, parent, isModifiable)

end

function RegisterGenerateTotalRP3BubbleForOthersSetting(category, parent, isModifiable)
	local variable = "GENERATE_TOTAL_RP3_BUBBLES_FOR_OTHER_PLAYERS"
    local name = "From other players"
    local tooltip = "If checked, a chat bubble is created whenever you use the NPC speech feature of TotalRP3"
    local defaultValue = defaultValue[variable];

	local setting = Settings.RegisterAddOnSetting(category, variable, variable, settings, type(defaultValue), name, defaultValue);
	Settings.SetOnValueChangedCallback(variable, function(o, s, value) temporaryValue.GENERATE_TOTAL_RP3_BUBBLES_FOR_OTHER_PLAYERS = value; end);
    local initializer = Settings.CreateCheckbox(category, setting, tooltip);
	initializer:SetParentInitializer(parent, isModifiable);
end

function ToggleRestartRequired() 
	if ((temporaryValue.FONT_SIZE ~= nil and temporaryValue.FONT_SIZE ~= settings.FONT_SIZE) or 
        (temporaryValue.DRESS_BLIZZ_BUBBLE ~= nil and temporaryValue.DRESS_BLIZZ_BUBBLE ~= settings.DRESS_BLIZZ_BUBBLE)) then
			restartRequired = true;
		    SpeakerBeeRestartRequired:Show();
		else 
			restartRequired = false;
			SpeakerBeeRestartRequired:Hide();
	end
end

function ShowSettingsPanel()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPEN);
	SettingsPanel:OpenToCategory(CategoryId);
end

Import.initSettings = initSettings;
Import.ShowSettingsPanel = ShowSettingsPanel;