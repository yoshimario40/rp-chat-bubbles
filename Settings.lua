-- Author      : Chrono
-- Create Date : 6/14/2020 6:22:07 PM

local ADDON_NAME, Import = ...;

defaultValue = {
	IS_FRAME_VISIBLE = true,
	DRESS_BLIZZ_BUBBLE = true,
	SMART_COLORING = true,
	CREATE_BUTTON_EXTRA_TEXT = true,

	SELECTED_COLOR_RGB = { r = 1.0, g = 1.0, b = 1.0 },
	SELECTED_COLOR = "Say",
	CUSTOM_COLOR = { r = 1.0, g = 1.0, b = 1.0 },

	GENERATE_TOTAL_RP3_BUBBLES = true,
	GENERATE_TOTAL_RP3_BUBBLES_FOR_OTHER_PLAYERS = true
}

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
end

function ConfigureFrameOnRuntime(self, event, ...)
	--Check if TRP3 is installed and turn off the TRP3 options if it's not there.
	if TRP3_API == nil then
		totalRP3Header:SetFontObject("GameFontDisableLarge");
		totalRP3GenerateOptionLabel:SetFontObject("GameFontDisable");
		totalRP3GenerateOtherPlayerLabel:SetFontObject("GameFontDisable");
		totalRP3GenerateCheck:Disable();
		totalRP3GenerateOtherCheck:Disable();
		NotInstalledLabel:Show();
	end
	self:RegisterForDrag("LeftButton");
	self:SetScript("OnDragStart",self.StartMoving);
	self:SetScript("OnDragStop",self.StopMovingOrSizing);
end

function ShowSettingsPanel()
	if not SettingsPanel:IsVisible() then 
		SettingsPanel:Show()

		DressBlizzBubbleCheck:SetChecked(settings.get("DRESS_BLIZZ_BUBBLE"));
		ExtraTextCheck:SetChecked(settings.get("CREATE_BUTTON_EXTRA_TEXT"));
		SmartColoringCheck:SetChecked(settings.get("SMART_COLORING"));
		totalRP3GenerateCheck:SetChecked(settings.get("GENERATE_TOTAL_RP3_BUBBLES"));
		totalRP3GenerateOtherCheck:SetChecked(settings.get("GENERATE_TOTAL_RP3_BUBBLES_FOR_OTHER_PLAYERS"));
		
		TotalRP3_onStart();
	else
		CancelSettings();
	end
end

function ToggleReloadWarning(self, event, ...)
	--This function detects if the user has changed the Dress Blizz Bubble setting, which will show a reload required message on changed.
	if settings.DRESS_BLIZZ_BUBBLE ~= DressBlizzBubbleCheck:GetChecked() then
		if not UIReloadWarningLabel:IsVisible() then
			UIReloadWarningLabel:Show();
			SettingsPanel:SetSize(SettingsPanel:GetWidth(),SettingsPanel:GetHeight()+UIReloadWarningLabel:GetHeight()+5);
		end
	else
		if UIReloadWarningLabel:IsVisible() then
			UIReloadWarningLabel:Hide();
			SettingsPanel:SetSize(SettingsPanel:GetWidth(),SettingsPanel:GetHeight()-UIReloadWarningLabel:GetHeight()-5);
		end
	end
end

function SaveSettings(self, event, ...)
	local reloadRequired = settings.DRESS_BLIZZ_BUBBLE ~= DressBlizzBubbleCheck:GetChecked()
	
	settings.DRESS_BLIZZ_BUBBLE = DressBlizzBubbleCheck:GetChecked();
	settings.GENERATE_TOTAL_RP3_BUBBLES = totalRP3GenerateCheck:GetChecked();
	settings.GENERATE_TOTAL_RP3_BUBBLES_FOR_OTHER_PLAYERS = totalRP3GenerateOtherCheck:GetChecked();
	settings.SMART_COLORING = SmartColoringCheck:GetChecked();
	settings.CREATE_BUTTON_EXTRA_TEXT = ExtraTextCheck:GetChecked();

	SettingsPanel:Hide();
	if reloadRequired then
		ReloadUI()
	end
end

function CancelSettings()
	SettingsPanel:Hide();
end

Import.initSettings = initSettings;
Import.ShowSettingsPanel = ShowSettingsPanel