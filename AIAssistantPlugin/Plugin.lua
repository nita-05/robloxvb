local toolbar = plugin:CreateToolbar("AI Assistant")
local button = toolbar:CreateButton("Open AI", "Open AI Panel", "")

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right,
	true,
	false,
	400,
	720,
	340,
	500
)

local widget = plugin:CreateDockWidgetPluginGui("AIAssistant", widgetInfo)
widget.Title = "AI Assistant"

button.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

-- UI ROOT
local frame = Instance.new("Frame")
frame.Size = UDim2.new(1, 0, 1, 0)
frame.BackgroundColor3 = Color3.fromRGB(11, 14, 26) -- deep navy base (reference-like)
frame.BorderSizePixel = 0
frame.Parent = widget

local THEME = {
	Bg = Color3.fromRGB(11, 14, 26),
	Panel = Color3.fromRGB(16, 20, 36),
	Surface = Color3.fromRGB(12, 16, 30),
	Border = Color3.fromRGB(34, 44, 74),
	Text = Color3.fromRGB(236, 242, 255),
	Muted = Color3.fromRGB(165, 176, 205),
	Primary = Color3.fromRGB(34, 211, 238), -- teal accent (reference-like)
	Primary2 = Color3.fromRGB(59, 130, 246), -- secondary blue
	Danger = Color3.fromRGB(120, 38, 55),
	Radius = UDim.new(0, 8),
	ButtonRadius = UDim.new(0, 14), -- pill buttons like reference
}

do
	-- Background "glow" layers (no external assets)
	local glow = Instance.new("Frame")
	glow.Name = "BgGlow"
	glow.BackgroundColor3 = Color3.fromRGB(30, 24, 70)
	glow.BackgroundTransparency = 0.35
	glow.BorderSizePixel = 0
	glow.Size = UDim2.new(1.2, 0, 0.6, 0)
	glow.Position = UDim2.new(-0.1, 0, -0.15, 0)
	glow.ZIndex = 0
	glow.Parent = frame

	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(0, 40)
	glowCorner.Parent = glow

	local glowGrad = Instance.new("UIGradient")
	glowGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(59, 130, 246)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(34, 211, 238)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(147, 51, 234)),
	})
	glowGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.7, 0.8),
		NumberSequenceKeypoint.new(1, 1),
	})
	glowGrad.Rotation = 25
	glowGrad.Parent = glow
end

local rootScroll = Instance.new("ScrollingFrame")
rootScroll.Name = "RootScroll"
rootScroll.Size = UDim2.new(1, 0, 1, -64)
rootScroll.Position = UDim2.new(0, 0, 0, 64)
rootScroll.BackgroundTransparency = 1
rootScroll.BorderSizePixel = 0
rootScroll.ScrollBarThickness = 8
rootScroll.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 90)
rootScroll.ScrollBarImageTransparency = 0.2
rootScroll.ScrollingDirection = Enum.ScrollingDirection.Y
rootScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
rootScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
rootScroll.Parent = frame

local rootPadding = Instance.new("UIPadding")
rootPadding.PaddingTop = UDim.new(0, 8)
rootPadding.PaddingBottom = UDim.new(0, 8)
rootPadding.PaddingLeft = UDim.new(0, 8)
rootPadding.PaddingRight = UDim.new(0, 8)
rootPadding.Parent = rootScroll

local rootLayout = Instance.new("UIListLayout")
rootLayout.FillDirection = Enum.FillDirection.Vertical
rootLayout.SortOrder = Enum.SortOrder.LayoutOrder
rootLayout.Padding = UDim.new(0, 8)
rootLayout.Parent = rootScroll

local function addPanel(parent, height)
	local panel = Instance.new("Frame")
	panel.BackgroundColor3 = THEME.Panel
	panel.BorderSizePixel = 0
	panel.Size = UDim2.new(1, 0, 0, height)
	panel.ClipsDescendants = true

	local stroke = Instance.new("UIStroke")
	stroke.Color = THEME.Border
	stroke.Thickness = 1
	stroke.Transparency = 0.35
	stroke.Parent = panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = THEME.Radius
	corner.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = panel

	panel.Parent = parent
	return panel
end

local function addSectionLabel(parent, text)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 20)
	row.Parent = parent

	local accent = Instance.new("Frame")
	accent.BackgroundColor3 = THEME.Primary
	accent.BackgroundTransparency = 0
	accent.BorderSizePixel = 0
	accent.Size = UDim2.new(0, 3, 1, -6)
	accent.Position = UDim2.new(0, 0, 0, 3)
	accent.Parent = row

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -10, 1, 0)
	label.Position = UDim2.new(0, 10, 0, 0)
	label.Text = string.upper(text)
	label.TextColor3 = THEME.Text
	label.TextTransparency = 0.08
	label.Font = Enum.Font.SourceSansSemibold
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = row

	local divider = Instance.new("Frame")
	divider.BackgroundColor3 = THEME.Border
	divider.BackgroundTransparency = 0.55
	divider.BorderSizePixel = 0
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.Position = UDim2.new(0, 0, 1, -1)
	divider.Parent = row

	return row
end

local function brighten(color, factor)
	return Color3.new(
		math.clamp(color.R * factor, 0, 1),
		math.clamp(color.G * factor, 0, 1),
		math.clamp(color.B * factor, 0, 1)
	)
end

local function applyHover(btn, baseColor)
	btn.AutoButtonColor = false
	btn:SetAttribute("BaseColor", baseColor)
	btn.BackgroundColor3 = baseColor

	btn.MouseEnter:Connect(function()
		if btn.Active then
			btn.BackgroundColor3 = brighten(baseColor, 1.08)
		end
	end)
	btn.MouseLeave:Connect(function()
		local bc = btn:GetAttribute("BaseColor")
		if typeof(bc) == "Color3" then
			btn.BackgroundColor3 = bc
		else
			btn.BackgroundColor3 = baseColor
		end
	end)
end

local function styleButton(btn, baseColor)
	btn.BackgroundColor3 = baseColor
	btn.BorderSizePixel = 0
	btn.TextColor3 = THEME.Text
	btn.Font = Enum.Font.SourceSansSemibold
	btn.TextSize = 15
	btn.TextYAlignment = Enum.TextYAlignment.Center

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = btn

	local corner = Instance.new("UICorner")
	corner.CornerRadius = THEME.ButtonRadius
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = THEME.Border
	stroke.Thickness = 1
	stroke.Transparency = 0.45
	stroke.Parent = btn

	btn.MouseButton1Down:Connect(function()
		if btn.Active then
			scale.Scale = 0.985
		end
	end)
	btn.MouseButton1Up:Connect(function()
		scale.Scale = 1
	end)
	btn.MouseLeave:Connect(function()
		scale.Scale = 1
	end)

	applyHover(btn, baseColor)
end

local headerPanel = addPanel(frame, 56)
headerPanel.Position = UDim2.new(0, 8, 0, 8)
headerPanel.Size = UDim2.new(1, -16, 0, 56)
headerPanel.ZIndex = 10

headerPanel.BackgroundColor3 = Color3.fromRGB(16, 20, 36)
local headerGrad = Instance.new("UIGradient")
headerGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 26, 46)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(13, 16, 30)),
})
headerGrad.Rotation = 90
headerGrad.Parent = headerPanel

local headerContent = Instance.new("Frame")
headerContent.Name = "HeaderContent"
headerContent.BackgroundTransparency = 1
headerContent.Size = UDim2.new(1, 0, 1, 0)
headerContent.ZIndex = 11
headerContent.Parent = headerPanel

local headerPadding = Instance.new("UIPadding")
headerPadding.PaddingTop = UDim.new(0, 10)
headerPadding.PaddingBottom = UDim.new(0, 10)
headerPadding.PaddingLeft = UDim.new(0, 10)
headerPadding.PaddingRight = UDim.new(0, 10)
headerPadding.Parent = headerContent

local headerH = Instance.new("UIListLayout")
headerH.FillDirection = Enum.FillDirection.Horizontal
headerH.HorizontalAlignment = Enum.HorizontalAlignment.Left
headerH.VerticalAlignment = Enum.VerticalAlignment.Center
headerH.SortOrder = Enum.SortOrder.LayoutOrder
headerH.Padding = UDim.new(0, 10)
headerH.Parent = headerContent

local brandTile = Instance.new("Frame")
brandTile.Name = "BrandTile"
brandTile.BackgroundColor3 = Color3.fromRGB(10, 16, 34)
brandTile.BorderSizePixel = 0
brandTile.Size = UDim2.new(0, 40, 0, 40)
brandTile.LayoutOrder = 1
brandTile.Parent = headerContent

local brandTileCorner = Instance.new("UICorner")
brandTileCorner.CornerRadius = UDim.new(0, 10)
brandTileCorner.Parent = brandTile

local brandTileStroke = Instance.new("UIStroke")
brandTileStroke.Color = Color3.fromRGB(33, 56, 104)
brandTileStroke.Thickness = 1
brandTileStroke.Transparency = 0.35
brandTileStroke.Parent = brandTile

local brandIcon = Instance.new("TextLabel")
brandIcon.Name = "BrandIcon"
brandIcon.BackgroundColor3 = Color3.fromRGB(86, 58, 212)
brandIcon.BorderSizePixel = 0
brandIcon.Size = UDim2.new(0, 34, 0, 34)
brandIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
brandIcon.AnchorPoint = Vector2.new(0.5, 0.5)
brandIcon.Text = "V"
brandIcon.TextColor3 = Color3.fromRGB(226, 238, 255)
brandIcon.TextSize = 23
brandIcon.Font = Enum.Font.GothamBold
brandIcon.ZIndex = 12
brandIcon.Parent = brandTile

local brandCorner = Instance.new("UICorner")
brandCorner.CornerRadius = UDim.new(0, 12)
brandCorner.Parent = brandIcon

local brandStroke = Instance.new("UIStroke")
brandStroke.Color = Color3.fromRGB(95, 186, 255)
brandStroke.Transparency = 0.12
brandStroke.Thickness = 1
brandStroke.Parent = brandIcon

local brandGrad = Instance.new("UIGradient")
brandGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(163, 84, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(74, 211, 255)),
})
brandGrad.Rotation = 32
brandGrad.Parent = brandIcon

local logoCore = Instance.new("Frame")
logoCore.Name = "LogoCore"
logoCore.AnchorPoint = Vector2.new(0.5, 0.5)
logoCore.Position = UDim2.new(0.45, 0, 0.52, 0)
logoCore.Size = UDim2.new(0, 14, 0, 14)
logoCore.BackgroundColor3 = Color3.fromRGB(6, 14, 28)
logoCore.BorderSizePixel = 0
logoCore.ZIndex = 13
logoCore.Parent = brandIcon

local logoCoreCorner = Instance.new("UICorner")
logoCoreCorner.CornerRadius = UDim.new(0, 5)
logoCoreCorner.Parent = logoCore

local logoCoreStroke = Instance.new("UIStroke")
logoCoreStroke.Color = THEME.Primary
logoCoreStroke.Thickness = 1.5
logoCoreStroke.Transparency = 0.05
logoCoreStroke.Parent = logoCore

