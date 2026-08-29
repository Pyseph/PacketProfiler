local TextService = game:GetService("TextService")

local PacketProfiler = script.Parent.Parent
local Packages = require(PacketProfiler.Modules.Packages)
local Vide = require(Packages.Directory.Vide)

local AnimatedButton = require(PacketProfiler.Components.AnimatedButton)

local create = Vide.create
local indexes = Vide.indexes

local function buttonWidth(text)
	return TextService:GetTextSize(text, 13, Enum.Font.BuilderSansMedium, Vector2.new(300, 24)).X + 20
end

local function LayerTabs(props)
	return create("ScrollingFrame")({
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		Position = props.Position,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		Size = props.Size,

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),

		AnimatedButton({
			Text = props.AllViewName,
			TextColor = function()
				return props.Theme("BrightText")
			end,
			AccentColor = Color3.fromHex("#4CC2FF"),
			Selected = function()
				return props.View() == "all"
			end,
			Size = function()
				return UDim2.fromOffset(buttonWidth(props.AllViewName()), 24)
			end,
			LayoutOrder = 1,
			OnClick = function()
				props.OnViewChanged("all")
			end,
		}),

		indexes(props.Layers, function(layer, index)
			return AnimatedButton({
				Text = function()
					return layer().Name
				end,
				TextColor = function()
					return props.Theme("BrightText")
				end,
				AccentColor = function()
					return layer().Color or Color3.fromHex("#8B95A5")
				end,
				Selected = function()
					return props.View() == layer().Id
				end,
				Size = function()
					return UDim2.fromOffset(buttonWidth(layer().Name), 24)
				end,
				LayoutOrder = index + 1,
				OnClick = function()
					props.OnViewChanged(layer().Id)
				end,
			})
		end),
	})
end

return LayerTabs
