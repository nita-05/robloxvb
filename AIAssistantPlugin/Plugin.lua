local toolbar = plugin:CreateToolbar("AI Assistant")
local button = toolbar:CreateButton("VibeCoder", "Open VibeCoder", "")

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
widget.Title = "VibeCoder"

button.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

-- UI ROOT
local frame = Instance.new("Frame")
frame.Size = UDim2.new(1, 0, 1, 0)
frame.BackgroundColor3 = Color3.fromRGB(12, 14, 20) -- premium dark canvas
frame.BorderSizePixel = 0
frame.Parent = widget

local THEME = {
	Bg = Color3.fromRGB(12, 14, 20),
	Panel = Color3.fromRGB(16, 18, 26),
	Card = Color3.fromRGB(18, 21, 31),
	Surface = Color3.fromRGB(14, 16, 24),
	Border = Color3.fromRGB(38, 44, 62),
	Text = Color3.fromRGB(238, 243, 255),
	Muted = Color3.fromRGB(160, 170, 195),
	Placeholder = Color3.fromRGB(112, 120, 142),
	Primary = Color3.fromRGB(34, 211, 238), -- cyan
	Primary2 = Color3.fromRGB(99, 102, 241), -- indigo
	AccentBlue = Color3.fromRGB(56, 139, 253),
	Danger = Color3.fromRGB(232, 84, 102),
	SecondaryBtn = Color3.fromRGB(26, 29, 40),
	Radius = UDim.new(0, 16),
	ButtonRadius = UDim.new(0, 14),
	PillRadius = UDim.new(0, 999),
}

-- Header logo (upload your PNG to Roblox, then paste the asset id here).
-- Example: "rbxassetid://1234567890"
local BRAND_LOGO_IMAGE = "rbxassetid://0"

-- UI/feature state must be defined BEFORE UI widgets reference it.
-- Memory is always on (automatic context from recent builds).
local selectedTemplate = "None" -- "None" | "Obby Game" | "Simulator" | "Tycoon" | "Combat System"

-- Simple usage feedback (UI-only until real pricing is implemented).
local credits = 100

-- Backend uses one default model (gpt-5.3-latest in config/models.js). Tier stays "fast" to skip extra upgrade calls.

-- Client-side memory (UI-level). We store prompt + compact script info.
local memoryEntries = {}
local MAX_MEMORY_ENTRIES = 4

-- Services used by UI tweens MUST be available before UI construction.
local TweenService = game:GetService("TweenService")

-- Top-level overlay for dropdown popups (prevents clipping in panels/scroll frames)
local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.BackgroundTransparency = 1
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.ZIndex = 500
-- Critical: overlay must never block clicks on underlying buttons.
overlay.Active = false
overlay.Selectable = false
overlay.Parent = frame

local function toOverlayPos(guiObj)
	local rootAbs = frame.AbsolutePosition
	local a = guiObj.AbsolutePosition
	return Vector2.new(a.X - rootAbs.X, a.Y - rootAbs.Y)
end

do
	-- Ambient blue wash (very subtle, Studio-like)
	local glow = Instance.new("Frame")
	glow.Name = "BgGlow"
	glow.BackgroundColor3 = Color3.fromRGB(28, 56, 120)
	glow.BackgroundTransparency = 0.88
	glow.BorderSizePixel = 0
	glow.Size = UDim2.new(1.15, 0, 0.55, 0)
	glow.Position = UDim2.new(-0.075, 0, -0.12, 0)
	glow.ZIndex = 0
	glow.Parent = frame

	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(0, 48)
	glowCorner.Parent = glow

	local glowGrad = Instance.new("UIGradient")
	glowGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(45, 100, 200)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(30, 80, 160)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 40, 120)),
	})
	glowGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.62),
		NumberSequenceKeypoint.new(0.6, 0.82),
		NumberSequenceKeypoint.new(1, 1),
	})
	glowGrad.Rotation = 22
	glowGrad.Parent = glow
end

local rootScroll = Instance.new("ScrollingFrame")
rootScroll.Name = "RootScroll"
rootScroll.Size = UDim2.new(1, 0, 1, -70)
rootScroll.Position = UDim2.new(0, 0, 0, 70)
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
rootPadding.PaddingTop = UDim.new(0, 14)
rootPadding.PaddingBottom = UDim.new(0, 18)
rootPadding.PaddingLeft = UDim.new(0, 14)
rootPadding.PaddingRight = UDim.new(0, 14)
rootPadding.Parent = rootScroll

local rootLayout = Instance.new("UIListLayout")
rootLayout.FillDirection = Enum.FillDirection.Vertical
rootLayout.SortOrder = Enum.SortOrder.LayoutOrder
rootLayout.Padding = UDim.new(0, 14)
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
	stroke.Transparency = 0.62
	stroke.Parent = panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = THEME.Radius
	corner.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 14)
	padding.PaddingBottom = UDim.new(0, 14)
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = panel

	panel.Parent = parent
	return panel
end

local function addSectionLabel(parent, text)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 20)
	row.Parent = parent

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Text = text
	label.TextColor3 = THEME.Muted
	label.TextTransparency = 0.12
	label.Font = Enum.Font.GothamSemibold
	label.TextSize = 11
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Bottom
	label.Parent = row

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

local TWEEN_HOVER = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_PRESS = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function tweenScaleUi(uiScale, targetScale)
	if uiScale and uiScale.Parent then
		TweenService:Create(uiScale, TWEEN_PRESS, { Scale = targetScale }):Play()
	end
end

local function styleButton(btn, baseColor)
	btn.BackgroundColor3 = baseColor
	btn.BorderSizePixel = 0
	btn.TextColor3 = THEME.Text
	btn.Font = Enum.Font.GothamSemibold
	btn.TextSize = 14
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
	stroke.Transparency = 0.72
	stroke.Parent = btn

	btn.MouseButton1Down:Connect(function()
		if btn.Active then
			tweenScaleUi(scale, 0.97)
		end
	end)
	btn.MouseButton1Up:Connect(function()
		tweenScaleUi(scale, 1)
	end)

	applyHover(btn, baseColor)

	btn.MouseEnter:Connect(function()
		if btn.Active then
			TweenService:Create(stroke, TWEEN_HOVER, { Transparency = 0.52 }):Play()
		end
	end)
	btn.MouseLeave:Connect(function()
		tweenScaleUi(scale, 1)
		TweenService:Create(stroke, TWEEN_HOVER, { Transparency = 0.72 }):Play()
	end)
end

-- UI references used by logic below (kept minimal to avoid Luau register limits).
-- promptBox is declared above (UI refs)
local enhancePromptBtn
local enhanceTooltip
local actionsPanel
local generateBtn
local generateLabel
local stopBtn
local actionStatus
local addFeatureBtn
local fixBugsBtn
local optimizeBtn
local clearBtn
local planScroll
local planBox
local logScroll
local logBox
local statusPill

do
local headerPanel = addPanel(frame, 52)
headerPanel.Position = UDim2.new(0, 0, 0, 10)
headerPanel.Size = UDim2.new(1, 0, 0, 54)
headerPanel.ZIndex = 10

headerPanel.BackgroundColor3 = THEME.Panel
local headerGrad = Instance.new("UIGradient")
headerGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 22, 34)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 14, 22)),
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
headerPadding.PaddingTop = UDim.new(0, 9)
headerPadding.PaddingBottom = UDim.new(0, 9)
headerPadding.PaddingLeft = UDim.new(0, 12)
headerPadding.PaddingRight = UDim.new(0, 12)
headerPadding.Parent = headerContent

local headerH = Instance.new("UIListLayout")
headerH.FillDirection = Enum.FillDirection.Horizontal
headerH.HorizontalAlignment = Enum.HorizontalAlignment.Left
headerH.VerticalAlignment = Enum.VerticalAlignment.Center
headerH.SortOrder = Enum.SortOrder.LayoutOrder
headerH.Padding = UDim.new(0, 10)
headerH.Parent = headerContent

-- Brand unit: keep logo + title visually grouped (modern SaaS-style header).
local brandUnit = Instance.new("Frame")
brandUnit.Name = "BrandUnit"
brandUnit.BackgroundTransparency = 1
-- Leave room for the right-side credits label.
brandUnit.Size = UDim2.new(1, -160, 1, 0)
brandUnit.LayoutOrder = 1
brandUnit.ZIndex = 11
brandUnit.Parent = headerContent

local brandUnitLayout = Instance.new("UIListLayout")
brandUnitLayout.FillDirection = Enum.FillDirection.Horizontal
brandUnitLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
brandUnitLayout.VerticalAlignment = Enum.VerticalAlignment.Center
brandUnitLayout.SortOrder = Enum.SortOrder.LayoutOrder
brandUnitLayout.Padding = UDim.new(0, 8)
brandUnitLayout.Parent = brandUnit

local brandTile = Instance.new("Frame")
brandTile.Name = "BrandTile"
brandTile.BackgroundColor3 = Color3.fromRGB(10, 16, 34)
brandTile.BorderSizePixel = 0
brandTile.Size = UDim2.new(0, 36, 0, 36)
brandTile.LayoutOrder = 1
brandTile.Parent = brandUnit
brandTile.Active = true
-- Brand icon tile (shown in header).
brandTile.Visible = true

local brandTileCorner = Instance.new("UICorner")
brandTileCorner.CornerRadius = UDim.new(1, 0)
brandTileCorner.Parent = brandTile

local brandTileStroke = Instance.new("UIStroke")
brandTileStroke.Color = Color3.fromRGB(33, 56, 104)
brandTileStroke.Thickness = 1
brandTileStroke.Transparency = 0.25
brandTileStroke.Parent = brandTile

local brandTileScale = Instance.new("UIScale")
brandTileScale.Scale = 1
brandTileScale.Parent = brandTile

-- Prefer a real logo image if configured; otherwise fallback to the V badge.
local brandLogo = Instance.new("ImageLabel")
brandLogo.Name = "BrandLogo"
brandLogo.BackgroundTransparency = 1
brandLogo.BorderSizePixel = 0
brandLogo.AnchorPoint = Vector2.new(0.5, 0.5)
brandLogo.Position = UDim2.new(0.5, 0, 0.5, 0)
brandLogo.Size = UDim2.new(0, 32, 0, 32)
brandLogo.ZIndex = 20
brandLogo.ScaleType = Enum.ScaleType.Fit
brandLogo.ImageTransparency = 0
brandLogo.Visible = (type(BRAND_LOGO_IMAGE) == "string" and BRAND_LOGO_IMAGE ~= "" and BRAND_LOGO_IMAGE ~= "rbxassetid://0")
if brandLogo.Visible then
	brandLogo.Image = BRAND_LOGO_IMAGE
end
brandLogo.Parent = brandTile

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
brandBadge.Size = UDim2.new(0, 32, 0, 32)
brandBadge.BackgroundColor3 = Color3.fromRGB(100, 70, 235)
brandBadge.BorderSizePixel = 0
brandBadge.Parent = brandTile
-- If an uploaded logo is configured, hide the V-badge.
if brandLogo.Visible then
	brandBadge.Visible = false
end

local brandBadgeCorner = Instance.new("UICorner")
brandBadgeCorner.CornerRadius = UDim.new(1, 0)
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
brandV.TextSize = 18
brandV.Parent = brandBadge

-- Make sure the visible badge actually fits the smaller brand tile.
brandBadge.ZIndex = 12
brandV.ZIndex = 13

local titleStack = Instance.new("Frame")
titleStack.Name = "TitleStack"
titleStack.BackgroundTransparency = 1
titleStack.Size = UDim2.new(1, 0, 1, 0)
titleStack.LayoutOrder = 2
titleStack.ZIndex = 11
titleStack.Parent = brandUnit

local titleStackLayout = Instance.new("UIListLayout")
titleStackLayout.FillDirection = Enum.FillDirection.Vertical
titleStackLayout.SortOrder = Enum.SortOrder.LayoutOrder
titleStackLayout.Padding = UDim.new(0, 0)
titleStackLayout.VerticalAlignment = Enum.VerticalAlignment.Center
titleStackLayout.Parent = titleStack

local title = Instance.new("TextLabel")
title.Text = "VibeCoder"
title.Size = UDim2.new(1, 0, 0, 22)
title.BackgroundTransparency = 1
title.TextColor3 = THEME.Text
title.Font = Enum.Font.GothamBold
title.TextSize = 19
title.TextXAlignment = Enum.TextXAlignment.Left
title.LayoutOrder = 1
title.ZIndex = 11
title.Parent = titleStack

local subtitle = Instance.new("TextLabel")
subtitle.Text = "Roblox AI Builder"
subtitle.Size = UDim2.new(1, 0, 0, 16)
subtitle.BackgroundTransparency = 1
subtitle.TextColor3 = THEME.Text
subtitle.TextTransparency = 0.5
subtitle.Font = Enum.Font.GothamMedium
subtitle.TextSize = 11
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.LayoutOrder = 2
subtitle.ZIndex = 11
subtitle.Parent = titleStack