local orbit = Instance.new("Frame")
orbit.Name = "LogoOrbit"
orbit.AnchorPoint = Vector2.new(0.5, 0.5)
orbit.Position = UDim2.new(0.56, 0, 0.53, 0)
orbit.Size = UDim2.new(0, 18, 0, 18)
orbit.BackgroundTransparency = 1
orbit.BorderSizePixel = 0
orbit.ZIndex = 13
orbit.Parent = brandIcon

local orbitStroke = Instance.new("UIStroke")
orbitStroke.Color = Color3.fromRGB(0, 174, 255)
orbitStroke.Thickness = 1.2
orbitStroke.Transparency = 0.25
orbitStroke.Parent = orbit

local logoDot = Instance.new("Frame")
logoDot.Name = "LogoDot"
logoDot.AnchorPoint = Vector2.new(0.5, 0.5)
logoDot.Position = UDim2.new(0.78, 0, 0.23, 0)
logoDot.Size = UDim2.new(0, 5, 0, 5)
logoDot.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
logoDot.BorderSizePixel = 0
logoDot.ZIndex = 14
logoDot.Parent = brandIcon

local logoDotCorner = Instance.new("UICorner")
logoDotCorner.CornerRadius = UDim.new(1, 0)
logoDotCorner.Parent = logoDot

-- Use V-badge logo style for header icon.
logoCore.Visible = false
orbit.Visible = false
logoDot.Visible = false

-- Rebuild visible icon exactly in the reference style.
brandIcon.Visible = false

local brandBadge = Instance.new("Frame")
brandBadge.Name = "BrandBadge"
brandBadge.AnchorPoint = Vector2.new(0.5, 0.5)
brandBadge.Position = UDim2.new(0.5, 0, 0.5, 0)
brandBadge.Size = UDim2.new(0, 34, 0, 34)
brandBadge.BackgroundColor3 = Color3.fromRGB(100, 70, 235)
brandBadge.BorderSizePixel = 0
brandBadge.Parent = brandTile

local brandBadgeCorner = Instance.new("UICorner")
brandBadgeCorner.CornerRadius = UDim.new(0, 11)
brandBadgeCorner.Parent = brandBadge

local brandBadgeGrad = Instance.new("UIGradient")
brandBadgeGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(168, 86, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(78, 216, 255)),
})
brandBadgeGrad.Rotation = 32
brandBadgeGrad.Parent = brandBadge

local brandBadgeStroke = Instance.new("UIStroke")
brandBadgeStroke.Color = Color3.fromRGB(140, 220, 255)
brandBadgeStroke.Thickness = 1
brandBadgeStroke.Transparency = 0.25
brandBadgeStroke.Parent = brandBadge

local brandV = Instance.new("TextLabel")
brandV.Name = "BrandV"
brandV.BackgroundTransparency = 1
brandV.Size = UDim2.new(1, 0, 1, 0)
brandV.Text = "V"
brandV.TextColor3 = Color3.fromRGB(229, 236, 255)
brandV.Font = Enum.Font.GothamBold
brandV.TextSize = 22
brandV.Parent = brandBadge

local titleStack = Instance.new("Frame")
titleStack.Name = "TitleStack"
titleStack.BackgroundTransparency = 1
titleStack.Size = UDim2.new(1, -186, 1, 0)
titleStack.LayoutOrder = 2
titleStack.ZIndex = 11
titleStack.Parent = headerContent

local titleStackLayout = Instance.new("UIListLayout")
titleStackLayout.FillDirection = Enum.FillDirection.Vertical
titleStackLayout.SortOrder = Enum.SortOrder.LayoutOrder
titleStackLayout.Padding = UDim.new(0, 1)
titleStackLayout.VerticalAlignment = Enum.VerticalAlignment.Center
titleStackLayout.Parent = titleStack

local title = Instance.new("TextLabel")
title.Text = "VibeCoder"
title.Size = UDim2.new(1, 0, 0, 22)
title.BackgroundTransparency = 1
title.TextColor3 = THEME.Text
title.Font = Enum.Font.SourceSansBold
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.LayoutOrder = 1
title.ZIndex = 11
title.Parent = titleStack

local subtitle = Instance.new("TextLabel")
subtitle.Text = "ROBLOX AI BUILDER"
subtitle.Size = UDim2.new(1, 0, 0, 16)
subtitle.BackgroundTransparency = 1
subtitle.TextColor3 = THEME.Text
subtitle.TextTransparency = 0.35
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 11
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.LayoutOrder = 2
subtitle.ZIndex = 11
subtitle.Parent = titleStack

local headerFill = Instance.new("Frame")
headerFill.Name = "HeaderFill"
headerFill.BackgroundTransparency = 1
headerFill.Size = UDim2.new(1, 0, 1, 0)
headerFill.LayoutOrder = 3
headerFill.Parent = headerContent

local statusPill = Instance.new("TextLabel")
statusPill.Name = "StatusPill"
statusPill.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
statusPill.BorderSizePixel = 0
statusPill.Size = UDim2.new(0, 86, 0, 22)
statusPill.Position = UDim2.new(0, 0, 0, 0)
statusPill.Text = "READY"
statusPill.TextColor3 = THEME.Text
statusPill.TextTransparency = 0.15
statusPill.Font = Enum.Font.SourceSansSemibold
statusPill.TextSize = 12
statusPill.ZIndex = 12
statusPill.LayoutOrder = 4
statusPill.Parent = headerContent
statusPill.Visible = false

local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 999)
statusCorner.Parent = statusPill

local statusStroke = Instance.new("UIStroke")
statusStroke.Color = THEME.Border
statusStroke.Thickness = 1
statusStroke.Transparency = 0.4
statusStroke.Parent = statusPill

local promptPanel = addPanel(rootScroll, 0)
promptPanel.LayoutOrder = 1
promptPanel.AutomaticSize = Enum.AutomaticSize.Y

local promptLayout = Instance.new("UIListLayout")
promptLayout.FillDirection = Enum.FillDirection.Vertical
promptLayout.SortOrder = Enum.SortOrder.LayoutOrder
promptLayout.Padding = UDim.new(0, 6)
promptLayout.Parent = promptPanel

addSectionLabel(promptPanel, "Prompt").LayoutOrder = 1

local promptBox = Instance.new("TextBox")
promptBox.PlaceholderText = "Describe your game"
promptBox.Text = ""
promptBox.Size = UDim2.new(1, 0, 0, 72)
promptBox.Position = UDim2.new(0, 0, 0, 0)
promptBox.BackgroundColor3 = THEME.Surface
promptBox.TextColor3 = THEME.Text
promptBox.ClearTextOnFocus = false
promptBox.TextWrapped = true
promptBox.TextXAlignment = Enum.TextXAlignment.Left
promptBox.TextYAlignment = Enum.TextYAlignment.Top
promptBox.Font = Enum.Font.SourceSans
promptBox.TextSize = 14
promptBox.LayoutOrder = 2

promptBox.MultiLine = true

local promptPadding = Instance.new("UIPadding")
promptPadding.PaddingTop = UDim.new(0, 8)
promptPadding.PaddingBottom = UDim.new(0, 8)
promptPadding.PaddingLeft = UDim.new(0, 8)
promptPadding.PaddingRight = UDim.new(0, 8)
promptPadding.Parent = promptBox

local promptStroke = Instance.new("UIStroke")
promptStroke.Color = THEME.Border
promptStroke.Thickness = 1
promptStroke.Transparency = 0.35
promptStroke.Parent = promptBox

local promptCorner = Instance.new("UICorner")
promptCorner.CornerRadius = UDim.new(0, 8)
promptCorner.Parent = promptBox

promptBox.Focused:Connect(function()
	promptStroke.Color = THEME.Primary
	promptStroke.Transparency = 0.15
end)
promptBox.FocusLost:Connect(function()
	promptStroke.Color = THEME.Border
	promptStroke.Transparency = 0.35
end)

promptBox.Parent = promptPanel

local actionsPanel = addPanel(rootScroll, 0)
actionsPanel.LayoutOrder = 2
actionsPanel.AutomaticSize = Enum.AutomaticSize.Y

local actionsLayout = Instance.new("UIListLayout")
actionsLayout.FillDirection = Enum.FillDirection.Vertical
actionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
actionsLayout.Padding = UDim.new(0, 4)
actionsLayout.Parent = actionsPanel

addSectionLabel(actionsPanel, "Actions").LayoutOrder = 1

local generateBtn = Instance.new("TextButton")
generateBtn.Text = "Generate"
generateBtn.Size = UDim2.new(1, 0, 0, 36)
generateBtn.Position = UDim2.new(0, 0, 0, 0)
generateBtn.LayoutOrder = 2
styleButton(generateBtn, THEME.Primary)
generateBtn.TextSize = 15
generateBtn.TextColor3 = Color3.fromRGB(16, 50, 92)

do
	-- subtle "premium" sheen on primary button (still minimal)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, brighten(THEME.Primary, 0.95)),
		ColorSequenceKeypoint.new(1, brighten(THEME.Primary2, 0.95)),
	})
	g.Rotation = 0
	g.Parent = generateBtn

	local s = generateBtn:FindFirstChildOfClass("UIStroke")
	if s then
		s.Color = THEME.Primary2
		s.Transparency = 0.25
	end
end

local secondaryRow = Instance.new("Frame")
secondaryRow.BackgroundTransparency = 1
secondaryRow.Size = UDim2.new(1, 0, 0, 36)
secondaryRow.LayoutOrder = 3
secondaryRow.Parent = actionsPanel
secondaryRow.Visible = false

local secondaryLayout = Instance.new("UIListLayout")
secondaryLayout.FillDirection = Enum.FillDirection.Horizontal
secondaryLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
secondaryLayout.SortOrder = Enum.SortOrder.LayoutOrder
secondaryLayout.Padding = UDim.new(0, 8)
secondaryLayout.Parent = secondaryRow

generateBtn.Parent = actionsPanel

local refineBtn = Instance.new("TextButton")
refineBtn.Text = "Refine"
refineBtn.Size = UDim2.new(0, 0, 0, 36)
refineBtn.Position = UDim2.new(0, 0, 0, 0)
refineBtn.LayoutOrder = 1
styleButton(refineBtn, Color3.fromRGB(33, 40, 64))
refineBtn.Parent = actionsPanel

local planBtn = Instance.new("TextButton")
planBtn.Text = "Plan"
planBtn.Size = UDim2.new(0.5, -4, 0, 30)
planBtn.Position = UDim2.new(0, 0, 0, 0)
planBtn.LayoutOrder = 2
styleButton(planBtn, THEME.Panel)
planBtn.Visible = false
planBtn.Active = false

local controlRow = Instance.new("Frame")
controlRow.BackgroundTransparency = 1
controlRow.Size = UDim2.new(1, 0, 0, 36)
controlRow.LayoutOrder = 4
controlRow.Parent = actionsPanel

