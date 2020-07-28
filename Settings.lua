-- Author      : Chrono
-- Create Date : 6/14/2020 6:22:07 PM

local ADDON_NAME, Import = ...;

function initSettings()
	if settings == nil then
		settings = {}
		settings.isFrameVisible = true;
		settings.dressBlizzBubbles = true;
		settings.generateTotalRP3Bubbles = true;
		settings.generateTotalRP3BubblesForOtherPlayers = true;
	end
	if settings.selectedColor == nil then
		c = {};
		c.r, c.g, c.b = 1.0, 1.0, 1.0
		settings.textColor = c;
		settings.selectedColor = "Say"
		settings.customColor = c;
	end
	Import.settings = settings;
end

function ConfigureFrameOnRuntime(self, event, ...)
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

		DressBlizzBubbleCheck:SetChecked(settings.dressBlizzBubbles);
		totalRP3GenerateCheck:SetChecked(settings.generateTotalRP3Bubbles);
		totalRP3GenerateOtherCheck:SetChecked(settings.generateTotalRP3BubblesForOtherPlayers);
		TotalRP3_onStart();
	else
		CancelSettings();
	end
end

function ToggleReloadWarning(self, event, ...)
	if settings.dressBlizzBubbles ~= DressBlizzBubbleCheck:GetChecked() then
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
	local reloadRequired = settings.dressBlizzBubbles ~= DressBlizzBubbleCheck:GetChecked()
	
	settings.dressBlizzBubbles = DressBlizzBubbleCheck:GetChecked();
	settings.generateTotalRP3Bubbles = totalRP3GenerateCheck:GetChecked();
	settings.generateTotalRP3BubblesForOtherPlayers = totalRP3GenerateOtherCheck:GetChecked();
		
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