-- Author      : Christopher Tse
-- Create Date : 3/28/2020 11:43:45 AM

local ADDON_NAME, Import = ...;

local mainFrame;
local ChatBubblePool = Import.ChatBubblePool

function RPChatBubbles_createChatBubble()
	return ChatBubblePool.getChatBubble()
end

function RPChatBubbles_OnLoad(self, event,...) 
	self:SetClampedToScreen(true);
    self:RegisterEvent("ADDON_LOADED");
end

function RPChatBubbles_OnEvent(self, event, ...) 
     if event == "ADDON_LOADED" and ... == ADDON_NAME then
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
	end
end

Import.modules = {};