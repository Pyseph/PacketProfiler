local TopFrameStore = {}
TopFrameStore.__index = TopFrameStore

local function isHigherRank(left, right)
	if left.Size == right.Size then
		return left.Frame.Time > right.Frame.Time
	end
	return left.Size > right.Size
end

function TopFrameStore.new(capacity)
	return setmetatable({
		Capacity = capacity,
		Views = {},
	}, TopFrameStore)
end

function TopFrameStore:_record(view, frame, size)
	if size <= 0 then
		return false
	end

	local entries = self.Views[view]
	if entries == nil then
		entries = {}
		self.Views[view] = entries
	end

	local entry = { Frame = frame, Size = size }
	local insertAt = #entries + 1
	for index, existing in entries do
		if isHigherRank(entry, existing) then
			insertAt = index
			break
		end
	end

	if insertAt > self.Capacity then
		return false
	end

	table.insert(entries, insertAt, entry)
	if #entries > self.Capacity then
		table.remove(entries)
	end
	return true
end

function TopFrameStore:Record(frame, layers, getSize)
	local changed = self:_record("all", frame, getSize(frame, "all"))
	for _, layer in layers do
		changed = self:_record(layer.Id, frame, getSize(frame, layer.Id)) or changed
	end
	return changed
end

function TopFrameStore:Get(view, limit)
	local entries = self.Views[view] or {}
	local result = {}
	for index = 1, math.min(limit, #entries) do
		result[index] = entries[index]
	end
	return result
end

function TopFrameStore:RemoveView(view)
	self.Views[view] = nil
end

function TopFrameStore:Clear()
	table.clear(self.Views)
end

return TopFrameStore
