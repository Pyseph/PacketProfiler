local PacketProfiler = script.Parent.Parent

local Modules = PacketProfiler.Modules
local Components = PacketProfiler.Components
local Packages = require(Modules.Packages)

local PacketSizeCounter = require(Packages.Directory.PacketSizeCounter)
local StudioSettings = require(Components.StudioSettings)

local function GetByteSize(Value: any): string
	local ValueSize = PacketSizeCounter.GetDataByteSize(Value)
	if ValueSize < 1000 then
		return `{ValueSize} bytes`
	else
		return string.format("%.3f kilobytes", ValueSize / 1000)
	end
end

local SpecialCharacters = {["\a"] = "\\a", ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t", ["\v"] = "\\v", ["\0"] = "\\0"}
local Keywords = { ["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true, ["elseif"] = true, ["end"] = true, ["false"] = true, ["for"] = true, ["function"] = true, ["if"] = true, ["in"] = true, ["local"] = true, ["nil"] = true, ["not"] = true, ["or"] = true, ["repeat"] = true, ["return"] = true, ["then"] = true, ["true"] = true, ["until"] = true, ["while"] = true, ["continue"] = true}
local RichTextEscapes = {["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ["\""] = "&quot;", ["'"] = "&apos;"}

local VALID_VARIABLE = "^[_%a][_%w]*$"
local CONTROL_CHARS = "[%c%z]"
local NO_TRAILING = "^%s*(.-)%s*$"
local RICH_TEXT_CHARS = "[%&%<%>%\"%']"

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

local function Syntax(Value, Type)
	return string.format("<font color=\"%s\">%s</font>", StyleGuideColors[Type] or StyleGuideColors.text, Value)
end

local c = {
	["."] = Syntax(".", "operator"),
	[","] = Syntax(",", "text"),
	["="] = Syntax("=", "operator"),
	["("] = Syntax("(", "bracket"),
	[")"] = Syntax(")", "bracket"),
	["{"] = Syntax("{", "bracket"),
	["}"] = Syntax("}", "bracket"),
	["["] = Syntax("[", "bracket"),
	["]"] = Syntax("]", "bracket"),
}

local function CleanupString(String)
	local NoSpecialChars = string.gsub(String, CONTROL_CHARS, SpecialCharacters)
	local NoRichText = string.gsub(NoSpecialChars, RICH_TEXT_CHARS, RichTextEscapes)
	return NoRichText
end

local function GetHierarchy(Object)
	local Result = ""

	local NotDone = true
	while NotDone do
		local NextObject = Object.Parent
		NotDone = NextObject and NextObject.Parent and NextObject ~= game
		local ObjName = CleanupString(Object.Name)
		if Keywords[ObjName] or not string.match(ObjName, VALID_VARIABLE) then
			ObjName = `{c["["]}{Syntax(`&quot;{ObjName}&quot;`, "string")}{c["]"]}`
		else
			ObjName = `{NotDone and c["."] or ""}{Syntax(ObjName, "text")}`
		end

		Result = ObjName .. Result
		Object = NextObject
	end

	return Result
end

local function ReadBuffer(Buffer: buffer)
	local Length = buffer.len(Buffer)
	local Data = table.create(Length)
	for Index = 0, Length - 1 do
		table.insert(Data, buffer.readu8(Buffer, Index))
	end

	return table.concat(Data, " ")
end

local function SerializeType(Value, Class)
	if Class == "string" then
		-- Not using %q as it messes up the special characters fix
		return Syntax(string.format("&quot;%s&quot;", CleanupString(Value)), "string")
	elseif Class == "Instance" then
		return GetHierarchy(Value)
	elseif Class == "buffer" then
		return `{Syntax("buffer", "builtin")}{c["."]}{Syntax("new", "builtin")}{c["("]}{Syntax(ReadBuffer(Value), "number")}{c[")"]}`
	elseif type(Value) ~= Class then -- CFrame, Vector3, UDim2, ...
		return `{Syntax(Class, "builtin")}{c["."]}{Syntax("new", "builtin")}{c["("]}{Syntax(tostring(Value), "number")}{c[")"]}`
	else -- number, boolean, nil, ...
		return Syntax(tostring(Value), Class)
	end
end
local function TableToSyntaxString(Table, DontShowBytes, IgnoredTables, DepthData, Path)
	IgnoredTables = IgnoredTables or {}
	local CyclicData = IgnoredTables[Table]
	if CyclicData then
		-- Remotes cant pass cyclic tables, but I'm keeping it just in case
		return Syntax("&quot;[Cyclic reference]&quot;", "string")
	end

	Path = Path or "ROOT"
	DepthData = DepthData or {0, Path}
	local Depth = DepthData[1] + 1
	DepthData[1] = Depth
	DepthData[2] = Path

	IgnoredTables[Table] = DepthData
	local Tab = string.rep("    ", Depth - 1)
	local TrailingTab = string.rep("    ", Depth - 2)
	local Lines = {Depth == 1 and "" or c["{"]}

	local HasOrder = true
	local Index = 1

	local IsEmpty = true
	for Key, Value in Table do
		IsEmpty = false
		if Index ~= Key then
			HasOrder = false
		end

		local KeyClass, ValueClass = typeof(Key), typeof(Value)
		local HasBrackets = false

		local KeySize = (KeyClass ~= "table" and not DontShowBytes) and `: {Syntax(GetByteSize(Key), "bytesize")} ` or ""
		local ValueSize = (ValueClass ~= "table" and not DontShowBytes) and `: {Syntax(GetByteSize(Value), "bytesize")}` or ""
		if KeyClass == "string" then
			Key = CleanupString(Key)
			if Keywords[Key] or not string.match(Key, VALID_VARIABLE) then
				HasBrackets = true
				Key = string.format(`{c["["]}{Syntax("&quot;%s&quot;", "string")}{c["]"]}`, Key)
			end
		else
			HasBrackets = true
			local KeyString = KeyClass == "table" and string.gsub(TableToSyntaxString(Key, DontShowBytes, IgnoredTables, {Depth, Path}), NO_TRAILING, "%1") or SerializeType(Key, KeyClass)
			Key = `{c["["]}{KeyString}{c["]"]}`
		end

		local LineTab = Depth == 1 and (Index == 1 and "" or "\n") or `\n{Tab}`
		Value = ValueClass == "table" and TableToSyntaxString(Value, DontShowBytes, IgnoredTables, {Depth, Path}, `{Path}{(HasBrackets and "" or ".")}{Key}`) or SerializeType(Value, ValueClass)
		Lines[Index] = `{LineTab}{(HasOrder and Value or `{Key}{KeySize}{Syntax("=", "operator")} {Value}`)}{ValueSize}{Syntax(",", "keyword")}`

		Index += 1
	end

	local StartBracket = Depth == 1 and "" or c["{"]
	local EndBracket = Depth == 1 and "" or c["}"]
	local NewLine = Depth == 1 and "" or `\n`
	local Result = table.concat(Lines, "")
	return IsEmpty and `{StartBracket}{Result}{EndBracket}` or `{StartBracket}{Result}{NewLine}{TrailingTab}{EndBracket}`
end

return TableToSyntaxString