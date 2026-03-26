local toolbar = plugin:CreateToolbar("AI Assistant")
local button = toolbar:CreateButton("Open AI", "Open AI Panel", "")

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right,
	true,
	false,
	380,
	560,
	320,
	420
)

local widget = plugin:CreateDockWidgetPluginGui("AIAssistant", widgetInfo)
widget.Title = "AI Assistant"

button.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

-- UI ROOT
local frame = Instance.new("Frame")
frame.Size = UDim2.new(1, 0, 1, 0)
frame.BackgroundColor3 = Color3.fromRGB(43, 43, 43) -- #2B2B2B
frame.BorderSizePixel = 0
frame.Parent = widget

local rootScroll = Instance.new("ScrollingFrame")
rootScroll.Name = "RootScroll"
rootScroll.Size = UDim2.new(1, 0, 1, 0)
rootScroll.BackgroundTransparency = 1
rootScroll.BorderSizePixel = 0
rootScroll.ScrollBarThickness = 6
rootScroll.ScrollingDirection = Enum.ScrollingDirection.Y
rootScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
rootScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
rootScroll.Parent = frame

local rootPadding = Instance.new("UIPadding")
rootPadding.PaddingTop = UDim.new(0, 10)
rootPadding.PaddingBottom = UDim.new(0, 10)
rootPadding.PaddingLeft = UDim.new(0, 10)
rootPadding.PaddingRight = UDim.new(0, 10)
rootPadding.Parent = rootScroll

local rootLayout = Instance.new("UIListLayout")
rootLayout.FillDirection = Enum.FillDirection.Vertical
rootLayout.SortOrder = Enum.SortOrder.LayoutOrder
rootLayout.Padding = UDim.new(0, 10)
rootLayout.Parent = rootScroll

local function addPanel(parent, height)
	local panel = Instance.new("Frame")
	panel.BackgroundColor3 = Color3.fromRGB(49, 49, 49) -- #313131
	panel.BorderSizePixel = 0
	panel.Size = UDim2.new(1, 0, 0, height)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 60, 60) -- #3C3C3C
	stroke.Thickness = 1
	stroke.Parent = panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = panel

	panel.Parent = parent
	return panel
end

local function addSectionLabel(parent, text)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 18)
	label.Text = text
	label.TextColor3 = Color3.fromRGB(237, 237, 237) -- #EDEDED
	label.TextTransparency = 0.1
	label.Font = Enum.Font.SourceSansSemibold
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
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
	btn.TextColor3 = Color3.fromRGB(237, 237, 237) -- #EDEDED
	btn.Font = Enum.Font.SourceSansSemibold
	btn.TextSize = 15

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 60, 60) -- #3C3C3C
	stroke.Thickness = 1
	stroke.Parent = btn

	applyHover(btn, baseColor)
end

local title = Instance.new("TextLabel")
title.Text = "AI Game Builder"
title.Size = UDim2.new(1, 0, 0, 28)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(237, 237, 237) -- #EDEDED
title.Font = Enum.Font.SourceSansBold
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.LayoutOrder = 1
title.Parent = rootScroll

local headerDivider = Instance.new("Frame")
headerDivider.BackgroundColor3 = Color3.fromRGB(60, 60, 60) -- #3C3C3C
headerDivider.BorderSizePixel = 0
headerDivider.Size = UDim2.new(1, 0, 0, 1)
headerDivider.LayoutOrder = 2
headerDivider.Parent = rootScroll

local promptPanel = addPanel(rootScroll, 120)
promptPanel.LayoutOrder = 3

local promptLayout = Instance.new("UIListLayout")
promptLayout.FillDirection = Enum.FillDirection.Vertical
promptLayout.SortOrder = Enum.SortOrder.LayoutOrder
promptLayout.Padding = UDim.new(0, 8)
promptLayout.Parent = promptPanel

addSectionLabel(promptPanel, "Prompt").LayoutOrder = 1

local promptBox = Instance.new("TextBox")
promptBox.PlaceholderText = "Describe your game"
promptBox.Text = ""
promptBox.Size = UDim2.new(1, 0, 0, 72)
promptBox.Position = UDim2.new(0, 0, 0, 0)
promptBox.BackgroundColor3 = Color3.fromRGB(43, 43, 43) -- slightly darker input
promptBox.TextColor3 = Color3.fromRGB(237, 237, 237) -- #EDEDED
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
promptStroke.Color = Color3.fromRGB(60, 60, 60) -- #3C3C3C
promptStroke.Thickness = 1
promptStroke.Parent = promptBox

