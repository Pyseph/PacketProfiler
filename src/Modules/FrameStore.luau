local PacketProfiler = script.Parent.Parent
local CircularBuffer = require(PacketProfiler.Modules.CircularBuffer)

local FrameStore = {}
FrameStore.__index = FrameStore

local function newFrame(time)
	return {
		Time = time,
		TotalSize = 0,
		PacketCount = 0,
		LayerTotals = {},
		Packets = {},
	}
end

function FrameStore.new(maxFrames, frameInterval)
	local nextBucket = math.floor(os.clock() / frameInterval)
	return setmetatable({
		Frames = CircularBuffer.new(maxFrames),
		FrameInterval = frameInterval,
		NextBucket = nextBucket,
		PendingFrames = {},
	}, FrameStore)
end

function FrameStore:Record(packet)
	local bucket = math.max(math.floor(packet.Timestamp / self.FrameInterval), self.NextBucket)
	local frame = self.PendingFrames[bucket]
	if frame == nil then
		frame = newFrame(bucket * self.FrameInterval)
		self.PendingFrames[bucket] = frame
	end
	if packet.IncludeInAll then
		frame.TotalSize += packet.Size
	end
	frame.PacketCount += 1
	frame.LayerTotals[packet.LayerId] = (frame.LayerTotals[packet.LayerId] or 0) + packet.Size
	table.insert(frame.Packets, packet)
	return frame
end

function FrameStore:Commit()
	local bucket = self.NextBucket
	local frame = self.PendingFrames[bucket] or newFrame(bucket * self.FrameInterval)
	self.PendingFrames[bucket] = nil
	self.NextBucket += 1
	self.Frames:push(frame)
	return frame
end

function FrameStore:Skip(count)
	if count <= 0 then
		return
	end
	local nextBucket = self.NextBucket + count
	for bucket in self.PendingFrames do
		if bucket < nextBucket then
			self.PendingFrames[bucket] = nil
		end
	end
	self.NextBucket = nextBucket
end

function FrameStore:Seek(timestamp)
	table.clear(self.PendingFrames)
	self.NextBucket = math.floor(timestamp / self.FrameInterval)
end

function FrameStore:GetSize(frame, view)
	if view == nil or view == "all" then
		return frame.TotalSize
	end
	return frame.LayerTotals[view] or 0
end

function FrameStore:GetPackets(frame, view)
	if view == nil or view == "all" then
		local packets = {}
		for _, packet in frame.Packets do
			if packet.IncludeInAll then
				table.insert(packets, packet)
			end
		end
		return packets
	end

	local packets = {}
	for _, packet in frame.Packets do
		if packet.LayerId == view then
			table.insert(packets, packet)
		end
	end
	return packets
end

function FrameStore:GetView(frame, view)
	local packets = self:GetPackets(frame, view)
	return {
		Time = frame.Time,
		TotalSize = self:GetSize(frame, view),
		PacketCount = #packets,
		LayerTotals = frame.LayerTotals,
		Packets = packets,
	}
end

return FrameStore
