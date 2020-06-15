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
	end
end

function RPChatBubbles_createChatBubble()
	return ChatBubblePool.getChatBubble()
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

function SetVisibility(self, visible)
	if visible then
		self:SetAlpha(1.0);
		removeVisibilityScripts(MainFrame);
		removeVisibilityScripts(CreateButton);
		removeVisibilityScripts(SettingsButton);
		removeVisibilityScripts(HideButton);
		HideButtonTexture:SetTexture("Interface/Addons/RoleplayChatBubbles/button/UI-hideButton");
	else
		self:SetAlpha(0.5);
		addVisibilityScripts(MainFrame);
		addVisibilityScripts(CreateButton);
		addVisibilityScripts(SettingsButton);
		addVisibilityScripts(HideButton);
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