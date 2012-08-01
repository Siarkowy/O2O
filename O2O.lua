--------------------------------------------------------------------------------
--	O2O (c) 2012 by Siarkowy
--	Released under the terms of GNU GPL v3 license.
--------------------------------------------------------------------------------

O2O = {
	author	= GetAddOnMetadata("O2O", "Author"),
	version	= GetAddOnMetadata("O2O", "Version"),
}

--------------------------------------------------------------------------------
--	Locals and utils
--------------------------------------------------------------------------------

local O2O = O2O
local PROMPT = "|cFF55EE33O2O:|r "
local f -- event frame
local player = UnitName("player")
local receiver
local request

function O2O:Print(s, ...) DEFAULT_CHAT_FRAME:AddMessage(PROMPT .. tostring(s), ...) end
function O2O:Printf(...) DEFAULT_CHAT_FRAME:AddMessage(PROMPT .. format(...)) end
function O2O:Echo(...) DEFAULT_CHAT_FRAME:AddMessage(format(...)) end

--------------------------------------------------------------------------------
--	Core
--------------------------------------------------------------------------------

function O2O:Init()
	f = CreateFrame("frame")

	f:SetScript("OnEvent", function(frame, event, ...)
		self[event](self, ...)
	end)

	f:RegisterEvent("CHAT_MSG_ADDON")
	f:RegisterEvent("CHAT_MSG_OFFICER")
end

function O2O:Close()
	receiver = nil
end

function O2O:Connect(player)
	if receiver then
		self:Comm(receiver, "C")
		self:Close()
	end

	request = player
	self:Comm(player, "O")
end

function O2O:IsFriend(player)
	for i = 1, GetNumFriends() do
		if GetFriendInfo(i) == player then
			return 1
		end
	end

	return nil
end

function O2O:Open(player)
	request = nil
	receiver = player
end

StaticPopupDialogs["O2O_CONNECTION_REQUEST"] = {
	text = "%s requested an officer chat connection. Do you want to accept it?",
	button1 = YES,
	button2 = NO,

	OnAccept = function(data)
		O2O:Open(data)
		O2O:Comm(data, "A")
		O2O:Printf("Connection with %s opened.", data)
	end,

	OnCancel = function(data)
		O2O:Comm(data, "D")
	end,

	timeout = 0,
	hideOnEscape = 1,
	whileDead = 1,
}

--------------------------------------------------------------------------------
--	Communication
--------------------------------------------------------------------------------

-- Don't touch this!
local COMM_PREFIX	= "O2O"
local COMM_DELIM	= "\a"

-- util
local function pack(...) return strjoin(COMM_DELIM, ...) end
local function unpk(msg) return strsplit(COMM_DELIM, msg) end

function O2O:Comm(who, ...)
	SendAddonMessage(COMM_PREFIX, pack(...), "WHISPER", who)
end

function O2O:CHAT_MSG_ADDON(pref, msg, distr, sender)
	if pref ~= COMM_PREFIX or sender == player or distr == "UNKNOWN" then
		return
	end

	self:HandleComm(sender, unpk(msg))
end

function O2O:HandleComm(sender, type, ...)
	if sender == receiver then -- connected comms
		if type == "M" then -- message
			local author, msg = ...
			SendChatMessage(format("[%s]: %s", author, msg), "OFFICER")

		elseif type == "C" then -- close
			self:Close()
			self:Printf("Connection with %s closed.", sender)

		end

	elseif sender == request then -- request comms
		if type == "A" then -- accept
			self:Open(sender)
			self:Printf("Connection with %s opened.", sender)

		elseif type == "B" then -- busy
			request = nil
			self:Printf("Connection denied, %s is busy.", sender)

		elseif type == "D" then -- deny
			request = nil
			self:Printf("Connection request denied by %s.", sender)

		end

	elseif type == "O" then -- open request
		if receiver or request then
			self:Comm(sender, "B") -- busy
			return
		end

		if self:IsFriend(sender) then
			self:Open(sender)
			self:Comm(sender, "A") -- accept
			self:Printf("Connection with %s opened.", sender)

		else
			local dlg = StaticPopup_Show("O2O_CONNECTION_REQUEST", sender, nil, sender)
			if dlg then dlg.data = sender end

		end

	end
end

function O2O:CHAT_MSG_OFFICER(msg, sender)
	if receiver and not msg:match("^%[%S+%]:%s*") then
		self:Comm(receiver, "M", sender, msg)
	end
end

--------------------------------------------------------------------------------

O2O:Init()

--------------------------------------------------------------------------------
-- Slash command
--------------------------------------------------------------------------------

function O2O:OnSlashCmd(msg)
	if msg == "" then
		self:PrintUsage()

	elseif msg:lower() == "off" then
		request = nil
		if receiver then
			self:Printf("Connection with %s closed.", receiver)
			self:Comm(receiver, "C")
			self:Close()
		end

	else
		self:Printf("Connection request sent to %s.", msg)
		self:Connect(msg)

	end
end

function O2O:PrintUsage()
	self:Printf("Version %s operating.", self.version)
	self:Echo("   /o2o off - Disables connection.")
	self:Echo("   /o2o <player> - Enables connection with <player>.")
	self:Echo("   /o2o - Prints general and usage info.")

	if receiver then
		self:Printf("Currently connected with %s.", receiver)
	else
		self:Echo("Currently disabled.")
	end
end

SlashCmdList.O2O = function(msg) O2O:OnSlashCmd(msg) end
SLASH_O2O1 = "/o2o"