local headerFill = Instance.new("Frame")
headerFill.Name = "HeaderFill"
headerFill.BackgroundTransparency = 1
-- Spacer: keep 0-width so it doesn't push right controls off-screen.
headerFill.Size = UDim2.new(0, 0, 1, 0)
headerFill.LayoutOrder = 2
headerFill.Parent = headerContent

-- Top-right: credits / header extras
local headerRight = Instance.new("Frame")
headerRight.Name = "HeaderRight"
headerRight.BackgroundTransparency = 1
headerRight.Size = UDim2.new(0, 160, 1, 0)
headerRight.LayoutOrder = 3
headerRight.Parent = headerContent

-- Subtle hover polish (purely visual).
-- (logo hidden)

-- Responsive: slightly tighten spacing and type on narrow widths.
local function applyBrandResponsive()
	local w = headerPanel.AbsoluteSize.X
	local compact = w > 0 and w < 620
	brandUnitLayout.Padding = UDim.new(0, 0)
	title.TextSize = compact and 18 or 19
	subtitle.TextSize = compact and 10 or 11
	titleStack.Size = UDim2.new(1, 0, 1, 0)
end
applyBrandResponsive()
headerPanel:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyBrandResponsive)

local headerRightLayout = Instance.new("UIListLayout")
headerRightLayout.FillDirection = Enum.FillDirection.Horizontal
headerRightLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
headerRightLayout.VerticalAlignment = Enum.VerticalAlignment.Center
headerRightLayout.SortOrder = Enum.SortOrder.LayoutOrder
headerRightLayout.Padding = UDim.new(0, 6)
headerRightLayout.Parent = headerRight

local creditsValLabel = Instance.new("TextLabel")
creditsValLabel.Name = "CreditsLabel"
creditsValLabel.BackgroundTransparency = 1
creditsValLabel.Size = UDim2.new(1, 0, 0, 28)
creditsValLabel.TextXAlignment = Enum.TextXAlignment.Right
creditsValLabel.Text = ("💰 Credits: %d"):format(credits)
creditsValLabel.TextColor3 = THEME.Muted
creditsValLabel.TextTransparency = 0.05
creditsValLabel.Font = Enum.Font.GothamMedium
creditsValLabel.TextSize = 11
creditsValLabel.ZIndex = 12
creditsValLabel.LayoutOrder = 1
creditsValLabel.Parent = headerRight

statusPill = Instance.new("TextLabel")
statusPill.Name = "StatusPill"
statusPill.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
statusPill.BorderSizePixel = 0
statusPill.Size = UDim2.new(0, 86, 0, 22)
statusPill.Position = UDim2.new(1, -92, 0, 0)
statusPill.Text = ""
statusPill.TextColor3 = THEME.Text
statusPill.TextTransparency = 0.15
statusPill.Font = Enum.Font.SourceSansSemibold
statusPill.TextSize = 12
statusPill.ZIndex = 12
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

local function makeDropdownOption(parent, text)
	local b = Instance.new("TextButton")
	b.Text = text
	b.BackgroundColor3 = THEME.Panel
	b.BackgroundTransparency = 0
	b.BorderSizePixel = 0
	b.Size = UDim2.new(1, 0, 0, 26)
	b.TextColor3 = THEME.Text
	b.TextTransparency = 0
	b.Font = Enum.Font.SourceSansSemibold
	b.TextSize = 13
	b.AutoButtonColor = true
	-- Ensure options render above the popup background (overlay popups use high ZIndex)
	local pz = 1
	pcall(function()
		pz = parent.ZIndex
	end)
	b.ZIndex = pz + 1
	b.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = THEME.PillRadius
	c.Parent = b
	local s = Instance.new("UIStroke")
	s.Color = THEME.Border
	s.Thickness = 1
	s.Transparency = 0.45
	s.Parent = b
	return b
end

-- Optional Right Sidebar (collapsible) — disabled
if false then
	local sidebarW = 180
	local sidebarHPadTop = 64
	local sidebarY = sidebarHPadTop
	local sidebarX = -sidebarW - 8

	local sidebarExpanded = false
	local sidebarFrame = Instance.new("Frame")
	sidebarFrame.Name = "RightSidebar"
	sidebarFrame.BackgroundColor3 = THEME.Panel
	sidebarFrame.BorderSizePixel = 0
	sidebarFrame.ClipsDescendants = true
	sidebarFrame.Size = UDim2.new(0, sidebarW, 1, -(sidebarY + 16))
	sidebarFrame.Position = UDim2.new(1, sidebarX, 0, sidebarY)
	sidebarFrame.Visible = false
	sidebarFrame.ZIndex = 30
	sidebarFrame.Parent = frame

	local sidebarCorner = Instance.new("UICorner")
	sidebarCorner.CornerRadius = THEME.Radius
	sidebarCorner.Parent = sidebarFrame

	local sidebarStroke = Instance.new("UIStroke")
	sidebarStroke.Color = THEME.Border
	sidebarStroke.Thickness = 1
	sidebarStroke.Transparency = 0.35
	sidebarStroke.Parent = sidebarFrame

	local sidebarHeader = Instance.new("Frame")
	sidebarHeader.Name = "SidebarHeader"
	sidebarHeader.BackgroundTransparency = 1
	sidebarHeader.Size = UDim2.new(1, 0, 0, 30)
	sidebarHeader.Parent = sidebarFrame

	local headerLayout = Instance.new("UIListLayout")
	headerLayout.FillDirection = Enum.FillDirection.Horizontal
	headerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	headerLayout.Padding = UDim.new(0, 6)
	-- Enum.HorizontalAlignment has no "Fill" (this was crashing the plugin UI build).
	headerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	headerLayout.Parent = sidebarHeader

	local scriptsTabBtn = Instance.new("TextButton")
	scriptsTabBtn.Text = "Scripts"
	scriptsTabBtn.AutoButtonColor = true
	scriptsTabBtn.Size = UDim2.new(0, 0, 0, 26)
	scriptsTabBtn.LayoutOrder = 1
	styleButton(scriptsTabBtn, THEME.Surface)
	scriptsTabBtn.Parent = sidebarHeader

	local memoryTabBtn = Instance.new("TextButton")
	memoryTabBtn.Text = "Memory"
	memoryTabBtn.AutoButtonColor = true
	memoryTabBtn.Size = UDim2.new(0, 0, 0, 26)
	memoryTabBtn.LayoutOrder = 2
	styleButton(memoryTabBtn, THEME.Surface)
	memoryTabBtn.Parent = sidebarHeader

	local historyTabBtn = Instance.new("TextButton")
	historyTabBtn.Text = "History"
	historyTabBtn.AutoButtonColor = true
	historyTabBtn.Size = UDim2.new(0, 0, 0, 26)
	historyTabBtn.LayoutOrder = 3
	styleButton(historyTabBtn, THEME.Surface)
	historyTabBtn.Parent = sidebarHeader

	local sidebarBody = Instance.new("Frame")
	sidebarBody.Name = "SidebarBody"
	sidebarBody.BackgroundTransparency = 1
	sidebarBody.Size = UDim2.new(1, 0, 1, -30)
	sidebarBody.Position = UDim2.new(0, 0, 0, 30)
	sidebarBody.Parent = sidebarFrame

	local scriptsTab = Instance.new("Frame")
	scriptsTab.Name = "ScriptsTab"
	scriptsTab.BackgroundTransparency = 1
	scriptsTab.Size = UDim2.new(1, 0, 1, 0)
	scriptsTab.Visible = true
	scriptsTab.Parent = sidebarBody

	local memoryTab = Instance.new("Frame")
	memoryTab.Name = "MemoryTab"
	memoryTab.BackgroundTransparency = 1
	memoryTab.Size = UDim2.new(1, 0, 1, 0)
	memoryTab.Visible = false
	memoryTab.Parent = sidebarBody

	local historyTab = Instance.new("Frame")
	historyTab.Name = "HistoryTab"
	historyTab.BackgroundTransparency = 1
	historyTab.Size = UDim2.new(1, 0, 1, 0)
	historyTab.Visible = false
	historyTab.Parent = sidebarBody

	local scriptsText = Instance.new("TextLabel")
	scriptsText.BackgroundTransparency = 1
	scriptsText.Size = UDim2.new(1, -10, 1, -10)
	scriptsText.Position = UDim2.new(0, 5, 0, 5)
	scriptsText.TextXAlignment = Enum.TextXAlignment.Left
	scriptsText.TextYAlignment = Enum.TextYAlignment.Top
	scriptsText.TextWrapped = true
	scriptsText.Font = Enum.Font.Code
	scriptsText.TextSize = 12
	scriptsText.TextColor3 = THEME.Text
	scriptsText.Text = "No scripts yet."
	scriptsText.Parent = scriptsTab

	local memoryText = Instance.new("TextLabel")
	memoryText.BackgroundTransparency = 1
	memoryText.Size = UDim2.new(1, -10, 1, -10)
	memoryText.Position = UDim2.new(0, 5, 0, 5)
	memoryText.TextXAlignment = Enum.TextXAlignment.Left
	memoryText.TextYAlignment = Enum.TextYAlignment.Top
	memoryText.TextWrapped = true
	memoryText.Font = Enum.Font.Code
	memoryText.TextSize = 12
	memoryText.TextColor3 = THEME.Text
	memoryText.Text = "Memory is OFF."
	memoryText.Parent = memoryTab

	local historyText = Instance.new("TextLabel")
	historyText.BackgroundTransparency = 1
	historyText.Size = UDim2.new(1, -10, 1, -10)
	historyText.Position = UDim2.new(0, 5, 0, 5)
	historyText.TextXAlignment = Enum.TextXAlignment.Left
	historyText.TextYAlignment = Enum.TextYAlignment.Top
	historyText.TextWrapped = true
	historyText.Font = Enum.Font.Code
	historyText.TextSize = 12
	historyText.TextColor3 = THEME.Text
	historyText.Text = "No history yet."
	historyText.Parent = historyTab

	local function refreshSidebar()
		-- Scripts
		local names = {}
		if type(lastStructuredBuild) == "table" and type(lastStructuredBuild.instances) == "table" then
			for _, inst in ipairs(lastStructuredBuild.instances) do
				if type(inst) == "table" then
					local cn = inst.className
					if cn == "Script" or cn == "LocalScript" or cn == "ModuleScript" then
						local n = inst.name or inst.id or cn
						if n and n ~= "" then
							table.insert(names, tostring(n))
						end
					end
				end
			end
		end
		if #names > 0 then
			scriptsText.Text = table.concat(names, ", ")
		else
			scriptsText.Text = "No scripts yet."
		end

		-- Memory (automatic; sidebar is normally hidden)
		if #memoryEntries > 0 then
			local lines = {}
			for i, e in ipairs(memoryEntries) do
				if e and e.prompt then
					local sn = e.scripts and #e.scripts > 0 and table.concat(e.scripts, ", ") or "none"
					table.insert(lines, ("#%d: %s\nscripts: %s"):format(i, tostring(e.prompt), sn))
				end
			end
			memoryText.Text = table.concat(lines, "\n\n")
		else
			memoryText.Text = "No memory entries yet."
		end

		historyText.Text = "Activity is shown in AI Console."
	end

	local function showTab(which)
		scriptsTab.Visible = which == "scripts"
		memoryTab.Visible = which == "memory"
		historyTab.Visible = which == "history"
		refreshSidebar()
	end

	scriptsTabBtn.MouseButton1Click:Connect(function()
		showTab("scripts")
	end)
	memoryTabBtn.MouseButton1Click:Connect(function()
		showTab("memory")
	end)
	historyTabBtn.MouseButton1Click:Connect(function()
		showTab("history")
	end)

	-- Collapse/expand handle
	local handleBtn = Instance.new("TextButton")
	handleBtn.Name = "SidebarHandle"
	handleBtn.Text = ">>"
	handleBtn.BackgroundColor3 = THEME.Panel
	handleBtn.BorderSizePixel = 0
	handleBtn.TextColor3 = THEME.Text
	handleBtn.Font = Enum.Font.SourceSansSemibold
	handleBtn.TextSize = 14
	handleBtn.AutoButtonColor = false
	handleBtn.Size = UDim2.new(0, 24, 0, 70)
	handleBtn.Position = UDim2.new(1, -28, 0, sidebarY + 100)
	handleBtn.ZIndex = 40
	handleBtn.Parent = frame

	local handleCorner = Instance.new("UICorner")
	handleCorner.CornerRadius = UDim.new(0, 12)
	handleCorner.Parent = handleBtn

	local handleStroke = Instance.new("UIStroke")
	handleStroke.Color = THEME.Border
	handleStroke.Thickness = 1
	handleStroke.Transparency = 0.35
	handleStroke.Parent = handleBtn

	handleBtn.MouseButton1Click:Connect(function()
		sidebarExpanded = not sidebarExpanded
		sidebarFrame.Visible = sidebarExpanded
		handleBtn.Text = sidebarExpanded and "<<" or ">>"
		if sidebarExpanded then
			refreshSidebar()
		end
	end)