local promptCorner = Instance.new("UICorner")
promptCorner.CornerRadius = UDim.new(0, 8)
promptCorner.Parent = promptBox

promptBox.Parent = promptPanel

local actionsPanel = addPanel(rootScroll, 164)
actionsPanel.LayoutOrder = 4

local actionsLayout = Instance.new("UIListLayout")
actionsLayout.FillDirection = Enum.FillDirection.Vertical
actionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
actionsLayout.Padding = UDim.new(0, 8)
actionsLayout.Parent = actionsPanel

addSectionLabel(actionsPanel, "Actions").LayoutOrder = 1

local generateBtn = Instance.new("TextButton")
generateBtn.Text = "Generate"
generateBtn.Size = UDim2.new(1, 0, 0, 38)
generateBtn.Position = UDim2.new(0, 0, 0, 0)
generateBtn.LayoutOrder = 2
styleButton(generateBtn, Color3.fromRGB(10, 132, 255)) -- #0A84FF
generateBtn.TextSize = 16
generateBtn.Parent = actionsPanel

local secondaryRow = Instance.new("Frame")
secondaryRow.BackgroundTransparency = 1
secondaryRow.Size = UDim2.new(1, 0, 0, 34)
secondaryRow.LayoutOrder = 3
secondaryRow.Parent = actionsPanel

local secondaryLayout = Instance.new("UIListLayout")
secondaryLayout.FillDirection = Enum.FillDirection.Horizontal
secondaryLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
secondaryLayout.SortOrder = Enum.SortOrder.LayoutOrder
secondaryLayout.Padding = UDim.new(0, 8)
secondaryLayout.Parent = secondaryRow

local refineBtn = Instance.new("TextButton")
refineBtn.Text = "Refine"
refineBtn.Size = UDim2.new(0.5, -4, 0, 34)
refineBtn.Position = UDim2.new(0, 0, 0, 0)
refineBtn.LayoutOrder = 1
styleButton(refineBtn, Color3.fromRGB(70, 70, 70))
refineBtn.Parent = secondaryRow

local planBtn = Instance.new("TextButton")
planBtn.Text = "Plan"
planBtn.Size = UDim2.new(0.5, -4, 0, 34)
planBtn.Position = UDim2.new(0, 0, 0, 0)
planBtn.LayoutOrder = 2
styleButton(planBtn, Color3.fromRGB(70, 70, 70))
planBtn.Parent = secondaryRow

local controlRow = Instance.new("Frame")
controlRow.BackgroundTransparency = 1
controlRow.Size = UDim2.new(1, 0, 0, 30)
controlRow.LayoutOrder = 4
controlRow.Parent = actionsPanel

local controlLayout = Instance.new("UIListLayout")
controlLayout.FillDirection = Enum.FillDirection.Horizontal
controlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
controlLayout.SortOrder = Enum.SortOrder.LayoutOrder
controlLayout.Padding = UDim.new(0, 8)
controlLayout.Parent = controlRow

local controlLabel = Instance.new("TextLabel")
controlLabel.BackgroundTransparency = 1
controlLabel.Size = UDim2.new(1, 0, 0, 14)
controlLabel.Text = ""
controlLabel.LayoutOrder = 5
controlLabel.Parent = actionsPanel

local clearBtn = Instance.new("TextButton")
clearBtn.Text = "Clear Build"
clearBtn.Size = UDim2.new(0.5, -4, 0, 30)
clearBtn.Position = UDim2.new(0, 0, 0, 0)
clearBtn.LayoutOrder = 2
styleButton(clearBtn, Color3.fromRGB(92, 32, 32)) -- dark red
clearBtn.Parent = controlRow

local stopBtn = Instance.new("TextButton")
stopBtn.Text = "Stop"
stopBtn.Size = UDim2.new(0.5, -4, 0, 30)
stopBtn.Position = UDim2.new(0, 0, 0, 0)
stopBtn.LayoutOrder = 1
styleButton(stopBtn, Color3.fromRGB(70, 70, 70))
stopBtn.Parent = controlRow

