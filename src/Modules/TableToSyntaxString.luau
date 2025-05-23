local PacketProfiler = script.Parent.Parent

local Modules = PacketProfiler.Modules
local Components = PacketProfiler.Components
local Packages = require(Modules.Packages)

local PacketSizeCounter = require(Packages.Directory.PacketSizeCounter)
local StudioSettings = require(Components.StudioSettings)

local SPECIAL_CHARS = {["\a"] = "\\a", ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t", ["\v"] = "\\v", ["\0"] = "\\0"}
local KEYWORDS = { ["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true, ["elseif"] = true, ["end"] = true, ["false"] = true, ["for"] = true, ["function"] = true, ["if"] = true, ["in"] = true, ["local"] = true, ["nil"] = true, ["not"] = true, ["or"] = true, ["repeat"] = true, ["return"] = true, ["then"] = true, ["true"] = true, ["until"] = true, ["while"] = true, ["continue"] = true}
local RICH_TEXT_ESCAPES = {["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ["\""] = "&quot;", ["'"] = "&apos;"}

local VALID_VARIABLE = "^[_%a][_%w]*$"
local CONTROL_CHARS = "[%c%z]"
local RICH_TEXT_CHARS = "[%&%<%>%\"%']"

-- Maximum glyphs that can be rendered
local MAX_GLYPHS = 20000
local TRIM_MESSAGE = "... [Trimmed]"
local TRIM_MESSAGE_LENGTH = #TRIM_MESSAGE

local function GetByteSize(Value: any): string
	local ValueSize = PacketSizeCounter.GetDataByteSize(Value)
	if ValueSize < 1000 then
		return `{ValueSize} bytes`
	else
		return string.format("%.3f kilobytes", ValueSize / 1000)
	end
end

local StyleGuideColorEnums = {
	string = "ScriptString",
	number = "ScriptNumber",
	operator = "ScriptOperator",
	keyword = "ScriptKeyword",
	boolean = "ScriptKeyword",
	builtin = "ScriptBuiltInFunction",
	funcname = "ScriptFunctionName",
	text = "ScriptText",
	["nil"] = "ScriptKeyword",
	bytesize = "ScriptComment",
	bracket = "ScriptBracket",
}
local StyleGuideColors = {}

local function UpdateStyleGuideColors()
	local Theme = StudioSettings.Theme
	for Name, ColorEnum in StyleGuideColorEnums do
		StyleGuideColors[Name] = `#{Theme:GetColor(ColorEnum):ToHex()}`
	end
end

UpdateStyleGuideColors()
StudioSettings.ThemeChanged:Connect(UpdateStyleGuideColors)

-- Helper class to track both formatted string and rendered glyph count
local StringAccumulator = {}
StringAccumulator.__index = StringAccumulator

function StringAccumulator.new(maxGlyphs)
	return setmetatable({
		parts = {},
		glyphCount = 0,
		maxGlyphs = maxGlyphs or MAX_GLYPHS,
		trimmed = false,
	}, StringAccumulator)
end

function StringAccumulator:getRemainingGlyphs()
	return math.max(0, self.maxGlyphs - self.glyphCount - TRIM_MESSAGE_LENGTH)
end

function StringAccumulator:canAddGlyphs(count)
	return self.glyphCount + count + TRIM_MESSAGE_LENGTH <= self.maxGlyphs
end

function StringAccumulator:addRaw(str)
	if self.trimmed then return false end
	
	local renderedLength = #str
	if not self:canAddGlyphs(renderedLength) then
		self.trimmed = true
		table.insert(self.parts, TRIM_MESSAGE)
		self.glyphCount = self.glyphCount + TRIM_MESSAGE_LENGTH
		return false
	end
	
	table.insert(self.parts, str)
	self.glyphCount = self.glyphCount + renderedLength
	return true
end

function StringAccumulator:addFormatted(str, renderedStr)
	if self.trimmed then return false end
	
	local renderedLength = #renderedStr
	if not self:canAddGlyphs(renderedLength) then
		-- Try to add partial content if there's room
		local remaining = self:getRemainingGlyphs()
		if remaining > 0 then
			local partial = string.sub(renderedStr, 1, remaining)
			-- For formatted strings, we need to close the font tag
			table.insert(self.parts, string.format("<font color=\"%s\">%s</font>", 
				string.match(str, 'color="([^"]+)"') or StyleGuideColors.text, 
				partial))
			self.glyphCount = self.glyphCount + #partial
		end
		
		self.trimmed = true
		table.insert(self.parts, TRIM_MESSAGE)
		self.glyphCount = self.glyphCount + TRIM_MESSAGE_LENGTH
		return false
	end
	
	table.insert(self.parts, str)
	self.glyphCount = self.glyphCount + renderedLength
	return true
end

function StringAccumulator:toString()
	return table.concat(self.parts)
end

function StringAccumulator:isTrimmed()
	return self.trimmed
end

local function Syntax(Value, Type, accumulator)
	local formatted = string.format("<font color=\"%s\">%s</font>", StyleGuideColors[Type] or StyleGuideColors.text, Value)
	if accumulator then
		accumulator:addFormatted(formatted, Value)
		return formatted
	end
	return formatted
end

local c = {
	["."] = function(acc) return Syntax(".", "operator", acc) end,
	[","] = function(acc) return Syntax(",", "text", acc) end,
	["="] = function(acc) return Syntax("=", "operator", acc) end,
	["("] = function(acc) return Syntax("(", "bracket", acc) end,
	[")"] = function(acc) return Syntax(")", "bracket", acc) end,
	["{"] = function(acc) return Syntax("{", "bracket", acc) end,
	["}"] = function(acc) return Syntax("}", "bracket", acc) end,
	["["] = function(acc) return Syntax("[", "bracket", acc) end,
	["]"] = function(acc) return Syntax("]", "bracket", acc) end,
}

local function CleanupString(String)
	local NoSpecialChars = string.gsub(String, CONTROL_CHARS, SPECIAL_CHARS)
	local NoRichText = string.gsub(NoSpecialChars, RICH_TEXT_CHARS, RICH_TEXT_ESCAPES)
	return NoRichText
end

local function GetHierarchy(Object, accumulator)
	local parts = {}
	local renderedParts = {}

	local NotDone = true
	while NotDone do
		local NextObject = Object.Parent
		NotDone = NextObject and NextObject.Parent and NextObject ~= game
		local ObjName = CleanupString(Object.Name)
		local renderedName = ObjName
		
		if KEYWORDS[ObjName] or not string.match(ObjName, VALID_VARIABLE) then
			local quotedName = `&quot;{ObjName}&quot;`
			local formattedQuoted = Syntax(quotedName, "string")
			table.insert(parts, 1, `{c["["](nil)}{formattedQuoted}{c["]"](nil)}`)
			table.insert(renderedParts, 1, `["{renderedName}"]`)
		else
			local dot = NotDone and c["."](nil) or ""
			local formattedName = Syntax(ObjName, "text")
			table.insert(parts, 1, `{dot}{formattedName}`)
			table.insert(renderedParts, 1, `{NotDone and "." or ""}{renderedName}`)
		end

		Object = NextObject
	end

	local result = table.concat(parts)
	local rendered = table.concat(renderedParts)
	
	if accumulator then
		accumulator:addFormatted(result, rendered)
	end
	
	return result
end

local function ReadBuffer(Buffer: buffer)
	local Length = buffer.len(Buffer)
	local Data = table.create(Length)
	for Index = 0, Length - 1 do
		table.insert(Data, buffer.readu8(Buffer, Index))
	end

	return table.concat(Data, " ")
end

local function SerializeType(Value, Class, accumulator)
	local result, rendered
	
	if Class == "string" then
		local cleaned = CleanupString(Value)
		rendered = `"{cleaned}"`
		result = Syntax(`&quot;{cleaned}&quot;`, "string")
	elseif Class == "Instance" then
		return GetHierarchy(Value, accumulator)
	elseif Class == "buffer" then
		local bufferData = ReadBuffer(Value)
		rendered = `buffer.new(${bufferData})`
		result = `{Syntax("buffer", "builtin")}{c["."](nil)}{Syntax("new", "builtin")}{c["("](nil)}{Syntax(bufferData, "number")}{c[")"](nil)}`
	elseif type(Value) ~= Class then -- CFrame, Vector3, UDim2, ...
		local valueStr = tostring(Value)
		rendered = `{Class}.new({valueStr})`
		result = `{Syntax(Class, "builtin")}{c["."](nil)}{Syntax("new", "builtin")}{c["("](nil)}{Syntax(valueStr, "number")}{c[")"](nil)}`
	else -- number, boolean, nil, ...
		local valueStr = tostring(Value)
		rendered = valueStr
		result = Syntax(valueStr, Class)
	end
	
	if accumulator then
		accumulator:addFormatted(result, rendered)
	end
	
	return result
end

local function TableToSyntaxString(Table, DontShowBytes, IgnoredTables, PreviousDepth, accumulator)
	accumulator = accumulator or StringAccumulator.new()
	IgnoredTables = IgnoredTables or {}
	
	local CyclicData = IgnoredTables[Table]
	if CyclicData then
		local msg = "&quot;[Cyclic reference]&quot;"
		Syntax(msg, "string", accumulator)
		return accumulator:toString()
	end
	IgnoredTables[Table] = true

	local ShowBytes = not DontShowBytes
	local Depth = (PreviousDepth or 0) + 1

	local Tab = string.rep("    ", Depth - 1)
	local TrailingTab = string.rep("    ", Depth - 2)

	local IsEmpty = next(Table) == nil
	local HasOrder = true

	if Depth ~= 1 and not IsEmpty then
		c["{"](accumulator)
		accumulator:addRaw("\n")
	end

	local Index = 1
	for Key, Value in Table do
		if accumulator:isTrimmed() then
			break
		end
		
		if Index ~= Key then
			HasOrder = false
		end

		local KeyClass = typeof(Key)
		local ValueClass = typeof(Value)

		-- Add indentation
		if Index > 1 then
			accumulator:addRaw("\n")
		end
		accumulator:addRaw(Tab)

		-- Handle key
		if not HasOrder then
			if KeyClass == "string" then
				Key = CleanupString(Key)
				if KEYWORDS[Key] or not string.match(Key, VALID_VARIABLE) then
					c["["](accumulator)
					Syntax(`&quot;{Key}&quot;`, "string", accumulator)
					c["]"](accumulator)
				else
					accumulator:addRaw(Key)
				end
			else
				c["["](accumulator)
				if KeyClass == "table" then
					TableToSyntaxString(Key, DontShowBytes, IgnoredTables, 1, accumulator)
				else
					SerializeType(Key, KeyClass, accumulator)
				end
				c["]"](accumulator)
			end

			-- Add key size if needed
			if KeyClass ~= "table" and ShowBytes then
				local keySize = GetByteSize(Key)
				Syntax(`: {keySize} `, "bytesize", accumulator)
			end

			accumulator:addRaw(" ")
			c["="](accumulator)
			accumulator:addRaw(" ")
		end

		-- Handle value
		if ValueClass == "table" then
			TableToSyntaxString(Value, DontShowBytes, IgnoredTables, Depth, accumulator)
		else
			SerializeType(Value, ValueClass, accumulator)
		end

		-- Add value size if needed
		if ValueClass ~= "table" and ShowBytes then
			local valueSize = GetByteSize(Value)
			Syntax(`: {valueSize}`, "bytesize", accumulator)
		end

		c[","](accumulator)
		Index += 1
	end

	if Depth == 1 then
		return accumulator:toString()
	else
		if IsEmpty then
			c["{"](accumulator)
			c["}"](accumulator)
		else
			accumulator:addRaw("\n")
			accumulator:addRaw(TrailingTab)
			c["}"](accumulator)
		end
		return accumulator:toString()
	end
end

return TableToSyntaxString