end

local promptPanel = addPanel(rootScroll, 0)
promptPanel.LayoutOrder = 1
promptPanel.AutomaticSize = Enum.AutomaticSize.Y
-- Allow Enhance Prompt hover/glow without clipping.
promptPanel.ClipsDescendants = false

local promptLayout = Instance.new("UIListLayout")
promptLayout.FillDirection = Enum.FillDirection.Vertical
promptLayout.SortOrder = Enum.SortOrder.LayoutOrder
promptLayout.Padding = UDim.new(0, 12)
promptLayout.Parent = promptPanel

addSectionLabel(promptPanel, "Prompt").LayoutOrder = 1

-- Forward declare so Template dropdown can auto-fill it.
-- promptBox is declared above (UI refs)

-- Template dropdown (above prompt)
do
	local templateRow = Instance.new("Frame")
	templateRow.BackgroundTransparency = 1
	templateRow.Size = UDim2.new(1, 0, 0, 32)
	templateRow.LayoutOrder = 2
	templateRow.Parent = promptPanel

	local templateLbl = Instance.new("TextLabel")
	templateLbl.BackgroundTransparency = 1
	templateLbl.Size = UDim2.new(0, 70, 1, 0)
	templateLbl.Position = UDim2.new(0, 0, 0, 0)
	templateLbl.Text = "Template"
	templateLbl.TextColor3 = THEME.Muted
	templateLbl.TextTransparency = 0.05
	templateLbl.Font = Enum.Font.GothamMedium
	templateLbl.TextSize = 11
	templateLbl.TextXAlignment = Enum.TextXAlignment.Left
	templateLbl.Parent = templateRow

	local templateMain = Instance.new("TextButton")
	templateMain.Name = "TemplateDropdownBtn"
	templateMain.Text = "Template: None"
	templateMain.BackgroundColor3 = THEME.Surface
	templateMain.BorderSizePixel = 0
	templateMain.TextColor3 = THEME.Text
	templateMain.Font = Enum.Font.GothamMedium
	templateMain.TextSize = 11
	templateMain.Size = UDim2.new(1, -78, 0, 26)
	templateMain.Position = UDim2.new(0, 78, 0, 3)
	templateMain.AutoButtonColor = false
	templateMain.ZIndex = 50
	templateMain.Parent = templateRow

	local templateCorner = Instance.new("UICorner")
	templateCorner.CornerRadius = THEME.PillRadius
	templateCorner.Parent = templateMain

	local templateStroke = Instance.new("UIStroke")
	templateStroke.Color = THEME.Border
	templateStroke.Thickness = 1
	templateStroke.Transparency = 0.35
	templateStroke.Parent = templateMain

	local templatePopup = Instance.new("Frame")
	templatePopup.Name = "TemplateDropdownPopup"
	templatePopup.BackgroundColor3 = THEME.Surface
	templatePopup.BorderSizePixel = 0
	templatePopup.Visible = false
	templatePopup.Size = UDim2.new(0, 190, 0, 132)
	templatePopup.ZIndex = 600
	templatePopup.Parent = overlay

	local templatePopupCorner = Instance.new("UICorner")
	templatePopupCorner.CornerRadius = UDim.new(0, 10)
	templatePopupCorner.Parent = templatePopup

	local templatePopupStroke = Instance.new("UIStroke")
	templatePopupStroke.Color = THEME.Border
	templatePopupStroke.Thickness = 1
	templatePopupStroke.Transparency = 0.35
	templatePopupStroke.Parent = templatePopup

	local templatePopupLayout = Instance.new("UIListLayout")
	templatePopupLayout.FillDirection = Enum.FillDirection.Vertical
	templatePopupLayout.Padding = UDim.new(0, 6)
	templatePopupLayout.SortOrder = Enum.SortOrder.LayoutOrder
	templatePopupLayout.Parent = templatePopup

	local templateOpen = false
	local lastTemplateAutofill = ""

	local function templateStarterPrompt(t)
		if t == "Obby Game" then
			return table.concat({
				"Build a fun ROBLOX obby with a clear start and finish.",
				"Include checkpoints every 3-4 stages, a few kill/reset parts, and a win screen.",
				"Style: dark neon vibe, soft glow lighting, readable UI.",
			}, "\n")
		elseif t == "Tycoon" then
			return table.concat({
				"Build a simple tycoon game with a money loop and upgrades.",
				"Include: leaderstats cash, a dropper/collector system, and 3-5 purchasable upgrades.",
				"Add a clean upgrade UI panel and basic progression pacing.",
			}, "\n")
		elseif t == "Simulator" then
			return table.concat({
				"Build a simulator game with a core loop and upgrades.",
				"Include: leaderstats coins, a main action (click/collect/touch), and scaling rewards.",
				"Add an upgrades UI and a simple objective list.",
			}, "\n")
		elseif t == "Combat System" then
			return table.concat({
				"Build a combat system for a Roblox game.",
				"Include: melee + ranged example, damage/health, cooldowns, and server-side validation for hits.",
				"Add: simple combat UI (HP) + clean, extensible module structure.",
			}, "\n")
		end
		return ""
	end

	local function closeTemplate()
		templateOpen = false
		templatePopup.Visible = false
	end
	local function setTemplate(t)
		selectedTemplate = t
		templateMain.Text = "Template: " .. tostring(t)
		closeTemplate()

		-- Auto-fill prompt when choosing a template (user can Enhance Prompt after).
		local starter = templateStarterPrompt(t)
		if t ~= "None" and starter ~= "" then
			if promptBox.Text == "" or promptBox.Text == lastTemplateAutofill then
				promptBox.Text = starter
				lastTemplateAutofill = starter
				promptBox.PlaceholderText = "💡 Describe your game or feature..."
			end
		else
			-- If switching back to None and the box only has the auto-fill, clear it.
			if promptBox.Text ~= "" and promptBox.Text == lastTemplateAutofill then
				promptBox.Text = ""
			end
			lastTemplateAutofill = ""
		end
	end

	local templateOptions = { "None", "Obby Game", "Simulator", "Tycoon", "Combat System" }
	for i, t in ipairs(templateOptions) do
		local label = tostring(t)
		local opt = makeDropdownOption(templatePopup, label)
		opt.LayoutOrder = i
		opt.MouseButton1Click:Connect(function()
			setTemplate(label)
		end)
	end

	templateMain.MouseButton1Click:Connect(function()
		templateOpen = not templateOpen
		if templateOpen then
			local p = toOverlayPos(templateMain)
			templatePopup.Position = UDim2.new(0, p.X, 0, p.Y + templateMain.AbsoluteSize.Y + 6)
			templatePopup.Visible = true
		else
			templatePopup.Visible = false
		end
	end)
end

-- Prompt card: tall field + enhance as icon (bottom-right)
local promptCard = Instance.new("Frame")
promptCard.Name = "PromptCard"
promptCard.BackgroundColor3 = THEME.Card
promptCard.BorderSizePixel = 0
promptCard.Size = UDim2.new(1, 0, 0, 168)
promptCard.LayoutOrder = 3
promptCard.ClipsDescendants = false
promptCard.Parent = promptPanel

local promptCardCorner = Instance.new("UICorner")
promptCardCorner.CornerRadius = THEME.Radius
promptCardCorner.Parent = promptCard

local promptCardStroke = Instance.new("UIStroke")
promptCardStroke.Name = "PromptCardStroke"
promptCardStroke.Color = THEME.Border
promptCardStroke.Thickness = 1
promptCardStroke.Transparency = 0.45
promptCardStroke.Parent = promptCard

local promptInnerPad = Instance.new("UIPadding")
-- Leave room for quick prompt chips (smart-feel).
promptInnerPad.PaddingTop = UDim.new(0, 14)
promptInnerPad.PaddingBottom = UDim.new(0, 14)
promptInnerPad.PaddingLeft = UDim.new(0, 14)
-- Keep the card’s true bottom-right corner intact (so the Enhance button pins correctly).
promptInnerPad.PaddingRight = UDim.new(0, 52)
promptInnerPad.Parent = promptCard

-- Quick prompt chips (lightweight suggestions).
local chipsRow = Instance.new("Frame")
chipsRow.Name = "QuickChips"
chipsRow.BackgroundTransparency = 1
chipsRow.Size = UDim2.new(1, -176, 0, 28)
chipsRow.Position = UDim2.new(0, 12, 0, 10)
chipsRow.ZIndex = 10
chipsRow.Parent = promptCard

local chipsLayout = Instance.new("UIListLayout")
chipsLayout.FillDirection = Enum.FillDirection.Horizontal
chipsLayout.SortOrder = Enum.SortOrder.LayoutOrder
chipsLayout.Padding = UDim.new(0, 8)
chipsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
chipsLayout.Parent = chipsRow

-- Hidden by default; we show auto-suggestions after a successful generation.
chipsRow.Visible = false

local function makeChip(text)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.Text = text
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 11
	b.TextColor3 = Color3.fromRGB(246, 249, 255)
	-- Chips sit on a dark prompt card; use a brighter surface to keep them readable.
	b.BackgroundColor3 = Color3.fromRGB(36, 40, 52)
	b.BorderSizePixel = 0
	b.Size = UDim2.fromOffset(0, 24)
	b.AutomaticSize = Enum.AutomaticSize.X
	b.ZIndex = 11

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = b
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, 10)
	p.PaddingRight = UDim.new(0, 10)
	p.Parent = b
	local s = Instance.new("UIStroke")
	s.Color = THEME.Border
	s.Transparency = 0.35
	s.Thickness = 1
	s.Parent = b

	local sc = Instance.new("UIScale")
	sc.Scale = 1
	sc.Parent = b

	b.MouseEnter:Connect(function()
		if b.Active then
			TweenService:Create(sc, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.04 }):Play()
			TweenService:Create(s, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 0.25 }):Play()
		end
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(sc, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(s, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 0.55 }):Play()
	end)
	b.MouseButton1Down:Connect(function()
		if b.Active then
			TweenService:Create(sc, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.97 }):Play()
		end
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(sc, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.04 }):Play()
	end)

	return b
end

local function applyChipPrompt(text)
	promptBox.Text = tostring(text or "")
	promptBox.PlaceholderText = "💡 Describe your game or feature..."
	pcall(function()
		promptBox:CaptureFocus()
		promptBox.CursorPosition = #promptBox.Text + 1
		promptBox.SelectionStart = #promptBox.Text + 1
		promptBox:ReleaseFocus()
	end)
end

