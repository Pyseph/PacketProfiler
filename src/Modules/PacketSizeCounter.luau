--!strict
local REMOTE_OVERHEAD = 9
local BYTE_OVERHEAD = 1

-- Byte sizes of different types of values
local Float64 = 8
local Float32 = 4
local Float16 = 2
local Int32 = 4
local Int16 = 2
local Int8 = 1

-- Vector3's are stored as 3 Float32s, which equates to 12 bytes. They have a 1-byte overhead
-- for what's presumably type differentiation, so the informal calculation for datatypes is:
-- num_types*num_bytes_in_type + BYTE_OVERHEAD
-- Example:
-- Vector3: 3 float32s, 1 byte overhead: 3*4 + 1 = 13 bytes
-- The structs of datatypes can be found below:
-- https://dom.rojo.space/binary.html
-- !! It should still be benchmarked to see if the bytes are correctly calculated !!

local COLOR3_BYTES = 3*Float32
local VECTOR3_BYTES = 3*Float32

local TypeByteSizes: {[string]: number} = {
	EnumItem = Int32,
	boolean = 1,
	number = Float64,
	UDim = Float32 + Int32,
	UDim2 = 2*(Float32 + Int32),
	Ray = 6*Float32,
	Faces = 6,
	Axes = 6,
	BrickColor = Int32,
	Color3 = COLOR3_BYTES,
	Vector2 = 2*Float32,
	Vector3 = VECTOR3_BYTES,
	-- It's unclear how instances are sent, but in binary-storage format they're stored with
	-- 'Referents', which can be found in the binary-storage documentation above.
	-- Benchmarks also show that they take up 4 bytes, excluding byte overhead.
	Instance = Int32,
	Vector2int16 = 2*Int16,
	Vector3int16 = 3*Int16,
	NumberSequenceKeypoint = 3*Float32,
	ColorSequenceKeypoint = 4*Float32,
	NumberRange = 2*Float32,
	Rect = 2*(2*Float32),
	PhysicalProperties = 5*Float32,
	Color3uint8 = 3*Int8,
}

-- https://dom.rojo.space/binary.html#cframe
local CFrameSpecialCases = {
	[CFrame.Angles(0, 0, 0)] 							= true, 	[CFrame.Angles(0, math.rad(180), math.rad(0))] 				= true,
	[CFrame.Angles(math.rad(90), 0, 0)] 				= true, 	[CFrame.Angles(math.rad(-90), math.rad(-180), math.rad(0))] = true,
	[CFrame.Angles(0, math.rad(180), math.rad(180))] 	= true,		[CFrame.Angles(0, math.rad(0), math.rad(180))] 				= true,
	[CFrame.Angles(math.rad(-90), 0, 0)] 				= true,		[CFrame.Angles(math.rad(90), math.rad(180), math.rad(0))] 	= true,
	[CFrame.Angles(0, math.rad(180), math.rad(90))] 	= true,		[CFrame.Angles(0, math.rad(0), math.rad(-90))] 				= true,
	[CFrame.Angles(0, math.rad(90), math.rad(90))] 		= true,		[CFrame.Angles(0, math.rad(-90), math.rad(-90))]			= true,
	[CFrame.Angles(0, 0, math.rad(90))] 				= true,		[CFrame.Angles(0, math.rad(-180), math.rad(-90))] 			= true,
	[CFrame.Angles(0, math.rad(-90), math.rad(90))] 	= true,		[CFrame.Angles(0, math.rad(90), math.rad(-90))] 			= true,
	[CFrame.Angles(math.rad(-90), math.rad(-90), 0)] 	= true,		[CFrame.Angles(math.rad(90), math.rad(90), 0)] 				= true,
	[CFrame.Angles(0, math.rad(-90), 0)] 				= true,		[CFrame.Angles(0, math.rad(90), 0)] 						= true,
	[CFrame.Angles(math.rad(90), math.rad(-90), 0)] 	= true,		[CFrame.Angles(math.rad(-90), math.rad(90), 0)] 			= true,
	[CFrame.Angles(0, math.rad(90), math.rad(180))] 	= true,		[CFrame.Angles(0, math.rad(-90), math.rad(180))] 			= true,
}

local function GetDataByteSize(Data: any, AlreadyTraversed: {[{[any]: any}]: boolean})
	local DataType = typeof(Data)
	if TypeByteSizes[DataType] then
		return TypeByteSizes[DataType]
	elseif DataType == "string" then
		-- There isn't concrete information about the size of a string over the wire, but zeuxcg mentioned
		-- that `string.pack("hhh", math.round(v.X), math.round(v.Y), math.round(v.Z))` should be around 8 bytes.
		-- From this along with Tomarty's observations (https://devforum.roblox.com/t/ore-one-remote-event/569721/33),
		-- we can assume that a string's byte size is #String + 2.
		return #Data + 2
	elseif DataType == "table" then
		if AlreadyTraversed[Data] then
			return 0
		end
		AlreadyTraversed[Data] = true

		local KeyTotal = 0
		local ValueTotal = 0

		local Index = 1
		local IsOrdered = true
		for Key, Value in next, Data do
			if Key ~= Index then
				IsOrdered = false
			else
				Index += 1
			end

			KeyTotal += GetDataByteSize(Key, AlreadyTraversed) + BYTE_OVERHEAD
			ValueTotal += GetDataByteSize(Value, AlreadyTraversed) + BYTE_OVERHEAD
		end

		return 1 + (IsOrdered and #Data + ValueTotal or KeyTotal + ValueTotal)
	elseif DataType == "CFrame" then
		local IsSpecialCase = false
		for SpecialCase in next, CFrameSpecialCases do
			if SpecialCase == Data.Rotation then
				IsSpecialCase = true
				break
			end
		end

		if IsSpecialCase then
			-- Axis-aligned CFrames skip sending rotation and are encoded as only 13 bytes
			return 1 + VECTOR3_BYTES
		else
			-- 1 byte for the ID, 12 bytes for the position vector, and 8 bytes for the quaternion representation
			--                         I'm assuming each quaternion axis is a Float16
			return 1 + VECTOR3_BYTES + 4*Float16
		end
	elseif DataType == "NumberSequence" or DataType == "ColorSequence" then
		local Total = 4
		for _, Keypoint in next, Data.Keypoints do
			Total += GetDataByteSize(Keypoint, AlreadyTraversed)
		end

		return Total
	else
		warn("Unsupported data type: " .. DataType)
		return 0
	end
end

local function GetRemotePacketSize(IgnoreRemoteOffset: boolean, ...: any): number
	local Total = IgnoreRemoteOffset and 0 or REMOTE_OVERHEAD
	local AlreadyTraversed = {}

	for _, Data in ipairs({...}) do
		Total += GetDataByteSize(Data, AlreadyTraversed) + BYTE_OVERHEAD
	end

	return Total
end

return GetRemotePacketSize