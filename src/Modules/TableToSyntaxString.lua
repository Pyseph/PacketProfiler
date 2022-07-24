local Settings = settings()
local Studio = Settings:GetService("Studio")

local Modules = script.Parent
local GetRemotePacketSize = require(Modules.PacketSizeCounter)

local function GetByteSize(Value: any): string
	local ValueSize = GetRemotePacketSize(true, Value)
	if ValueSize < 1000 then
		return ValueSize .. "B"
	else
		return string.format("%.3fKB", ValueSize / 1000)
	end
end

local SpecialCharacters = {["\a"] = "\\a", ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t", ["\v"] = "\\v", ["\0"] = "\\0"}
local Keywords = { ["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true, ["elseif"] = true, ["end"] = true, ["false"] = true, ["for"] = true, ["function"] = true, ["if"] = true, ["in"] = true, ["local"] = true, ["nil"] = true, ["not"] = true, ["or"] = true, ["repeat"] = true, ["return"] = true, ["then"] = true, ["true"] = true, ["until"] = true, ["while"] = true, ["continue"] = true}

local VALID_VARIABLE = "^[_%a][_%w]*$"
local CONTROL_CHARS = "[%c%z]"
local NO_TRAILING = "^%s*(.-)%s*$"

local StyleGuideColorEnums = {
	string = Enum.StudioStyleGuideColor.ScriptString,
	number = Enum.StudioStyleGuideColor.ScriptNumber,
	operator = Enum.StudioStyleGuideColor.ScriptOperator,
	keyword = Enum.StudioStyleGuideColor.ScriptKeyword,
	boolean = Enum.StudioStyleGuideColor.ScriptKeyword,
	builtin = Enum.StudioStyleGuideColor.ScriptBuiltInFunction,
	funcname = Enum.StudioStyleGuideColor.ScriptFunctionName,
	text = Enum.StudioStyleGuideColor.ScriptText,
	["nil"] = Enum.StudioStyleGuideColor.ScriptKeyword,
	bytesize = Enum.StudioStyleGuideColor.ScriptComment,
}
local StyleGuideColors = {}
local c = {
	["."] = ".",
	["{"] = "{",
	["}"] = "}",
	["["] = "[",
	["]"] = "]",
	["("] = "(",
	[")"] = ")",
}

local function Syntax(Value, Type)
	return string.format("<font color=\"%s\">%s</font>", StyleGuideColors[Type] or StyleGuideColors.text, Value)
end

local function UpdateStyleGuideColors()
	for Name, ColorEnum in pairs(StyleGuideColorEnums) do
		StyleGuideColors[Name] = "#" .. Studio.Theme:GetColor(ColorEnum):ToHex()
	end

	for Name in pairs(c) do
		StyleGuideColors[Name] = Syntax(Name, "text")
	end
end
UpdateStyleGuideColors()
Studio.ThemeChanged:Connect(UpdateStyleGuideColors)

local function GetHierarchy(Object)
	local Result = ""
	while Object and Object ~= game do
		local ObjName = string.gsub(Object.Name, CONTROL_CHARS, SpecialCharacters)
		if Keywords[ObjName] or not string.match(ObjName, VALID_VARIABLE) then
			ObjName = c["["] .. Syntax("&quot;" .. ObjName .. "&quot;", "string") .. c["]"]
		else
			ObjName = c["."] .. Syntax(ObjName, "text")
		end

		Result = ObjName .. Result
		Object = Object.Parent
	end

	return string.sub(Result, 2)
end
local function SerializeType(Value, Class)
	if Class == "string" then
		-- Not using %q as it messes up the special characters fix
		return Syntax(string.format("&quot;%s&quot;", (string.gsub(Value, CONTROL_CHARS, SpecialCharacters))), "string")
	elseif Class == "Instance" then
		return GetHierarchy(Value)
	elseif type(Value) ~= Class then -- CFrame, Vector3, UDim2, ...
		return Syntax(Class, "builtin") .. c["."] .. Syntax("new", "builtin") .. c["("] .. Syntax(tostring(Value), "number") .. c[")"]
	else -- number, boolean, nil, ...
		return Syntax(tostring(Value), Class)
	end
end
local function TableToSyntaxString(Table, IgnoredTables, DepthData, Path)
	IgnoredTables = IgnoredTables or {}
	local CyclicData = IgnoredTables[Table]
	if CyclicData then
		-- Remotes cant pass cyclic tableS, but I'm keeping it just in case
		return Syntax("&quot;[Cyclic reference]&quot;", "string")
	end

	Path = Path or "ROOT"
	DepthData = DepthData or {0, Path}
	local Depth = DepthData[1] + 1
	DepthData[1] = Depth
	DepthData[2] = Path

	IgnoredTables[Table] = DepthData
	local Tab = string.rep("    ", Depth)
	local TrailingTab = string.rep("    ", Depth - 1)
	local Result = c["{"]

	local LineTab = "\n" .. Tab
	local HasOrder = true
	local Index = 1

	local IsEmpty = true
	for Key, Value in next, Table do
		IsEmpty = false
		if Index ~= Key then
			HasOrder = false
		else
			Index += 1
		end

		local KeyClass, ValueClass = typeof(Key), typeof(Value)
		local HasBrackets = false

		local KeySize = KeyClass ~= "table" and ": " .. Syntax(GetByteSize(Key), "bytesize") .. " " or ""
		local ValueSize = ValueClass ~= "table" and ": " .. Syntax(GetByteSize(Value), "bytesize") or ""
		if KeyClass == "string" then
			Key = string.gsub(Key, CONTROL_CHARS, SpecialCharacters)
			if Keywords[Key] or not string.match(Key, VALID_VARIABLE) then
				HasBrackets = true
				Key = string.format(c["["] .. Syntax("&quot;%s&quot;", "string") .. c["]"], Key)
			end
		else
			HasBrackets = true
			local KeyString = (KeyClass == "table" and string.gsub(TableToSyntaxString(Key, IgnoredTables, {Depth, Path}), NO_TRAILING, "%1") or SerializeType(Key, KeyClass))
			Key = c["["] .. KeyString .. c["]"]
		end

		Value = ValueClass == "table" and TableToSyntaxString(Value, IgnoredTables, {Depth, Path}, Path .. (HasBrackets and "" or ".") .. Key) or SerializeType(Value, ValueClass)
		Result = Result .. LineTab .. (HasOrder and Value or Key .. KeySize .. Syntax("=", "operator") .. " " .. Value) .. ValueSize .. Syntax(",", "keyword")
	end

	return IsEmpty and Result .. c["}"] or Result .. "\n" .. TrailingTab .. c["}"]
end

return TableToSyntaxString