local function clearQuickChips()
	for _, child in ipairs(chipsRow:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function setQuickChips(items)
	clearQuickChips()
	if type(items) ~= "table" or #items == 0 then
		chipsRow.Visible = false
		return
	end
	for i, it in ipairs(items) do
		if type(it) == "table" and type(it.label) == "string" and type(it.prompt) == "string" then
			local c = makeChip(it.label)
			c.LayoutOrder = i
			c.Parent = chipsRow
			c.MouseButton1Click:Connect(function()
				applyChipPrompt(it.prompt)
			end)
		end
	end
	chipsRow.Visible = true
end

local function buildAutoSuggestionsFromPrompt(promptText)
	local p = string.lower(tostring(promptText or ""))
	local suggestions = {}

	local function add(label, lines)
		table.insert(suggestions, {
			label = label,
			prompt = table.concat(lines, "\n"),
		})
	end

	-- Template-ish suggestions (simple heuristics).
	if string.find(p, "obby", 1, true) then
		add("🧱 Obby", {
			"Build a fun Roblox obby with a clear start and finish.",
			"Include checkpoints every 3-4 stages, a few kill/reset parts, and a win screen.",
			"Style: dark neon vibe, soft glow lighting, readable UI.",
		})
	end
	if string.find(p, "tycoon", 1, true) then
		add("🏗️ Tycoon", {
			"Build a Roblox tycoon with droppers, upgrades, and a purchase UI.",
			"Include server validation, data model (session), and clean module structure.",
		})
	end
	if string.find(p, "simulator", 1, true) then
		add("💎 Simulator", {
			"Build a Roblox simulator loop (collect -> upgrade -> unlock).",
			"Include simple UI, progression, and clean server/client boundaries.",
		})
	end
	if string.find(p, "combat", 1, true) or string.find(p, "fight", 1, true) then
		add("⚔️ Combat", {
			"Build a combat system for a Roblox game.",
			"Include: melee + ranged example, damage/health, hit validation server-side, cooldowns, and basic effects.",
			"Add: simple HUD (HP) and clean, extensible modules.",
		})
	end
	if string.find(p, "shop", 1, true) or string.find(p, "store", 1, true) then
		add("🏪 Shop", {
			"Build a shop system for a Roblox game.",
			"Include: currency (leaderstats/session), item catalog, purchase validation server-side, and a clean shop UI.",
			"Add: equip/unequip flow and basic feedback (toast/confirmation).",
		})
	end

	-- Always provide at least a couple useful suggestions after generation.
	if #suggestions == 0 then
		add("🧠 Core System", {
			"Build a robust core game system framework for a Roblox game.",
			"Include: player data model (session-only), state management, events, and clean module structure.",
			"Add: basic UI shell + notifications, and safe server/client boundaries.",
		})
		add("✨ Polish UI", {
			"Improve the game's UI/UX.",
			"Make it readable, consistent, and responsive; add subtle animations and clear feedback.",
		})
	end

	-- Cap to keep the row clean.
	while #suggestions > 4 do
		table.remove(suggestions)
	end
	return suggestions
end

promptBox = Instance.new("TextBox")
promptBox.Name = "PromptBox"
promptBox.PlaceholderText = "💡 Describe your game or feature..."
promptBox.PlaceholderColor3 = THEME.Placeholder
promptBox.Text = ""
promptBox.Size = UDim2.new(1, 0, 1, 0)
promptBox.BackgroundTransparency = 1
promptBox.TextColor3 = THEME.Text
promptBox.ClearTextOnFocus = false
promptBox.TextWrapped = true
promptBox.TextXAlignment = Enum.TextXAlignment.Left
promptBox.TextYAlignment = Enum.TextYAlignment.Top
promptBox.Font = Enum.Font.SourceSans
promptBox.TextSize = 14
promptBox.MultiLine = true
promptBox.ZIndex = 2
promptBox.Parent = promptCard

local promptBoxPad = Instance.new("UIPadding")
-- Leave space so prompt text doesn't render under the quick chips row.
promptBoxPad.PaddingTop = UDim.new(0, 2)
promptBoxPad.PaddingBottom = UDim.new(0, 2)
promptBoxPad.PaddingLeft = UDim.new(0, 0)
promptBoxPad.PaddingRight = UDim.new(0, 0)
promptBoxPad.Parent = promptBox

promptBox.Focused:Connect(function()
	promptCardStroke.Color = THEME.AccentBlue
	promptCardStroke.Transparency = 0.1
	promptCardStroke.Thickness = 1.5
end)
promptBox.FocusLost:Connect(function()
	promptCardStroke.Color = THEME.Border
	promptCardStroke.Transparency = 0.45
	promptCardStroke.Thickness = 1
end)

-- Lightweight autosuggestions popup disabled (user requested removal).
if false then
	local suggestPopup = Instance.new("Frame")
	suggestPopup.Name = "PromptSuggestPopup"
	suggestPopup.BackgroundColor3 = THEME.Surface
	suggestPopup.BorderSizePixel = 0
	suggestPopup.Visible = false
	suggestPopup.Size = UDim2.new(0, 360, 0, 120)
	suggestPopup.ZIndex = 650
	suggestPopup.Parent = overlay

	local suggestCorner = Instance.new("UICorner")
	suggestCorner.CornerRadius = UDim.new(0, 10)
	suggestCorner.Parent = suggestPopup

	local suggestStroke = Instance.new("UIStroke")
	suggestStroke.Color = THEME.Border
	suggestStroke.Thickness = 1
	suggestStroke.Transparency = 0.35
	suggestStroke.Parent = suggestPopup

	local suggestLayout = Instance.new("UIListLayout")
	suggestLayout.FillDirection = Enum.FillDirection.Vertical
	suggestLayout.Padding = UDim.new(0, 6)
	suggestLayout.SortOrder = Enum.SortOrder.LayoutOrder
	suggestLayout.Parent = suggestPopup

	local function makeSuggestRow(text)
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.Text = text
		b.BackgroundColor3 = THEME.Panel
		b.BorderSizePixel = 0
		b.Size = UDim2.new(1, 0, 0, 32)
		b.TextColor3 = THEME.Text
		b.TextTransparency = 0.05
		b.Font = Enum.Font.GothamMedium
		b.TextSize = 12
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.ZIndex = suggestPopup.ZIndex + 1

		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 10)
		pad.Parent = b

		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 10)
		c.Parent = b

		local s = Instance.new("UIStroke")
		s.Color = THEME.Border
		s.Transparency = 0.55
		s.Thickness = 1
		s.Parent = b

		b.MouseEnter:Connect(function()
			if b.Active then
				b.BackgroundColor3 = brighten(THEME.Panel, 1.06)
				TweenService:Create(s, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 0.25 }):Play()
			end
		end)
		b.MouseLeave:Connect(function()
			b.BackgroundColor3 = THEME.Panel
			TweenService:Create(s, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 0.55 }):Play()
		end)

		b.Parent = suggestPopup
		return b
	end

	local rows = {
		makeSuggestRow("🧠 Game System — modular core framework"),
		makeSuggestRow("⚔️ Combat System — melee/ranged + validation"),
		makeSuggestRow("🏪 Shop System — catalog + purchase UI"),
	}

	local function setVisible(on)
		suggestPopup.Visible = on
	end

	local function positionPopup()
		local p = toOverlayPos(promptCard)
		suggestPopup.Position = UDim2.new(0, p.X + 12, 0, p.Y + promptCard.AbsoluteSize.Y + 6)
	end

	rows[1].MouseButton1Click:Connect(function()
		setVisible(false)
		applyChipPrompt(table.concat({
			"Build a robust core game system framework for a Roblox game.",
			"Include: player data model (session-only), state management, events, and clean module structure.",
			"Add: basic UI shell + notifications, and safe server/client boundaries.",
		}, "\n"))
	end)
	rows[2].MouseButton1Click:Connect(function()
		setVisible(false)
		applyChipPrompt(table.concat({
			"Build a combat system for a Roblox game.",
			"Include: melee + ranged example, damage/health, hit validation server-side, cooldowns, and basic effects.",
			"Add: simple HUD (HP) and clean, extensible modules.",
		}, "\n"))
	end)
	rows[3].MouseButton1Click:Connect(function()
		setVisible(false)
		applyChipPrompt(table.concat({
			"Build a shop system for a Roblox game.",
			"Include: currency (leaderstats/session), item catalog, purchase validation server-side, and a clean shop UI.",
			"Add: equip/unequip flow and basic feedback (toast/confirmation).",
		}, "\n"))
	end)

	promptBox.Focused:Connect(function()
		positionPopup()
		setVisible(true)
	end)
	promptBox.FocusLost:Connect(function()
		task.delay(0.1, function()
			setVisible(false)
		end)
	end)
	promptCard:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if suggestPopup.Visible then
			positionPopup()
		end
	end)
end

enhancePromptBtn = Instance.new("TextButton")
enhancePromptBtn.Name = "EnhancePromptBtn"
-- Keep the previous pill button look + font, but use Generate-style hover energy.
enhancePromptBtn.RichText = true
enhancePromptBtn.Text = '<font color="rgb(255,232,150)">⭐</font><font color="rgb(255,255,255)">  Enhance Prompt</font>'
local enhanceBase = Color3.fromRGB(26, 33, 52)
styleButton(enhancePromptBtn, enhanceBase)
enhancePromptBtn.AutoButtonColor = false
enhancePromptBtn.AnchorPoint = Vector2.new(1, 0.5)
enhancePromptBtn.Size = UDim2.new(0, 156, 0, 38)
-- Enhance Prompt lives OUTSIDE the prompt box, aligned bottom-right under it.
local enhanceRow = Instance.new("Frame")
enhanceRow.Name = "EnhanceRow"
enhanceRow.BackgroundTransparency = 1
enhanceRow.Size = UDim2.new(1, 0, 0, 44)
enhanceRow.LayoutOrder = 4
enhanceRow.ZIndex = 30
enhanceRow.Parent = promptPanel

enhancePromptBtn.Position = UDim2.new(1, 0, 0.5, 0)
enhancePromptBtn.ZIndex = 31
enhancePromptBtn.ClipsDescendants = false
enhancePromptBtn.Font = Enum.Font.GothamSemibold
enhancePromptBtn.TextSize = 12
enhancePromptBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
enhancePromptBtn.TextTransparency = 0
enhancePromptBtn.TextStrokeTransparency = 1
enhancePromptBtn.Parent = enhanceRow

local enhanceCorner = Instance.new("UICorner")
enhanceCorner.CornerRadius = THEME.PillRadius
enhanceCorner.Parent = enhancePromptBtn

do
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(56, 139, 253)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(99, 102, 241)),
	})
	g.Rotation = 0
	g.Parent = enhancePromptBtn

	-- Same hover treatment pattern as Generate (glow fades in/out).
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.BackgroundColor3 = Color3.fromRGB(110, 195, 255)
	glow.BackgroundTransparency = 0.86
	glow.BorderSizePixel = 0
	glow.Active = false
	glow.Selectable = false
	glow.Size = UDim2.new(1, 16, 1, 16)
	glow.Position = UDim2.new(0, -8, 0, -8)
	glow.ZIndex = enhancePromptBtn.ZIndex - 1
	glow.Parent = enhancePromptBtn

	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = THEME.ButtonRadius
	glowCorner.Parent = glow

	local glowGrad = Instance.new("UIGradient")
	glowGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(160, 235, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 135, 255)),
	})
	glowGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(1, 1),
	})
	glowGrad.Rotation = 90
	glowGrad.Parent = glow

	local s = enhancePromptBtn:FindFirstChildOfClass("UIStroke")
	if s then
		s.Color = Color3.fromRGB(135, 205, 255)
		s.Transparency = 0.28
		s.Thickness = 2
	end

	enhancePromptBtn.MouseEnter:Connect(function()
		if enhancePromptBtn.Active then
			TweenService:Create(glow, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.78 }):Play()
			if s then
				TweenService:Create(s, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 0.16 }):Play()
			end
		end
	end)
	enhancePromptBtn.MouseLeave:Connect(function()
		TweenService:Create(glow, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.86 }):Play()
		if s then
			TweenService:Create(s, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 0.28 }):Play()
		end
	end)
end

enhanceTooltip = Instance.new("TextLabel")
enhanceTooltip.Name = "EnhanceTooltip"
enhanceTooltip.BackgroundColor3 = THEME.Panel
enhanceTooltip.BackgroundTransparency = 0
enhanceTooltip.BorderSizePixel = 0
enhanceTooltip.Text = "Enhance Prompt"
enhanceTooltip.TextColor3 = Color3.fromRGB(255, 255, 255)
enhanceTooltip.TextSize = 11
enhanceTooltip.Font = Enum.Font.GothamMedium
enhanceTooltip.TextTransparency = 1
enhanceTooltip.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
enhanceTooltip.TextStrokeTransparency = 0.65
enhanceTooltip.TextXAlignment = Enum.TextXAlignment.Center
enhanceTooltip.Size = UDim2.fromOffset(132, 26)
enhanceTooltip.AnchorPoint = Vector2.new(1, 1)
-- Slightly closer to the ⭐ so intent is obvious.
enhanceTooltip.Position = UDim2.new(1, -6, 1, -42)
enhanceTooltip.Visible = false
enhanceTooltip.ZIndex = 20
enhanceTooltip.Parent = promptCard
local enhanceTipCorner = Instance.new("UICorner")
enhanceTipCorner.CornerRadius = UDim.new(0, 8)
enhanceTipCorner.Parent = enhanceTooltip
local enhanceTipStroke = Instance.new("UIStroke")
enhanceTipStroke.Color = THEME.Border
enhanceTipStroke.Transparency = 0.4
enhanceTipStroke.Parent = enhanceTooltip
local enhanceTipPad = Instance.new("UIPadding")
enhanceTipPad.PaddingLeft = UDim.new(0, 8)
enhanceTipPad.PaddingRight = UDim.new(0, 8)
enhanceTipPad.Parent = enhanceTooltip

actionsPanel = addPanel(rootScroll, 0)
actionsPanel.LayoutOrder = 2
actionsPanel.AutomaticSize = Enum.AutomaticSize.Y

local actionsLayout = Instance.new("UIListLayout")
actionsLayout.FillDirection = Enum.FillDirection.Vertical
actionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
actionsLayout.Padding = UDim.new(0, 10)
actionsLayout.Parent = actionsPanel

addSectionLabel(actionsPanel, "Actions").LayoutOrder = 1

-- Single model (configured on server: gpt-5.3-latest by default)
local modelHintRow = Instance.new("Frame")
modelHintRow.Name = "ModelHintRow"
modelHintRow.BackgroundTransparency = 1
modelHintRow.Size = UDim2.new(1, 0, 0, 22)
modelHintRow.LayoutOrder = 2
modelHintRow.Parent = actionsPanel