local historyRow = Instance.new("Frame")
historyRow.BackgroundTransparency = 1
historyRow.Size = UDim2.new(1, 0, 0, 30)
historyRow.LayoutOrder = 6
historyRow.Parent = actionsPanel

local historyLayout = Instance.new("UIListLayout")
historyLayout.FillDirection = Enum.FillDirection.Horizontal
historyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
historyLayout.SortOrder = Enum.SortOrder.LayoutOrder
historyLayout.Padding = UDim.new(0, 8)
historyLayout.Parent = historyRow

local undoBtn = Instance.new("TextButton")
undoBtn.Text = "Undo"
undoBtn.Size = UDim2.new(0.5, -4, 0, 30)
undoBtn.Position = UDim2.new(0, 0, 0, 0)
undoBtn.LayoutOrder = 1
styleButton(undoBtn, Color3.fromRGB(70, 70, 70))
undoBtn.Parent = historyRow

local redoBtn = Instance.new("TextButton")
redoBtn.Text = "Redo"
redoBtn.Size = UDim2.new(0.5, -4, 0, 30)
redoBtn.Position = UDim2.new(0, 0, 0, 0)
redoBtn.LayoutOrder = 2
styleButton(redoBtn, Color3.fromRGB(70, 70, 70))
redoBtn.Parent = historyRow

local outputPanel = addPanel(rootScroll, 0)
outputPanel.LayoutOrder = 5
outputPanel.AutomaticSize = Enum.AutomaticSize.Y

local outputLayout = Instance.new("UIListLayout")
outputLayout.FillDirection = Enum.FillDirection.Vertical
outputLayout.SortOrder = Enum.SortOrder.LayoutOrder
outputLayout.Padding = UDim.new(0, 8)
outputLayout.Parent = outputPanel

addSectionLabel(outputPanel, "Output").LayoutOrder = 1

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

local planScroll = Instance.new("ScrollingFrame")
planScroll.Name = "PlanScroll"
planScroll.Size = UDim2.new(1, 0, 0, 120)
planScroll.Position = UDim2.new(0, 0, 0, 0)
planScroll.BackgroundColor3 = Color3.fromRGB(43, 43, 43)
planScroll.BorderSizePixel = 0
planScroll.ScrollBarThickness = 6
planScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
planScroll.Active = true
planScroll.ScrollingEnabled = true
planScroll.LayoutOrder = 1

local planCorner = Instance.new("UICorner")
planCorner.CornerRadius = UDim.new(0, 8)
planCorner.Parent = planScroll

local planStroke = Instance.new("UIStroke")
planStroke.Color = Color3.fromRGB(60, 60, 60)
planStroke.Thickness = 1
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
logScroll.Size = UDim2.new(1, 0, 0, 220)
logScroll.Position = UDim2.new(0, 0, 0, 0)
logScroll.BackgroundColor3 = Color3.fromRGB(43, 43, 43)
logScroll.BorderSizePixel = 0
logScroll.ScrollBarThickness = 6
logScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
logScroll.Active = true
logScroll.ScrollingEnabled = true
logScroll.LayoutOrder = 2

local logCorner = Instance.new("UICorner")
logCorner.CornerRadius = UDim.new(0, 8)
logCorner.Parent = logScroll

local logStroke = Instance.new("UIStroke")
logStroke.Color = Color3.fromRGB(60, 60, 60)
logStroke.Thickness = 1
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
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local StarterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")

local ROOT_FOLDER_NAME = "AI_Build"

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

	setVisual(generateBtn, enabled)
	setVisual(refineBtn, enabled)
	setVisual(planBtn, enabled)
	setVisual(clearBtn, enabled)
	setVisual(stopBtn, not enabled)

	setVisual(undoBtn, enabled and (#undoStack > 0))
	setVisual(redoBtn, enabled and (#redoStack > 0))
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
	local data, err = requestWithTimeout("https://assistant-3alw.onrender.com/plan", { prompt = prompt, fast = true }, 25)
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
	local data, err = requestWithTimeout("https://assistant-3alw.onrender.com/ai-final", {
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
	local data, err = requestWithTimeout("https://assistant-3alw.onrender.com/ai-final", {
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

