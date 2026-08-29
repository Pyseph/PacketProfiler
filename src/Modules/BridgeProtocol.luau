local HttpService = game:GetService("HttpService")

local BridgeProtocol = {
	EventName = "PacketProfilerBridge.profiler",
	OutboundName = "PacketProfilerBridgeOutbound.profiler",
	OwnerAttribute = "PacketProfilerStudioBridge",
	VersionAttribute = "PacketProfilerBridgeVersion",
	Version = 3,
	RegisterLayer = "RegisterLayer",
	RegistrationResult = "RegistrationResult",
	RecordBatch = "RecordBatch",
	UnregisterLayer = "UnregisterLayer",
}

local TYPE_FIELD = "__packetProfilerType"

local function encodeValue(value)
	local valueType = typeof(value)
	if value == nil or valueType == "boolean" or valueType == "number" or valueType == "string" then
		return value
	end
	if valueType == "Color3" then
		return { [TYPE_FIELD] = "Color3", R = value.R, G = value.G, B = value.B }
	end
	if valueType == "Vector2" or valueType == "Vector3" then
		return { [TYPE_FIELD] = valueType, X = value.X, Y = value.Y, Z = value.Z }
	end
	if valueType == "Instance" then
		return { [TYPE_FIELD] = "Instance", ClassName = value.ClassName, Path = value:GetFullName() }
	end
	if valueType == "EnumItem" then
		return { [TYPE_FIELD] = "EnumItem", Value = tostring(value) }
	end
	if valueType == "table" then
		local encoded = {}
		for key, item in value do
			if type(key) == "string" or type(key) == "number" then
				encoded[key] = encodeValue(item)
			end
		end
		return encoded
	end
	return tostring(value)
end

local function decodeValue(value)
	if type(value) ~= "table" then
		return value
	end
	if value[TYPE_FIELD] == "Color3" then
		return Color3.new(value.R, value.G, value.B)
	end
	if value[TYPE_FIELD] == "Vector2" then
		return Vector2.new(value.X, value.Y)
	end
	if value[TYPE_FIELD] == "Vector3" then
		return Vector3.new(value.X, value.Y, value.Z)
	end

	local decoded = {}
	for key, item in value do
		decoded[key] = decodeValue(item)
	end
	return decoded
end

function BridgeProtocol.EncodeArguments(...)
	local arguments = table.pack(...)
	local values = table.create(arguments.n)
	for index = 1, arguments.n do
		values[index] = encodeValue(arguments[index])
	end
	return HttpService:JSONEncode({ Count = arguments.n, Values = values })
end

function BridgeProtocol.DecodeArguments(payload)
	local envelope = HttpService:JSONDecode(payload)
	local values = decodeValue(envelope.Values)
	return table.unpack(values, 1, envelope.Count)
end

function BridgeProtocol.CreateLayerDescriptor(layer)
	return {
		Id = layer.Id,
		Name = layer.Name,
		Color = layer.Color,
		Description = layer.Description,
		EntryName = layer.EntryName,
		Unit = layer.Unit,
		IncludeInAll = layer.IncludeInAll,
		DefaultMaxFrameValue = layer.DefaultMaxFrameValue,
		ScaleValues = layer.ScaleValues and table.clone(layer.ScaleValues) or nil,
	}
end

function BridgeProtocol.CreatePacket(packet)
	return {
		Name = packet.Name,
		Size = packet.Size,
		Data = packet.Data,
		RawData = packet.RawData,
		Metadata = packet.Metadata,
		Timestamp = packet.Timestamp,
	}
end

return BridgeProtocol