local modelHintLabel = Instance.new("TextLabel")
modelHintLabel.BackgroundTransparency = 1
modelHintLabel.Size = UDim2.new(1, 0, 1, 0)
modelHintLabel.Font = Enum.Font.GothamMedium
modelHintLabel.TextSize = 10
modelHintLabel.TextColor3 = THEME.Muted
modelHintLabel.TextXAlignment = Enum.TextXAlignment.Center
modelHintLabel.Text = "🤖 AI model: GPT-5.3 latest (one model — fast path)"
modelHintLabel.Parent = modelHintRow

generateBtn = Instance.new("TextButton")
-- Use a dedicated label so the text stays crisp over gradients/glows.
generateBtn.Text = ""
generateBtn.Size = UDim2.new(1, 0, 0, 50)
generateBtn.Position = UDim2.new(0, 0, 0, 0)
generateBtn.LayoutOrder = 3
local generateBase = Color3.fromRGB(42, 108, 235)
styleButton(generateBtn, generateBase)
generateBtn.ClipsDescendants = false

generateLabel = Instance.new("TextLabel")
generateLabel.Name = "GenerateLabel"
generateLabel.BackgroundTransparency = 1
generateLabel.Size = UDim2.new(1, 0, 1, 0)
generateLabel.Position = UDim2.new(0, 0, 0, 0)
-- Ensure the overlay label never intercepts clicks intended for the button.
generateLabel.Active = false
generateLabel.Selectable = false
generateLabel.ClipsDescendants = false
generateLabel.Text = "Generate"
generateLabel.Font = Enum.Font.GothamBold
generateLabel.TextSize = 16
generateLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
generateLabel.TextTransparency = 0
generateLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
generateLabel.TextStrokeTransparency = 0.12
generateLabel.ZIndex = (generateBtn.ZIndex or 1) + 1
generateLabel.Parent = generateBtn

do
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		-- Brighter top for more “pop”.
		ColorSequenceKeypoint.new(0, Color3.fromRGB(92, 175, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(32, 86, 220)),
	})
	g.Rotation = 90
	g.Parent = generateBtn

	-- Soft glow behind the button (premium “click me” energy).
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.BackgroundColor3 = Color3.fromRGB(110, 195, 255)
	glow.BackgroundTransparency = 0.82
	glow.BorderSizePixel = 0
	glow.Active = false
	glow.Selectable = false
	glow.Size = UDim2.new(1, 16, 1, 16)
	glow.Position = UDim2.new(0, -8, 0, -8)
	glow.ZIndex = (generateBtn.ZIndex or 1) - 1
	glow.Parent = generateBtn

	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = THEME.ButtonRadius
	glowCorner.Parent = glow

	local glowGrad = Instance.new("UIGradient")
	glowGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(160, 235, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 135, 255)),
	})
	glowGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(1, 1),
	})
	glowGrad.Rotation = 90
	glowGrad.Parent = glow

	local s = generateBtn:FindFirstChildOfClass("UIStroke")
	if s then
		s.Color = Color3.fromRGB(135, 205, 255)
		s.Transparency = 0.16
		s.Thickness = 2
	end

	-- Extra hover energy (does not affect layout).
	generateBtn.MouseEnter:Connect(function()
		if generateBtn.Active then
			TweenService:Create(glow, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.70 }):Play()
		end
	end)
	generateBtn.MouseLeave:Connect(function()
		TweenService:Create(glow, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.82 }):Play()
	end)
end

generateBtn.Parent = actionsPanel

-- Swap-in Stop button (replaces Generate while busy).
stopBtn = Instance.new("TextButton")
stopBtn.Name = "StopBtn"
stopBtn.AutoButtonColor = false
-- Use an overlay label for crisper text (matches Generate button treatment).
stopBtn.Text = ""
stopBtn.Size = UDim2.new(1, 0, 0, 50)
stopBtn.Position = UDim2.new(0, 0, 0, 0)
stopBtn.LayoutOrder = 3
local stopBase = Color3.fromRGB(94, 38, 46)
styleButton(stopBtn, stopBase)
stopBtn.TextSize = 16
stopBtn.Font = Enum.Font.GothamBold
stopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
stopBtn.TextTransparency = 1
stopBtn.TextStrokeTransparency = 1
stopBtn.ClipsDescendants = false

local stopLabel = Instance.new("TextLabel")
stopLabel.Name = "StopLabel"
stopLabel.BackgroundTransparency = 1
stopLabel.Size = UDim2.new(1, 0, 1, 0)
stopLabel.Position = UDim2.new(0, 0, 0, 0)
stopLabel.Active = false
stopLabel.Selectable = false
stopLabel.ClipsDescendants = false
stopLabel.Text = "Stop"
stopLabel.Font = Enum.Font.GothamBold
stopLabel.TextSize = 16
stopLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
stopLabel.TextTransparency = 0
stopLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
stopLabel.TextStrokeTransparency = 0.12
stopLabel.ZIndex = (stopBtn.ZIndex or 1) + 1
stopLabel.Parent = stopBtn
do
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 72, 92)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(132, 36, 54)),
	})
	g.Rotation = 90
	g.Parent = stopBtn

	-- Soft red glow (matches Generate premium feel).
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.BackgroundColor3 = Color3.fromRGB(255, 120, 145)
	glow.BackgroundTransparency = 0.86
	glow.BorderSizePixel = 0
	glow.Active = false
	glow.Selectable = false
	glow.Size = UDim2.new(1, 16, 1, 16)
	glow.Position = UDim2.new(0, -8, 0, -8)
	glow.ZIndex = (stopBtn.ZIndex or 1) - 1
	glow.Parent = stopBtn

	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = THEME.ButtonRadius
	glowCorner.Parent = glow

	local glowGrad = Instance.new("UIGradient")
	glowGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 170, 190)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 72, 92)),
	})
	glowGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	glowGrad.Rotation = 90
	glowGrad.Parent = glow

	local s = stopBtn:FindFirstChildOfClass("UIStroke")
	if s then
		s.Color = Color3.fromRGB(255, 150, 170)
		s.Transparency = 0.25
		s.Thickness = 2
	end

	stopBtn.MouseEnter:Connect(function()
		if stopBtn.Active then
			TweenService:Create(glow, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.78 }):Play()
		end
	end)
	stopBtn.MouseLeave:Connect(function()
		TweenService:Create(glow, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.86 }):Play()
	end)
end
stopBtn.Visible = false
stopBtn.Parent = actionsPanel

local secondaryRow = Instance.new("Frame")
secondaryRow.BackgroundTransparency = 1
secondaryRow.Size = UDim2.new(1, 0, 0, 34)
secondaryRow.LayoutOrder = 3
secondaryRow.Parent = actionsPanel
secondaryRow.Visible = true

local secondaryLayout = Instance.new("UIListLayout")
secondaryLayout.FillDirection = Enum.FillDirection.Horizontal
secondaryLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
secondaryLayout.SortOrder = Enum.SortOrder.LayoutOrder
secondaryLayout.Padding = UDim.new(0, 8)
secondaryLayout.Parent = secondaryRow

addFeatureBtn = Instance.new("TextButton")
addFeatureBtn.Text = "⚡ Add Feature"
addFeatureBtn.Size = UDim2.new(0.333, -6, 0, 32)
addFeatureBtn.Position = UDim2.new(0, 0, 0, 0)
addFeatureBtn.LayoutOrder = 1
styleButton(addFeatureBtn, THEME.SecondaryBtn)
addFeatureBtn.TextSize = 12
addFeatureBtn.Font = Enum.Font.GothamSemibold
addFeatureBtn.TextColor3 = THEME.Text
do
	local s = addFeatureBtn:FindFirstChildOfClass("UIStroke")
	if s then
		s.Color = Color3.fromRGB(120, 190, 255)
		s.Transparency = 0.35
	end
end
addFeatureBtn.Parent = secondaryRow

fixBugsBtn = Instance.new("TextButton")
fixBugsBtn.Text = "🐞 Fix Bugs"
fixBugsBtn.Size = UDim2.new(0.333, -6, 0, 32)
fixBugsBtn.Position = UDim2.new(0, 0, 0, 0)
fixBugsBtn.LayoutOrder = 2
styleButton(fixBugsBtn, THEME.SecondaryBtn)
fixBugsBtn.TextSize = 12
fixBugsBtn.Font = Enum.Font.GothamSemibold
fixBugsBtn.TextColor3 = THEME.Text
do
	local s = fixBugsBtn:FindFirstChildOfClass("UIStroke")
	if s then
		s.Color = Color3.fromRGB(255, 185, 120)
		s.Transparency = 0.35
	end
end
fixBugsBtn.Parent = secondaryRow

optimizeBtn = Instance.new("TextButton")
optimizeBtn.Text = "🚀 Optimize"
optimizeBtn.Size = UDim2.new(0.333, -6, 0, 32)
optimizeBtn.Position = UDim2.new(0, 0, 0, 0)
optimizeBtn.LayoutOrder = 3
styleButton(optimizeBtn, THEME.SecondaryBtn)
optimizeBtn.TextSize = 12
optimizeBtn.Font = Enum.Font.GothamSemibold
optimizeBtn.TextColor3 = THEME.Text
do
	local s = optimizeBtn:FindFirstChildOfClass("UIStroke")
	if s then
		s.Color = Color3.fromRGB(150, 255, 190)
		s.Transparency = 0.35
	end
end
optimizeBtn.Parent = secondaryRow

local controlRow = Instance.new("Frame")
controlRow.BackgroundTransparency = 1
controlRow.Size = UDim2.new(1, 0, 0, 32)
controlRow.LayoutOrder = 4
controlRow.Parent = actionsPanel

clearBtn = Instance.new("TextButton")
clearBtn.Name = "ClearBuildBtn"
clearBtn.Text = "Clear Build"
clearBtn.Size = UDim2.new(0, 100, 0, 30)
clearBtn.Position = UDim2.new(1, 0, 0.5, 0)
clearBtn.AnchorPoint = Vector2.new(1, 0.5)
local clearBase = Color3.fromRGB(72, 36, 40)
styleButton(clearBtn, clearBase)
clearBtn.TextSize = 12
clearBtn.Font = Enum.Font.GothamSemibold
clearBtn.TextColor3 = Color3.fromRGB(255, 220, 220)
do
	local s = clearBtn:FindFirstChildOfClass("UIStroke")
	if s then
		s.Color = THEME.Danger
		s.Transparency = 0.25
	end
end
clearBtn.Parent = controlRow

local historyRow = Instance.new("Frame")
historyRow.BackgroundTransparency = 1
historyRow.Size = UDim2.new(1, 0, 0, 0)
historyRow.LayoutOrder = 5
historyRow.Parent = actionsPanel
historyRow.Visible = false

local historyLayout = Instance.new("UIListLayout")
historyLayout.FillDirection = Enum.FillDirection.Horizontal
historyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
historyLayout.SortOrder = Enum.SortOrder.LayoutOrder
historyLayout.Padding = UDim.new(0, 8)
historyLayout.Parent = historyRow

local outputPanel = addPanel(rootScroll, 0)
outputPanel.LayoutOrder = 3
outputPanel.AutomaticSize = Enum.AutomaticSize.Y
outputPanel.Visible = true

local outputLayout = Instance.new("UIListLayout")
outputLayout.FillDirection = Enum.FillDirection.Vertical
outputLayout.SortOrder = Enum.SortOrder.LayoutOrder
outputLayout.Padding = UDim.new(0, 10)
outputLayout.Parent = outputPanel

local outputLabel = addSectionLabel(outputPanel, "AI Console")
outputLabel.LayoutOrder = 1
outputLabel.Visible = true

local outputInner = Instance.new("Frame")
outputInner.BackgroundTransparency = 1
outputInner.Size = UDim2.new(1, 0, 1, 0)
outputInner.LayoutOrder = 2
outputInner.Parent = outputPanel

local outputInnerLayout = Instance.new("UIListLayout")
outputInnerLayout.FillDirection = Enum.FillDirection.Vertical
outputInnerLayout.SortOrder = Enum.SortOrder.LayoutOrder
outputInnerLayout.Padding = UDim.new(0, 8)
outputInnerLayout.Parent = outputInner

planScroll = Instance.new("ScrollingFrame")
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
planCorner.CornerRadius = THEME.Radius
planCorner.Parent = planScroll

local planStroke = Instance.new("UIStroke")
planStroke.Color = THEME.Border
planStroke.Thickness = 1
planStroke.Transparency = 0.5
planStroke.Parent = planScroll

planScroll.Parent = outputInner

planBox = Instance.new("TextLabel")
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

logScroll = Instance.new("ScrollingFrame")
logScroll.Size = UDim2.new(1, 0, 0, 180)
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

