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
frame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
frame.BorderSizePixel = 0
frame.Parent = widget

local title = Instance.new("TextLabel")
title.Text = "AI Game Builder"
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 20
title.Parent = frame

local promptBox = Instance.new("TextBox")
promptBox.PlaceholderText = "Describe your game"
promptBox.Text = ""
promptBox.Size = UDim2.new(1, -20, 0, 54)
promptBox.Position = UDim2.new(0, 10, 0, 50)
promptBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
promptBox.TextColor3 = Color3.fromRGB(255, 255, 255)
promptBox.ClearTextOnFocus = false
promptBox.TextWrapped = true
promptBox.TextXAlignment = Enum.TextXAlignment.Left
promptBox.TextYAlignment = Enum.TextYAlignment.Top
promptBox.Parent = frame

local generateBtn = Instance.new("TextButton")
generateBtn.Text = "Generate"
generateBtn.Size = UDim2.new(0.33, -10, 0, 36)
generateBtn.Position = UDim2.new(0, 10, 0, 110)
generateBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
generateBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
generateBtn.Parent = frame

local refineBtn = Instance.new("TextButton")
refineBtn.Text = "Refine"
refineBtn.Size = UDim2.new(0.34, -10, 0, 36)
refineBtn.Position = UDim2.new(0.33, 5, 0, 110)
refineBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
refineBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
refineBtn.Parent = frame

local planBtn = Instance.new("TextButton")
planBtn.Text = "Plan"
planBtn.Size = UDim2.new(0.33, -10, 0, 36)
planBtn.Position = UDim2.new(0.66, 0, 0, 110)
planBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
planBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
planBtn.Parent = frame

local clearBtn = Instance.new("TextButton")
clearBtn.Text = "Clear Build"
clearBtn.Size = UDim2.new(1, -20, 0, 28)
clearBtn.Position = UDim2.new(0, 10, 0, 150)
clearBtn.BackgroundColor3 = Color3.fromRGB(110, 45, 45)
clearBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
clearBtn.Parent = frame

local planBox = Instance.new("TextLabel")
planBox.Text = "Plan will appear here..."
planBox.Size = UDim2.new(1, -20, 0, 110)
planBox.Position = UDim2.new(0, 10, 0, 190)
planBox.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
planBox.TextColor3 = Color3.fromRGB(200, 200, 200)
planBox.TextWrapped = true
planBox.TextXAlignment = Enum.TextXAlignment.Left
planBox.TextYAlignment = Enum.TextYAlignment.Top
planBox.Font = Enum.Font.SourceSans
planBox.TextSize = 14
planBox.Parent = frame

local logScroll = Instance.new("ScrollingFrame")
logScroll.Size = UDim2.new(1, -20, 1, -310)
logScroll.Position = UDim2.new(0, 10, 0, 310)
logScroll.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
logScroll.BorderSizePixel = 0
logScroll.ScrollBarThickness = 6
logScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
logScroll.Parent = frame

local logBox = Instance.new("TextLabel")
logBox.Text = "Logs..."
logBox.Size = UDim2.new(1, -12, 0, 0)
logBox.Position = UDim2.new(0, 6, 0, 6)
logBox.BackgroundTransparency = 1
logBox.TextColor3 = Color3.fromRGB(150, 255, 150)
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

local ROOT_FOLDER_NAME = "AI_Build"

local isBusy = false
local lastPrompt = ""
local lastStructuredBuild = nil

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
	generateBtn.Active = enabled
	generateBtn.AutoButtonColor = enabled
	refineBtn.Active = enabled
	refineBtn.AutoButtonColor = enabled
	planBtn.Active = enabled
	planBtn.AutoButtonColor = enabled
	clearBtn.Active = enabled
	clearBtn.AutoButtonColor = enabled
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

local function requestWithTimeout(url, body, timeoutSeconds)
	local done = false
	local timedOut = false
	local resultData = nil
	local resultErr = nil

	task.spawn(function()
		local data, err = postJson(url, body)
		if timedOut then
			return
		end
		done = true
		resultData = data
		resultErr = err
	end)

	task.delay(timeoutSeconds, function()
		if done then
			return
		end
		timedOut = true
		resultErr = "Request timed out (Render may be cold-starting). Try again."
	end)

	-- Wait until either done or timed out
	while not done and not timedOut do
		task.wait(0.05)
	end

	return resultData, resultErr
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
	end
	return nil
end

local function applyStructuredBuild(build)
	if type(build) ~= "table" or type(build.instances) ~= "table" then
		return false, "Invalid build payload"
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
		end
		pcall(function()
			inst.Parent = parent
		end)
	end

	return true, ("Created %d instances"):format(#specs)
end

clearBtn.MouseButton1Click:Connect(function()
	if isBusy then return end
	local removed = clearGeneratedBuild()
	lastStructuredBuild = nil
	lastPrompt = ""
	promptBox.Text = ""
	promptBox.PlaceholderText = "Describe your game"
	setLog(("Cleared AI build folders: %d"):format(removed))
end)

planBtn.MouseButton1Click:Connect(function()
	if inPlayClientMode() then
		setLog("Plan works only in Edit mode. Stop Play and try again.")
		return
	end
	if isBusy then return end
	isBusy = true
	setButtonsEnabled(false)
	local stop = startProgress("Planning")
	local prompt = promptBox.Text
	local data, err = requestWithTimeout("https://assistant-3alw.onrender.com/plan", { prompt = prompt, fast = true }, 25)
	stop()
	if err then
		setLog("Plan request failed: " .. err)
	else
		planBox.Text = "🧠 " .. tostring(data.plan or "(empty)")
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

