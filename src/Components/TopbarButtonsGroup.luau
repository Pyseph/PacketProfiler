local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")

local PacketProfiler = script.Parent.Parent
local Modules = PacketProfiler.Modules
local Packages = require(Modules.Packages)

local Roact = require(Packages.Directory.Roact)

local TOPBAR_HEIGHT = 10
local IsEditMode = not RunService:IsRunning()

local function TopbarOptionsButton(props)
	return Roact.createElement("TextButton", {
		AutoLocalize = false,
		Text = props.ButtonName,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Center,
		Font = Enum.Font.Code,
		TextColor3 = props.Theme.Name == "Light" and Color3.new(0, 0, 0) or Color3.new(1, 1, 1),
		TextSize = TOPBAR_HEIGHT + 2,
		BackgroundColor3 = props.Theme:GetColor("ScrollBarBackground"),
		Size = props.Size,
		BorderSizePixel = 0,
		[Roact.Event.Activated] = props.OnClick,
	})
end

local TopbarButtonsGroup = Roact.Component:extend("TopbarButtonsGroup")

function TopbarButtonsGroup:init()
	self.MouseHovering, self.SetMouseHovering = Roact.createBinding(0)
	self.TopbarRef = Roact.createRef()
end

function TopbarButtonsGroup:render()
	local props = self.props
	local Buttons = {}

	local ButtonGroupTextSize = TextService:GetTextSize(props.Text, TOPBAR_HEIGHT + 2, Enum.Font.Code, Vector2.new(10000, TOPBAR_HEIGHT + 1))
	local LongestButtonWidth = ButtonGroupTextSize.X
	for _, Data in props.Options do
		local ButtonTextSize = TextService:GetTextSize(Data.Name, TOPBAR_HEIGHT + 1, Enum.Font.Code, Vector2.new(10000, TOPBAR_HEIGHT + 1))
		LongestButtonWidth = math.max(LongestButtonWidth, ButtonTextSize.X)
	end

	for _, Data in props.Options do
		table.insert(Buttons, TopbarOptionsButton({
			ButtonName = Data.Name,
			OnClick = Data.Callback,
			Theme = props.Theme,
			Size = UDim2.fromOffset(LongestButtonWidth, TOPBAR_HEIGHT + 1),
		}))
	end

	return Roact.createElement("TextLabel", {
		AutoLocalize = false,
		Text = props.Text,
		TextColor3 = props.Theme.Name == "Light" and Color3.new(0, 0, 0) or Color3.new(1, 1, 1),
		BackgroundColor3 = self.MouseHovering:map(function(VisibleIndex)
			return VisibleIndex > 0 and props.Theme:GetColor("Light") or props.Theme:GetColor("ScrollBarBackground")
		end),
		TextSize = TOPBAR_HEIGHT + 2,
		Font = Enum.Font.Code,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(ButtonGroupTextSize.X, TOPBAR_HEIGHT),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		LayoutOrder = props.LayoutOrder,
		Visible = not IsEditMode,
		[Roact.Event.MouseEnter] = function()
			self.SetMouseHovering(1)
		end,
		[Roact.Event.MouseLeave] = function()
			task.defer(function()
				if self.MouseHovering:getValue() == 1 then
					self.SetMouseHovering(0)
				end
			end)
		end,
		[Roact.Ref] = self.TopbarRef,
	}, {
		OptionsHolder = Roact.createElement("Frame", {
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Visible = self.MouseHovering:map(function(VisibleIndex)
				return VisibleIndex > 0
			end),
			Position = UDim2.fromOffset(0, TOPBAR_HEIGHT),
			[Roact.Event.MouseEnter] = function()
				self.SetMouseHovering(2)
			end,
			[Roact.Event.MouseLeave] = function()
				task.defer(function()
					if self.MouseHovering:getValue() == 2 then
						self.SetMouseHovering(0)
					end
				end)
			end,
			Size = UDim2.fromOffset(LongestButtonWidth, 0),
		}, {
			OptionsListLayout = Roact.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Top,
			}),
			Buttons = Roact.createFragment(Buttons),
		})
	})
end

return TopbarButtonsGroup