local logPad = Instance.new("UIPadding")
logPad.PaddingLeft = UDim.new(0, 12)
logPad.PaddingRight = UDim.new(0, 12)
logPad.PaddingTop = UDim.new(0, 10)
logPad.PaddingBottom = UDim.new(0, 10)
logPad.Parent = logScroll

local logCorner = Instance.new("UICorner")
logCorner.CornerRadius = THEME.Radius
logCorner.Parent = logScroll

local logStroke = Instance.new("UIStroke")
logStroke.Color = THEME.Border
logStroke.Thickness = 1
logStroke.Transparency = 0.5
logStroke.Parent = logScroll

logScroll.Parent = outputInner

logBox = Instance.new("TextLabel")
logBox.Text = "Idle."
logBox.Size = UDim2.new(1, 0, 0, 0)
logBox.Position = UDim2.new(0, 0, 0, 0)
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

end -- UI construction scope

local HttpService = game:GetService("HttpService")
local InsertService = game:GetService("InsertService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local StarterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")

-- Single-script build: embed StructuredBuild as a local module (isolated function scope).
local StructuredBuild = (function()
	local workspace = game:GetService("Workspace")
	local ServerScriptService = game:GetService("ServerScriptService")
	local StarterGui = game:GetService("StarterGui")
	local StarterPlayer = game:GetService("StarterPlayer")
	local StarterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")

	local ROOT_FOLDER_NAME = "AI_Build"

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

	local function clearGeneratedBuild()
		local removed = 0
		local w = workspace:FindFirstChild(ROOT_FOLDER_NAME)
		if w then
			if pcall(function()
				w:Destroy()
			end) then
				removed += 1
			end
		end
		local s = ServerScriptService:FindFirstChild(ROOT_FOLDER_NAME)
		if s then
			if pcall(function()
				s:Destroy()
			end) then
				removed += 1
			end
		end
		local g = StarterGui:FindFirstChild(ROOT_FOLDER_NAME)
		if g then
			if pcall(function()
				g:Destroy()
			end) then
				removed += 1
			end
		end
		local sps = StarterPlayerScripts:FindFirstChild(ROOT_FOLDER_NAME)
		if sps then
			if pcall(function()
				sps:Destroy()
			end) then
				removed += 1
			end
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
			local r, g, b = v:match("@{r=([%-%d%.]+)%s*;%s*g=([%-%d%.]+)%s*;%s*b=([%-%d%.]+)%s*}")
			if r and g and b then
				r, g, b = tonumber(r), tonumber(g), tonumber(b)
				if r and g and b then
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

	local function applyStructuredBuild(build, recordHistory)
		if type(build) ~= "table" or type(build.instances) ~= "table" then
			return false, "Invalid build payload"
		end

		if recordHistory == nil then
			recordHistory = true
		end

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
								if c then
									inst[k] = c
								end
							elseif
								k == "Position"
								or k == "Size"
								or k == "Rotation"
								or k == "StudsOffset"
								or k == "StudsOffsetWorldSpace"
							then
								local vec = toVector3(v)
								if vec then
									inst[k] = vec
								end
							elseif k == "BrickColor" then
								if type(v) == "string" then
									pcall(function()
										inst[k] = BrickColor.new(v)
									end)
								end
							elseif k == "CFrame" then
								local cf = toCFrame(v)
								if cf then
									inst.CFrame = cf
								end
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

			if
				(inst:IsA("Script") or inst:IsA("LocalScript") or inst:IsA("ModuleScript"))
				and type(spec.source) == "string"
			then
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

	return {
		getOrCreateFolder = getOrCreateFolder,
		ensureAiFolders = ensureAiFolders,
		clearGeneratedBuild = clearGeneratedBuild,
		applyStructuredBuild = applyStructuredBuild,
	}
end)()

local ROOT_FOLDER_NAME = "AI_Build"
local GENERATED_GAME_NAME = "GeneratedGame"

-- Production (Render). For local testing use http://127.0.0.1:3000 instead.
local DEFAULT_API_BASE = "https://robloxvb.onrender.com"

-- If your backend has BACKEND_API_KEY set, paste the same value here so requests succeed.
-- Leave empty if your backend does not require an API key (local testing only).
local BACKEND_API_KEY = ""

-- Optional micro-sound (set to a valid rbxassetid://... you own if desired).
local TICK_SOUND_ID = ""

local function playTick()
	if TICK_SOUND_ID == "" then
		return
	end
	pcall(function()
		local s = Instance.new("Sound")
		s.Name = "AIAssistantTick"
		s.SoundId = TICK_SOUND_ID
		s.Volume = 0.25
		s.PlaybackSpeed = 1.05
		s.Parent = SoundService
		SoundService:PlayLocalSound(s)
		task.delay(1.5, function()
			pcall(function()
				s:Destroy()
			end)
		end)
	end)
end

local function getApiBase()
	return DEFAULT_API_BASE
end

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

local function getTemplateClause()
	if selectedTemplate == "None" then
		return ""
	end
	return ("\n\nTemplate preference: %s (use it as a strong starting point when applicable)."):format(selectedTemplate)
end

local function extractScriptNamesFromStructuredBuild(build)
	local names = {}
	if type(build) ~= "table" or type(build.instances) ~= "table" then
		return names
	end
	for _, inst in ipairs(build.instances) do
		if type(inst) == "table" then
			local cn = inst.className
			if cn == "Script" or cn == "LocalScript" or cn == "ModuleScript" then
				local n = inst.name or inst.id or cn
				if n and n ~= "" then
					table.insert(names, tostring(n))
				end
			end
		end
	end
	return names
end

local function getMemoryContextText()
	if #memoryEntries == 0 then
		return ""
	end

	local parts = {}
	table.insert(parts, "Memory context (previous builds):")
	local startAt = math.max(1, #memoryEntries - 2)
	for i = startAt, #memoryEntries do
		local e = memoryEntries[i]
		if e and e.prompt then
			local scripts = e.scripts and #e.scripts > 0 and table.concat(e.scripts, ", ") or "none"
			table.insert(parts, ("- Prompt: %s\n  Scripts: %s"):format(tostring(e.prompt), scripts))
		end
	end
	return table.concat(parts, "\n")
end

local function augmentPromptForAI(promptText)
	local s = tostring(promptText or "")
	s = s .. getTemplateClause()
	local mem = getMemoryContextText()
	if mem ~= "" then
		s = s .. ("\n\n%s"):format(mem)
	end
	return s
end

local function saveMemoryFromStructuredBuild(promptText, build)
	-- Store a compact "generated scripts" memory for the next request.
	-- We keep only script names + a short source snippet (privacy/perf friendly).
	local scripts = {}
	if type(build) == "table" and type(build.instances) == "table" then
		for _, inst in ipairs(build.instances) do
			if type(inst) == "table" then
				local cn = inst.className
				if cn == "Script" or cn == "LocalScript" or cn == "ModuleScript" then
					local n = inst.name or inst.id or cn
					if n and n ~= "" then
						local src = tostring(inst.source or "")
						src = src:gsub("\r", ""):gsub("\n", " ")
						if #src > 0 then
							src = string.sub(src, 1, 180)
							table.insert(scripts, tostring(n) .. ": " .. src)
						else
							table.insert(scripts, tostring(n))
						end
					end
				end
			end
		end
	end

	table.insert(memoryEntries, {
		prompt = tostring(promptText or ""),
		scripts = scripts,
	})
	while #memoryEntries > MAX_MEMORY_ENTRIES do
		table.remove(memoryEntries, 1)
	end
end

-- Always "fast" so structured /ai-final does not run a second "upgrade" OpenAI pass.
local function modelTierForApi()
	return "fast"
end

-- Backend sets modelUpgraded when the second (stronger) model pass replaced the fast output.
local function modelUpgradedFromResponse(data)
	if type(data) ~= "table" then
		return false
	end
	local v = data.modelUpgraded
	if v == true then
		return true
	end
	if type(v) == "string" then
		local s = string.lower((v:gsub("^%s+", ""):gsub("%s+$", "")))
		return s == "true" or s == "1"
	end
	return false
end

local typingToken = 0
local cursorToken = 0
local function setCursorVisible(visible)
	if #logLines == 0 then
		logLines = { "" }
	end
	local tail = logLines[#logLines] or ""
	local has = string.sub(tail, -1) == "▍"
	if visible and not has then
		logLines[#logLines] = tail .. "▍"
	elseif (not visible) and has then
		logLines[#logLines] = string.sub(tail, 1, #tail - 1)
	end
	logBox.Text = table.concat(logLines, "\n")
	refreshLogScroll()
end

local function startBlinkingCursor(requestCancelToken)
	requestCancelToken = requestCancelToken or cancelToken
	cursorToken += 1
	local myCursor = cursorToken
	task.spawn(function()
		local on = true
		while cursorToken == myCursor and cancelToken == requestCancelToken do
			setCursorVisible(on)
			on = not on
			task.wait(0.22)
		end
		if cursorToken == myCursor then
			-- ensure cursor is off when stopping
			setCursorVisible(false)
		end
	end)
	return function()
		if cursorToken == myCursor then
			cursorToken += 1
			setCursorVisible(false)
		end
	end
end

local function typewriterAppendLog(fullText, requestCancelToken, speedSecondsPerChar)
	requestCancelToken = requestCancelToken or cancelToken
	speedSecondsPerChar = speedSecondsPerChar or 0.002

	typingToken += 1
	local myTyping = typingToken

	local text = tostring(fullText or "")
	table.insert(logLines, "")
	local targetIndex = #logLines
	logBox.Text = table.concat(logLines, "\n")
	refreshLogScroll()

	for i = 1, #text do
		if cancelToken ~= requestCancelToken then
			return
		end
		if myTyping ~= typingToken then
			return
		end
		logLines[targetIndex] = string.sub(text, 1, i)
		logBox.Text = table.concat(logLines, "\n")
		refreshLogScroll()
		task.wait(speedSecondsPerChar)
	end
end

local function streamWordsAppendLog(fullText, requestCancelToken, secondsPerWord)
	requestCancelToken = requestCancelToken or cancelToken
	secondsPerWord = secondsPerWord or 0.02

	typingToken += 1
	local myTyping = typingToken

	local text = tostring(fullText or "")
	table.insert(logLines, "")
	local targetIndex = #logLines
	logBox.Text = table.concat(logLines, "\n")
	refreshLogScroll()

	local stopCursor = startBlinkingCursor(requestCancelToken)
	local out = ""
	for word in string.gmatch(text, "%S+") do
		if cancelToken ~= requestCancelToken then
			stopCursor()
			return
		end
		if myTyping ~= typingToken then
			stopCursor()
			return
		end
		if out == "" then
			out = word
		else
			out = out .. " " .. word
		end
		logLines[targetIndex] = out
		logBox.Text = table.concat(logLines, "\n")
		refreshLogScroll()
		task.wait(secondsPerWord)
	end
	stopCursor()
end

local function startConsoleLoader(baseText, requestCancelToken)
	requestCancelToken = requestCancelToken or cancelToken
	local text = tostring(baseText or "")
	table.insert(logLines, text)
	local targetIndex = #logLines
	logBox.Text = table.concat(logLines, "\n")
	refreshLogScroll()

	local stopCursor = startBlinkingCursor(requestCancelToken)
	local alive = true
	task.spawn(function()
		local dots = 0
		while alive and cancelToken == requestCancelToken do
			dots = (dots % 3) + 1
			-- Keep cursor on this line via global cursor toggler.
			logLines[targetIndex] = text .. string.rep(".", dots)
			logBox.Text = table.concat(logLines, "\n")
			refreshLogScroll()
			task.wait(0.28)
		end
	end)

	return function()
		alive = false
		stopCursor()
	end
end

local function appendConsoleLine(line, opts)
	opts = opts or {}
	local text = tostring(line or "")
	if opts.streamWords then
		streamWordsAppendLog(text, cancelToken, opts.secondsPerWord)
		return
	end
	if opts.typewriter then
		typewriterAppendLog(text, cancelToken, opts.speedSecondsPerChar)
		return
	end
	appendLog(text)
end

-- Keep Toolbox logs clean by default. Set true only when debugging asset IDs.
local TOOLBOX_VERBOSE_LOGS = false
-- When true, suppress ALL toolbox-related log lines (success + errors).
local TOOLBOX_SILENT = true

local generateAnimToken = 0
local function setActionStatus(text)
	-- Status label removed for a cleaner UI.
end

-- Status micro-animation (keeps the UI feeling alive without being distracting).
local statusPulseToken = 0
local function setActionStatusAnimated(text, pulse)
	setActionStatus(text)
	if not pulse or not actionStatus or not actionStatus.Parent then
		return
	end
	statusPulseToken += 1
	local myPulse = statusPulseToken
	task.spawn(function()
		-- Quick pulse: fade slightly in/out 2x
		for _ = 1, 2 do
			if statusPulseToken ~= myPulse then return end
			TweenService:Create(actionStatus, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0.22 }):Play()
			task.wait(0.24)
			if statusPulseToken ~= myPulse then return end
			TweenService:Create(actionStatus, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0.05 }):Play()
			task.wait(0.24)
		end
	end)
end

local function setButtonsEnabled(enabled)
	local function setVisual(btn, isActive)
		btn.Active = isActive

		local bc = btn:GetAttribute("BaseColor")
		if typeof(bc) == "Color3" then
			btn.BackgroundColor3 = isActive and bc or brighten(bc, 0.82)
		end

		-- Keep primary text crisp (Generate/Stop), but allow slight dim on secondary buttons.
		if btn == generateBtn or btn == stopBtn or btn == enhancePromptBtn then
			btn.TextTransparency = 0
			if btn == generateBtn and generateLabel then
				generateLabel.TextTransparency = 0
			end
		else
			btn.TextTransparency = isActive and 0 or 0.25
		end
	end

	-- Status pill UI disabled (hide always)
	statusPill.Visible = false

	setVisual(generateBtn, enabled)
	setVisual(addFeatureBtn, enabled)
	setVisual(fixBugsBtn, enabled)
	setVisual(optimizeBtn, enabled)
	setVisual(clearBtn, enabled)
	setVisual(enhancePromptBtn, enabled)

	local busy = not enabled
	generateBtn.Visible = not busy
	stopBtn.Visible = busy
	setVisual(stopBtn, busy)

	if enabled then
		generateAnimToken += 1
		if generateLabel then
			generateLabel.Text = "Generate"
		end
		setActionStatus("⚡ Ready")
		local gsc = generateBtn:FindFirstChildOfClass("UIScale")
		if gsc then
			gsc.Scale = 1
		end
	end
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
	local headers = {
		["Content-Type"] = "application/json",
	}
	if BACKEND_API_KEY ~= "" then
		headers["x-api-key"] = BACKEND_API_KEY
	end

	local ok, resp = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = "POST",
			Headers = headers,
			Body = HttpService:JSONEncode(body),
		})
	end)
	if not ok then
		local msg = tostring(resp)
		local lower = string.lower(msg)
		-- In Studio, HttpService.HttpEnabled can be stale/false even after toggling.
		-- Prefer detecting the real platform error and guiding the user.
		if string.find(lower, "http requests are not enabled", 1, true)
			or string.find(lower, "http requests are disabled", 1, true)
			or string.find(lower, "httprequestsaredisabled", 1, true)
		then
			return nil,
				"HTTP requests are disabled. In Roblox Studio open Game Settings → Security → enable Allow HTTP Requests, click Save, then restart Studio."
		end
		return nil, msg
	end
	if type(resp) ~= "table" then
		return nil, "Invalid HTTP response"
	end
	if resp.Success ~= true then
		local code = tonumber(resp.StatusCode) or 0
		if code == 401 then
			return nil, "Unauthorized. If your backend uses BACKEND_API_KEY, set BACKEND_API_KEY in this plugin to match."
		elseif code == 429 then
			return nil, "Rate limited. Try again in a moment."
		end
		return nil, ("HTTP %s: %s"):format(tostring(resp.StatusCode), tostring(resp.StatusMessage))
	end

	local decodeOk, dataOrError = pcall(function()
		return HttpService:JSONDecode(resp.Body or "")
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
		local hint = "Try again in a moment."
		if string.find(string.lower(url), "onrender.com", 1, true) then
			hint =
				"Free Render often needs 1–2 min to wake after sleep—open " .. getApiBase() .. "/health in a browser once, wait until you see JSON, then retry."
		end
		resultErr = "Request timed out. " .. hint
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
	setActionStatus("⚡ Ready")
	setLog("Cancelled.")
end)