local controlLayout = Instance.new("UIListLayout")
controlLayout.FillDirection = Enum.FillDirection.Horizontal
controlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
controlLayout.SortOrder = Enum.SortOrder.LayoutOrder
controlLayout.Padding = UDim.new(0, 8)
controlLayout.HorizontalFlex = Enum.UIFlexAlignment.Fill
controlLayout.Parent = controlRow

refineBtn.Parent = controlRow

local controlLabel = Instance.new("TextLabel")
controlLabel.BackgroundTransparency = 1
controlLabel.Size = UDim2.new(1, 0, 0, 14)
controlLabel.Text = ""
controlLabel.LayoutOrder = 5
controlLabel.Parent = actionsPanel

local clearBtn = Instance.new("TextButton")
clearBtn.Text = "Clear Build"
clearBtn.Size = UDim2.new(0, 0, 0, 36)
clearBtn.Position = UDim2.new(0, 0, 0, 0)
clearBtn.LayoutOrder = 4
styleButton(clearBtn, Color3.fromRGB(92, 32, 32)) -- dark red
do
	local s = clearBtn:FindFirstChildOfClass("UIStroke")
	if s then
		s.Color = brighten(THEME.Danger, 1.1)
		s.Transparency = 0.35
	end
end
clearBtn.Parent = controlRow

local stopBtn = Instance.new("TextButton")
stopBtn.Text = "Stop"
stopBtn.Size = UDim2.new(0, 0, 0, 36)
stopBtn.Position = UDim2.new(0, 0, 0, 0)
stopBtn.LayoutOrder = 2
styleButton(stopBtn, Color3.fromRGB(33, 40, 64))
stopBtn.Parent = controlRow

local historyRow = Instance.new("Frame")
historyRow.BackgroundTransparency = 1
historyRow.Size = UDim2.new(1, 0, 0, 0)
historyRow.LayoutOrder = 6
historyRow.Parent = actionsPanel
historyRow.Visible = false

local historyLayout = Instance.new("UIListLayout")
historyLayout.FillDirection = Enum.FillDirection.Horizontal
historyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
historyLayout.SortOrder = Enum.SortOrder.LayoutOrder
historyLayout.Padding = UDim.new(0, 8)
historyLayout.Parent = historyRow

local undoBtn = Instance.new("TextButton")
undoBtn.Text = "Undo"
undoBtn.Size = UDim2.new(0, 0, 0, 36)
undoBtn.Position = UDim2.new(0, 0, 0, 0)
undoBtn.LayoutOrder = 1
styleButton(undoBtn, Color3.fromRGB(33, 40, 64))
undoBtn.Parent = controlRow

local redoBtn = Instance.new("TextButton")
redoBtn.Text = "Redo"
redoBtn.Size = UDim2.new(0.5, -4, 0, 28)
redoBtn.Position = UDim2.new(0, 0, 0, 0)
redoBtn.LayoutOrder = 2
styleButton(redoBtn, THEME.Panel)
redoBtn.Visible = false
redoBtn.Active = false

local hybridPanel = addPanel(rootScroll, 0)
hybridPanel.LayoutOrder = 3
hybridPanel.AutomaticSize = Enum.AutomaticSize.Y

local hybridLayout = Instance.new("UIListLayout")
hybridLayout.FillDirection = Enum.FillDirection.Vertical
hybridLayout.SortOrder = Enum.SortOrder.LayoutOrder
hybridLayout.Padding = UDim.new(0, 6)
hybridLayout.Parent = hybridPanel

addSectionLabel(hybridPanel, "Hybrid templates + AI").LayoutOrder = 1

local hybridInfoLabel = Instance.new("TextLabel")
hybridInfoLabel.BackgroundTransparency = 1
hybridInfoLabel.Size = UDim2.new(1, 0, 0, 36)
hybridInfoLabel.Text = "Using templates: — (run Generate Game)"
hybridInfoLabel.TextColor3 = THEME.Muted
hybridInfoLabel.TextWrapped = true
hybridInfoLabel.Font = Enum.Font.SourceSans
hybridInfoLabel.TextSize = 12
hybridInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
hybridInfoLabel.LayoutOrder = 2
hybridInfoLabel.Parent = hybridPanel

local hybridRow1 = Instance.new("Frame")
hybridRow1.BackgroundTransparency = 1
hybridRow1.Size = UDim2.new(1, 0, 0, 36)
hybridRow1.LayoutOrder = 3
hybridRow1.Parent = hybridPanel

local hybridRow1Layout = Instance.new("UIListLayout")
hybridRow1Layout.FillDirection = Enum.FillDirection.Horizontal
hybridRow1Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
hybridRow1Layout.SortOrder = Enum.SortOrder.LayoutOrder
hybridRow1Layout.Padding = UDim.new(0, 8)
hybridRow1Layout.HorizontalFlex = Enum.UIFlexAlignment.Fill
hybridRow1Layout.Parent = hybridRow1

local hybridGenerateBtn = Instance.new("TextButton")
hybridGenerateBtn.Text = "Generate Game"
hybridGenerateBtn.Size = UDim2.new(0, 0, 0, 36)
hybridGenerateBtn.LayoutOrder = 1
styleButton(hybridGenerateBtn, Color3.fromRGB(59, 130, 246))
hybridGenerateBtn.TextColor3 = Color3.fromRGB(240, 248, 255)
hybridGenerateBtn.Parent = hybridRow1

local hybridRefineBtn = Instance.new("TextButton")
hybridRefineBtn.Text = "Refine Game"
hybridRefineBtn.Size = UDim2.new(0, 0, 0, 36)
hybridRefineBtn.LayoutOrder = 2
styleButton(hybridRefineBtn, Color3.fromRGB(33, 40, 64))
hybridRefineBtn.Parent = hybridRow1

local hybridPipelineBtn = Instance.new("TextButton")
hybridPipelineBtn.Text = "Full pipeline"
hybridPipelineBtn.Size = UDim2.new(0, 0, 0, 36)
hybridPipelineBtn.LayoutOrder = 3
styleButton(hybridPipelineBtn, Color3.fromRGB(28, 95, 78))
hybridPipelineBtn.TextColor3 = Color3.fromRGB(220, 255, 245)
hybridPipelineBtn.Parent = hybridRow1

local hybridRow2 = Instance.new("Frame")
hybridRow2.BackgroundTransparency = 1
hybridRow2.Size = UDim2.new(1, 0, 0, 36)
hybridRow2.LayoutOrder = 4
hybridRow2.Parent = hybridPanel

local hybridRow2Layout = Instance.new("UIListLayout")
hybridRow2Layout.FillDirection = Enum.FillDirection.Horizontal
hybridRow2Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
hybridRow2Layout.SortOrder = Enum.SortOrder.LayoutOrder
hybridRow2Layout.Padding = UDim.new(0, 8)
hybridRow2Layout.HorizontalFlex = Enum.UIFlexAlignment.Fill
hybridRow2Layout.Parent = hybridRow2

local hybridAiBoostBtn = Instance.new("TextButton")
hybridAiBoostBtn.Text = "AI boost: OFF"
hybridAiBoostBtn.Size = UDim2.new(0, 0, 0, 36)
hybridAiBoostBtn.LayoutOrder = 1
styleButton(hybridAiBoostBtn, THEME.Panel)
hybridAiBoostBtn.Parent = hybridRow2

local hybridForceAiOnlyBtn = Instance.new("TextButton")
hybridForceAiOnlyBtn.Text = "AI-only: OFF"
hybridForceAiOnlyBtn.Size = UDim2.new(0, 0, 0, 36)
hybridForceAiOnlyBtn.LayoutOrder = 2
styleButton(hybridForceAiOnlyBtn, THEME.Panel)
hybridForceAiOnlyBtn.Parent = hybridRow2

local hybridClearBtn = Instance.new("TextButton")
hybridClearBtn.Text = "Clear hybrid"
hybridClearBtn.Size = UDim2.new(0, 0, 0, 36)
hybridClearBtn.LayoutOrder = 3
styleButton(hybridClearBtn, Color3.fromRGB(55, 36, 48))
hybridClearBtn.Parent = hybridRow2

local hybridRow3 = Instance.new("Frame")
hybridRow3.BackgroundTransparency = 1
hybridRow3.Size = UDim2.new(1, 0, 0, 36)
hybridRow3.LayoutOrder = 5
hybridRow3.Parent = hybridPanel

local hybridRow3Layout = Instance.new("UIListLayout")
hybridRow3Layout.FillDirection = Enum.FillDirection.Horizontal
hybridRow3Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
hybridRow3Layout.SortOrder = Enum.SortOrder.LayoutOrder
hybridRow3Layout.Padding = UDim.new(0, 8)
hybridRow3Layout.HorizontalFlex = Enum.UIFlexAlignment.Fill
hybridRow3Layout.Parent = hybridRow3

local planGameBtn = Instance.new("TextButton")
planGameBtn.Text = "Plan game"
planGameBtn.Size = UDim2.new(0, 0, 0, 36)
planGameBtn.LayoutOrder = 1
styleButton(planGameBtn, Color3.fromRGB(45, 90, 72))
planGameBtn.Parent = hybridRow3

local executePlanBtn = Instance.new("TextButton")
executePlanBtn.Text = "Run plan"
executePlanBtn.Size = UDim2.new(0, 0, 0, 36)
executePlanBtn.LayoutOrder = 2
styleButton(executePlanBtn, Color3.fromRGB(80, 55, 120))
executePlanBtn.Parent = hybridRow3

local toolboxPanel = addPanel(rootScroll, 0)
toolboxPanel.LayoutOrder = 4
toolboxPanel.AutomaticSize = Enum.AutomaticSize.Y

local assetStyle = "realistic"

local toolboxLayout = Instance.new("UIListLayout")
toolboxLayout.FillDirection = Enum.FillDirection.Vertical
toolboxLayout.SortOrder = Enum.SortOrder.LayoutOrder
toolboxLayout.Padding = UDim.new(0, 6)
toolboxLayout.Parent = toolboxPanel

addSectionLabel(toolboxPanel, "Toolbox assets").LayoutOrder = 1

local assetSceneBox = Instance.new("TextBox")
assetSceneBox.PlaceholderText = "Describe props to fetch (e.g. modern house, sofa, trees)"
assetSceneBox.Text = ""
assetSceneBox.Size = UDim2.new(1, 0, 0, 56)
assetSceneBox.BackgroundColor3 = THEME.Surface
assetSceneBox.TextColor3 = THEME.Text
assetSceneBox.ClearTextOnFocus = false
assetSceneBox.TextWrapped = true
assetSceneBox.TextXAlignment = Enum.TextXAlignment.Left
assetSceneBox.TextYAlignment = Enum.TextYAlignment.Top
assetSceneBox.Font = Enum.Font.SourceSans
assetSceneBox.TextSize = 13
assetSceneBox.LayoutOrder = 2
assetSceneBox.MultiLine = true

local assetScenePadding = Instance.new("UIPadding")
assetScenePadding.PaddingTop = UDim.new(0, 6)
assetScenePadding.PaddingBottom = UDim.new(0, 6)
assetScenePadding.PaddingLeft = UDim.new(0, 8)
assetScenePadding.PaddingRight = UDim.new(0, 8)
assetScenePadding.Parent = assetSceneBox

