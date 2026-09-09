local PacketProfiler = script.Parent.Parent
local BridgeProtocol = require(PacketProfiler.Modules.BridgeProtocol)

local BridgeReceiver = {}
BridgeReceiver.__index = BridgeReceiver

local function isPositiveFinite(value)
	return type(value) == "number" and value > 0 and value == value and value < math.huge
end

local function validateDescriptor(descriptor)
	if type(descriptor) ~= "table" then
		return false, "descriptor must be a table"
	end
	if type(descriptor.Id) ~= "string" or descriptor.Id == "" then
		return false, "Id must be a non-empty string"
	end
	if type(descriptor.Name) ~= "string" or descriptor.Name == "" then
		return false, "Name must be a non-empty string"
	end
	if descriptor.Color ~= nil and typeof(descriptor.Color) ~= "Color3" then
		return false, "Color must be a Color3"
	end
	if descriptor.IncludeInAll ~= nil and type(descriptor.IncludeInAll) ~= "boolean" then
		return false, "IncludeInAll must be a boolean"
	end
	if descriptor.DefaultMaxFrameValue ~= nil and not isPositiveFinite(descriptor.DefaultMaxFrameValue) then
		return false, "DefaultMaxFrameValue must be positive and finite"
	end
	if descriptor.ScaleValues ~= nil then
		if type(descriptor.ScaleValues) ~= "table" or #descriptor.ScaleValues == 0 then
			return false, "ScaleValues must be a non-empty array"
		end
		for _, value in descriptor.ScaleValues do
			if not isPositiveFinite(value) then
				return false, "ScaleValues must contain positive finite numbers"
			end
		end
	end
	return true
end

function BridgeReceiver.new(profiler, respond)
	return setmetatable({
		Profiler = profiler,
		Respond = respond,
		Registrations = {},
		OwnedLayers = {},
	}, BridgeReceiver)
end

function BridgeReceiver:_ownerKey(ownerId, sessionId, registrationId)
	return string.format("%s:%s:%s", ownerId, tostring(sessionId), tostring(registrationId))
end

function BridgeReceiver:_unregisterLayer(ownerId, sessionId, registrationId, layerId)
	local key = self:_ownerKey(ownerId, sessionId, registrationId)
	local ownership = self.OwnedLayers[key]
	if ownership == nil or ownership.LayerId ~= layerId then
		return
	end

	self.OwnedLayers[key] = nil
	local registration = self.Registrations[layerId]
	if registration == nil then
		return
	end

	registration.Owners[key] = nil
	if next(registration.Owners) == nil then
		registration.Handle:Disconnect()
		self.Registrations[layerId] = nil
	end
end

function BridgeReceiver:_registerLayer(ownerId, sessionId, registrationId, descriptor)
	local valid, validationMessage = validateDescriptor(descriptor)
	if not valid then
		self.Respond(ownerId, registrationId, false, validationMessage)
		return
	end
	if self.Profiler:GetLayer(descriptor.Id) and self.Registrations[descriptor.Id] == nil then
		local message = string.format("layer %q conflicts with a plugin layer", descriptor.Id)
		warn("PacketProfiler bridge " .. message)
		self.Respond(ownerId, registrationId, false, message)
		return
	end

	local registration = self.Registrations[descriptor.Id]
	if registration == nil then
		local ok, handle = pcall(function()
			return self.Profiler:RegisterLayer(BridgeProtocol.CreateLayerDescriptor(descriptor))
		end)
		if not ok then
			warn(string.format("PacketProfiler bridge rejected layer %q: %s", descriptor.Id, tostring(handle)))
			self.Respond(ownerId, registrationId, false, tostring(handle))
			return
		end
		registration = { Handle = handle, Owners = {} }
		self.Registrations[descriptor.Id] = registration
	end

	local key = self:_ownerKey(ownerId, sessionId, registrationId)
	registration.Owners[key] = true
	self.OwnedLayers[key] = {
		OwnerId = ownerId,
		LayerId = descriptor.Id,
		SessionId = sessionId,
		RegistrationId = registrationId,
	}
	self.Respond(ownerId, registrationId, true)
end

function BridgeReceiver:_record(ownerId, sessionId, item)
	if type(item) ~= "table" then
		return
	end
	local layerId = item.LayerId
	local key = self:_ownerKey(ownerId, sessionId, item.RegistrationId)
	local registration = self.Registrations[layerId]
	if registration == nil or not registration.Owners[key] or type(item.Packet) ~= "table" then
		return
	end

	local ok, message = pcall(function()
		self.Profiler:Record(layerId, BridgeProtocol.CreatePacket(item.Packet))
	end)
	if not ok then
		warn(string.format("PacketProfiler bridge rejected a %q packet: %s", layerId, tostring(message)))
	end
end

function BridgeReceiver:Receive(ownerId, command, first, second, third)
	if command == BridgeProtocol.RegisterLayer then
		self:_registerLayer(ownerId, first, second, third)
	elseif command == BridgeProtocol.RecordBatch and self.Profiler:IsCapturing() and type(second) == "table" then
		for _, item in second do
			self:_record(ownerId, first, item)
		end
	elseif command == BridgeProtocol.UnregisterLayer then
		self:_unregisterLayer(ownerId, first, second, third)
	end
end

function BridgeReceiver:DisconnectOwner(ownerId)
	local ownerships = {}
	for key, ownership in self.OwnedLayers do
		if ownership.OwnerId == ownerId then
			ownerships[key] = ownership
		end
	end
	for _, ownership in ownerships do
		self:_unregisterLayer(ownerId, ownership.SessionId, ownership.RegistrationId, ownership.LayerId)
	end
end

function BridgeReceiver:Destroy()
	for _, registration in self.Registrations do
		registration.Handle:Disconnect()
	end
	table.clear(self.Registrations)
	table.clear(self.OwnedLayers)
end

return BridgeReceiver