local function ensureToolboxFolder()
	local root = StructuredBuild.getOrCreateFolder(workspace, ROOT_FOLDER_NAME)
	return StructuredBuild.getOrCreateFolder(root, "ToolboxAssets")
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

local INSERTABLE_ASSET_TYPE_IDS = {
	[Enum.AssetType.Model.Value] = true,
}

local function getInsertabilityInfo(assetId)
	local okInfo, infoOrErr = pcall(function()
		return MarketplaceService:GetProductInfo(assetId)
	end)
	if not okInfo or type(infoOrErr) ~= "table" then
		return false, ("GetProductInfo failed: %s"):format(tostring(infoOrErr))
	end

	local assetTypeId = tonumber(infoOrErr.AssetTypeId)
	if not assetTypeId then
		return false, "Missing AssetTypeId"
	end
	if not INSERTABLE_ASSET_TYPE_IDS[assetTypeId] then
		return false, ("Not insertable via InsertService (AssetTypeId=%s)"):format(tostring(assetTypeId))
	end

	if infoOrErr.IsForSale == false and infoOrErr.IsPublicDomain == false then
		return false, "Not for sale / not public domain"
	end

	return true, nil
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
	local skipped = 0
	local failed = 0
	for _, aid in ipairs(assetList) do
		local id = nil
		if type(aid) == "number" and aid > 0 then
			id = aid
		elseif type(aid) == "string" then
			id = tonumber(aid)
		end
		if id then
			local okCheck, reason = getInsertabilityInfo(id)
			if not okCheck then
				skipped += 1
				if not TOOLBOX_SILENT and TOOLBOX_VERBOSE_LOGS then
					appendLog(("Toolbox: skipped asset %s: %s"):format(tostring(id), tostring(reason)))
				end
				continue
			end

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
					failed += 1
					if not TOOLBOX_SILENT and TOOLBOX_VERBOSE_LOGS then
						appendLog(("Toolbox: empty package for asset %s"):format(tostring(id)))
					end
				end
				pack:Destroy()
			else
				failed += 1
				if not TOOLBOX_SILENT and TOOLBOX_VERBOSE_LOGS then
					appendLog(("Toolbox: LoadAsset failed for %s: %s"):format(tostring(id), tostring(pack)))
				end
			end
			task.wait(0.15)
		end
	end
	if not TOOLBOX_SILENT and (skipped > 0 or failed > 0) then
		appendLog(("Toolbox: placed %d | skipped %d | failed %d"):format(placed, skipped, failed))
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
	local root = StructuredBuild.getOrCreateFolder(workspace, GENERATED_GAME_NAME)
	StructuredBuild.getOrCreateFolder(root, "Map")
	StructuredBuild.getOrCreateFolder(root, "Assets")
	StructuredBuild.getOrCreateFolder(root, "NPCs")
	StructuredBuild.getOrCreateFolder(root, "Scripts")
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
	local folder = StructuredBuild.getOrCreateFolder(service, GENERATED_GAME_NAME)
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
	local skipped = 0
	local failed = 0
	for _, aid in ipairs(assetList) do
		local id = nil
		if type(aid) == "number" and aid > 0 then
			id = aid
		elseif type(aid) == "string" then
			id = tonumber(aid)
		end
		if id then
			local okCheck, reason = getInsertabilityInfo(id)
			if not okCheck then
				skipped += 1
				if not TOOLBOX_SILENT and TOOLBOX_VERBOSE_LOGS then
					appendLog(("Hybrid: skipped asset %s: %s"):format(tostring(id), tostring(reason)))
				end
				continue
			end

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
					failed += 1
					if not TOOLBOX_SILENT and TOOLBOX_VERBOSE_LOGS then
						appendLog(("Hybrid: empty package for %s"):format(tostring(id)))
					end
				end
				pack:Destroy()
			else
				failed += 1
				if not TOOLBOX_SILENT and TOOLBOX_VERBOSE_LOGS then
					appendLog(("Hybrid: LoadAsset failed for %s: %s"):format(tostring(id), tostring(pack)))
				end
			end
			task.wait(0.15)
		end
	end
	if not TOOLBOX_SILENT and (skipped > 0 or failed > 0) then
		appendLog(("Hybrid assets: placed %d | skipped %d | failed %d"):format(placed, skipped, failed))
	end
	return placed
end

-- Structured build mode inserts into AI_Build; this keeps toolbox assets in the same area.
local function insertAssetsIntoAiBuild(assetList)
	if type(assetList) ~= "table" then
		return 0
	end
	local folders = StructuredBuild.ensureAiFolders()
	local assetsFolder = StructuredBuild.getOrCreateFolder(folders.workspace, "Assets")
	local placed = 0
	local skipped = 0
	local failed = 0
	for _, aid in ipairs(assetList) do
		local id = nil
		if type(aid) == "number" and aid > 0 then
			id = aid
		elseif type(aid) == "string" then
			id = tonumber(aid)
		end
		if id then
			local okCheck, reason = getInsertabilityInfo(id)
			if not okCheck then
				skipped += 1
				if not TOOLBOX_SILENT and TOOLBOX_VERBOSE_LOGS then
					appendLog(("Toolbox: skipped asset %s: %s"):format(tostring(id), tostring(reason)))
				end
				continue
			end

			local okPack, pack = pcall(function()
				return InsertService:LoadAsset(id)
			end)
			if okPack and pack then
				local child = pack:GetChildren()[1]
				if child then
					stripImportedScripts(child)
					child.Name = "ToolboxAsset_" .. tostring(id)
					child.Parent = assetsFolder
					placed += 1
					layoutInsertedModel(child, placed)
				else
					failed += 1
					if not TOOLBOX_SILENT and TOOLBOX_VERBOSE_LOGS then
						appendLog(("Toolbox: empty package for %s"):format(tostring(id)))
					end
				end
				pack:Destroy()
			else
				failed += 1
				if not TOOLBOX_SILENT and TOOLBOX_VERBOSE_LOGS then
					appendLog(("Toolbox: LoadAsset failed for %s: %s"):format(tostring(id), tostring(pack)))
				end
			end
			task.wait(0.15)
		end
	end
	if not TOOLBOX_SILENT and (skipped > 0 or failed > 0) then
		appendLog(("Toolbox: placed %d | skipped %d | failed %d"):format(placed, skipped, failed))
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
		local assetStyle = guessAssetStyleFromPrompt(promptText)
		local assetLine = ""
		if type(plan.assets) == "table" and #plan.assets > 0 then
			assetLine = table.concat(plan.assets, ", ")
		end
		if assetLine ~= "" then
			local dataA, errA = requestWithTimeout(getApiBase() .. "/generate-assets", {
				prompt = assetLine,
				style = assetStyle,
				regenerate = false,
				maxAssets = 12,
			}, 120)
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
		local data, err = requestWithTimeout(getApiBase() .. "/hybrid-generate", {
			prompt = promptText,
			enhance = hybridAiBoost,
			forceAiOnly = hybridForceAiOnly,
		}, 180)
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

clearBtn.MouseButton1Click:Connect(function()
	if isBusy then return end
	local removed = StructuredBuild.clearGeneratedBuild()
	lastStructuredBuild = nil
	lastPrompt = ""
	promptBox.Text = ""
	promptBox.PlaceholderText = "💡 Describe your game or feature..."
	setQuickChips({})
	setLog(("Cleared AI build folders: %d"):format(removed))
	setButtonsEnabled(true)
end)

local function guessAssetStyleFromPrompt(promptText)
	local p = string.lower(tostring(promptText or ""))
	-- Heuristic: if user asks for stylized/cartoon/pixel/low-poly, bias asset search.
	if string.find(p, "cartoon", 1, true)
		or string.find(p, "stylized", 1, true)
		or string.find(p, "pixel", 1, true)
		or string.find(p, "low poly", 1, true)
	then
		return "cartoon"
	end
	return "realistic"
end

local function autoImportToolboxEnvironmentAssets(gamePromptText, requestToken)
	if cancelToken ~= requestToken then
		return
	end

	local assetStyle = guessAssetStyleFromPrompt(gamePromptText)

	-- Nudge the keyword extractor to focus on "environment / set dressing" assets.
	-- The backend turns this into Toolbox search keyword phrases and returns matching asset IDs.
	local envPrompt = tostring(gamePromptText or "") .. "\n\nEnvironment focus: choose the best scenery/set-dressing props for this game (terrain/landscaping, decor, walls/structures, lighting, atmosphere)."

	local data, err = requestWithTimeout(getApiBase() .. "/generate-assets", {
		prompt = envPrompt,
		style = assetStyle,
		regenerate = false,
		maxAssets = 12,
	}, 120)

	if cancelToken ~= requestToken then
		return
	end

	if err then
		-- Silent by default (toolbox failures are common due to permissions).
		return
	end

	if type(data) == "table" and data.success ~= false and type(data.assets) == "table" then
		local placed = insertAssetsIntoAiBuild(data.assets)
		-- Silent by default; assets appear in AI_Build/Assets if any were insertable.
		return
	end

	if type(data) == "table" and data.success == false then
		-- Silent by default.
		return
	end
	-- Silent by default.
end