local assetSceneStroke = Instance.new("UIStroke")
assetSceneStroke.Color = THEME.Border
assetSceneStroke.Thickness = 1
assetSceneStroke.Transparency = 0.35
assetSceneStroke.Parent = assetSceneBox

local assetSceneCorner = Instance.new("UICorner")
assetSceneCorner.CornerRadius = UDim.new(0, 8)
assetSceneCorner.Parent = assetSceneBox

assetSceneBox.Parent = toolboxPanel

local toolboxControlRow = Instance.new("Frame")
toolboxControlRow.BackgroundTransparency = 1
toolboxControlRow.Size = UDim2.new(1, 0, 0, 36)
toolboxControlRow.LayoutOrder = 3
toolboxControlRow.Parent = toolboxPanel

local toolboxControlLayout = Instance.new("UIListLayout")
toolboxControlLayout.FillDirection = Enum.FillDirection.Horizontal
toolboxControlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
toolboxControlLayout.SortOrder = Enum.SortOrder.LayoutOrder
toolboxControlLayout.Padding = UDim.new(0, 8)
toolboxControlLayout.HorizontalFlex = Enum.UIFlexAlignment.Fill
toolboxControlLayout.Parent = toolboxControlRow

local styleToggleBtn = Instance.new("TextButton")
styleToggleBtn.Text = "Style: Realistic"
styleToggleBtn.Size = UDim2.new(0, 0, 0, 36)
styleToggleBtn.LayoutOrder = 1
styleButton(styleToggleBtn, Color3.fromRGB(33, 40, 64))
styleToggleBtn.Parent = toolboxControlRow

local insertAssetsBtn = Instance.new("TextButton")
insertAssetsBtn.Text = "Insert assets"
insertAssetsBtn.Size = UDim2.new(0, 0, 0, 36)
insertAssetsBtn.LayoutOrder = 2
styleButton(insertAssetsBtn, THEME.Primary2)
insertAssetsBtn.TextColor3 = Color3.fromRGB(16, 50, 92)
insertAssetsBtn.Parent = toolboxControlRow

local regenerateAssetsBtn = Instance.new("TextButton")
regenerateAssetsBtn.Text = "More picks"
regenerateAssetsBtn.Size = UDim2.new(0, 0, 0, 36)
regenerateAssetsBtn.LayoutOrder = 3
styleButton(regenerateAssetsBtn, THEME.Panel)
regenerateAssetsBtn.Parent = toolboxControlRow

local outputPanel = addPanel(rootScroll, 0)
outputPanel.LayoutOrder = 5
outputPanel.AutomaticSize = Enum.AutomaticSize.Y
outputPanel.Visible = true

local outputLayout = Instance.new("UIListLayout")
outputLayout.FillDirection = Enum.FillDirection.Vertical
outputLayout.SortOrder = Enum.SortOrder.LayoutOrder
outputLayout.Padding = UDim.new(0, 6)
outputLayout.Parent = outputPanel

local outputLabel = addSectionLabel(outputPanel, "Output")
outputLabel.LayoutOrder = 1
outputLabel.Visible = false

local outputInner = Instance.new("Frame")
outputInner.BackgroundTransparency = 1
outputInner.Size = UDim2.new(1, 0, 1, 0)
outputInner.LayoutOrder = 2
outputInner.Parent = outputPanel

local outputInnerLayout = Instance.new("UIListLayout")
outputInnerLayout.FillDirection = Enum.FillDirection.Vertical
outputInnerLayout.SortOrder = Enum.SortOrder.LayoutOrder
outputInnerLayout.Padding = UDim.new(0, 6)
outputInnerLayout.Parent = outputInner

local planScroll = Instance.new("ScrollingFrame")
planScroll.Name = "PlanScroll"
planScroll.Size = UDim2.new(1, 0, 0, 120)
planScroll.Position = UDim2.new(0, 0, 0, 0)
planScroll.BackgroundColor3 = THEME.Surface
planScroll.BorderSizePixel = 0
planScroll.ScrollBarThickness = 8
planScroll.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 90)
planScroll.ScrollBarImageTransparency = 0.2
planScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
planScroll.Active = true
planScroll.ScrollingEnabled = true
planScroll.LayoutOrder = 1
planScroll.Visible = false
planScroll.Size = UDim2.new(1, 0, 0, 0)

local planCorner = Instance.new("UICorner")
planCorner.CornerRadius = UDim.new(0, 8)
planCorner.Parent = planScroll

local planStroke = Instance.new("UIStroke")
planStroke.Color = THEME.Border
planStroke.Thickness = 1
planStroke.Transparency = 0.35
planStroke.Parent = planScroll

planScroll.Parent = outputInner

local planBox = Instance.new("TextLabel")
planBox.Name = "PlanLabel"
planBox.Text = "Plan will appear here..."
planBox.Size = UDim2.new(1, -12, 0, 0)
planBox.Position = UDim2.new(0, 6, 0, 6)
planBox.BackgroundTransparency = 1
planBox.TextColor3 = Color3.fromRGB(237, 237, 237)
planBox.TextTransparency = 0.15
planBox.TextWrapped = true
planBox.TextXAlignment = Enum.TextXAlignment.Left
planBox.TextYAlignment = Enum.TextYAlignment.Top
planBox.Font = Enum.Font.SourceSans
planBox.TextSize = 14
planBox.AutomaticSize = Enum.AutomaticSize.Y
planBox.Parent = planScroll

local logScroll = Instance.new("ScrollingFrame")
logScroll.Size = UDim2.new(1, 0, 0, 300)
logScroll.Position = UDim2.new(0, 0, 0, 0)
logScroll.BackgroundColor3 = THEME.Surface
logScroll.BorderSizePixel = 0
logScroll.ScrollBarThickness = 8
logScroll.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 90)
logScroll.ScrollBarImageTransparency = 0.2
logScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
logScroll.Active = true
logScroll.ScrollingEnabled = true
logScroll.LayoutOrder = 1

local logCorner = Instance.new("UICorner")
logCorner.CornerRadius = UDim.new(0, 8)
logCorner.Parent = logScroll

local logStroke = Instance.new("UIStroke")
logStroke.Color = THEME.Border
logStroke.Thickness = 1
logStroke.Transparency = 0.35
logStroke.Parent = logScroll

logScroll.Parent = outputInner

local logBox = Instance.new("TextLabel")
logBox.Text = "Logs..."
logBox.Size = UDim2.new(1, -12, 0, 0)
logBox.Position = UDim2.new(0, 6, 0, 6)
logBox.BackgroundTransparency = 1
logBox.TextColor3 = Color3.fromRGB(237, 237, 237)
logBox.TextTransparency = 0.05
logBox.TextWrapped = true
logBox.TextXAlignment = Enum.TextXAlignment.Left
logBox.TextYAlignment = Enum.TextYAlignment.Top
logBox.Font = Enum.Font.Code
logBox.TextSize = 13
logBox.AutomaticSize = Enum.AutomaticSize.Y
logBox.Parent = logScroll

local HttpService = game:GetService("HttpService")
local InsertService = game:GetService("InsertService")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local StarterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")

local ROOT_FOLDER_NAME = "AI_Build"
local GENERATED_GAME_NAME = "GeneratedGame"

local API_BASE = "https://assistant-3alw.onrender.com"

local hybridAiBoost = false
local hybridForceAiOnly = false
local hybridLastMode = ""
local hybridLastConfidence = 0
local hybridLastTemplates = {}
local hybridLastFeatures = {}
local hybridLastPrompt = ""
local hybridScriptNames = {}
local lastStructuredGamePlan = nil
local lastPlanPrompt = ""

local isBusy = false
local lastPrompt = ""
local lastStructuredBuild = nil
local cancelToken = 0
local undoStack = {}
local redoStack = {}

local logLines = {}
local function refreshLogScroll()
	task.defer(function()
		logScroll.CanvasSize = UDim2.new(0, 0, 0, logBox.TextBounds.Y + 16)
		logScroll.CanvasPosition = Vector2.new(
			0,
			math.max(0, logScroll.CanvasSize.Y.Offset - logScroll.AbsoluteWindowSize.Y)
		)
	end)
end

local function refreshPlanScroll()
	task.defer(function()
		planScroll.CanvasSize = UDim2.new(0, 0, 0, planBox.TextBounds.Y + 16)
	end)
end

local function setLog(text)
	logLines = { tostring(text or "") }
	logBox.Text = logLines[1]
	refreshLogScroll()
end

local function appendLog(line)
	table.insert(logLines, tostring(line or ""))
	logBox.Text = table.concat(logLines, "\n")
	refreshLogScroll()
end

