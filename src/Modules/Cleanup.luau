local Cleanup = {}

function Cleanup.run(item)
	local itemType = typeof(item)

	if itemType == "RBXScriptConnection" then
		item:Disconnect()
	elseif itemType == "Instance" then
		item:Destroy()
	elseif type(item) == "function" then
		item()
	elseif type(item) == "table" then
		if type(item.Disconnect) == "function" then
			item:Disconnect()
		elseif type(item.Destroy) == "function" then
			item:Destroy()
		end
	end
end

function Cleanup.all(items)
	for index = #items, 1, -1 do
		Cleanup.run(items[index])
		items[index] = nil
	end
end

return Cleanup
