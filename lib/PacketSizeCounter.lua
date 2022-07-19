--!strict
-- TODO: This could be used to visualize packets
-- https://marketplace.visualstudio.com/items?itemName=ArtemGevorkyan.MicroProfilerx64x86
-- How it'd work:
-- - select area with packets
-- - it would display a circle with each remote
-- - you can select any segment of the circle representing a remote to see another circle of all the remotes packets

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestRemote = Instance.new("RemoteEvent")
TestRemote.Parent = ReplicatedStorage

local REMOTE_OVERHEAD = 9
local BYTE_OVERHEAD = 1

-- Byte sizes of different types of values
local Float64 = 8
local Float32 = 4
local Int32 = 4
local Int16 = 2
local Int8 = 1

-- Vector3's are stored as 3 Float32s, which equates to 12 bytes. They have a 1-byte overhead
-- for what's presumably type differentiation, so the informal calculation for datatypes is:
-- num_values*value_length + BYTE_OVERHEAD
-- Example:
-- Vector3: 3 float32s, 1 byte overhead: 3*4 + 1 = 13 bytes
-- The structs of datatypes can be found below:
-- https://dom.rojo.space/binary.html

local COLOR3_BYTES = 3*Float32
local VECTOR3_BYTES = 3*Float32

local TypeByteSizes: {[string]: number} = {
	EnumItem = Int32,
	boolean = 1,
	number = Float64,
	UDim = Float32 + Int32,
	UDim2 = 2*(Float32 + Int32),
	Ray = 6*Float32,
	Faces = 1,
	Axes = 1,
	BrickColor = Int32,
	Color3 = COLOR3_BYTES,
	Vector2 = 2*Float32,
	Vector3 = VECTOR3_BYTES,
	-- It's unclear how instances are sent, but in binary-storage format they're stored with
	-- 'Referents', which can be found in the binary-storage documentation above.
	Instance = Int32,
	Vector3Int16 = 3*Int16,
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

		local Total = 2
		for Key, Value in next, Data do
			Total += GetDataByteSize(Key, AlreadyTraversed) + GetDataByteSize(Value, AlreadyTraversed)
		end
		return Total
	elseif DataType == "CFrame" then
		-- Axis-aligned CFrames are encoded as 13 bytes (14 including datatype overhead)
		if CFrameSpecialCases[Data] then
			return 1 + VECTOR3_BYTES
		else
			-- 1 byte for the ID, 12 bytes for the position vector, and 16 bytes for the quaternion representation
			return 1 + VECTOR3_BYTES + 4*4
		end
	elseif DataType == "NumberSequence" or DataType == "ColorSequence" then
		local Total = 4
		for _, Keypoint in next, Data.Keypoints do
			Total += GetDataByteSize(Keypoint, AlreadyTraversed)
		end

		return Total
	else
		error("Unsupported data type: " .. DataType)
	end
end

local function GetRemotePacketSize(...: any): number
	local Total = REMOTE_OVERHEAD
	local AlreadyTraversed = {}

	for _, Data in ipairs({...}) do
		Total += GetDataByteSize(Data, AlreadyTraversed) + BYTE_OVERHEAD
	end

	return Total
end

return GetRemotePacketSize