local function getTemplateMechanicsGuide()
	if selectedTemplate == "Obby Game" then
		return table.concat({
			"Include: spawn area, sequential obstacles, checkpoints, fail/reset zones, and a fair landing path.",
			"Add: progression UI (e.g., checkpoint count), difficulty ramp, and clear win condition.",
		}, "\n")
	elseif selectedTemplate == "Tycoon" then
		return table.concat({
			"Include: economy/leaderstats (cash), purchasable upgrades, and a simple scaling production loop.",
			"Add: player growth loop, spawn safety, and basic UI for upgrades.",
		}, "\n")
	elseif selectedTemplate == "Simulator" then
		return table.concat({
			"Include: core click/loop mechanic, progression counter, and upgrade path.",
			"Add: objective hints, scaling rewards, and a restart/rebirth loop if it fits.",
		}, "\n")
	elseif selectedTemplate == "Combat System" then
		return table.concat({
			"Include: damage/health model, cooldowns, server-side hit validation, and simple effects/feedback.",
			"Add: clean module structure so weapons/skills can be extended safely.",
		}, "\n")
	end
	return ""
end

local function runAgentRefine(instructionText, agentLabel)
	if inPlayClientMode() then
		setLog((agentLabel or "Action") .. " works only in Edit mode. Stop Play and try again.")
		return
	end
	if isBusy then return end
	if not lastStructuredBuild then
		setLog((agentLabel or "Action") .. " requires an existing build. Generate first.")
		return
	end
	if instructionText == "" then
		setLog("Type an instruction in the prompt box first.")
		return
	end

	local myToken = cancelToken

	isBusy = true
	setButtonsEnabled(false)
	playTick()
	-- More realistic feedback for tool-like actions (Fix Bugs / Optimize / Add Feature).
	local labelLower = string.lower(tostring(agentLabel or ""))
	local isToolAction = string.find(labelLower, "fix", 1, true) or string.find(labelLower, "optim", 1, true) or string.find(labelLower, "add", 1, true)
	if isToolAction then
		setActionStatusAnimated("🔧 Processing...", true)
	else
		setActionStatusAnimated("⚡ Generating...", true)
	end

	appendConsoleLine("⚡ " .. tostring(agentLabel or "Action") .. " — contacting AI...", { streamWords = true, secondsPerWord = 0.006 })

	local refinedPrompt = augmentPromptForAI(lastPrompt)
	local stopLoader = startConsoleLoader("🔧 Processing your Roblox system", myToken)
	local data, err = requestWithTimeout(getApiBase() .. "/ai-final", {
		prompt = refinedPrompt,
		structured = true,
		modelTier = modelTierForApi(),
		action = "refine",
		instruction = instructionText,
		build = lastStructuredBuild,
	}, 240)
	stopLoader()

	if cancelToken ~= myToken then
		-- Ensure UI restores after Stop/Cancel.
		isBusy = false
		setButtonsEnabled(true)
		setActionStatus("⚡ Ready")
		return
	end
	if err then
		setLog((agentLabel or "Action") .. " request failed: " .. err)
		isBusy = false
		setButtonsEnabled(true)
		setActionStatus("⚡ Ready")
		return
	end

	if modelUpgradedFromResponse(data) then
		appendConsoleLine("🧠 Enhancing... — quality pass applied (stronger model).", { streamWords = true, secondsPerWord = 0.007 })
		setActionStatusAnimated("🧠 Enhancing...", true)
	end

	appendConsoleLine("Injecting into workspace...", { typewriter = false })
	appendConsoleLine(tostring(data.message or "OK"), { streamWords = true, secondsPerWord = 0.006 })
	if cancelToken ~= myToken then
		return
	end

	if type(data.build) == "table" then
		local ok, msg = StructuredBuild.applyStructuredBuild(data.build)
		if ok then
			lastStructuredBuild = data.build
			promptBox.Text = ""
			promptBox.PlaceholderText = "💡 Optional: describe another change (or use actions below)"
			saveMemoryFromStructuredBuild(lastPrompt, data.build)
			appendConsoleLine("Done. " .. msg, { typewriter = true, speedSecondsPerChar = 0.001 })
			appendConsoleLine("Updating environment and importing toolbox assets...", { typewriter = false })
			if cancelToken ~= myToken then
				return
			end
			autoImportToolboxEnvironmentAssets(lastPrompt .. "\n\nAgent action: " .. tostring(agentLabel) .. "\n" .. instructionText, myToken)
		else
			appendConsoleLine("Structured build failed: " .. tostring(msg), { typewriter = false })
		end
	else
		appendConsoleLine("No structured build returned. (Check backend logs / env vars)", { typewriter = false })
	end

	isBusy = false
	setButtonsEnabled(true)
end

enhancePromptBtn.MouseButton1Click:Connect(function()
	if inPlayClientMode() then
		setLog("Enhance Prompt works only in Edit mode. Stop Play and try again.")
		return
	end
	if isBusy then return end

	local myToken = cancelToken
	local promptRaw = promptBox.Text
	if promptRaw == "" then
		setLog("Enter a prompt first.")
		return
	end

	isBusy = true
	setButtonsEnabled(false)
	playTick()
	setActionStatusAnimated("🧠 Enhancing...", true)

	enhanceTooltip.Text = "🧠 Enhancing..."
	enhanceTooltip.Visible = true

	appendConsoleLine("🧠 Enhance Prompt — contacting AI...", { streamWords = true, secondsPerWord = 0.007 })

	local stopLoader = startConsoleLoader("🧠 Improving your prompt", myToken)
	local data, err = requestWithTimeout(getApiBase() .. "/enhance-prompt", {
		prompt = promptRaw,
		template = selectedTemplate,
		-- Keep Enhance Prompt consistently fast: backend will run a single FAST pass.
		modelTier = "fast",
	}, 25)
	stopLoader()

	if cancelToken ~= myToken then
		enhanceTooltip.Text = "Enhance Prompt"
		enhanceTooltip.Visible = false
		isBusy = false
		setButtonsEnabled(true)
		return
	end
	if err then
		setLog("Enhance Prompt failed: " .. err)
		enhanceTooltip.Text = "Enhance Prompt"
		enhanceTooltip.Visible = false
		isBusy = false
		setButtonsEnabled(true)
		setActionStatus("⚡ Ready")
		return
	end

	local improved = ""
	if type(data) == "table" then
		improved = tostring(data.prompt or data.enhancedPrompt or "")
	end
	if improved == "" then
		improved = promptRaw
	end

	if modelUpgradedFromResponse(data) then
		appendConsoleLine("🧠 Enhancing... — quality pass applied (stronger model).", { streamWords = true, secondsPerWord = 0.007 })
	end

	-- Update prompt box with the improved prompt (Roblox-ready).
	promptBox.Text = improved
	promptBox.PlaceholderText = "💡 Describe your game or feature..."

	-- Make the update visible: jump to the end.
	pcall(function()
		promptBox:CaptureFocus()
		promptBox.CursorPosition = #promptBox.Text + 1
		promptBox.SelectionStart = #promptBox.Text + 1
		promptBox:ReleaseFocus()
	end)
	appendConsoleLine("Prompt enhanced. Ready to Generate.", { streamWords = true, secondsPerWord = 0.006 })
	if cancelToken ~= myToken then
		enhanceTooltip.Text = "Enhance Prompt"
		enhanceTooltip.Visible = false
		isBusy = false
		setButtonsEnabled(true)
		return
	end

	enhanceTooltip.Text = "Enhance Prompt"
	enhanceTooltip.Visible = false

	isBusy = false
	setButtonsEnabled(true)
end)

addFeatureBtn.MouseButton1Click:Connect(function()
	if inPlayClientMode() then
		setLog("Add Feature works only in Edit mode. Stop Play and try again.")
		return
	end
	local detail = promptBox.Text
	if detail == "" then
		setLog("Describe the feature you want to add in the prompt box first.")
		return
	end
	runAgentRefine("Add this feature to existing game:\n" .. detail, "Add Feature")
end)

fixBugsBtn.MouseButton1Click:Connect(function()
	if inPlayClientMode() then
		setLog("Fix Bugs works only in Edit mode. Stop Play and try again.")
		return
	end
	local detail = promptBox.Text
	if detail == "" then
		detail = "Fix bugs, edge cases, and runtime errors in scripts."
	end
	runAgentRefine("Analyze and fix bugs in current scripts:\n" .. detail, "Fix Bugs")
end)

optimizeBtn.MouseButton1Click:Connect(function()
	if inPlayClientMode() then
		setLog("Optimize works only in Edit mode. Stop Play and try again.")
		return
	end
	local detail = promptBox.Text
	if detail == "" then
		detail = "Optimize performance and structure without changing gameplay intent."
	end
	runAgentRefine("Optimize performance and structure:\n" .. detail, "Optimize")
end)

generateBtn.MouseButton1Click:Connect(function()
	if inPlayClientMode() then
		setLog("Generate works only in Edit mode. Stop Play and try again.")
		return
	end
	if isBusy then return end
	local myToken = cancelToken
	local promptRaw = promptBox.Text
	if promptRaw == "" then
		setLog("Enter a game prompt first.")
		return
	end

	isBusy = true
	setButtonsEnabled(false)
	playTick()
	setActionStatusAnimated("⚡ Generating...", true)
	-- Hard-enforce swap (prevents any UI desync).
	generateBtn.Visible = false
	stopBtn.Visible = true

	generateAnimToken += 1
	local myGenAnim = generateAnimToken
	-- Generate button is hidden while busy (Stop is shown).
	task.spawn(function()
		local sc = stopBtn:FindFirstChildOfClass("UIScale")
		while generateAnimToken == myGenAnim and isBusy do
			if sc then
				TweenService:Create(sc, TweenInfo.new(0.48, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Scale = 1.04 }):Play()
			end
			task.wait(0.52)
			if generateAnimToken ~= myGenAnim or not isBusy then
				break
			end
			if sc then
				TweenService:Create(sc, TweenInfo.new(0.48, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Scale = 1 }):Play()
			end
			task.wait(0.52)
		end
	end)

	local stopLoader = startConsoleLoader("⚡ Generating your Roblox system", myToken)
	appendConsoleLine("⚡ Generate — contacting AI...", { streamWords = true, secondsPerWord = 0.006 })
	if string.find(string.lower(getApiBase()), "onrender.com", 1, true) then
		appendConsoleLine(
			"Tip: Free Render sleeps when idle—the first request can take a minute to wake the server; after that, replies are faster.",
			{ typewriter = false }
		)
	end

	local augmentedPrompt = augmentPromptForAI(promptRaw)
	local data, err = requestWithTimeout(getApiBase() .. "/ai-final", {
		prompt = augmentedPrompt,
		structured = true,
		modelTier = modelTierForApi(),
	}, 240)
	stopLoader()

	
	if cancelToken ~= myToken then
		isBusy = false
		setButtonsEnabled(true)
		setActionStatus("⚡ Ready")
		return
	end

	if err then
		setLog("Generate request failed: " .. err)
		isBusy = false
		setButtonsEnabled(true)
		setActionStatus("⚡ Ready")
		return
	end

	if modelUpgradedFromResponse(data) then
		appendConsoleLine("🧠 Enhancing... — quality pass applied (stronger model).", { streamWords = true, secondsPerWord = 0.007 })
		setActionStatusAnimated("🧠 Enhancing...", true)
	end

	appendConsoleLine("Injecting into workspace...", { typewriter = false })

	-- Stream the final message (typewriter) in Live Mode
	appendConsoleLine(tostring(data.message or "OK"), { streamWords = true, secondsPerWord = 0.006 })
	if cancelToken ~= myToken then
		isBusy = false
		setButtonsEnabled(true)
		return
	end

	if type(data.build) == "table" then
		local ok, msg = StructuredBuild.applyStructuredBuild(data.build)
		if ok then
			lastPrompt = promptRaw
			lastStructuredBuild = data.build
			promptBox.Text = ""
			promptBox.PlaceholderText = "💡 Optional: describe another change (or use actions below)"
			saveMemoryFromStructuredBuild(promptRaw, data.build)
			setQuickChips(buildAutoSuggestionsFromPrompt(promptRaw))
			appendConsoleLine("Done. " .. msg, { typewriter = true, speedSecondsPerChar = 0.001 })
			appendConsoleLine("Analyzing environment and importing toolbox assets...", { typewriter = false })
			if cancelToken ~= myToken then
				isBusy = false
				setButtonsEnabled(true)
				return
			end
			autoImportToolboxEnvironmentAssets(promptRaw, myToken)
		else
			appendConsoleLine("Structured build failed: " .. tostring(msg), { typewriter = false })
		end
	else
		appendConsoleLine("No structured build returned. (Check backend logs / env vars)", { typewriter = false })
	end

	isBusy = false
	setButtonsEnabled(true)
end)