local function setButtonsEnabled(enabled)
	local function setVisual(btn, isActive)
		btn.Active = isActive

		local bc = btn:GetAttribute("BaseColor")
		if typeof(bc) == "Color3" then
			btn.BackgroundColor3 = isActive and bc or brighten(bc, 0.82)
		end

		btn.TextTransparency = isActive and 0 or 0.25
	end

	if enabled then
		statusPill.Text = "READY"
		statusPill.BackgroundColor3 = THEME.Surface
		statusStroke.Color = THEME.Border
	else
		statusPill.Text = "WORKING"
		statusPill.BackgroundColor3 = brighten(THEME.Primary, 0.35)
		statusStroke.Color = THEME.Primary
	end

	setVisual(generateBtn, enabled)
	setVisual(refineBtn, enabled)
	setVisual(planBtn, enabled)
	setVisual(clearBtn, enabled)
	setVisual(stopBtn, not enabled)

	setVisual(undoBtn, enabled and (#undoStack > 0))
	setVisual(redoBtn, enabled and (#redoStack > 0))

	setVisual(styleToggleBtn, enabled)
	setVisual(insertAssetsBtn, enabled)
	setVisual(regenerateAssetsBtn, enabled)

	setVisual(hybridGenerateBtn, enabled)
	setVisual(hybridRefineBtn, enabled)
	setVisual(hybridPipelineBtn, enabled)
	setVisual(hybridAiBoostBtn, enabled)
	setVisual(hybridForceAiOnlyBtn, enabled)
	setVisual(hybridClearBtn, enabled)
	setVisual(planGameBtn, enabled)
	setVisual(executePlanBtn, enabled and (lastStructuredGamePlan ~= nil))
end

local function inPlayClientMode()
	return RunService:IsRunning()
end

local function startProgress(prefix)
	local alive = true
	task.spawn(function()
		local dots = 0
		while alive do
			dots = (dots % 3) + 1
			setLog(prefix .. string.rep(".", dots))
			task.wait(0.35)
		end
	end)
	return function()
		alive = false
	end
end

local function postJson(url, body)
	local ok, responseOrError = pcall(function()
		return HttpService:PostAsync(url, HttpService:JSONEncode(body), Enum.HttpContentType.ApplicationJson)
	end)
	if not ok then
		return nil, tostring(responseOrError)
	end
	local decodeOk, dataOrError = pcall(function()
		return HttpService:JSONDecode(responseOrError)
	end)
	if not decodeOk then
		return nil, "Invalid JSON response: " .. tostring(dataOrError)
	end
	return dataOrError, nil
end

local function requestWithTimeout(url, body, timeoutSeconds)
	local myToken = cancelToken
	local done = false
	local timedOut = false
	local resultData = nil
	local resultErr = nil

	task.spawn(function()
		local data, err = postJson(url, body)
		if cancelToken ~= myToken then
			return
		end
		if timedOut then
			return
		end
		done = true
		resultData = data
		resultErr = err
	end)

	task.delay(timeoutSeconds, function()
		if cancelToken ~= myToken then
			return
		end
		if done then
			return
		end
		timedOut = true
		resultErr = "Request timed out (Render may be cold-starting). Try again."
	end)

	-- Wait until either done or timed out
	while not done and not timedOut do
		if cancelToken ~= myToken then
			return nil, "Cancelled"
		end
		task.wait(0.05)
	end

	return resultData, resultErr
end

stopBtn.MouseButton1Click:Connect(function()
	if not isBusy then
		return
	end
	cancelToken += 1
	isBusy = false
	setButtonsEnabled(true)
	setLog("Cancelled.")
end)

local function getOrCreateFolder(parent, name)
	local f = parent:FindFirstChild(name)
	if f and f:IsA("Folder") then
		return f
	end
	f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function ensureAiFolders()
	return {
		workspace = getOrCreateFolder(workspace, ROOT_FOLDER_NAME),
		server = getOrCreateFolder(ServerScriptService, ROOT_FOLDER_NAME),
		gui = getOrCreateFolder(StarterGui, ROOT_FOLDER_NAME),
		starterPlayerScripts = getOrCreateFolder(StarterPlayerScripts, ROOT_FOLDER_NAME),
	}
end

local function ensureToolboxFolder()
	local root = getOrCreateFolder(workspace, ROOT_FOLDER_NAME)
	return getOrCreateFolder(root, "ToolboxAssets")
end

local function stripImportedScripts(rootInst)
	local kill = {}
	for _, d in ipairs(rootInst:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
			table.insert(kill, d)
		end
	end
	for _, d in ipairs(kill) do
		d:Destroy()
	end
end

local function layoutInsertedModel(model, index)
	local spacing = 16
	local cols = 4
	local row = math.floor((index - 1) / cols)
	local col = (index - 1) % cols
	local cf = CFrame.new(col * spacing, 0, row * spacing)
	if model:IsA("Model") then
		local ok = pcall(function()
			if model.PrimaryPart then
				model:SetPrimaryPartCFrame(cf)
			else
				model:PivotTo(cf)
			end
		end)
		if not ok then
			pcall(function()
				model:PivotTo(cf)
			end)
		end
	elseif model:IsA("BasePart") then
		model.CFrame = cf
	end
end

local function insertAssetsFromServerList(assetList)
	if type(assetList) ~= "table" then
		return 0, "No asset list"
	end
	local folder = ensureToolboxFolder()
	local placed = 0
	for _, aid in ipairs(assetList) do
		local id = nil
		if type(aid) == "number" and aid > 0 then
			id = aid
		elseif type(aid) == "string" then
			id = tonumber(aid)
		end
		if id then
			local okPack, pack = pcall(function()
				return InsertService:LoadAsset(id)
			end)
			if okPack and pack then
				local child = pack:GetChildren()[1]
				if child then
					stripImportedScripts(child)
					child.Name = "Toolbox_" .. tostring(id)
					child.Parent = folder
					placed += 1
					layoutInsertedModel(child, placed)
				else
					appendLog(("Empty package for asset %s"):format(tostring(id)))
				end
				pack:Destroy()
			else
				appendLog(("LoadAsset failed for %s: %s"):format(tostring(id), tostring(pack)))
			end
		end
	end
	return placed, nil
end

local function tearDownHybridRuntime()
	local w = workspace:FindFirstChild(GENERATED_GAME_NAME)
	if w then
		pcall(function()
			w:Destroy()
		end)
	end
	local ssf = ServerScriptService:FindFirstChild(GENERATED_GAME_NAME)
	if ssf then
		pcall(function()
			ssf:Destroy()
		end)
	end
	local sps = StarterPlayerScripts:FindFirstChild(GENERATED_GAME_NAME)
	if sps then
		pcall(function()
			sps:Destroy()
		end)
	end
end

local function ensureWorkspaceGeneratedGame()
	local root = getOrCreateFolder(workspace, GENERATED_GAME_NAME)
	getOrCreateFolder(root, "Map")
	getOrCreateFolder(root, "Assets")
	getOrCreateFolder(root, "NPCs")
	getOrCreateFolder(root, "Scripts")
	return root
end

local function injectHybridScript(spec)
	if type(spec) ~= "table" then
		return false
	end
	local name = spec.name
	local parentName = spec.parent
	local className = spec.className
	local source = spec.source
	if type(name) ~= "string" or type(source) ~= "string" then
		return false
	end
	if parentName ~= "ServerScriptService" and parentName ~= "StarterPlayerScripts" then
		return false
	end
	if className ~= "Script" and className ~= "LocalScript" then
		return false
	end
	local trusted = string.sub(name, 1, 7) == "Hybrid_"
		or string.sub(name, 1, 10) == "HybridExt_"
		or string.sub(name, 1, 9) == "HybridAI_"
	if not trusted then
		return false
	end
	local service = (parentName == "ServerScriptService") and ServerScriptService or StarterPlayerScripts
	local folder = getOrCreateFolder(service, GENERATED_GAME_NAME)
	local existing = folder:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local s = Instance.new(className)
	s.Name = name
	s.Source = source
	s.Parent = folder
	return true
end

local function insertMergedAssetsIntoGenerated(assetList)
	if type(assetList) ~= "table" then
		return 0
	end
	ensureWorkspaceGeneratedGame()
	local root = workspace:FindFirstChild(GENERATED_GAME_NAME)
	local assetsFolder = root and root:FindFirstChild("Assets")
	if not assetsFolder then
		return 0
	end
	local placed = 0
	for _, aid in ipairs(assetList) do
		local id = nil
		if type(aid) == "number" and aid > 0 then
			id = aid
		elseif type(aid) == "string" then
			id = tonumber(aid)
		end
		if id then
			local okPack, pack = pcall(function()
				return InsertService:LoadAsset(id)
			end)
			if okPack and pack then
				local child = pack:GetChildren()[1]
				if child then
					stripImportedScripts(child)
					child.Name = "HybridAsset_" .. tostring(id)
					child.Parent = assetsFolder
					placed += 1
					layoutInsertedModel(child, placed)
				else
					appendLog(("Hybrid: empty package for %s"):format(tostring(id)))
				end
				pack:Destroy()
			else
				appendLog(("Hybrid: LoadAsset failed for %s"):format(tostring(id)))
			end
		end
	end
	return placed
end

local function removeHybridScriptsByNames(names)
	if type(names) ~= "table" then
		return
	end
	for _, folder in ipairs({ ServerScriptService:FindFirstChild(GENERATED_GAME_NAME), StarterPlayerScripts:FindFirstChild(GENERATED_GAME_NAME) }) do
		if folder then
			for _, nName in ipairs(names) do
				if type(nName) == "string" then
					local ch = folder:FindFirstChild(nName)
					if ch and string.sub(nName, 1, 10) == "HybridExt_" then
						ch:Destroy()
					end
				end
			end
		end
	end
end

local function capitalizeWord(w)
	if w == "" then
		return w
	end
	return string.upper(string.sub(w, 1, 1)) .. string.sub(w, 2)
end

local function hybridUsingLabelText(templates)
	if type(templates) ~= "table" or #templates == 0 then
		return "Using templates: — (run Generate Game)"
	end
	local parts = {}
	for _, t in ipairs(templates) do
		table.insert(parts, capitalizeWord(tostring(t)))
	end
	return "Using templates: " .. table.concat(parts, " + ")
end

local function hybridInfoFromMode(mode, templates)
	local m = tostring(mode or "")
	if m == "ai-only" then
		return "Using AI full generation mode"
	end
	if m == "template+ai" then
		return hybridUsingLabelText(templates) .. " (partial match — AI layer)"
	end
	return hybridUsingLabelText(templates)
end

local function formatStructuredGamePlan(plan)
	if type(plan) ~= "table" then
		return ""
	end
	local lines = {}
	table.insert(lines, "mode: " .. tostring(plan.mode or "?"))
	if plan.matchTier then
		table.insert(lines, "matchTier: " .. tostring(plan.matchTier))
	end
	if type(plan.reason) == "string" and plan.reason ~= "" then
		table.insert(lines, "reason: " .. plan.reason)
	end
	if type(plan.templates) == "table" and #plan.templates > 0 then
		table.insert(lines, "templates: " .. table.concat(plan.templates, ", "))
	end
	if type(plan.features) == "table" and #plan.features > 0 then
		table.insert(lines, "features: " .. table.concat(plan.features, "; "))
	end
	if type(plan.assets) == "table" and #plan.assets > 0 then
		table.insert(lines, "assets: " .. table.concat(plan.assets, "; "))
	end
	if plan.placement_strategy then
		table.insert(lines, "placement: " .. tostring(plan.placement_strategy))
	end
	if type(plan.script_requirements) == "table" and #plan.script_requirements > 0 then
		table.insert(lines, "script_requirements: " .. table.concat(plan.script_requirements, "; "))
	end
	if type(plan.steps) == "table" and #plan.steps > 0 then
		table.insert(lines, "--- steps ---")
		for i, s in ipairs(plan.steps) do
			table.insert(lines, ("%d. %s"):format(i, tostring(s)))
		end
	end
	return table.concat(lines, "\n")
end

local function applyHybridMerged(merged)
	tearDownHybridRuntime()
	ensureWorkspaceGeneratedGame()
	local scriptOk = 0
	if type(merged) == "table" and type(merged.scripts) == "table" then
		for _, spec in ipairs(merged.scripts) do
			if injectHybridScript(spec) then
				scriptOk += 1
			end
		end
	end
	local assetN = 0
	if type(merged) == "table" and type(merged.assets) == "table" then
		assetN = insertMergedAssetsIntoGenerated(merged.assets)
	end
	return scriptOk, assetN
end

local function rebuildHybridScriptNameList(merged)
	hybridScriptNames = {}
	if type(merged) == "table" and type(merged.scripts) == "table" then
		for _, spec in ipairs(merged.scripts) do
			if type(spec) == "table" and type(spec.name) == "string" then
				table.insert(hybridScriptNames, spec.name)
			end
		end
	end
end

local function appendHybridRefinement(payload)
	if type(payload) ~= "table" then
		return
	end
	if type(payload.removeScriptNames) == "table" then
		removeHybridScriptsByNames(payload.removeScriptNames)
		for _, nName in ipairs(payload.removeScriptNames) do
			for i = #hybridScriptNames, 1, -1 do
				if hybridScriptNames[i] == nName then
					table.remove(hybridScriptNames, i)
				end
			end
		end
	end
	if type(payload.appendScripts) == "table" then
		for _, spec in ipairs(payload.appendScripts) do
			if injectHybridScript(spec) and type(spec.name) == "string" then
				table.insert(hybridScriptNames, spec.name)
			end
		end
	end
	if type(payload.addAssets) == "table" and #payload.addAssets > 0 then
		ensureWorkspaceGeneratedGame()
		local nAdded = insertMergedAssetsIntoGenerated(payload.addAssets)
		appendLog(("Refine: added %d asset(s)"):format(nAdded))
	end
end

local function runGamePlanExecution()
	local plan = lastStructuredGamePlan
	local promptText = lastPlanPrompt
	if not plan or promptText == "" then
		setLog('Run "Plan game" first (no saved plan).')
		return
	end
	if inPlayClientMode() then
		setLog("Run plan works only in Edit mode. Stop Play and try again.")
		return
	end
	if isBusy then
		return
	end
	local myToken = cancelToken
	isBusy = true
	setButtonsEnabled(false)
	setLog("Executing plan steps...")
	task.spawn(function()
		for i, step in ipairs(plan.steps or {}) do
			if cancelToken ~= myToken then
				break
			end
			appendLog(("Step %d: %s"):format(i, tostring(step)))
			task.wait(0.22)
		end
		if cancelToken ~= myToken then
			isBusy = false
			setButtonsEnabled(true)
			return
		end
		appendLog("Importing assets from plan keywords...")
		local assetLine = ""
		if type(plan.assets) == "table" and #plan.assets > 0 then
			assetLine = table.concat(plan.assets, ", ")
		end
		if assetLine ~= "" then
			local dataA, errA = requestWithTimeout(API_BASE .. "/generate-assets", {
				prompt = assetLine,
				style = assetStyle,
				regenerate = false,
				maxAssets = 12,
			}, 40)
			if errA then
				appendLog("Asset import failed: " .. errA)
			elseif type(dataA) == "table" and dataA.success ~= false and type(dataA.assets) == "table" then
				local placedA = insertMergedAssetsIntoGenerated(dataA.assets)
				appendLog(("Placed %d asset(s) into GeneratedGame.Assets"):format(placedA))
			end
		else
			appendLog("No asset list in plan; skipping import.")
		end
		if cancelToken ~= myToken then
			isBusy = false
			setButtonsEnabled(true)
			return
		end
		appendLog("Running hybrid build (templates + scripts)...")
		local data, err = requestWithTimeout(API_BASE .. "/hybrid-generate", {
			prompt = promptText,
			enhance = hybridAiBoost,
			forceAiOnly = hybridForceAiOnly,
		}, 50)
		if cancelToken ~= myToken then
			isBusy = false
			setButtonsEnabled(true)
			return
		end
		if err then
			setLog("Hybrid generate failed: " .. err)
			isBusy = false
			setButtonsEnabled(true)
			return
		end
		if type(data) == "table" and data.success == false then
			setLog("Hybrid generate failed: " .. tostring(data.error))
			isBusy = false
			setButtonsEnabled(true)
			return
		end
		hybridLastPrompt = promptText
		hybridLastMode = tostring(data.mode or "template")
		hybridLastConfidence = tonumber(data.confidence) or tonumber(data.confidencePercent) or 0
		hybridLastTemplates = data.templates or {}
		hybridLastFeatures = data.features or {}
		local merged = data.merged or {}
		local sOk, aN = applyHybridMerged(merged)
		rebuildHybridScriptNameList(merged)
		hybridInfoLabel.Text = hybridInfoFromMode(hybridLastMode, hybridLastTemplates)
		hybridInfoLabel.TextColor3 = THEME.Text
		setLog("Plan execution finished.")
		appendLog(("Scripts injected: %d | Merged asset slots: %d"):format(sOk, aN))
		if type(data.reason) == "string" and data.reason ~= "" then
			appendLog("Classifier: " .. data.reason)
		end
		if data.forcedAiFallback == true then
			appendLog("AI-only fallback: template merge skipped; see classifierRouting.")
		end
		if type(data.message) == "string" and data.message ~= "" then
			appendLog(data.message)
		end
		isBusy = false
		setButtonsEnabled(true)
	end)
end

local function clearGeneratedBuild()
	local removed = 0
	local w = workspace:FindFirstChild(ROOT_FOLDER_NAME)
	if w then
		if pcall(function() w:Destroy() end) then removed += 1 end
	end
	local s = ServerScriptService:FindFirstChild(ROOT_FOLDER_NAME)
	if s then
		if pcall(function() s:Destroy() end) then removed += 1 end
	end
	local g = StarterGui:FindFirstChild(ROOT_FOLDER_NAME)
	if g then
		if pcall(function() g:Destroy() end) then removed += 1 end
	end
	local sps = StarterPlayerScripts:FindFirstChild(ROOT_FOLDER_NAME)
	if sps then
		if pcall(function() sps:Destroy() end) then removed += 1 end
	end
	return removed
end

local ALLOWED_CLASSES = {
	Folder = true,
	Model = true,
	Part = true,
	MeshPart = true,
	SpawnLocation = true,
	PointLight = true,
	BillboardGui = true,
	ScreenGui = true,
	TextLabel = true,
	TextButton = true,
	UICorner = true,
	UIStroke = true,
	UIListLayout = true,
	Script = true,
	LocalScript = true,
	ModuleScript = true,
}

local ALLOWED_PROPERTIES = {
	Name = true,
	Anchored = true,
	CanCollide = true,
	Transparency = true,
	Material = true,
	Color = true,
	BrickColor = true,
	Brightness = true,
	Range = true,
	Size = true,
	Position = true,
	CFrame = true,
	Rotation = true,
	Text = true,
	TextSize = true,
	TextColor3 = true,
	BorderSizePixel = true,
	BackgroundColor3 = true,
	BackgroundTransparency = true,
	Font = true,
	Visible = true,
	Enabled = true,
	ResetOnSpawn = true,
	AlwaysOnTop = true,
	StudsOffset = true,
	StudsOffsetWorldSpace = true,
}

local function toColor3(v)
	if typeof(v) == "Color3" then
		return v
	end
	if type(v) == "string" then
		-- Backend sometimes sends colors in this format: "@{r=1; g=0; b=0}"
		local r, g, b = v:match("@{r=([%-%d%.]+)%s*;%s*g=([%-%d%.]+)%s*;%s*b=([%-%d%.]+)%s*}")
		if r and g and b then
			r, g, b = tonumber(r), tonumber(g), tonumber(b)
			if r and g and b then
				-- If values are 0-1, convert to 0-255
				if r <= 1 and g <= 1 and b <= 1 then
					return Color3.fromRGB(r * 255, g * 255, b * 255)
				end
				return Color3.fromRGB(r, g, b)
			end
		end
	end
	if type(v) == "table" then
		if v.r and v.g and v.b then
			return Color3.new(v.r, v.g, v.b)
		end
		if #v == 3 then
			if v[1] > 1 or v[2] > 1 or v[3] > 1 then
				return Color3.fromRGB(v[1], v[2], v[3])
			end
			return Color3.new(v[1], v[2], v[3])
		end
	end
	return nil
end

local function toVector3(v)
	if typeof(v) == "Vector3" then
		return v
	end
	if type(v) == "string" then
		-- Backend sometimes sends vectors in this format: "@{x=20; y=1; z=20}"
		local x, y, z = v:match("@{x=([%-%d%.]+)%s*;%s*y=([%-%d%.]+)%s*;%s*z=([%-%d%.]+)%s*}")
		if x and y and z then
			x, y, z = tonumber(x), tonumber(y), tonumber(z)
			if x and y and z then
				return Vector3.new(x, y, z)
			end
		end
	end
	if type(v) == "table" and #v == 3 then
		return Vector3.new(v[1], v[2], v[3])
	end
	return nil
end

local function toCFrame(v)
	if typeof(v) == "CFrame" then
		return v
	end
	if type(v) == "table" and #v == 3 then
		return CFrame.new(v[1], v[2], v[3])
	end
	return nil
end

local function resolveServiceParent(parentKey)
	if parentKey == "workspace" then
		return workspace
	elseif parentKey == "ServerScriptService" then
		return ServerScriptService
	elseif parentKey == "StarterGui" then
		return StarterGui
	elseif parentKey == "StarterPlayerScripts" then
		return StarterPlayerScripts
	end
	return nil
end

local function applyStructuredBuild(build)
	if type(build) ~= "table" or type(build.instances) ~= "table" then
		return false, "Invalid build payload"
	end

	-- Track history for Undo/Redo
	if lastStructuredBuild then
		table.insert(undoStack, lastStructuredBuild)
		redoStack = {}
	end

	-- Reset AI_Build folders each apply for deterministic results
	clearGeneratedBuild()
	local folders = ensureAiFolders()

	local created = {}
	local specs = {}
	for _, spec in ipairs(build.instances) do
		if type(spec) == "table" and type(spec.id) == "string" and type(spec.className) == "string" then
			table.insert(specs, spec)
		end
	end

	for _, spec in ipairs(specs) do
		if not ALLOWED_CLASSES[spec.className] then
			return false, "Disallowed class: " .. tostring(spec.className)
		end
		local inst = Instance.new(spec.className)
		if type(spec.name) == "string" and spec.name ~= "" then
			inst.Name = spec.name
		end
		created[spec.id] = inst
	end

	for _, spec in ipairs(specs) do
		local inst = created[spec.id]
		local props = spec.properties
		if type(props) == "table" then
			for k, v in pairs(props) do
				if ALLOWED_PROPERTIES[k] then
					pcall(function()
						if k == "Color" or k == "TextColor3" or k == "BackgroundColor3" then
							local c = toColor3(v)
							if c then inst[k] = c end
						elseif k == "Position" or k == "Size" or k == "Rotation" or k == "StudsOffset" or k == "StudsOffsetWorldSpace" then
							local vec = toVector3(v)
							if vec then inst[k] = vec end
						elseif k == "BrickColor" then
							if type(v) == "string" then
								pcall(function()
									inst[k] = BrickColor.new(v)
								end)
							end
						elseif k == "CFrame" then
							local cf = toCFrame(v)
							if cf then inst.CFrame = cf end
						elseif k == "Material" then
							if type(v) == "string" then
								pcall(function()
									local maybe = Enum.Material[v]
									if maybe then
										inst.Material = maybe
									end
								end)
							end
						else
							inst[k] = v
						end
					end)
				end
			end
		end

		if (inst:IsA("Script") or inst:IsA("LocalScript") or inst:IsA("ModuleScript")) and type(spec.source) == "string" then
			pcall(function()
				inst.Source = spec.source
			end)
		end
	end

	for _, spec in ipairs(specs) do
		local inst = created[spec.id]
		local parent = nil
		if type(spec.parent) == "string" then
			parent = created[spec.parent] or resolveServiceParent(spec.parent)
		end
		if not parent then
			parent = folders.workspace
		end
		if parent == workspace then
			parent = folders.workspace
		elseif parent == ServerScriptService then
			parent = folders.server
		elseif parent == StarterGui then
			parent = folders.gui
		elseif parent == StarterPlayerScripts then
			parent = folders.starterPlayerScripts
		end
		pcall(function()
			inst.Parent = parent
		end)
	end

	return true, ("Created %d instances"):format(#specs)
end

undoBtn.MouseButton1Click:Connect(function()
	if isBusy then return end
	if #undoStack == 0 then return end
	if not lastStructuredBuild then return end
	local prev = table.remove(undoStack)
	table.insert(redoStack, lastStructuredBuild)
	local ok, msg = applyStructuredBuild(prev)
	if ok then
		lastStructuredBuild = prev
		setLog("Undone. " .. msg)
	else
		setLog("Undo failed: " .. tostring(msg))
	end
	setButtonsEnabled(true)
end)

redoBtn.MouseButton1Click:Connect(function()
	if isBusy then return end
	if #redoStack == 0 then return end
	if not lastStructuredBuild then return end
	local nextBuild = table.remove(redoStack)
	table.insert(undoStack, lastStructuredBuild)
	local ok, msg = applyStructuredBuild(nextBuild)
	if ok then
		lastStructuredBuild = nextBuild
		setLog("Redone. " .. msg)
	else
		setLog("Redo failed: " .. tostring(msg))
	end
	setButtonsEnabled(true)
end)

clearBtn.MouseButton1Click:Connect(function()
	if isBusy then return end
	local removed = clearGeneratedBuild()
	lastStructuredBuild = nil
	lastPrompt = ""
	promptBox.Text = ""
	promptBox.PlaceholderText = "Describe your game"
	undoStack = {}
	redoStack = {}
	setLog(("Cleared AI build folders: %d"):format(removed))
	setButtonsEnabled(true)
end)

planBtn.MouseButton1Click:Connect(function()
	if inPlayClientMode() then
		setLog("Plan works only in Edit mode. Stop Play and try again.")
		return
	end
	if isBusy then return end
	local myToken = cancelToken
	isBusy = true
	setButtonsEnabled(false)
	local stop = startProgress("Planning")
	local prompt = promptBox.Text
	local data, err = requestWithTimeout(API_BASE .. "/plan", { prompt = prompt, fast = true }, 25)
	stop()
	if cancelToken ~= myToken then
		return
	end
	if err then
		setLog("Plan request failed: " .. err)
	else
		planBox.Text = "🧠 " .. tostring(data.plan or "(empty)")
		refreshPlanScroll()
		setLog("Plan updated.")
	end
	isBusy = false
	setButtonsEnabled(true)
end)

generateBtn.MouseButton1Click:Connect(function()
	if inPlayClientMode() then
		setLog("Generate works only in Edit mode. Stop Play and try again.")
		return
	end
	if isBusy then return end
	local myToken = cancelToken
	local prompt = promptBox.Text
	if prompt == "" then
		setLog("Enter a game prompt first.")
		return
	end

	isBusy = true
	setButtonsEnabled(false)
	local stop = startProgress("Generating")
	local data, err = requestWithTimeout(API_BASE .. "/ai-final", {
		prompt = prompt,
		fast = true,
		structured = true,
	}, 45)
	stop()
	if cancelToken ~= myToken then
		return
	end
	if err then
		setLog("Generate request failed: " .. err)
		isBusy = false
		setButtonsEnabled(true)
		return
	end

	setLog(tostring(data.message or "OK"))
	if type(data.build) == "table" then
		local ok, msg = applyStructuredBuild(data.build)
		if ok then
			lastPrompt = prompt
			lastStructuredBuild = data.build
			promptBox.Text = ""
			promptBox.PlaceholderText = "Type refine instruction, then click Refine"
			appendLog("Done. " .. msg)
		else
			appendLog("Structured build failed: " .. tostring(msg))
		end
	else
		appendLog("No structured build returned. (Check backend logs / env vars)")
	end

	isBusy = false
	setButtonsEnabled(true)
end)

refineBtn.MouseButton1Click:Connect(function()
	if inPlayClientMode() then
		setLog("Refine works only in Edit mode. Stop Play and try again.")
		return
	end
	if isBusy then return end
	local myToken = cancelToken
	if not lastStructuredBuild then
		setLog("Generate first, then Refine.")
		return
	end
	local instruction = promptBox.Text
	if instruction == "" then
		setLog("Type a refine instruction in the top box first.")
		return
	end

	isBusy = true
	setButtonsEnabled(false)
	local stop = startProgress("Refining")
	local data, err = requestWithTimeout(API_BASE .. "/ai-final", {
		prompt = lastPrompt,
		fast = true,
		structured = true,
		action = "refine",
		instruction = instruction,
		build = lastStructuredBuild,
	}, 45)
	stop()
	if cancelToken ~= myToken then
		return
	end
	if err then
		setLog("Refine request failed: " .. err)
		isBusy = false
		setButtonsEnabled(true)
		return
	end

	setLog(tostring(data.message or "OK"))
	if type(data.build) == "table" then
		local ok, msg = applyStructuredBuild(data.build)
		if ok then
			lastStructuredBuild = data.build
			promptBox.Text = ""
			promptBox.PlaceholderText = "Type next refine instruction, then click Refine"
			appendLog("Done. " .. msg)
		else
			appendLog("Structured build failed: " .. tostring(msg))
		end
	else
		appendLog("No structured build returned. (Check backend logs / env vars)")
	end

	isBusy = false
	setButtonsEnabled(true)
end)

styleToggleBtn.MouseButton1Click:Connect(function()
	if isBusy then
		return
	end
	if assetStyle == "realistic" then
		assetStyle = "cartoon"
		styleToggleBtn.Text = "Style: Cartoon"
	else
		assetStyle = "realistic"
		styleToggleBtn.Text = "Style: Realistic"
	end
end)

local function runToolboxAssetRequest(regenerate)
	if inPlayClientMode() then
		setLog("Toolbox insert works only in Edit mode. Stop Play and try again.")
		return
	end
	if isBusy then
		return
	end
	if assetSceneBox.Text == "" then
		setLog("Enter a Toolbox scene description first.")
		return
	end
	local myToken = cancelToken
	isBusy = true
	setButtonsEnabled(false)
	local stop = startProgress(regenerate and "More asset picks" or "Picking assets")
	local data, err = requestWithTimeout(API_BASE .. "/generate-assets", {
		prompt = assetSceneBox.Text,
		style = assetStyle,
		regenerate = regenerate,
		maxAssets = 10,
	}, 35)
	stop()
	if cancelToken ~= myToken then
		return
	end
	if err then
		setLog("Assets request failed: " .. err)
		isBusy = false
		setButtonsEnabled(true)
		return
	end
	if type(data) == "table" and data.success == false then
		setLog("Assets request failed: " .. tostring(data.error))
		isBusy = false
		setButtonsEnabled(true)
		return
	end
	setLog("Toolbox assets ready.")
	if type(data.keywords) == "table" and #data.keywords > 0 then
		appendLog("Keywords: " .. table.concat(data.keywords, ", "))
	end
	local placed = insertAssetsFromServerList(data.assets)
	appendLog(("Inserted %d model(s) under Workspace.%s.ToolboxAssets."):format(placed, ROOT_FOLDER_NAME))
	isBusy = false
	setButtonsEnabled(true)
end

insertAssetsBtn.MouseButton1Click:Connect(function()
	runToolboxAssetRequest(false)
end)

regenerateAssetsBtn.MouseButton1Click:Connect(function()
	runToolboxAssetRequest(true)
end)

hybridAiBoostBtn.MouseButton1Click:Connect(function()
	if isBusy then
		return
	end
	hybridAiBoost = not hybridAiBoost
	hybridAiBoostBtn.Text = hybridAiBoost and "AI boost: ON" or "AI boost: OFF"
end)

hybridForceAiOnlyBtn.MouseButton1Click:Connect(function()
	if isBusy then
		return
	end
	hybridForceAiOnly = not hybridForceAiOnly
	hybridForceAiOnlyBtn.Text = hybridForceAiOnly and "AI-only: ON" or "AI-only: OFF"
end)

hybridClearBtn.MouseButton1Click:Connect(function()
	if isBusy then
		return
	end
	tearDownHybridRuntime()
	hybridLastMode = ""
	hybridLastConfidence = 0
	hybridLastTemplates = {}
	hybridLastFeatures = {}
	hybridLastPrompt = ""
	hybridScriptNames = {}
	hybridForceAiOnly = false
	hybridForceAiOnlyBtn.Text = "AI-only: OFF"
	lastStructuredGamePlan = nil
	lastPlanPrompt = ""
	hybridInfoLabel.Text = "Using templates: — (run Generate Game)"
	hybridInfoLabel.TextColor3 = THEME.Muted
	planBox.Text = "Plan will appear here..."
	planScroll.Visible = false
	setLog("Cleared hybrid GeneratedGame (workspace + services).")
end)

planGameBtn.MouseButton1Click:Connect(function()
	if inPlayClientMode() then
		setLog("Plan game works only in Edit mode. Stop Play and try again.")
		return
	end
	if isBusy then
		return
	end
	if promptBox.Text == "" then
		setLog("Enter a game prompt first.")
		return
	end
	local myToken = cancelToken
	isBusy = true
	setButtonsEnabled(false)
	local stop = startProgress("Planning game")
	local data, err = requestWithTimeout(API_BASE .. "/plan-game", {
		prompt = promptBox.Text,
	}, 45)
	stop()
	if cancelToken ~= myToken then
		isBusy = false
		setButtonsEnabled(true)
		return
	end
	if err then
		setLog("Plan game failed: " .. err)
		isBusy = false
		setButtonsEnabled(true)
		return
	end
	if type(data) == "table" and data.success == false then
		setLog("Plan game failed: " .. tostring(data.error))
		isBusy = false
		setButtonsEnabled(true)
		return
	end
	lastStructuredGamePlan = data
	lastPlanPrompt = promptBox.Text
	planBox.Text = formatStructuredGamePlan(data)
	planScroll.Visible = true
	planScroll.Size = UDim2.new(1, 0, 0, 180)
	refreshPlanScroll()
	setLog("Planning game... done.")
	local conf = tonumber(data.confidence) or tonumber(data.confidencePercent) or 0
	local mt = ""
	if type(data.matchTier) == "string" and data.matchTier ~= "" then
		mt = (" | tier: %s"):format(data.matchTier)
	end
	appendLog(
		("Mode: %s | Template fit ~%d%%%s%s"):format(
			tostring(data.mode or "?"),
			conf,
			mt,
			data.cached and " | cached plan" or ""
		)
	)
	if type(data.reason) == "string" and data.reason ~= "" then
		appendLog("Classifier: " .. data.reason)
	end
	isBusy = false
	setButtonsEnabled(true)
end)

executePlanBtn.MouseButton1Click:Connect(function()
	runGamePlanExecution()
end)

hybridGenerateBtn.MouseButton1Click:Connect(function()
	if inPlayClientMode() then
		setLog("Hybrid generate works only in Edit mode. Stop Play and try again.")
		return
	end
	if isBusy then
		return
	end
	if promptBox.Text == "" then
		setLog("Describe your game in the Prompt box first.")
		return
	end
	local myToken = cancelToken
	isBusy = true
	setButtonsEnabled(false)
	local stop = startProgress("Hybrid generate")
	local data, err = requestWithTimeout(API_BASE .. "/hybrid-generate", {
		prompt = promptBox.Text,
		enhance = hybridAiBoost,
		forceAiOnly = hybridForceAiOnly,
	}, 45)
	stop()
	if cancelToken ~= myToken then
		return
	end
	if err then
		setLog("Hybrid generate failed: " .. err)
		isBusy = false
		setButtonsEnabled(true)
		return
	end
	if type(data) == "table" and data.success == false then
		setLog("Hybrid generate failed: " .. tostring(data.error))
		isBusy = false
		setButtonsEnabled(true)
		return
	end
	hybridLastPrompt = promptBox.Text
	hybridLastMode = tostring(data.mode or "template")
	hybridLastConfidence = tonumber(data.confidence) or 0
	hybridLastTemplates = data.templates or {}
	hybridLastFeatures = data.features or {}
	local merged = data.merged or {}
	local sOk, aN = applyHybridMerged(merged)
	rebuildHybridScriptNameList(merged)
	hybridInfoLabel.Text = hybridInfoFromMode(hybridLastMode, hybridLastTemplates)
	hybridInfoLabel.TextColor3 = THEME.Text
	setLog("Hybrid game scaffold ready.")
	if not lastStructuredGamePlan or lastPlanPrompt ~= promptBox.Text then
		appendLog('Tip: run "Plan game" first for a structured blueprint aligned to this prompt.')
	end
	local tierNote = ""
	if type(data.matchTier) == "string" and data.matchTier ~= "" then
		tierNote = (" | tier: %s"):format(data.matchTier)
	end
	appendLog(("Mode: %s (template fit ~%d%%)%s%s"):format(
		hybridLastMode,
		hybridLastConfidence,
		tierNote,
		data.routingCached and " [cached routing]" or ""
	))
	if type(data.reason) == "string" and data.reason ~= "" then
		appendLog("Classifier: " .. data.reason)
	end
	if data.forcedAiFallback == true then
		appendLog("AI-only fallback: template merge skipped; see classifierRouting in API response.")
	end
	appendLog(("Scripts injected: %d | Assets placed: %d"):format(sOk, aN))
	if hybridLastMode == "ai-only" and type(data.assetKeywords) == "table" and #data.assetKeywords > 0 then
		appendLog("Asset keywords: " .. table.concat(data.assetKeywords, ", "))
	end
	if type(data.message) == "string" and data.message ~= "" then
		appendLog(data.message)
	end
	if type(data.preMerge) == "table" then
		local pm = data.preMerge
		if pm.okToMerge == false then
			appendLog("Pre-merge: not OK to merge — see blockingIssues in API / log.")
		elseif type(pm.scriptConflicts) == "table" and #pm.scriptConflicts > 0 then
			appendLog(("Pre-merge: %d script slot note(s) (later template wins where names clash)."):format(#pm.scriptConflicts))
		end
	end
	if hybridLastMode == "template" and hybridAiBoost then
		appendLog("AI boost may add HybridExt_* scripts when the model returns them.")
	elseif hybridLastMode == "template+ai" then
		appendLog("Partial template match: base pack + required AI hybrid layer.")
	end
	isBusy = false
	setButtonsEnabled(true)
end)

hybridPipelineBtn.MouseButton1Click:Connect(function()
	if inPlayClientMode() then
		setLog("Full pipeline works only in Edit mode. Stop Play and try again.")
		return
	end
	if isBusy then
		return
	end
	if promptBox.Text == "" then
		setLog("Describe your game in the Prompt box first.")
		return
	end
	local myToken = cancelToken
	isBusy = true
	setButtonsEnabled(false)
	local stop = startProgress("Pipeline")
	local data, err = requestWithTimeout(API_BASE .. "/pipeline-generate", {
		prompt = promptBox.Text,
		enhance = hybridAiBoost,
		alwaysRefine = true,
		forceAiOnly = hybridForceAiOnly,
	}, 90)
	stop()
	if cancelToken ~= myToken then
		isBusy = false
		setButtonsEnabled(true)
		return
	end
	if err then
		setLog("Pipeline failed: " .. err)
		isBusy = false
		setButtonsEnabled(true)
		return
	end
	if type(data) == "table" and data.success == false then
		setLog("Pipeline failed: " .. tostring(data.error))
		isBusy = false
		setButtonsEnabled(true)
		return
	end
	hybridLastPrompt = promptBox.Text
	hybridLastMode = tostring(data.mode or "template")
	hybridLastConfidence = tonumber(data.confidence) or tonumber(data.confidencePercent) or 0
	hybridLastTemplates = data.templates or {}
	hybridLastFeatures = data.features or {}
	local merged = data.mergedFinal or {}
	local sOk, aN = applyHybridMerged(merged)
	rebuildHybridScriptNameList(merged)
	if type(data.refinement) == "table" and type(data.refinement.removeScriptNames) == "table" then
		removeHybridScriptsByNames(data.refinement.removeScriptNames)
	end
	hybridInfoLabel.Text = hybridInfoFromMode(hybridLastMode, hybridLastTemplates)
	hybridInfoLabel.TextColor3 = THEME.Text
	setLog("Full pipeline finished (generate → refine → recheck).")
	if type(data.recheckCyclesUsed) == "number" and type(data.recheckCycleLimit) == "number" then
		appendLog(("Recheck cycles: %d / %d (max)"):format(data.recheckCyclesUsed, data.recheckCycleLimit))
	end
	local pTier = ""
	if type(data.matchTier) == "string" and data.matchTier ~= "" then
		pTier = (" | tier: %s"):format(data.matchTier)
	end
	appendLog(("Mode: %s | Template fit ~%d%%%s"):format(hybridLastMode, hybridLastConfidence, pTier))
	if type(data.reason) == "string" and data.reason ~= "" then
		appendLog("Classifier: " .. data.reason)
	end
	if data.forcedAiFallback == true then
		appendLog("AI-only fallback: template merge skipped; see classifierRouting.")
	end
	appendLog(("Scripts injected: %d | Assets placed: %d"):format(sOk, aN))
	if type(data.smartLoopHint) == "string" and data.smartLoopHint ~= "" then
		appendLog("Smart loop: " .. data.smartLoopHint)
	end
	if data.recheckRouting and type(data.recheckRouting.mode) == "string" then
		appendLog("After refine, classifier mode: " .. data.recheckRouting.mode)
	end
	if data.recheckRouting and type(data.recheckRouting.reason) == "string" and data.recheckRouting.reason ~= "" then
		appendLog("Recheck: " .. data.recheckRouting.reason)
	end
	if type(data.message) == "string" and data.message ~= "" then
		appendLog(data.message)
	end
	if type(data.preMerge) == "table" then
		local pm = data.preMerge
		if pm.okToMerge == false then
			appendLog("Pre-merge: not OK to merge — see blockingIssues.")
		elseif type(pm.scriptConflicts) == "table" and #pm.scriptConflicts > 0 then
			appendLog(("Pre-merge: %d script slot note(s)."):format(#pm.scriptConflicts))
		end
	end
	if hybridLastMode == "ai-only" and type(data.assetKeywords) == "table" and #data.assetKeywords > 0 then
		appendLog("Asset keywords: " .. table.concat(data.assetKeywords, ", "))
	end
	if type(data.refinement) == "table" and type(data.refinement.message) == "string" and data.refinement.message ~= "" then
		appendLog("Refine: " .. data.refinement.message)
	end
	isBusy = false
	setButtonsEnabled(true)
end)

hybridRefineBtn.MouseButton1Click:Connect(function()
	if inPlayClientMode() then
		setLog("Hybrid refine works only in Edit mode. Stop Play and try again.")
		return
	end
	if isBusy then
		return
	end
	if hybridLastPrompt == "" then
		setLog('Run hybrid "Generate Game" first.')
		return
	end
	local instruction = promptBox.Text
	if instruction == "" then
		setLog("Type a refine instruction in the Prompt box (e.g. make it scarier).")
		return
	end
	local myToken = cancelToken
	isBusy = true
	setButtonsEnabled(false)
	local stop = startProgress("Refine: template check")
	local data, err = requestWithTimeout(API_BASE .. "/refine-game", {
		prompt = hybridLastPrompt,
		instruction = instruction,
		templates = hybridLastTemplates,
		features = hybridLastFeatures,
		scriptNames = hybridScriptNames,
		generationMode = hybridLastMode,
	}, 45)
	stop()
	if cancelToken ~= myToken then
		isBusy = false
		setButtonsEnabled(true)
		return
	end
	if err then
		setLog("Hybrid refine failed: " .. err)
		isBusy = false
		setButtonsEnabled(true)
		return
	end
	if type(data) == "table" and data.success == false then
		setLog("Hybrid refine failed: " .. tostring(data.error))
		isBusy = false
		setButtonsEnabled(true)
		return
	end
	local path = tostring(data.path or "ai_refine")
	if path == "template_merge" and type(data.merged) == "table" then
		if type(data.routing) == "table" then
			hybridLastMode = tostring(data.routing.mode or "template")
			hybridLastConfidence = tonumber(data.routing.confidence) or tonumber(data.routing.confidencePercent) or hybridLastConfidence
			if type(data.routing.templates) == "table" then
				hybridLastTemplates = data.routing.templates
			end
			if type(data.routing.features) == "table" then
				hybridLastFeatures = data.routing.features
			end
		end
		local sOk, aN = applyHybridMerged(data.merged)
		rebuildHybridScriptNameList(data.merged)
		hybridInfoLabel.Text = hybridInfoFromMode(hybridLastMode, hybridLastTemplates)
		hybridInfoLabel.TextColor3 = THEME.Text
		setLog(tostring(data.message or "Template merge applied."))
		appendLog(("Refine path: template_merge | scripts: %d | assets: %d"):format(sOk, aN))
	elseif path == "template_hybrid_refine" and type(data.merged) == "table" then
		if type(data.routing) == "table" then
			hybridLastMode = tostring(data.routing.mode or "template")
			hybridLastConfidence = tonumber(data.routing.confidence) or tonumber(data.routing.confidencePercent) or hybridLastConfidence
			if type(data.routing.templates) == "table" then
				hybridLastTemplates = data.routing.templates
			end
			if type(data.routing.features) == "table" then
				hybridLastFeatures = data.routing.features
			end
		end
		local sOk, aN = applyHybridMerged(data.merged)
		rebuildHybridScriptNameList(data.merged)
		appendHybridRefinement(data)
		hybridInfoLabel.Text = hybridInfoFromMode(hybridLastMode, hybridLastTemplates)
		hybridInfoLabel.TextColor3 = THEME.Text
		setLog(tostring(data.message or "Template + AI refine applied."))
		appendLog(
			("Refine path: template_hybrid_refine | base scripts: %d | base assets: %d"):format(sOk, aN)
		)
	else
		appendHybridRefinement(data)
		setLog(tostring(data.message or "Hybrid refine applied."))
		appendLog("Refine path: ai_refine (HybridExt_* append/remove).")
	end
	isBusy = false
	setButtonsEnabled(true)
end)

