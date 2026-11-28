-- Check for table that is shared between executions.
if not shared then
	return warn("No shared, no script.")
end

-- Module table.
local Zenny = {}

-- Services.
local playersService = game:GetService("Players")
local runService = game:GetService("RunService")
local lightingService = game:GetService("Lighting")
local userInputService = game:GetService("UserInputService")
local tweenService = game:GetService("TweenService")
local statsService = game:GetService("Stats")
local httpService = game:GetService("HttpService")
local coreGuiService = game:GetService("CoreGui")

-- Constants.
local BLOCK_KEY = Enum.KeyCode.F
local TOGGLE_KEY = Enum.KeyCode.RightShift
local COLORS = {
	card = Color3.fromRGB(17, 17, 20),
	accent = Color3.fromRGB(245, 245, 248),
	accentDark = Color3.fromRGB(105, 105, 115),
	text = Color3.fromRGB(248, 248, 250),
	dim = Color3.fromRGB(155, 155, 164),
	off = Color3.fromRGB(35, 35, 41),
	good = Color3.fromRGB(235, 235, 240),
	now = Color3.fromRGB(205, 205, 212),
	bad = Color3.fromRGB(175, 175, 182),
	warn = Color3.fromRGB(220, 220, 226),
	ink = Color3.fromRGB(5, 5, 7),
}
local DASH_TYPES = {
	["10480793962"] = "RIGHT",
	["10480796021"] = "LEFT",
	["10491993682"] = "BACK",
	["10479335397"] = "FRONT",
}
local UPPERCUT_IDS = { ["10503381238"] = true, ["13379003796"] = true }
-- Seed animation ids from memory; unverified. Learn buttons add the real ones.
local SEED_IDS = {
	barrage = { ["10466974800"] = true },
	shove = { ["10471336737"] = true },
}
local ACTION_PRIORITIES = {
	[Enum.AnimationPriority.Action] = true,
	[Enum.AnimationPriority.Action2] = true,
	[Enum.AnimationPriority.Action3] = true,
	[Enum.AnimationPriority.Action4] = true,
}
local REACTION_STATES = {
	[Enum.HumanoidStateType.Physics] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
	[Enum.HumanoidStateType.Ragdoll] = true,
	[Enum.HumanoidStateType.PlatformStanding] = true,
	[Enum.HumanoidStateType.Dead] = true,
}
-- Enemies in these states are skipped, like KittyWare's ignore list.
local ENEMY_IGNORE = { "DoingEmote", "CancelEmote", "CancelEmote2", "BeingLaunched", "Freeze" }
local COUNTER_NAMES = { "Counter", "HunterCounter", "AtomicCounter" }
local FRONT_DASH = { Dash = Enum.KeyCode.W, Key = Enum.KeyCode.Q, Goal = "KeyPress" }
local EVASIVE_KEYS = { Back = Enum.KeyCode.S, Left = Enum.KeyCode.A, Right = Enum.KeyCode.D }
local SMOOTH = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local QUICK = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Bot.
local Bot = {
	keys = {
		bot = Enum.KeyCode.B,
		lock = Enum.KeyCode.C,
		cycle = Enum.KeyCode.V,
		combo = Enum.KeyCode.G,
	},
	slots = { "Combo 1", "Combo 2", "Combo 3", "Combo 4" },
	allSlots = { "Combo 1", "Combo 2", "Combo 3", "Combo 4", "Punish", "Poke", "Ragdoll", "Guard Break", "Finisher" },
	ragdolled = false,
	brainAt = 0,
	selfLastM1 = nil,
	selfOpponent = nil,
	selfOpponentAt = 0,
	hookUntil = 0,
	faded = true,
	rollAt = 0,
	longArmOk = false,
	brainWatching = 0,
	brainResult = "none yet",
	blended = nil,
	blendedAt = 0,
	brainWatched = setmetatable({}, { __mode = "k" }),
	resetAt = 0,
	lesson = nil,
	lessonRoot = nil,
	lessonResult = "none yet",
	reason = nil,
	ignoredGoals = { UpdateMousePos = true, UpdateCamera = true, MouseMove = true, Mouse = true },
	active = false,
	saved = nil,
	target = nil,
	mode = "NEUTRAL",
	modeUntil = 0,
	resetPending = false,
	strafeSign = 1,
	strafeUntil = 0,
	nextM1 = 0,
	nextDash = 0,
	nextSide = 0,
	nextPoke = 0,
	hits = 0,
	lastM1 = 0,
	moveVector = Vector3.zero,
	status = "Off",
	myRoot = nil,
	assistRoot = nil,
	assistBusy = false,
	lockOn = false,
	lockTarget = nil,
	lockPickAt = 0,
	recording = nil,
	comboRun = nil,
	comboIndex = 0,
	comboReadyAt = 0,
	studySubject = nil,
	studyAt = 0,
	selfMemo = {},
	subjectMemo = {},
	-- Features the bot forces on while it runs; the old values come back when it stops.
	profile = {
		autoBlock = true,
		blockFull = true,
		broadDetect = true,
		blockFace = true,
		blockShove = true,
		consecBlock = true,
		autoEvasive = true,
		evasiveMode = "Both",
		dashPredict = true,
		frontBlock = true,
		counterBait = true,
		counterPunish = true,
		catchEnabled = true,
		catchSmart = true,
		bdcEnabled = true,
		preBlock = false,
		shoveM1 = true,
	},
}

---Make sure a style has the dash type counters.
---@param style table
function Bot.ensureTypes(style)
	style.types = style.types or {}
	for _, kind in ipairs({ "circle", "longarm", "hook", "back", "front" }) do
		style.types[kind] = style.types[kind] or 0
	end
end

---A fresh, empty strafe and dash style.
---@return table
function Bot.newStyle()
	local style = { segments = {}, dist = {}, time = 0, pokes = 0, dashes = 0 }
	Bot.ensureTypes(style)
	return style
end

-- Recorded combos and learned strafe style survive re-executes.
Bot.combos = shared.ZennyCombos or {}
shared.ZennyCombos = Bot.combos
Bot.style = shared.ZennyStyle or Bot.newStyle()
Bot.ensureTypes(Bot.style)
shared.ZennyStyle = Bot.style

-- What the brain learned from other players survives re-executes too.
Bot.profiles = shared.ZennyProfiles or {}
shared.ZennyProfiles = Bot.profiles
Bot.profileNames = { "None" }
for name, profile in pairs(Bot.profiles) do
	Bot.ensureTypes(profile.style)
	table.insert(Bot.profileNames, name)
end

-- State.
local localPlayer = playersService.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local connections = {}
local logLines = {}
local seenTracks = setmetatable({}, { __mode = "k" })
local ownSeen = setmetatable({}, { __mode = "k" })
local lastTime = setmetatable({}, { __mode = "k" })
local ownTime = setmetatable({}, { __mode = "k" })
local watched = setmetatable({}, { __mode = "k" })
local enemyHealth = setmetatable({}, { __mode = "k" })
local enemyHurtAt = setmetatable({}, { __mode = "k" })
local lastMoveEnd = setmetatable({}, { __mode = "k" })
local counterSeen = setmetatable({}, { __mode = "k" })
local comboHealth = setmetatable({}, { __mode = "k" })
local moves = {}
local dashes = {}
local espObjects = {}
local safeMarkers = {}
local uiRefreshers = {}
local friendCache = {}
-- Learned animations and move timings survive re-executes.
local learned = shared.ZennyLearned or { barrage = {}, shove = {}, uppercut = {} }
shared.ZennyLearned = learned
learned.back = learned.back or {}
learned.front = learned.front or {}
learned.m1 = learned.m1 or {}
-- Measured dash speeds per dash kind survive re-executes.
local dashSpeeds = shared.ZennySpeeds or {}
shared.ZennySpeeds = dashSpeeds
local moveData = shared.ZennyMoves or {}
shared.ZennyMoves = moveData
local remoteCache = nil
local heldBlocks = 0
local blockLockedUntil = 0
local blockHoldUntil = 0
local blockUntil = 0
local blockDown = false
local nextEvasiveAt = 0
local ragdollSince = nil
local m1ButtonCache = nil
local evasiveLockedUntil = 0
local ownActionUntil = 0
local lockState = nil
local alignOrientation = nil
local alignAttachment = nil
local techBusy = false
local learning = nil
local learningUntil = 0
local labRun = nil
local labDummy = nil
local boundHumanoid = nil
local lastHealth = 0
local gui = nil
local holder = nil
local selfHighlight = nil
local comboHud = nil
local comboHits = 0
local comboDamage = 0
local comboLastAt = 0
local presetStatus = "No preset action yet"
local originalShadows = lightingService.GlobalShadows

local Settings = {
	friendCheck = false,
	autoBlock = false,
	blockFull = true,
	broadDetect = true,
	m1Method = "Remote+Mobile",
	adaptiveBlock = false,
	blockRange = 22,
	blockHold = 0.35,
	blockLead = 0.1,
	faceCheck = false,
	selfGrace = 0.1,
	blockTail = 0.25,
	preBlock = false,
	preBlockRange = 8,
	autoEvasive = false,
	evasiveMode = "Ragdoll",
	evasiveDirection = "Back",
	evasiveBlock = false,
	evasiveRate = 0.06,
	consecBlock = false,
	consecChance = 100,
	consecRange = 18,
	shoveM1 = false,
	shoveDelay = 0.07,
	shoveRange = 15,
	catchEnabled = false,
	catchVisual = true,
	catchFace = true,
	catchPing = true,
	catchRange = 30,
	catchReach = 10,
	catchSmart = true,
	catchSpeed = 60,
	blockShove = false,
	blockFov = 360,
	blockFace = true,
	dashPredict = true,
	predictRange = 28,
	predictReach = 11,
	predictTail = 0.5,
	catchOffset = 0.05,
	catchDelay = 0.2,
	catchLock = 1.5,
	catchZones = true,
	catchCloseRange = 15,
	catchCloseDelay = 0,
	catchFarDelay = 0.3,
	bdcEnabled = false,
	bdcRange = 25,
	bdcReach = 12,
	bdcDelay = 0,
	frontBlock = true,
	frontRange = 30,
	frontM1 = true,
	frontM1Range = 30,
	frontMaxHold = 0,
	frontTail = 0.4,
	counterBait = false,
	counterPunish = false,
	techLoop = false,
	techRange = 40,
	techStartDelay = 0.1,
	techStart = 0,
	techSecond = 0,
	techSecondDelay = 0.04,
	techThird = 0,
	techThirdDelay = 0.12,
	techJump = true,
	techCamera = false,
	esp = false,
	selfChams = false,
	fovEnabled = false,
	fov = 90,
	noSmoke = false,
	noShadows = false,
	safeIndicator = false,
	safeRange = 25,
	comboCounter = false,
	quickPills = true,
	indicators = true,
	debugConsole = false,
	presetSlot = "Slot 1",
	labTest = "Side Dash In",
	labDistance = 12,
	labAttackDist = 5,
	labPing = 60,
	labSpeed = 60,
	labReach = 12,
	labStartup = 0.05,
	labHit = 0.3,
	labDryRun = true,
	botEnabled = false,
	botPlayersOnly = true,
	botTargetMode = "Nearest",
	botRange = 120,
	botEngage = 5,
	botReach = 7,
	botM1Rate = 0.2,
	botComboPause = 0.55,
	botStrafe = true,
	botRespectBlock = true,
	botDashIn = true,
	botDashRange = 20,
	botUseTech = false,
	botRetreatHp = 20,
	botStyle = "Competitive",
	spaceMin = 8,
	spaceMax = 12,
	pokeEvery = 2.5,
	punishWhiff = true,
	punishWindow = 0.6,
	neutralDash = true,
	botBackStep = true,
	botHook = true,
	hookAngle = 35,
	hookRange = 12,
	botUseLock = true,
	lockCamera = true,
	lockFaceChar = true,
	lockPredict = true,
	lockRange = 80,
	lockSpeed = 18,
	assistSide = false,
	assistFront = false,
	assistBack = false,
	assistHook = true,
	assistM1 = false,
	assistRange = 40,
	assistTail = 0.3,
	comboUse = true,
	comboSlot = "Combo 1",
	comboUseMode = "Selected",
	comboRange = 10,
	comboCooldown = 2.5,
	comboCancel = true,
	styleUse = true,
	styleLearnSelf = false,
	padVisible = true,
	backStepRange = 11,
	backStepDelay = 0.05,
	botStringHits = 4,
	brainOn = false,
	brainRange = 60,
	brainMode = "Mine",
	brainMentor = "None",
	longArm = true,
	longArmChance = 10,
	longArmBacklash = 35,
	backlashName = "Backlash",
	backlashMode = "Auto",
	hookAway = true,
	hookAwayAngle = 60,
	hookWindow = 0.5,
	hookFade = true,
}

---Connect a signal and track it for detach.
---@param signal RBXScriptSignal
---@param callback function
local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

---Create an instance with properties in one call.
---@param className string
---@param properties table
---@param parent Instance?
local function newInstance(className, properties, parent)
	local instance = Instance.new(className)
	for key, value in pairs(properties) do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

---Play a smooth tween on an instance.
---@param instance Instance
---@param properties table
---@param info TweenInfo?
local function tween(instance, properties, info)
	tweenService:Create(instance, info or SMOOTH, properties):Play()
end

---Add a line to the debug log.
---@param text string
local function log(text)
	table.insert(logLines, string.format("%5.1f  %s", os.clock() % 1000, text))
	if #logLines > 60 then
		table.remove(logLines, 1)
	end

	if Settings.debugConsole then
		print("[Zenny] " .. text)
	end
end

---Get the current ping in milliseconds.
---@return number
local function getPing()
	local ok, value = pcall(function()
		return statsService.Network.ServerStatsItem["Data Ping"]:GetValue()
	end)

	return ok and value or 0
end

---Get the ping used for timing; the lab can simulate a different one.
---@return number
local function effectivePing()
	if labRun then
		return Settings.labPing
	end

	return getPing()
end

---Record an event while a lab test is running.
---@param name string
---@param data table?
local function labEvent(name, data)
	if labRun then
		table.insert(labRun.events, { name = name, t = os.clock() - labRun.t0, data = data or {} })
	end
end

---Get our character, root and humanoid.
---@return Model?, BasePart?, Humanoid?
local function getMe()
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return character, root, humanoid
end

---Check whether a character belongs to a friend.
---@param character Model
---@return boolean
local function isFriend(character)
	local player = playersService:GetPlayerFromCharacter(character)
	if not player then
		return false
	end

	if friendCache[player.UserId] == nil then
		friendCache[player.UserId] = false
		task.spawn(function()
			local ok, result = pcall(function()
				return localPlayer:IsFriendsWith(player.UserId)
			end)
			friendCache[player.UserId] = ok and result == true
		end)
	end

	return friendCache[player.UserId] == true
end

---Check whether a character is whitelisted or a skipped friend.
---@param character Model
---@return boolean
local function isIgnored(character)
	local player = playersService:GetPlayerFromCharacter(character)
	if player and Settings["wl_" .. player.Name] then
		return true
	end

	return Settings.friendCheck and isFriend(character)
end

---Get the character's input remote that the game's own controls fire.
---@return RemoteEvent?
local function getRemote()
	local character = localPlayer.Character
	if remoteCache and remoteCache.Parent and character and remoteCache:IsDescendantOf(character) then
		return remoteCache
	end

	remoteCache = nil
	local found = character and character:FindFirstChild("Communicate", true)
	if found and found:IsA("RemoteEvent") then
		remoteCache = found
	end

	return remoteCache
end

---Fire the game's own listeners of an input signal with a synthetic input.
---@param signal RBXScriptSignal
---@param inputType Enum.UserInputType
---@param state Enum.UserInputState
---@return boolean
local function fireInputListeners(signal, inputType, state)
	if not getconnections then
		return false
	end

	local fakeInput = {
		UserInputType = inputType,
		UserInputState = state,
		KeyCode = Enum.KeyCode.Unknown,
		Position = Vector3.zero,
		Delta = Vector3.zero,
		IsModifierKeyDown = function()
			return false
		end,
	}

	local fired = 0
	for _, connection in ipairs(getconnections(signal)) do
		local callback = connection.Function
		-- Engine connections have no Lua function; skip them and our own.
		if callback and not (isexecutorclosure and isexecutorclosure(callback)) then
			fired += 1
			task.spawn(function()
				pcall(function()
					connection:Fire(fakeInput, false)
				end)
			end)
		end
	end

	return fired > 0
end

---Find an on-screen M1 button.
---@return GuiButton?
local function findM1Button()
	if m1ButtonCache and m1ButtonCache.Parent then
		return m1ButtonCache
	end

	for _, descendant in ipairs(playerGui:GetDescendants()) do
		if descendant:IsA("GuiButton") then
			local name = descendant.Name:lower()
			if name == "m1" or name:find("attack", 1, true) or name:find("click", 1, true) then
				m1ButtonCache = descendant
				return descendant
			end
		end
	end

	return nil
end

---Fire the signals of a gui button the way a tap would.
---@param button GuiButton
---@param down boolean
local function pressButton(button, down)
	local names = down and { "MouseButton1Down", "InputBegan", "Activated", "MouseButton1Click" } or { "MouseButton1Up", "InputEnded" }
	for _, signalName in ipairs(names) do
		for _, connection in ipairs(getconnections(button[signalName])) do
			task.spawn(function()
				pcall(function()
					connection:Fire({
						UserInputType = Enum.UserInputType.Touch,
						UserInputState = down and Enum.UserInputState.Begin or Enum.UserInputState.End,
						KeyCode = Enum.KeyCode.Unknown,
						Position = Vector3.zero,
					})
				end)
			end)
		end
	end
end

---Send an M1 with a specific method.
---@param method string
---@param reason string?
---@return boolean
local function sendM1(method, reason)
	local tag = string.format("%s (%s)", method, reason or "?")

	if method == "Remote+Mobile" or method == "Remote" then
		local remote = getRemote()
		if not remote then
			log("M1 FAILED: no Communicate remote " .. tag)
			return false
		end

		local mobile = method == "Remote+Mobile"
		remote:FireServer(mobile and { Goal = "LeftClick", Mobile = true } or { Goal = "LeftClick" })
		task.delay(0.06, function()
			local current = getRemote()
			if current then
				current:FireServer(mobile and { Goal = "LeftClickRelease", Mobile = true } or { Goal = "LeftClickRelease" })
			end
		end)
	elseif method == "Signal" then
		if not fireInputListeners(userInputService.InputBegan, Enum.UserInputType.MouseButton1, Enum.UserInputState.Begin) then
			log("M1 FAILED: no input listeners " .. tag)
			return false
		end

		task.delay(0.06, function()
			fireInputListeners(userInputService.InputEnded, Enum.UserInputType.MouseButton1, Enum.UserInputState.End)
		end)
	else
		local button = getconnections and findM1Button()
		if not button then
			log("M1 FAILED: no M1 button found " .. tag)
			return false
		end

		pressButton(button, true)
		task.delay(0.06, function()
			pressButton(button, false)
		end)
	end

	log("M1 sent via " .. tag)
	return true
end

---Send an M1 with the selected method.
---@param reason string?
---@return boolean
local function clickM1(reason)
	if labRun then
		labEvent("M1", { reason = reason })
		if Settings.labDryRun then
			log("M1 (dry run) " .. tostring(reason))
			return true
		end
	end

	return sendM1(Settings.m1Method, reason)
end

---Keep block held for at least a duration; overlapping requests extend it.
---@param duration number
---@return boolean
local function requestBlock(duration)
	if labRun then
		labEvent("BLOCK", { duration = duration })
		if Settings.labDryRun then
			return true
		end
	end

	if not getRemote() then
		log("block FAILED: no Communicate remote")
		return false
	end

	blockUntil = math.max(blockUntil, os.clock() + duration)
	blockHoldUntil = blockUntil
	return true
end

---Start holding block until releaseBlock is called.
---@return boolean
local function holdBlock()
	if labRun then
		labEvent("HOLD")
		if Settings.labDryRun then
			return true
		end
	end

	if not getRemote() then
		log("block hold FAILED: no Communicate remote")
		return false
	end

	heldBlocks += 1
	return true
end

---Let go of one held block.
local function releaseBlock()
	if labRun then
		labEvent("RELEASE")
	end

	heldBlocks = math.max(heldBlocks - 1, 0)
end

---Hold block for a duration, defaulting to the Hold Time setting.
---@param duration number?
---@return boolean
local function pressBlock(duration)
	return requestBlock(duration or Settings.blockHold)
end

---Press or release the block key so it matches what has been requested.
local function updateBlockController()
	local now = os.clock()
	local want = now < blockUntil or heldBlocks > 0
	if heldBlocks > 0 then
		blockHoldUntil = now + 0.2
	end

	if want == blockDown then
		return
	end

	local remote = getRemote()
	if not remote then
		blockDown = false
		return
	end

	blockDown = want
	remote:FireServer({ Goal = want and "KeyPress" or "KeyRelease", Key = BLOCK_KEY })
	if want then
		log("block down")
	end
end

---Check the game's cooldown display for a move or dash.
---@param name string
---@return boolean
local function isOnCooldown(name)
	local bar = playerGui:FindFirstChild("Bar")
	local magic = bar and bar:FindFirstChild("MagicHealth")
	local cooldowns = magic and magic:FindFirstChild("cdholder")
	local entry = cooldowns and cooldowns:FindFirstChild(name, true)
	local template = entry and entry:FindFirstChild("template")
	local fill = template and template:FindFirstChild("Fill")

	return fill ~= nil and fill.Size.Y.Scale > 0.01
end

---Hold block and dash away to dodge a move.
---@return boolean
local function pressEvasive()
	local now = os.clock()
	if now < evasiveLockedUntil then
		return false
	end

	local remote = getRemote()
	if not remote then
		log("evasive FAILED: no Communicate remote")
		return false
	end

	evasiveLockedUntil = now + 1
	requestBlock(0.4)
	task.delay(0.04, function()
		local current = getRemote()
		if current then
			current:FireServer({ Dash = EVASIVE_KEYS[Settings.evasiveDirection], Key = Enum.KeyCode.Q, Goal = "KeyPress" })
		end
	end)

	log("evasive sent (" .. Settings.evasiveDirection .. ")")
	return true
end

---Check whether we are ragdolled or knocked down.
---@param character Model
---@param humanoid Humanoid
---@return boolean
local function isRagdolled(character, humanoid)
	if character:FindFirstChild("Ragdoll") or character:GetAttribute("Ragdoll") then
		return true
	end

	return REACTION_STATES[humanoid:GetState()] == true
end

---Spam dash while ragdolled so the ragdoll gets cancelled.
local function updateEvasive()
	local character, _, humanoid = getMe()
	local active = Settings.autoEvasive and Settings.evasiveMode ~= "Consec"
	if not active or not character or not humanoid or humanoid.Health <= 0 or not isRagdolled(character, humanoid) then
		ragdollSince = nil
		return
	end

	local now = os.clock()
	if not ragdollSince then
		ragdollSince = now
		log("ragdolled: spamming dash")
	end

	-- Stop after a while so a long knockdown does not spam forever.
	if now - ragdollSince > 4 or now < nextEvasiveAt then
		return
	end

	local remote = getRemote()
	if not remote then
		return
	end

	nextEvasiveAt = now + Settings.evasiveRate
	if Settings.evasiveBlock then
		requestBlock(0.15)
	end
	remote:FireServer({ Dash = EVASIVE_KEYS[Settings.evasiveDirection], Key = Enum.KeyCode.Q, Goal = "KeyPress" })
end

---Get the numeric asset id of an animation track.
---@param track AnimationTrack
---@return string?
local function getTrackId(track)
	local animation = track.Animation
	local id = animation and animation.AnimationId
	return id and id:match("%d+")
end

---Decide whether an animation track just started a new play.
---Games replay one track object, so a seen track can still start again.
---@param seen table
---@param times table
---@param track AnimationTrack
---@param fromEvent boolean
---@return boolean
local function isNewPlay(seen, times, track, fromEvent)
	local now = os.clock()
	local seenAt = seen[track]
	local position = track.TimePosition
	local previous = times[track]
	times[track] = position

	if not seenAt then
		seen[track] = now
		return fromEvent or position <= 0.35
	end

	if fromEvent then
		-- The poll and the event can report the same play a frame apart.
		if now - seenAt < 0.05 then
			return false
		end

		seen[track] = now
		return true
	end

	-- Polled: the track restarted if its time went backwards.
	if previous and position < previous - 0.05 and track.IsPlaying then
		seen[track] = now
		return position <= 0.35
	end

	return false
end

---Check whether a character is mid counter.
---@param character Model
---@return boolean
local function isCountering(character)
	for _, name in ipairs(COUNTER_NAMES) do
		if character:FindFirstChild(name) then
			return true
		end
	end

	return false
end

---Check whether a character looks like it is blocking.
---@param character Model
---@return boolean
local function isBlocking(character)
	if character:GetAttribute("Blocking") or character:FindFirstChild("Blocking") then
		return true
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return false
	end

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track.Name:lower():find("block", 1, true) then
			return true
		end
	end

	return false
end

---Remove the orientation constraint used by the lock.
local function releaseAlign()
	if alignOrientation then
		alignOrientation:Destroy()
		alignOrientation = nil
	end

	if alignAttachment then
		alignAttachment:Destroy()
		alignAttachment = nil
	end
end

---Get the orientation constraint, creating it if needed.
---@param myRoot BasePart
---@return AlignOrientation
local function getAlign(myRoot)
	if alignOrientation and alignOrientation.Parent == myRoot and alignAttachment and alignAttachment.Parent == myRoot then
		return alignOrientation
	end

	releaseAlign()
	alignAttachment = newInstance("Attachment", { Name = "ZennyAlign" }, myRoot)
	alignOrientation = newInstance("AlignOrientation", {
		Mode = Enum.OrientationAlignmentMode.OneAttachment,
		Attachment0 = alignAttachment,
		RigidityEnabled = false,
		MaxTorque = 1e9,
		MaxAngularVelocity = math.huge,
		Responsiveness = 80,
	}, myRoot)

	return alignOrientation
end

---Release the character lock and give rotation back to the game.
local function stopLock()
	releaseAlign()

	if not lockState then
		return
	end

	local humanoid = lockState.humanoid
	if humanoid and humanoid.Parent and lockState.autoRotate ~= nil then
		humanoid.AutoRotate = lockState.autoRotate
	end

	lockState = nil
end

---Lock our character onto a target for the configured time.
---@param targetRoot BasePart
---@param force boolean? Keep locking even when Lock Target is off.
local function startLock(targetRoot, force)
	if lockState then
		lockState.force = force or lockState.force
		lockState.root = targetRoot
		lockState.expires = os.clock() + Settings.catchLock
		return
	end

	local _, _, humanoid = getMe()
	lockState = {
		force = force,
		root = targetRoot,
		expires = os.clock() + Settings.catchLock,
		humanoid = humanoid,
		autoRotate = humanoid and humanoid.AutoRotate,
	}

	-- Stop the game turning the character back while locked.
	if humanoid then
		humanoid.AutoRotate = false
	end
end

---Turn the character at the target's predicted position.
---@param myRoot BasePart
---@param snap boolean
local function updateLock(myRoot, snap)
	if not lockState then
		return
	end

	if (not Settings.catchFace and not lockState.force) or os.clock() > lockState.expires or not lockState.root.Parent then
		return stopLock()
	end

	-- Aim where the target will be once our input reaches the server.
	local lead = (Settings.catchPing and effectivePing() / 1000 or 0) + 0.03
	local predicted = lockState.root.Position + lockState.root.AssemblyLinearVelocity * lead
	local direction = (predicted - myRoot.Position) * Vector3.new(1, 0, 1)
	if direction.Magnitude < 0.1 then
		return
	end

	local goal = CFrame.lookAt(myRoot.Position, myRoot.Position + direction)
	if snap then
		myRoot.CFrame = goal
	end

	-- A constraint turns us without rewriting position, so walking still works.
	getAlign(myRoot).CFrame = goal
end

---Keep the character lock tracking its target every frame.
local function updateLockFrame()
	local _, myRoot = getMe()
	if not myRoot then
		return stopLock()
	end

	-- The tech turns the character itself.
	if not techBusy then
		updateLock(myRoot, false)
	end
end

---Stretch a box adornment into a line between two world positions.
---@param adornment BoxHandleAdornment
---@param myRoot BasePart
---@param startPosition Vector3
---@param endPosition Vector3
local function setLine(adornment, myRoot, startPosition, endPosition)
	local length = (endPosition - startPosition).Magnitude
	if length < 0.05 then
		adornment.Visible = false
		return
	end

	adornment.Visible = true
	adornment.Adornee = myRoot
	adornment.Size = Vector3.new(adornment.Size.X, adornment.Size.Y, length)
	adornment.CFrame = myRoot.CFrame:ToObjectSpace(CFrame.lookAt((startPosition + endPosition) / 2, endPosition))
end

---Build the timing rings, line and card for a tracked dash.
---@param entry table
---@param myRoot BasePart
local function createVisual(entry, myRoot)
	local flat = CFrame.new(0, -2.9, 0) * CFrame.Angles(math.rad(90), 0, 0)

	local target = newInstance("CylinderHandleAdornment", {
		Adornee = entry.root,
		Height = 0.12,
		Radius = 2.6,
		InnerRadius = 2.2,
		CFrame = flat,
		Color3 = COLORS.accent,
		Transparency = 0.35,
		AlwaysOnTop = true,
		ZIndex = 1,
	}, holder)

	local ring = newInstance("CylinderHandleAdornment", {
		Adornee = entry.root,
		Height = 0.12,
		Radius = 7,
		InnerRadius = 6.65,
		CFrame = flat,
		Color3 = COLORS.accentDark,
		Transparency = 0.1,
		AlwaysOnTop = true,
		ZIndex = 2,
	}, holder)

	local baseLine = newInstance("BoxHandleAdornment", {
		Adornee = myRoot,
		Size = Vector3.new(0.2, 0.05, 1),
		Color3 = COLORS.accentDark,
		Transparency = 0.55,
		AlwaysOnTop = true,
		ZIndex = 1,
	}, holder)

	local progressLine = newInstance("BoxHandleAdornment", {
		Adornee = myRoot,
		Size = Vector3.new(0.3, 0.08, 1),
		Color3 = COLORS.accent,
		Transparency = 0.05,
		AlwaysOnTop = true,
		ZIndex = 3,
	}, holder)

	local billboard = newInstance("BillboardGui", {
		Adornee = entry.root,
		Size = UDim2.fromOffset(170, 44),
		StudsOffset = Vector3.new(0, 4.2, 0),
		AlwaysOnTop = true,
	}, holder)

	local card = newInstance("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(8, 14, 10),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	}, billboard)
	newInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, card)
	local stroke = newInstance("UIStroke", { Color = COLORS.accent, Transparency = 0.3, Thickness = 1.5 }, card)

	local label = newInstance("TextLabel", {
		Position = UDim2.fromOffset(0, 5),
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.text,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
	}, card)

	local track = newInstance("Frame", {
		Position = UDim2.new(0.1, 0, 0, 30),
		Size = UDim2.new(0.8, 0, 0, 6),
		BackgroundColor3 = COLORS.off,
		BorderSizePixel = 0,
	}, card)
	newInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, track)

	local fill = newInstance("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = COLORS.accent,
		BorderSizePixel = 0,
	}, track)
	newInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)

	entry.visual = {
		baseLine = baseLine,
		progressLine = progressLine,
		target = target,
		ring = ring,
		billboard = billboard,
		stroke = stroke,
		label = label,
		fill = fill,
	}
end

---Update the rings, line and card for the time left until the M1.
---@param entry table
---@param remaining number
---@param myRoot BasePart
local function updateVisual(entry, remaining, myRoot)
	local visual = entry.visual
	local alpha = math.clamp(remaining / math.max(entry.delay or 0.2, 0.01), 0, 1)
	local counter = entry.countering
	local now = remaining <= 0.04 and not counter
	local radius = 2.6 + (7 - 2.6) * alpha
	local color = counter and COLORS.bad or (now and COLORS.now or COLORS.accent)

	-- Inner radius first so it never exceeds the radius while shrinking.
	visual.ring.InnerRadius = math.max(radius - 0.35, 0)
	visual.ring.Radius = radius
	visual.ring.Color3 = counter and COLORS.bad or (now and COLORS.now or COLORS.accentDark)

	visual.target.InnerRadius = now and 0 or 2.2
	visual.target.Color3 = color
	visual.target.Transparency = now and 0.15 or 0.35

	visual.stroke.Color = color
	visual.fill.BackgroundColor3 = color
	visual.fill.Size = UDim2.fromScale(1 - alpha, 1)
	visual.label.TextColor3 = counter and COLORS.bad or (now and COLORS.now or COLORS.text)
	if counter then
		visual.label.Text = string.format("%s  COUNTER", entry.kind)
	elseif now then
		visual.label.Text = string.format("%s  M1 NOW", entry.kind)
	else
		visual.label.Text = string.format("%s  M1 in %.2fs", entry.kind, remaining)
	end

	-- Ground line from us to them; the bright part fills as the M1 window nears.
	local ground = Vector3.new(0, -2.9, 0)
	local startPosition = myRoot.Position + ground
	local endPosition = entry.root.Position + ground
	local progress = startPosition:Lerp(endPosition, 1 - alpha)

	setLine(visual.baseLine, myRoot, startPosition, endPosition)
	setLine(visual.progressLine, myRoot, startPosition, progress)
	visual.baseLine.Color3 = counter and COLORS.bad or (now and COLORS.now or COLORS.accentDark)
	visual.progressLine.Color3 = color
end

---Destroy the visual of a tracked dash.
---@param entry table
local function destroyVisual(entry)
	local visual = entry.visual
	if not visual then
		return
	end

	visual.baseLine:Destroy()
	visual.progressLine:Destroy()
	visual.target:Destroy()
	visual.ring:Destroy()
	visual.billboard:Destroy()
	entry.visual = nil
end

---Check whether an animation track has finished.
---@param track AnimationTrack
---@param elapsed number
---@return boolean
local function trackEnded(track, elapsed)
	if not track.IsPlaying then
		return true
	end

	local length = track.Length
	if length > 0 and elapsed > length + 0.5 then
		return true
	end

	return elapsed > 6
end

---Release held blocks and M1 when a front dash ends close to us.
---@param entry table
---@param silent boolean?
local function onDashEnded(entry, silent)
	if entry.holding then
		entry.holding = false

		-- Keep blocking a moment longer: the M1 usually comes right after the dash.
		if not silent then
			requestBlock(Settings.frontTail)
		end
		releaseBlock()
	end

	if silent or entry.kind ~= "FRONT" or not Settings.frontM1 or not entry.root.Parent then
		return
	end

	local _, myRoot = getMe()
	if not myRoot or (entry.root.Position - myRoot.Position).Magnitude > Settings.frontM1Range then
		return
	end

	if Settings.counterBait and isCountering(entry.root.Parent) then
		return
	end

	startLock(entry.root, true)
	updateLock(myRoot, true)
	clickM1("front dash end")
end

---Remove a tracked dash and its visual.
---@param track AnimationTrack
---@param silent boolean? Skip the end-of-dash M1.
local function untrackDash(track, silent)
	local entry = dashes[track]
	if entry then
		destroyVisual(entry)

		-- Remember how fast this kind of dash really is.
		local peak = entry.peakSpeed or 0
		if not silent and entry.kind ~= "FRONT" and peak > 20 and peak < 200 then
			local previous = dashSpeeds[entry.kind]
			dashSpeeds[entry.kind] = previous and (previous * 0.7 + peak * 0.3) or peak
		end

		onDashEnded(entry, silent)
	end
	dashes[track] = nil
end

---Start tracking a dash in range.
---@param ctx table
local function onDashTrack(ctx)
	local kind = ctx.kind
	local enabled, range
	if kind == "BACK" then
		enabled, range = Settings.bdcEnabled, Settings.bdcRange
	elseif kind == "FRONT" then
		enabled, range = Settings.frontBlock, Settings.frontRange
	else
		enabled = Settings.catchEnabled or Settings.catchVisual or Settings.catchFace or Settings.dashPredict
		range = math.max(Settings.catchRange, Settings.dashPredict and Settings.predictRange or 0)
	end

	if not enabled or ctx.distance > range then
		return
	end

	local entry = {
		root = ctx.root,
		kind = kind,
		range = range,
		startedAt = os.clock(),
		t0 = ctx.t0,
		fired = false,
	}

	if dashes[ctx.track] then
		untrackDash(ctx.track, true)
	end
	dashes[ctx.track] = entry

	if kind == "FRONT" then
		-- Block until the dash ends, if it is heading at us.
		if (ctx.distance < 10 or ctx.root.CFrame.LookVector:Dot(ctx.offset.Unit) > -0.1) and holdBlock() then
			entry.holding = true
			log("front dash: holding block")
		end
	elseif Settings.catchFace then
		startLock(ctx.root)
	end

	-- Already inside reach: M1 now instead of waiting for the next frame.
	if kind ~= "FRONT" and Settings.catchSmart then
		local reach = kind == "BACK" and Settings.bdcReach or Settings.catchReach
		local autoM1 = (kind == "BACK" and Settings.bdcEnabled) or (kind ~= "BACK" and Settings.catchEnabled)
		local flat = Vector3.new(ctx.offset.X, 0, ctx.offset.Z).Magnitude
		local _, myRoot = getMe()

		if autoM1 and myRoot and flat <= reach and not (Settings.counterBait and isCountering(ctx.character)) then
			entry.fired = true
			updateLock(myRoot, true)
			clickM1(string.format("%s dash d=%d (instant)", kind, flat))
		end
	end
end

---Run the dash timing, visuals and auto M1 every frame.
local function updateDashes()
	local _, myRoot = getMe()
	if not myRoot then
		for track in pairs(dashes) do
			untrackDash(track, true)
		end
		return
	end

	-- Lead the M1 by half the ping so it lands on time.
	local lead = Settings.catchPing and (effectivePing() / 2000) or 0

	for track, entry in pairs(dashes) do
		local distance = (entry.root.Position - myRoot.Position).Magnitude
		local elapsed = os.clock() - entry.startedAt + entry.t0
		local ended = not entry.root.Parent or trackEnded(track, elapsed)
		if ended or distance > entry.range * 1.5 then
			if ended and elapsed < 0.1 then
				log("dash track ended instantly; IsPlaying may be unreliable")
			end
			untrackDash(track, not ended)
			continue
		end

		if entry.kind == "FRONT" then
			if entry.holding then
				blockHoldUntil = os.clock() + 0.2

				-- Max hold of 0 means hold until the dash ends.
				if Settings.frontMaxHold > 0 and elapsed > Settings.frontMaxHold then
					entry.holding = false
					releaseBlock()
				end
			end
			continue
		end

		local reach = entry.kind == "BACK" and Settings.bdcReach or Settings.catchReach
		local flatOffset = (entry.root.Position - myRoot.Position) * Vector3.new(1, 0, 1)
		local flatDistance = flatOffset.Magnitude

		-- Estimate how fast they are moving. Other players only update a few times
		-- a second, so measure over a short window instead of frame to frame.
		local now = os.clock()
		local history = entry.history
		if not history then
			history = {}
			entry.history = history
		end

		table.insert(history, { t = now, position = entry.root.Position })
		while #history > 2 and now - history[1].t > 0.18 do
			table.remove(history, 1)
		end

		local velocity = Vector3.zero
		local oldest = history[1]
		if oldest and now - oldest.t >= 0.04 then
			velocity = (entry.root.Position - oldest.position) / (now - oldest.t)
		end

		local reported = entry.root.AssemblyLinearVelocity
		if reported.Magnitude > velocity.Magnitude then
			velocity = reported
		end

		local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
		entry.peakSpeed = math.max(entry.peakSpeed or 0, flatVelocity.Magnitude)

		-- Before their speed is measured, assume the dash goes the way the animation says.
		if flatVelocity.Magnitude < 8 and elapsed < 0.3 then
			local cframe = entry.root.CFrame
			local direction = nil
			if entry.kind == "RIGHT" then
				direction = cframe.RightVector
			elseif entry.kind == "LEFT" then
				direction = -cframe.RightVector
			elseif entry.kind == "BACK" then
				direction = -cframe.LookVector
			end

			local flatDirection = direction and Vector3.new(direction.X, 0, direction.Z)
			if flatDirection and flatDirection.Magnitude > 0.1 then
				velocity = flatDirection.Unit * (dashSpeeds[entry.kind] or Settings.catchSpeed)
			end
		end

		-- The animation we see is half a ping old and our M1 takes half a ping to
		-- arrive, so look a full ping ahead, plus the M1's own startup (the offset).
		local lookahead = (Settings.catchPing and effectivePing() / 1000 or 0) + Settings.catchOffset
		local relativeVelocity = (velocity - myRoot.AssemblyLinearVelocity) * Vector3.new(1, 0, 1)

		-- A dash stops, so never predict movement past its end.
		local duration = track.Length > 0 and track.Length or 0.4
		local travel = math.min(lookahead, math.max(duration - elapsed, 0))
		local predictedDistance = (flatOffset + relativeVelocity * travel).Magnitude

		-- Side dash prediction for blocking: work out the closest they will come
		-- along the dash, and have block up before they get there. Auto M1 catch
		-- handles side dashes itself when it is on.
		if Settings.dashPredict and (entry.kind == "RIGHT" or entry.kind == "LEFT") and not entry.predicted and not Settings.catchEnabled and flatDistance <= Settings.predictRange then
			local remainingDash = math.max(duration - elapsed, 0)
			local path = relativeVelocity * remainingDash
			local pathLength = path.Magnitude
			local closestAlong = pathLength > 0.1 and math.clamp(-flatOffset:Dot(path) / (pathLength * pathLength), 0, 1) or 0
			local closest = (flatOffset + path * closestAlong).Magnitude

			if flatDistance <= Settings.predictReach or closest <= Settings.predictReach then
				entry.predicted = true

				if Settings.blockFace then
					startLock(entry.root, true)
					updateLock(myRoot, true)
				end

				pressBlock(math.max(remainingDash, 0.2) + Settings.predictTail)
				log(string.format("side dash predicted: block (closest %.1f studs)", closest))
			end
		end

		-- How long until the M1 should go out, for the timing card.
		local closing = flatDistance > 0.1 and -flatOffset:Dot(relativeVelocity) / flatDistance or 0
		local eta = 0
		if flatDistance > reach then
			eta = closing > 1 and math.max((flatDistance - reach) / closing - lookahead, 0) or math.huge
		end

		local delay, remaining
		if Settings.catchSmart then
			if not entry.baseDelay then
				entry.baseDelay = math.clamp(eta < math.huge and eta + lookahead or 0.3, 0.15, 0.6)
			end

			delay = entry.baseDelay
			remaining = eta < math.huge and eta or delay
		else
			delay = Settings.catchDelay
			if entry.kind == "BACK" then
				delay = Settings.bdcDelay
			elseif Settings.catchZones then
				delay = flatDistance <= Settings.catchCloseRange and Settings.catchCloseDelay or Settings.catchFarDelay
			end

			remaining = delay - elapsed
		end
		entry.delay = delay
		entry.countering = Settings.counterBait and isCountering(entry.root.Parent)

		if Settings.catchVisual then
			if not entry.visual then
				createVisual(entry, myRoot)
			end
			updateVisual(entry, remaining, myRoot)
		else
			destroyVisual(entry)
		end

		-- Smart timing fires as soon as they are, or will be when the M1 lands,
		-- inside hit reach. A target already inside reach gets hit at once.
		local autoM1 = (entry.kind == "BACK" and Settings.bdcEnabled) or (entry.kind ~= "BACK" and Settings.catchEnabled)
		local timeOk = Settings.catchSmart or remaining <= lead
		local inReach = flatDistance <= reach or predictedDistance <= reach
		if autoM1 and not entry.fired and not entry.countering and timeOk and inReach then
			entry.fired = true
			updateLock(myRoot, true)
			clickM1(string.format("%s dash d=%d", entry.kind, flatDistance))
		end
	end
end

---Store when in a move we got hit, and whether it went through our block.
---@param id string
---@param hitTime number
---@param pierced boolean
local function learnMove(id, hitTime, pierced)
	local data = moveData[id]
	if not data then
		data = { hits = 0, pierce = 0 }
		moveData[id] = data
	end

	data.hit = data.hit and (data.hit * 0.7 + hitTime * 0.3) or hitTime
	data.hits += 1
	if pierced then
		data.pierce += 1
	end
end

---Attribute damage we take to the nearest recent move and learn from it.
---@param health number
local function onHealthChanged(health)
	local drop = lastHealth - health
	lastHealth = health
	if drop < 0.5 then
		return
	end

	local bestEntry
	for _, entry in pairs(moves) do
		if entry.near and (not bestEntry or entry.startedAt > bestEntry.startedAt) then
			bestEntry = entry
		end
	end

	if not bestEntry then
		return
	end

	local elapsed = os.clock() - bestEntry.startedAt + bestEntry.t0
	if elapsed < 0.03 then
		return
	end

	learnMove(bestEntry.id, elapsed, os.clock() < blockHoldUntil)
	bestEntry.hitUs = true
end

---Follow the current character's humanoid for damage learning.
---@param humanoid Humanoid
local function bindHealth(humanoid)
	if humanoid == boundHumanoid then
		return
	end

	boundHumanoid = humanoid
	lastHealth = humanoid.Health
	connect(humanoid.HealthChanged, onHealthChanged)
end

---Register an enemy attack animation and start any move-specific reaction.
---@param ctx table
local function onThreatTrack(ctx)
	local humanoid = ctx.humanoid
	local now = os.clock()

	-- Hit reactions look like attacks, so skip enemies that were just hit,
	-- are ragdolled, or reacting to our own attack.
	local reason = nil
	if now < ownActionUntil then
		reason = "our own attack"
	elseif now - (enemyHurtAt[humanoid] or 0) < 0.3 then
		reason = "just hurt"
	elseif ctx.character:FindFirstChild("Ragdoll") then
		reason = "ragdolled"
	end

	if reason then
		log(string.format("%s %s ignored (%s)", ctx.character.Name, ctx.kind, reason))
		labEvent("IGNORED", { reason = reason })
		return
	end

	-- Enemies facing away are not swinging at us.
	local facing = not Settings.faceCheck or ctx.distance < 8 or ctx.root.CFrame.LookVector:Dot(ctx.offset.Unit) >= -0.1

	-- Our own view cone: 360 blocks attackers from every direction.
	local _, myRoot = getMe()
	if facing and myRoot and Settings.blockFov < 359 then
		local toEnemy = Vector3.new(-ctx.offset.X, 0, -ctx.offset.Z)
		local ourLook = Vector3.new(myRoot.CFrame.LookVector.X, 0, myRoot.CFrame.LookVector.Z)
		if toEnemy.Magnitude > 0.1 and ourLook.Magnitude > 0.1 then
			local angle = math.deg(math.acos(math.clamp(ourLook.Unit:Dot(toEnemy.Unit), -1, 1)))
			facing = angle <= Settings.blockFov / 2
		end
	end

	local entry = {
		id = ctx.id or "0",
		kind = ctx.kind,
		root = ctx.root,
		startedAt = now,
		t0 = ctx.t0,
		length = ctx.track.Length,
		near = ctx.distance <= Settings.blockRange + 6,
		threat = ctx.distance <= Settings.blockRange and facing and (ctx.kind ~= "SHOVE" or Settings.blockShove),
		handled = false,
	}
	local previous = moves[ctx.track]
	if previous and previous.holding then
		previous.holding = false
		releaseBlock()
	end
	moves[ctx.track] = entry
	labEvent("THREAT", { threat = entry.threat, distance = ctx.distance })

	if ctx.kind == "BARRAGE" and Settings.consecBlock and ctx.distance <= Settings.consecRange then
		if math.random() * 100 < Settings.consecChance and holdBlock() then
			entry.holding = true
			entry.handled = true
			log("consec: holding block")
		end
	elseif ctx.kind == "SHOVE" and Settings.shoveM1 and ctx.distance <= Settings.shoveRange then
		local targetRoot = ctx.root
		log("shove seen: M1 queued")
		task.delay(Settings.shoveDelay, function()
			local _, myRoot = getMe()
			if myRoot and targetRoot.Parent then
				startLock(targetRoot, true)
				updateLock(myRoot, true)
				clickM1("shove")
			end
		end)
	end
end

---Block or evade due attacks and release finished holds.
local function updateThreats()
	local _, _, myHumanoid = getMe()
	if myHumanoid then
		bindHealth(myHumanoid)
	end

	-- Lead the reaction by our setting plus half the ping.
	local lead = Settings.blockLead + effectivePing() / 2000

	for track, entry in pairs(moves) do
		local elapsed = os.clock() - entry.startedAt + entry.t0

		if not entry.root.Parent or trackEnded(track, elapsed) then
			if entry.holding then
				entry.holding = false
				releaseBlock()
			end

			if entry.root.Parent and not entry.hitUs then
				lastMoveEnd[entry.root] = os.clock()
			end
			moves[track] = nil
			continue
		end

		if entry.holding then
			blockHoldUntil = os.clock() + 0.2
			if elapsed > 4 then
				entry.holding = false
				releaseBlock()
			end
		end

		if entry.threat and not entry.handled then
			local data = moveData[entry.id]
			local hitTime = Settings.adaptiveBlock and data and data.hit

			if not hitTime or elapsed >= hitTime - lead then
				entry.handled = true

				-- Consec moves get dodged when evasive covers them.
				local evaded = false
				if Settings.autoEvasive and Settings.evasiveMode ~= "Ragdoll" and entry.kind == "BARRAGE" then
					evaded = pressEvasive()
				end

				if not evaded and Settings.autoBlock then
					-- Face the attacker so the block covers the hit.
					if Settings.blockFace and entry.root.Parent then
						local _, myRoot = getMe()
						if myRoot then
							startLock(entry.root, true)
							updateLock(myRoot, true)
						end
					end

					-- Hold through the whole move so a late hit frame is still blocked.
					local duration = Settings.blockHold
					if hitTime then
						duration = math.max(hitTime - elapsed + 0.3, Settings.blockHold)
					elseif Settings.blockFull then
						duration = math.clamp((entry.length or 0.5) - elapsed + 0.1, Settings.blockHold, 1.4)
					end

					pressBlock(duration + Settings.blockTail)
				end
			end
		end
	end
end

---Hold block while an enemy is close and facing us, so the first hit is blocked.
local function updatePreBlock()
	if not Settings.preBlock then
		return
	end

	local myCharacter, myRoot = getMe()
	local now = os.clock()
	if not myRoot or now < ownActionUntil then
		return
	end

	local container = workspace:FindFirstChild("Live") or workspace
	for _, character in ipairs(container:GetChildren()) do
		if character == myCharacter or not character:IsA("Model") or isIgnored(character) then
			continue
		end

		local root = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not (root and humanoid and humanoid.Health > 0) or character:FindFirstChild("Ragdoll") then
			continue
		end

		local offset = myRoot.Position - root.Position
		if offset.Magnitude <= Settings.preBlockRange and offset.Magnitude > 0 and root.CFrame.LookVector:Dot(offset.Unit) > 0.3 then
			requestBlock(0.2)
			return
		end
	end
end

---Turn the camera to a yaw while keeping its pitch.
---@param yaw number
local function setCameraYaw(yaw)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local pitch = math.asin(math.clamp(camera.CFrame.LookVector.Y, -1, 1))
	camera.CFrame = CFrame.new(camera.CFrame.Position) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
end

---Run one flick-angle dash around a target.
---@param myRoot BasePart
---@param targetRoot BasePart
local function runTech(myRoot, targetRoot)
	techBusy = true

	local humanoid = myRoot.Parent and myRoot.Parent:FindFirstChildOfClass("Humanoid")
	local autoRotate = humanoid and humanoid.AutoRotate
	if humanoid then
		humanoid.AutoRotate = false
	end

	---Face the target rotated by an angle in degrees.
	---@param angle number
	local function flick(angle)
		if not (myRoot.Parent and targetRoot.Parent) then
			return
		end

		local direction = (targetRoot.Position - myRoot.Position) * Vector3.new(1, 0, 1)
		if direction.Magnitude < 0.1 then
			return
		end

		local yaw = math.atan2(-direction.X, -direction.Z) + math.rad(angle)
		myRoot.CFrame = CFrame.new(myRoot.Position) * CFrame.Angles(0, yaw, 0)
		if Settings.techCamera then
			setCameraYaw(yaw)
		end
	end

	pcall(function()
		flick(Settings.techStart)

		local remote = getRemote()
		if remote then
			remote:FireServer(FRONT_DASH)
		end

		if Settings.techJump and humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end

		task.wait(Settings.techSecondDelay)
		flick(Settings.techSecond)

		task.wait(math.max(Settings.techThirdDelay - Settings.techSecondDelay, 0))
		flick(Settings.techThird)
	end)

	if humanoid and humanoid.Parent and autoRotate ~= nil then
		humanoid.AutoRotate = autoRotate
	end

	techBusy = false
end

---Find the closest living enemy inside a stud range.
---@param myRoot BasePart
---@param range number
---@return BasePart?
local function getNearestTarget(myRoot, range)
	local targetRoot, closest = nil, range
	local container = workspace:FindFirstChild("Live") or workspace

	for _, character in ipairs(container:GetChildren()) do
		if character == myRoot.Parent or not character:IsA("Model") or isIgnored(character) then
			continue
		end

		local root = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not (root and humanoid and humanoid.Health > 0) then
			continue
		end

		local distance = (root.Position - myRoot.Position).Magnitude
		if distance <= closest then
			targetRoot, closest = root, distance
		end
	end

	return targetRoot
end

---Start the tech dash after our own uppercut.
---@param myRoot BasePart
local function triggerTech(myRoot)
	local targetRoot = getNearestTarget(myRoot, Settings.techRange)
	if not targetRoot then
		log("tech: no target in range")
		return
	end

	techBusy = true
	log("tech: uppercut seen, starting")
	task.spawn(function()
		task.wait(Settings.techStartDelay)

		-- Wait for the front dash to come back, but not forever.
		local deadline = os.clock() + 1
		while isOnCooldown("forward") and os.clock() < deadline do
			task.wait()
		end

		if not (myRoot.Parent and targetRoot.Parent) then
			techBusy = false
			return
		end

		runTech(myRoot, targetRoot)
	end)
end

---Handle one of our own animation tracks: grace window, learning and tech trigger.
---@param track AnimationTrack
---@param fromEvent boolean
local function onOwnTrack(track, fromEvent)
	if not isNewPlay(ownSeen, ownTime, track, fromEvent) then
		return
	end

	local id = getTrackId(track)

	-- Learn mode: our own next move becomes the chosen move.
	if learning then
		-- Dashes use any one-shot animation; moves need an action priority.
		local broad = learning == "back" or learning == "front"
		local priority = track.Priority
		local accepted = id
			and (
				ACTION_PRIORITIES[priority]
				or (broad and not track.Looped and track.Length > 0.1 and priority ~= Enum.AnimationPriority.Core and priority ~= Enum.AnimationPriority.Idle)
			)

		if accepted then
			learned[learning][id] = true
			log(string.format("learned %s = %s (%s)", learning, id, track.Name))

			-- The M1 string keeps learning for a few seconds to catch every swing.
			if learning ~= "m1" then
				learning = nil
			end
		elseif fromEvent then
			log(string.format("learn: skipped %s (priority %s)", track.Name, tostring(track.Priority)))
		end
		return
	end

	local ownDash = id and (DASH_TYPES[id] or (learned.back[id] and "BACK") or (learned.front[id] and "FRONT"))
	if ownDash then
		Bot.onOwnDash(ownDash, track)
	end

	if not ACTION_PRIORITIES[track.Priority] then
		return
	end

	ownActionUntil = os.clock() + Settings.selfGrace

	local isUppercut = id and (UPPERCUT_IDS[id] or learned.uppercut[id]) or track.Name:lower():find("uppercut", 1, true)
	if Settings.techLoop and not techBusy and isUppercut then
		local _, myRoot = getMe()
		if myRoot then
			triggerTech(myRoot)
		end
	end
end

---Hook and poll our own animator.
local function scanOwn()
	local _, _, humanoid = getMe()
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end

	if not watched[animator] then
		watched[animator] = true
		connect(animator.AnimationPlayed, function(track)
			onOwnTrack(track, true)
		end)
	end

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		onOwnTrack(track, false)
	end
end

---Work out what an enemy animation is.
---@param track AnimationTrack
---@param id string?
---@return string?
local function classify(track, id)
	if id then
		if DASH_TYPES[id] then
			return DASH_TYPES[id]
		end

		if learned.back[id] then
			return "BACK"
		end

		if learned.front[id] then
			return "FRONT"
		end

		if UPPERCUT_IDS[id] or learned.uppercut[id] then
			return "UPPERCUT"
		end

		if learned.barrage[id] or SEED_IDS.barrage[id] then
			return "BARRAGE"
		end

		if learned.shove[id] or SEED_IDS.shove[id] then
			return "SHOVE"
		end

		if learned.m1[id] then
			return "ATTACK"
		end
	end

	local name = track.Name:lower()
	if name:find("consecutive", 1, true) or name:find("barrage", 1, true) or name:find("machine gun", 1, true) then
		return "BARRAGE"
	end

	if name:find("shove", 1, true) then
		return "SHOVE"
	end

	-- Broad detection counts any one-shot move; walking and idling loop.
	if Settings.broadDetect then
		local priority = track.Priority
		if not track.Looped and track.Length > 0.1 and priority ~= Enum.AnimationPriority.Core and priority ~= Enum.AnimationPriority.Idle then
			return "ATTACK"
		end
	elseif ACTION_PRIORITIES[track.Priority] then
		return "ATTACK"
	end

	return nil
end

---Handle one enemy animation track.
---@param character Model
---@param track AnimationTrack
---@param fromEvent boolean
local function onEnemyTrack(character, track, fromEvent)
	if not isNewPlay(seenTracks, lastTime, track, fromEvent) then
		return
	end

	local _, myRoot = getMe()
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not (myRoot and root and humanoid and humanoid.Health > 0) then
		return
	end

	if isIgnored(character) then
		return
	end

	for _, name in ipairs(ENEMY_IGNORE) do
		if character:FindFirstChild(name) then
			return
		end
	end

	local id = getTrackId(track)
	local kind = classify(track, id)
	if not kind then
		return
	end

	local offset = myRoot.Position - root.Position
	local distance = offset.Magnitude
	if distance == 0 then
		return
	end

	if kind ~= "ATTACK" or distance <= Settings.blockRange + 6 then
		log(string.format("%s %s id=%s d=%d", character.Name, kind, tostring(id), distance))
	end

	if labRun and character == labDummy then
		labEvent("DETECT", { kind = kind, distance = distance })
	end

	local ctx = {
		character = character,
		root = root,
		humanoid = humanoid,
		track = track,
		id = id,
		kind = kind,
		offset = offset,
		distance = distance,
		t0 = track.TimePosition,
	}

	if kind == "RIGHT" or kind == "LEFT" or kind == "BACK" or kind == "FRONT" then
		onDashTrack(ctx)
	else
		onThreatTrack(ctx)
	end
end

---Check whether any feature needs to watch enemy animations.
---@return boolean
local function needsScan()
	return labRun ~= nil
		or Bot.lesson ~= nil
		or Settings.autoBlock
		or Settings.autoEvasive
		or Settings.adaptiveBlock
		or Settings.consecBlock
		or Settings.shoveM1
		or Settings.catchEnabled
		or Settings.catchVisual
		or Settings.catchFace
		or Settings.bdcEnabled
		or Settings.frontBlock
		or Settings.safeIndicator
		or Settings.counterBait
		or Settings.counterPunish
end

---Hook and poll every enemy animator in range.
local function scanEnemies()
	local myCharacter, myRoot = getMe()
	if not myRoot or not needsScan() then
		return
	end

	local now = os.clock()
	local container = workspace:FindFirstChild("Live") or workspace

	for _, character in ipairs(container:GetChildren()) do
		if character == myCharacter or not character:IsA("Model") then
			continue
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			continue
		end

		-- Track recent damage so hit reactions are not mistaken for attacks.
		local previousHealth = enemyHealth[humanoid]
		if previousHealth and humanoid.Health < previousHealth - 0.01 then
			enemyHurtAt[humanoid] = now
		end
		enemyHealth[humanoid] = humanoid.Health

		if not watched[animator] then
			watched[animator] = true
			connect(animator.AnimationPlayed, function(track)
				onEnemyTrack(character, track, true)
			end)
		end

		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			onEnemyTrack(character, track, false)
		end
	end
end

---Remove the esp objects of a player.
---@param player Player
local function removeEsp(player)
	local entry = espObjects[player]
	if not entry then
		return
	end

	entry.highlight:Destroy()
	entry.billboard:Destroy()
	espObjects[player] = nil
end

---Build esp objects for a player's current character.
---@param player Player
local function createEsp(player)
	removeEsp(player)

	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end

	local highlight = newInstance("Highlight", {
		Adornee = character,
		FillColor = isFriend(character) and COLORS.good or COLORS.accent,
		FillTransparency = 0.75,
		OutlineColor = Color3.new(1, 1, 1),
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
	}, holder)

	local billboard = newInstance("BillboardGui", {
		Adornee = head,
		Size = UDim2.fromOffset(140, 30),
		StudsOffset = Vector3.new(0, 2.5, 0),
		AlwaysOnTop = true,
	}, holder)

	local label = newInstance("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.4,
		Font = Enum.Font.GothamSemibold,
		TextSize = 13,
	}, billboard)

	espObjects[player] = { highlight = highlight, billboard = billboard, label = label, character = character }
end

---Keep esp objects in sync with the player list.
local function updateEsp()
	if not Settings.esp then
		for player in pairs(espObjects) do
			removeEsp(player)
		end
		return
	end

	for _, player in ipairs(playersService:GetPlayers()) do
		if player == localPlayer then
			continue
		end

		local entry = espObjects[player]
		if not entry or entry.character ~= player.Character then
			createEsp(player)
			entry = espObjects[player]
		end

		local humanoid = entry and entry.character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			entry.label.Text = string.format("%s [%d]", player.Name, math.floor(humanoid.Health))
		end
	end
end

---Keep the self chams highlight in sync with the setting.
local function updateSelfChams()
	local character = localPlayer.Character
	if not Settings.selfChams or not character then
		if selfHighlight then
			selfHighlight:Destroy()
			selfHighlight = nil
		end
		return
	end

	if selfHighlight and selfHighlight.Adornee == character then
		return
	end

	if selfHighlight then
		selfHighlight:Destroy()
	end

	selfHighlight = newInstance("Highlight", {
		Adornee = character,
		FillColor = COLORS.accent,
		FillTransparency = 0.6,
		OutlineTransparency = 0,
	}, holder)
end

---Pause M1s into counters and punish the endlag when a counter ends.
local function updateCounterBait()
	if not (Settings.counterBait or Settings.counterPunish) then
		table.clear(counterSeen)
		return
	end

	local myCharacter, myRoot = getMe()
	if not myRoot then
		return
	end

	local container = workspace:FindFirstChild("Live") or workspace
	for _, character in ipairs(container:GetChildren()) do
		if character == myCharacter or not character:IsA("Model") or isIgnored(character) then
			continue
		end

		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then
			continue
		end

		if (root.Position - myRoot.Position).Magnitude > Settings.catchRange then
			counterSeen[character] = nil
			continue
		end

		if isCountering(character) then
			counterSeen[character] = true
		elseif counterSeen[character] then
			counterSeen[character] = nil

			if Settings.counterPunish then
				startLock(root, true)
				task.delay(0.08, function()
					local _, currentRoot = getMe()
					if currentRoot and root.Parent then
						updateLock(currentRoot, true)
						clickM1("counter punish")
					end
				end)
			end
		end
	end
end

---Work out what state an enemy is in for the safe-to-hit marker.
---@param character Model
---@param root BasePart
---@param humanoid Humanoid
---@param now number
---@return string?, Color3?
local function getSafeState(character, root, humanoid, now)
	if isCountering(character) then
		return "COUNTER", COLORS.bad
	end

	if isBlocking(character) then
		return "BLOCKING", COLORS.warn
	end

	if REACTION_STATES[humanoid:GetState()] == true or now - (enemyHurtAt[humanoid] or 0) < 0.5 then
		return "OPEN", COLORS.good
	end

	if now - (lastMoveEnd[root] or 0) < 0.6 then
		return "PUNISH", COLORS.good
	end

	return nil
end

---Build a safe-to-hit marker under an enemy.
---@param root BasePart
local function createSafeMarker(root)
	local billboard = newInstance("BillboardGui", {
		Adornee = root,
		Size = UDim2.fromOffset(96, 24),
		StudsOffset = Vector3.new(0, -3.6, 0),
		AlwaysOnTop = true,
		Enabled = false,
	}, holder)

	local card = newInstance("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(8, 14, 10),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
	}, billboard)
	newInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, card)
	local stroke = newInstance("UIStroke", { Color = COLORS.good, Transparency = 0.2, Thickness = 1.5 }, card)

	local label = newInstance("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.good,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
	}, card)

	return { billboard = billboard, stroke = stroke, label = label }
end

---Show whether it is safe to hit each nearby enemy.
local function updateSafeIndicator()
	local character, myRoot = getMe()
	local seen = {}

	if Settings.safeIndicator and myRoot then
		local now = os.clock()
		local container = workspace:FindFirstChild("Live") or workspace

		for _, enemy in ipairs(container:GetChildren()) do
			if enemy == character or not enemy:IsA("Model") or isIgnored(enemy) then
				continue
			end

			local root = enemy:FindFirstChild("HumanoidRootPart")
			local humanoid = enemy:FindFirstChildOfClass("Humanoid")
			if not (root and humanoid and humanoid.Health > 0) then
				continue
			end

			if (root.Position - myRoot.Position).Magnitude > Settings.safeRange then
				continue
			end

			local marker = safeMarkers[enemy]
			if not marker then
				marker = createSafeMarker(root)
				safeMarkers[enemy] = marker
			end
			seen[enemy] = true

			local text, color = getSafeState(enemy, root, humanoid, now)
			marker.billboard.Enabled = text ~= nil
			if text then
				marker.label.Text = text
				marker.label.TextColor3 = color
				marker.stroke.Color = color
			end
		end
	end

	for enemy, marker in pairs(safeMarkers) do
		if not seen[enemy] then
			marker.billboard:Destroy()
			safeMarkers[enemy] = nil
		end
	end
end

---Build the combo counter pill.
local function ensureComboHud()
	if comboHud and comboHud.frame.Parent then
		return comboHud
	end

	local frame = newInstance("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(170, 38),
		BackgroundColor3 = Color3.fromRGB(8, 14, 10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
	}, gui)
	newInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, frame)
	local stroke = newInstance("UIStroke", { Color = COLORS.accent, Transparency = 1, Thickness = 1.5 }, frame)

	local label = newInstance("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.text,
		TextTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
	}, frame)

	comboHud = { frame = frame, stroke = stroke, label = label }
	return comboHud
end

---Count our hits and damage on nearby enemies and show them in a pill.
local function updateComboCounter()
	if not Settings.comboCounter then
		comboHits = 0
		if comboHud then
			comboHud.frame.Visible = false
		end
		return
	end

	local character, myRoot = getMe()
	if not myRoot then
		return
	end

	local now = os.clock()
	local container = workspace:FindFirstChild("Live") or workspace
	local gained = false

	for _, enemy in ipairs(container:GetChildren()) do
		local humanoid = enemy ~= character and enemy:IsA("Model") and enemy:FindFirstChildOfClass("Humanoid")
		local root = humanoid and enemy:FindFirstChild("HumanoidRootPart")
		if not root then
			continue
		end

		local previous = comboHealth[humanoid]
		comboHealth[humanoid] = humanoid.Health

		-- Damage on a nearby enemy right after one of our own attacks counts as our hit.
		if previous and humanoid.Health < previous - 0.5 and (root.Position - myRoot.Position).Magnitude <= 30 and now < ownActionUntil + 0.3 then
			comboHits += 1
			comboDamage += previous - humanoid.Health
			comboLastAt = now
			gained = true
		end
	end

	local hud = ensureComboHud()

	if comboHits > 0 and now - comboLastAt > 2 then
		comboHits, comboDamage = 0, 0
		tween(hud.frame, { BackgroundTransparency = 1 })
		tween(hud.stroke, { Transparency = 1 })
		tween(hud.label, { TextTransparency = 1 })
		task.delay(0.25, function()
			if comboHits == 0 then
				hud.frame.Visible = false
			end
		end)
	elseif gained then
		hud.frame.Visible = true
		hud.label.Text = string.format("%d HITS  %d dmg", comboHits, comboDamage)
		tween(hud.frame, { BackgroundTransparency = 0.25 })
		tween(hud.stroke, { Transparency = 0.2 })
		tween(hud.label, { TextTransparency = 0 })
	end
end

---Disable smoke and dust emitters as they spawn.
---@param instance Instance
local function onDescendantAdded(instance)
	if not Settings.noSmoke or not instance:IsA("ParticleEmitter") then
		return
	end

	local name = instance.Name:lower()
	if name:find("smoke") or name:find("dust") then
		instance.Enabled = false
	end
end

---Deep copy a recorded argument table; instances and enums are kept as they are.
---@param value any
---@return any
function Bot.copy(value)
	if type(value) ~= "table" then
		return value
	end

	local out = {}
	for key, inner in pairs(value) do
		out[key] = Bot.copy(inner)
	end

	return out
end

---Turn a recorded value into something JSON can hold.
---@param value any
---@return any
function Bot.encode(value)
	local kind = typeof(value)
	if kind == "EnumItem" then
		return { __enum = tostring(value) }
	elseif kind == "Vector3" then
		return { __v3 = { value.X, value.Y, value.Z } }
	elseif kind == "CFrame" then
		return { __cf = { value:GetComponents() } }
	elseif kind == "Instance" then
		return { __inst = value:GetFullName() }
	elseif kind == "table" then
		local out = {}
		if #value > 0 then
			for _, inner in ipairs(value) do
				table.insert(out, Bot.encode(inner))
			end
			return out
		end

		for key, inner in pairs(value) do
			out[tostring(key)] = Bot.encode(inner)
		end
		return out
	elseif kind == "number" or kind == "string" or kind == "boolean" then
		return value
	end

	return nil
end

---Turn a saved value back into the real thing.
---@param value any
---@return any
function Bot.decode(value)
	if type(value) ~= "table" then
		return value
	end

	if value.__enum then
		local parts = string.split(value.__enum, ".")
		local ok, item = pcall(function()
			return Enum[parts[2]][parts[3]]
		end)
		return ok and item or nil
	elseif value.__v3 then
		return Vector3.new(unpack(value.__v3))
	elseif value.__cf then
		return CFrame.new(unpack(value.__cf))
	elseif value.__inst then
		local current = game
		for _, part in ipairs(string.split(value.__inst, ".")) do
			current = current and current:FindFirstChild(part)
		end
		return current
	end

	local out = {}
	for key, inner in pairs(value) do
		out[key] = Bot.decode(inner)
	end

	return out
end

---Save recorded combos and the learned strafe style to disk.
---@return boolean
function Bot.save()
	if not (writefile and makefolder) then
		return false
	end

	local data = {
		combos = {},
		style = Bot.packStyle(Bot.style),
	}

	for slot, combo in pairs(Bot.combos) do
		local events = {}
		for _, event in ipairs(combo.events) do
			table.insert(events, { t = event.t, args = Bot.encode(event.args) })
		end
		data.combos[slot] = { events = events, length = combo.length }
	end

	data.profiles = {}
	for name, profile in pairs(Bot.profiles) do
		data.profiles[name] = {
			style = Bot.packStyle(profile.style),
			clicks = Bot.tail(profile.clicks, 100),
			fronts = Bot.tail(profile.fronts, 100),
			sides = Bot.tail(profile.sides, 100),
			backs = Bot.tail(profile.backs, 100),
			holds = Bot.tail(profile.holds, 100),
		}
	end

	return (pcall(function()
		if isfolder and not isfolder("Zenny") then
			makefolder("Zenny")
		end
		writefile("Zenny/Bot.json", httpService:JSONEncode(data))
	end))
end

---Load saved combos and strafe style.
---@return boolean
function Bot.load()
	if not (readfile and isfile) then
		return false
	end

	local ok, data = pcall(function()
		if not isfile("Zenny/Bot.json") then
			return nil
		end
		return httpService:JSONDecode(readfile("Zenny/Bot.json"))
	end)
	if not ok or type(data) ~= "table" then
		return false
	end

	for slot, combo in pairs(data.combos or {}) do
		local events = {}
		for _, event in ipairs(combo.events or {}) do
			table.insert(events, { t = event.t, args = Bot.decode(event.args) })
		end
		Bot.combos[slot] = { events = events, length = combo.length or 0 }
	end

	if data.style then
		for key, value in pairs(Bot.unpackStyle(data.style)) do
			Bot.style[key] = value
		end
	end

	for name, saved in pairs(data.profiles or {}) do
		local profile = Bot.newProfile(name)
		profile.style = Bot.unpackStyle(saved.style or {})
		profile.clicks = saved.clicks or {}
		profile.fronts = saved.fronts or {}
		profile.sides = saved.sides or {}
		profile.backs = saved.backs or {}
		profile.holds = saved.holds or {}
	end

	return true
end

---Turn the script's defensive features on for the bot, or give the old values back.
---@param on boolean
function Bot.applyProfile(on)
	if on then
		Bot.saved = {}
		for key, value in pairs(Bot.profile) do
			Bot.saved[key] = Settings[key]
			Settings[key] = value
		end
	elseif Bot.saved then
		for key, value in pairs(Bot.saved) do
			Settings[key] = value
		end
		Bot.saved = nil
	end

	for key in pairs(Bot.profile) do
		local refresh = uiRefreshers[key]
		if refresh then
			refresh(true)
		end
	end
end

---Get the root and humanoid of a living character.
---@param character Model
---@return BasePart?, Humanoid?
function Bot.getParts(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return root, humanoid
	end

	return nil, nil
end

---Rotate our character so a dash of this key travels where we want.
---@param myRoot BasePart
---@param targetRoot BasePart
---@param dashKey Enum.KeyCode
---@param hook boolean Curve side dashes in toward the target.
function Bot.aimDash(myRoot, targetRoot, dashKey, hook)
	local predicted = targetRoot.Position + targetRoot.AssemblyLinearVelocity * 0.1
	local offset = (predicted - myRoot.Position) * Vector3.new(1, 0, 1)
	if offset.Magnitude < 0.1 then
		return
	end

	local toward = offset.Unit
	local look = toward

	if dashKey == Enum.KeyCode.A or dashKey == Enum.KeyCode.D then
		-- Our right vector is (-look.Z, 0, look.X); the dash goes along it or its opposite.
		local sideSign = dashKey == Enum.KeyCode.D and 1 or -1
		local tangent = Vector3.new(-toward.Z, 0, toward.X) * sideSign
		-- "away" bends outward for a hook; true bends inward for a circle dash.
		local angle = hook == "away" and -math.rad(Settings.hookAwayAngle) or (hook and math.rad(Settings.hookAngle) or 0)
		local desired = tangent * math.cos(angle) + toward * math.sin(angle)
		local right = desired * sideSign
		look = Vector3.new(right.Z, 0, -right.X)
	end

	myRoot.CFrame = CFrame.lookAt(myRoot.Position, myRoot.Position + look)
end

---Fire a dash of one key aimed at the target, then keep facing them.
---@param myRoot BasePart
---@param targetRoot BasePart
---@param dashKey Enum.KeyCode
---@param hook boolean
---@return boolean
function Bot.dash(myRoot, targetRoot, dashKey, hook)
	local remote = getRemote()
	if not remote then
		return false
	end

	Bot.aimDash(myRoot, targetRoot, dashKey, hook)
	remote:FireServer({ Dash = dashKey, Key = Enum.KeyCode.Q, Goal = "KeyPress" })

	-- Give the server a moment to read the dash direction before turning back.
	task.delay(0.06, function()
		if targetRoot.Parent then
			startLock(targetRoot, true)
		end
	end)

	return true
end

---Aim the dash the player just pressed; runs inside the remote hook.
---@param dashKey Enum.KeyCode
function Bot.assistFire(dashKey)
	local kind
	if dashKey == Enum.KeyCode.W then
		kind = Settings.assistFront
	elseif dashKey == Enum.KeyCode.S then
		kind = Settings.assistBack
	elseif dashKey == Enum.KeyCode.A or dashKey == Enum.KeyCode.D then
		kind = Settings.assistSide
	end

	local myRoot, targetRoot = Bot.myRoot, Bot.assistRoot
	if not kind or not (myRoot and targetRoot and myRoot.Parent and targetRoot.Parent) then
		return
	end

	-- Close dashes circle around them; far ones are long arms and stay straight.
	local flat = ((targetRoot.Position - myRoot.Position) * Vector3.new(1, 0, 1)).Magnitude
	Bot.aimDash(myRoot, targetRoot, dashKey, Settings.assistHook and flat <= Settings.hookRange)
end

---Handle one remote the game fires: dash assist, style counting and combo recording.
---@param remote Instance
function Bot.onRemote(remote, ...)
	if remote.Name ~= "Communicate" then
		return
	end

	local args = ...
	if type(args) ~= "table" then
		return
	end

	Bot.measure(args)

	if args.Goal == "LeftClick" then
		Bot.selfLastM1 = os.clock()
	end

	if args.Dash and args.Goal == "KeyPress" then
		Bot.countOwnDash(args.Dash)
		Bot.assistFire(args.Dash)
	end

	local recording = Bot.recording
	if not recording or Bot.ignoredGoals[args.Goal] or #recording.events >= 150 then
		return
	end

	local now = os.clock()
	recording.start = recording.start or now
	recording.lastAt = now
	table.insert(recording.events, { t = now - recording.start, args = Bot.copy(args) })
end

---Hook FireServer once so we can see the game's own input remote calls.
function Bot.installHook()
	shared.ZennyRecord = Bot.onRemote

	if shared.ZennyHooked or not (hookmetamethod and getnamecallmethod and newcclosure) then
		return
	end

	local old
	old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
		local method = getnamecallmethod()
		local record = shared.ZennyRecord
		if record and method == "FireServer" and not checkcaller() then
			pcall(record, self, ...)
			if setnamecallmethod then
				setnamecallmethod(method)
			end
		end

		return old(self, ...)
	end))
	shared.ZennyHooked = true
end

---Start recording the next inputs the player sends into the selected combo slot.
function Bot.startRecording()
	if not shared.ZennyHooked then
		log("combo: remote hook missing, cannot record")
		return
	end

	Bot.recording = { slot = Settings.comboSlot, events = {}, startedAt = os.clock() }
	log("recording " .. Settings.comboSlot .. ": do your combo now")
end

---Finish recording and store the combo.
function Bot.stopRecording()
	local recording = Bot.recording
	Bot.recording = nil
	if not recording then
		return
	end

	if #recording.events == 0 then
		log("combo: nothing recorded")
		return
	end

	local length = recording.events[#recording.events].t
	Bot.combos[recording.slot] = { events = recording.events, length = length }
	log(string.format("%s saved: %d inputs, %.2fs", recording.slot, #recording.events, length))
end

---Stop recording after the player goes quiet.
---@param now number
function Bot.updateRecording(now)
	local recording = Bot.recording
	if not recording then
		return
	end

	if #recording.events > 0 and now - recording.lastAt > 2.5 then
		Bot.stopRecording()
	elseif #recording.events == 0 and now - recording.startedAt > 20 then
		Bot.recording = nil
		log("combo: recording timed out")
	end
end

---Point mouse-style arguments at the target.
---@param args table
---@param targetRoot BasePart
function Bot.retarget(args, targetRoot)
	for key, value in pairs(args) do
		local name = type(key) == "string" and key:lower() or ""
		if name:find("mouse", 1, true) or name:find("hit", 1, true) or name:find("pos", 1, true) then
			local kind = typeof(value)
			if kind == "CFrame" then
				args[key] = CFrame.new(targetRoot.Position)
			elseif kind == "Vector3" then
				args[key] = targetRoot.Position
			end
		end
	end
end

Bot.reasonSlots = { punish = "Punish", poke = "Poke", ragdoll = "Ragdoll", guard = "Guard Break" }

---Pick which combo slot to use next.
---@param reason string? "punish" or "poke" prefers the slot taught for it.
---@return string?
function Bot.pickCombo(reason)
	local special = Bot.reasonSlots[reason]
	local taught = special and Bot.combos[special]
	if taught and #taught.events > 0 then
		return special
	end

	-- Never run a normal combo into a guard.
	if reason == "guard" then
		return nil
	end

	local selected = Bot.combos[Settings.comboSlot]
	if Settings.comboUseMode == "Selected" then
		return selected and #selected.events > 0 and Settings.comboSlot or nil
	end

	for step = 1, #Bot.slots do
		local index = (Bot.comboIndex + step - 1) % #Bot.slots + 1
		local combo = Bot.combos[Bot.slots[index]]
		if combo and #combo.events > 0 then
			Bot.comboIndex = index
			return Bot.slots[index]
		end
	end

	return nil
end

---Replay a recorded combo on a target with the original timing.
---@param slot string
---@param targetRoot BasePart
---@return boolean
function Bot.playCombo(slot, targetRoot)
	local combo = Bot.combos[slot]
	if not combo or #combo.events == 0 or Bot.comboRun or Bot.recording or not getRemote() then
		return false
	end

	local run = { slot = slot, down = {} }
	Bot.comboRun = run
	log("combo: playing " .. slot)

	task.spawn(function()
		local startedAt = os.clock()

		for _, event in ipairs(combo.events) do
			local delay = startedAt + event.t - os.clock()
			if delay > 0 then
				task.wait(delay)
			end

			local _, myRoot, myHumanoid = getMe()
			local remote = getRemote()
			local blocked = Settings.comboCancel and (blockDown or os.clock() < blockUntil)
			if run.cancel or blocked or not (remote and myRoot and myHumanoid) or myHumanoid.Health <= 0 or not targetRoot.Parent then
				if blocked then
					log("combo: cancelled to block")
				end
				break
			end

			startLock(targetRoot, true)
			updateLock(myRoot, true)

			local args = Bot.copy(event.args)
			Bot.retarget(args, targetRoot)
			if args.Key and args.Goal == "KeyPress" then
				run.down[args.Key] = true
			elseif args.Key and args.Goal == "KeyRelease" then
				run.down[args.Key] = nil
			end

			remote:FireServer(args)
		end

		-- Let go of anything the combo left held.
		local remote = getRemote()
		if remote then
			for key in pairs(run.down) do
				remote:FireServer({ Goal = "KeyRelease", Key = key })
			end
		end

		Bot.comboRun = nil
		if Bot.active and Settings.botStyle == "Competitive" and Bot.mode == "PRESSURE" then
			Bot.endPressure(os.clock())
		end
	end)

	return true
end

---Feed one movement sample of a subject against an opponent into the strafe style.
---@param subject BasePart
---@param opponent BasePart
---@param now number
---@param memo table
---@param style table? The style to add to; ours by default.
function Bot.observe(subject, opponent, now, memo, style)
	local lastAt = memo.at
	local lastPosition = memo.position
	memo.at, memo.position = now, subject.Position
	if not lastAt or now - lastAt > 0.5 then
		memo.sign = nil
		return
	end

	local dt = now - lastAt
	local velocity = (subject.Position - lastPosition) / dt * Vector3.new(1, 0, 1)
	local offset = (opponent.Position - subject.Position) * Vector3.new(1, 0, 1)
	local distance = offset.Magnitude

	-- Dashes are far faster than walking; they are not strafing.
	if distance < 2 or distance > 35 or velocity.Magnitude > 35 then
		memo.sign = nil
		return
	end

	local direction = offset.Unit
	local tangent = Vector3.new(-direction.Z, 0, direction.X)
	local sideSpeed = velocity:Dot(tangent)
	local inSpeed = velocity:Dot(direction)
	style = style or Bot.style

	style.time += dt
	local bucket = math.floor(distance + 0.5)
	style.dist[bucket] = (style.dist[bucket] or 0) + dt

	-- A strafe segment is the time spent moving one way before switching.
	local sign = math.abs(sideSpeed) > 5 and (sideSpeed > 0 and 1 or -1) or 0
	if sign ~= 0 then
		if memo.sign == sign then
			memo.duration += dt
		else
			if memo.sign and memo.duration >= 0.12 and memo.duration <= 3 then
				table.insert(style.segments, memo.duration)
				if #style.segments > 200 then
					table.remove(style.segments, 1)
				end
			end
			memo.sign, memo.duration = sign, 0
		end
	end

	-- A poke is a fast step in from outside the neutral spacing.
	if inSpeed > 10 and distance > 6 then
		if not memo.poking then
			style.pokes += 1
			memo.poking = true
		end
	elseif inSpeed < 3 then
		memo.poking = false
	end
end

---Learn from our own movement and from a studied player.
---@param myRoot BasePart
---@param now number
function Bot.updateStudy(myRoot, now)
	local learnSelf = Bot.learningSelf()
	if not (learnSelf or Bot.studySubject) or now - Bot.studyAt < 0.1 then
		return
	end
	Bot.studyAt = now

	if learnSelf then
		local opponent = Bot.lockTarget and Bot.lockTarget:FindFirstChild("HumanoidRootPart") or getNearestTarget(myRoot, 35)
		Bot.selfOpponent, Bot.selfOpponentAt = opponent, now
		if opponent then
			Bot.observe(myRoot, opponent, now, Bot.selfMemo)
		end
	end

	local subject = Bot.studySubject
	if not subject then
		return
	end

	local subjectRoot = subject.Parent and subject:FindFirstChild("HumanoidRootPart")
	if not subjectRoot then
		Bot.studySubject = nil
		log("study: subject left")
		return
	end

	-- They are fighting whoever is closest to them, which may be us.
	local opponent, closest = nil, 35
	local container = workspace:FindFirstChild("Live") or workspace
	for _, character in ipairs(container:GetChildren()) do
		local root = character ~= subject and character:IsA("Model") and character:FindFirstChild("HumanoidRootPart")
		if root then
			local distance = (root.Position - subjectRoot.Position).Magnitude
			if distance < closest then
				opponent, closest = root, distance
			end
		end
	end

	if opponent then
		Bot.observe(subjectRoot, opponent, now, Bot.subjectMemo)
	end
end

---Get the neutral spacing band, from the learned style when there is enough of it.
---@return number, number
function Bot.getSpacing()
	local style = Bot.activeStyle()
	if Settings.styleUse and style.time >= 15 then
		local first = math.ceil(Settings.botReach) + 1
		local total = 0
		for bucket = first, 35 do
			total += style.dist[bucket] or 0
		end

		if total >= 8 then
			local low, high, sum = nil, nil, 0
			for bucket = first, 35 do
				sum += style.dist[bucket] or 0
				if not low and sum >= total * 0.25 then
					low = bucket
				end
				if not high and sum >= total * 0.75 then
					high = bucket
					break
				end
			end

			if low and high then
				return low, math.max(high, low + 2)
			end
		end
	end

	return Settings.spaceMin, math.max(Settings.spaceMax, Settings.spaceMin + 1)
end

---How long to strafe one way, sampled from what was learned.
---@return number
function Bot.strafeTime()
	local segments = Bot.activeStyle().segments
	if Settings.styleUse and #segments >= 8 then
		return segments[math.random(#segments)]
	end

	return 0.35 + math.random() * 0.75
end

---Seconds between pokes.
---@return number
function Bot.pokeInterval()
	local style = Bot.activeStyle()
	if Settings.styleUse and style.time >= 20 and style.pokes >= 3 then
		return math.clamp(style.time / style.pokes, 1, 8)
	end

	return Settings.pokeEvery
end

---Seconds between neutral side dashes.
---@return number
function Bot.sideInterval()
	local style = Bot.activeStyle()
	if Settings.styleUse and style.time >= 20 and style.dashes >= 3 then
		return math.clamp(style.time / style.dashes, 1.2, 8)
	end

	return 2.2 + math.random() * 2
end

---Leave the pressure phase: step back, then go back to spacing.
---@param now number
function Bot.endPressure(now)
	Bot.mode = "RESET"
	Bot.modeUntil = now + 0.5
	Bot.resetPending = true
	Bot.resetAt = now + Settings.backStepDelay
	Bot.hits = 0
	Bot.nextPoke = now + Bot.pokeInterval() * (0.7 + math.random() * 0.6)
end

---Check that a character is still a valid lock target.
---@param character Model
---@param myRoot BasePart
---@return boolean
function Bot.validLock(character, myRoot)
	if not character.Parent then
		return false
	end

	local root = Bot.getParts(character)
	return root ~= nil and (root.Position - myRoot.Position).Magnitude <= Settings.lockRange * 1.3
end

---Choose a lock target, best aligned with the camera first.
---@param myCharacter Model
---@param myRoot BasePart
---@param cycle boolean Move on to the next candidate.
---@return Model?
function Bot.pickLock(myCharacter, myRoot, cycle)
	local camera = workspace.CurrentCamera
	local origin = camera and camera.CFrame.Position or myRoot.Position
	local look = camera and camera.CFrame.LookVector or myRoot.CFrame.LookVector
	local list = {}
	local container = workspace:FindFirstChild("Live") or workspace

	for _, character in ipairs(container:GetChildren()) do
		if character == myCharacter or not character:IsA("Model") or isIgnored(character) then
			continue
		end

		if Settings.botPlayersOnly and not playersService:GetPlayerFromCharacter(character) then
			continue
		end

		local root = Bot.getParts(character)
		if not root then
			continue
		end

		local offset = root.Position - origin
		local distance = (root.Position - myRoot.Position).Magnitude
		if distance <= Settings.lockRange and offset.Magnitude > 0 then
			local angle = math.acos(math.clamp(look:Dot(offset.Unit), -1, 1))
			table.insert(list, { character = character, score = angle + distance / Settings.lockRange * 0.3 })
		end
	end

	if #list == 0 then
		return nil
	end

	table.sort(list, function(a, b)
		return a.score < b.score
	end)

	if cycle and Bot.lockTarget then
		for index, item in ipairs(list) do
			if item.character == Bot.lockTarget then
				return list[index % #list + 1].character
			end
		end
	end

	return list[1].character
end

---Turn the lock on or off.
---@param on boolean
function Bot.setLock(on)
	Bot.lockOn = on
	if on then
		local myCharacter, myRoot = getMe()
		Bot.lockTarget = myRoot and Bot.pickLock(myCharacter, myRoot, false) or nil
		log("lock on: " .. (Bot.lockTarget and Bot.lockTarget.Name or "no target"))
		return
	end

	Bot.lockTarget = nil
	if not Bot.active then
		stopLock()
	end
	log("lock off")
end

---Switch the lock to the next target.
function Bot.cycleLock()
	local myCharacter, myRoot = getMe()
	if not myRoot then
		return
	end

	Bot.lockOn = true
	Bot.lockTarget = Bot.pickLock(myCharacter, myRoot, true)
	log("lock: " .. (Bot.lockTarget and Bot.lockTarget.Name or "no target"))
end

---Keep the lock target valid and face it while we play by hand.
---@param myCharacter Model
---@param myRoot BasePart
---@param now number
function Bot.updateLockTarget(myCharacter, myRoot, now)
	if not Bot.lockOn then
		return
	end

	if not Bot.lockTarget or not Bot.validLock(Bot.lockTarget, myRoot) then
		Bot.lockTarget = nil
		if now - Bot.lockPickAt > 0.25 then
			Bot.lockPickAt = now
			Bot.lockTarget = Bot.pickLock(myCharacter, myRoot, false)
		end
	end

	local root = Bot.lockTarget and Bot.getParts(Bot.lockTarget)
	if root and not Bot.active and Settings.lockFaceChar and not techBusy then
		startLock(root, true)
	end
end

---Turn the camera toward the lock target; runs every render step.
---@param delta number
function Bot.updateCamera(delta)
	if not Bot.lockOn or not Settings.lockCamera or not Bot.lockTarget then
		return
	end

	local camera = workspace.CurrentCamera
	local root = Bot.lockTarget.Parent and Bot.lockTarget:FindFirstChild("HumanoidRootPart")
	if not camera or not root then
		return
	end

	local aim = root.Position + Vector3.new(0, 1, 0)
	if Settings.lockPredict then
		aim += root.AssemblyLinearVelocity * 0.05
	end

	-- Orbit the camera's focus so the zoom distance is kept.
	local focus = camera.Focus.Position
	local direction = aim - focus
	if direction.Magnitude < 0.1 then
		return
	end

	local zoom = (camera.CFrame.Position - focus).Magnitude
	local goal = CFrame.lookAt(focus - direction.Unit * zoom, focus)
	camera.CFrame = camera.CFrame:Lerp(goal, math.clamp(delta * Settings.lockSpeed, 0, 1))
end

---Pick who the dash assist aims at.
---@param myRoot BasePart
function Bot.updateAssistTarget(myRoot)
	if not (Settings.assistSide or Settings.assistFront or Settings.assistBack) then
		Bot.assistRoot = nil
		return
	end

	local lockRoot = Bot.lockOn and Bot.lockTarget and Bot.getParts(Bot.lockTarget)
	Bot.assistRoot = lockRoot or getNearestTarget(myRoot, Settings.assistRange)
end

---Keep facing the target through our own dash and M1 at the end of it.
---@param kind string
---@param track AnimationTrack
function Bot.onOwnDash(kind, track)
	local enabled = (kind == "FRONT" and Settings.assistFront) or (kind == "BACK" and Settings.assistBack) or ((kind == "LEFT" or kind == "RIGHT") and Settings.assistSide)
	local targetRoot = Bot.assistRoot
	local _, myRoot = getMe()
	if not enabled or Bot.assistBusy or not (targetRoot and myRoot) then
		return
	end

	Bot.assistBusy = true
	task.spawn(function()
		local startedAt = os.clock()
		local length = track.Length > 0 and track.Length or 0.4

		while os.clock() - startedAt < length + Settings.assistTail and targetRoot.Parent and myRoot.Parent do
			startLock(targetRoot, true)
			runService.Heartbeat:Wait()
		end

		Bot.assistBusy = false
		if not Settings.assistM1 or not (targetRoot.Parent and myRoot.Parent) then
			return
		end

		local flat = ((targetRoot.Position - myRoot.Position) * Vector3.new(1, 0, 1)).Magnitude
		local blocking = blockDown or heldBlocks > 0 or os.clock() < blockUntil
		if flat <= Settings.botReach + 2 and not blocking and not isCountering(targetRoot.Parent) then
			updateLock(myRoot, true)
			clickM1("dash assist")
		end
	end)
end

---Pick the enemy the bot should fight.
---@param myCharacter Model
---@param myRoot BasePart
---@return Model?, BasePart?, Humanoid?
function Bot.findTarget(myCharacter, myRoot)
	local best, bestRoot, bestHumanoid, bestScore = nil, nil, nil, math.huge
	local container = workspace:FindFirstChild("Live") or workspace

	for _, character in ipairs(container:GetChildren()) do
		if character == myCharacter or not character:IsA("Model") or isIgnored(character) then
			continue
		end

		if Settings.botPlayersOnly and not playersService:GetPlayerFromCharacter(character) then
			continue
		end

		local root, humanoid = Bot.getParts(character)
		if not root then
			continue
		end

		local distance = (root.Position - myRoot.Position).Magnitude
		if distance > Settings.botRange then
			continue
		end

		local score = Settings.botTargetMode == "Lowest HP" and (humanoid.Health + distance * 0.1) or distance

		-- Stick with the current target so the bot does not flip between two.
		if character == Bot.target then
			score *= 0.7
		end

		if score < bestScore then
			best, bestRoot, bestHumanoid, bestScore = character, root, humanoid, score
		end
	end

	return best, bestRoot, bestHumanoid
end

---The locked target if there is one, otherwise the best fresh target.
---@param myCharacter Model
---@param myRoot BasePart
---@return Model?, BasePart?, Humanoid?
function Bot.getTarget(myCharacter, myRoot)
	if Settings.botUseLock and Bot.lockOn and Bot.lockTarget then
		local root, humanoid = Bot.getParts(Bot.lockTarget)
		if root then
			return Bot.lockTarget, root, humanoid
		end
	end

	return Bot.findTarget(myCharacter, myRoot)
end

---Work out where the bot should walk this frame.
---@param myRoot BasePart
---@param targetRoot BasePart
---@param distance number
---@param retreat boolean
---@param attacking boolean
---@param now number
function Bot.updateMove(myRoot, targetRoot, distance, retreat, attacking, now)
	if now > Bot.strafeUntil then
		Bot.strafeSign = -Bot.strafeSign
		Bot.strafeUntil = now + Bot.strafeTime()
	end

	-- Aim at where they will be, not where they are.
	local predicted = targetRoot.Position + targetRoot.AssemblyLinearVelocity * 0.12
	local offset = (predicted - myRoot.Position) * Vector3.new(1, 0, 1)
	if offset.Magnitude < 0.1 then
		Bot.moveVector = Vector3.zero
		return
	end

	local direction = offset.Unit
	local tangent = Vector3.new(-direction.Z, 0, direction.X) * Bot.strafeSign
	local strafe = Settings.botStrafe and 1 or 0
	local competitive = Settings.botStyle == "Competitive"
	local low, high = Bot.getSpacing()
	local engage = Settings.botEngage

	if retreat or Bot.mode == "RESET" or (competitive and attacking and distance < high) then
		Bot.moveVector = -direction + tangent * 0.5 * strafe
	elseif competitive and Bot.mode == "NEUTRAL" then
		if distance > high + 1 then
			Bot.moveVector = direction + tangent * 0.4 * strafe
		elseif distance < low - 1 then
			Bot.moveVector = -direction + tangent * 0.6 * strafe
		else
			local lean = distance > (low + high) / 2 and 0.15 or -0.15
			Bot.moveVector = tangent * strafe + direction * lean
		end
	elseif distance > engage + 1.5 then
		Bot.moveVector = direction + tangent * 0.15 * strafe
	elseif distance < engage - 1.5 then
		Bot.moveVector = -direction * 0.6 + tangent * strafe
	else
		Bot.moveVector = tangent * strafe
	end
end

---Fight the target: spacing, pressure phases, dashes, combos and M1 strings.
---@param now number
---@param myCharacter Model
---@param myRoot BasePart
---@param myHumanoid Humanoid
function Bot.fight(now, myCharacter, myRoot, myHumanoid)
	local targetCharacter, targetRoot, targetHumanoid = Bot.getTarget(myCharacter, myRoot)
	Bot.target = targetCharacter
	if not targetCharacter then
		Bot.moveVector = Vector3.zero
		Bot.mode = "NEUTRAL"
		Bot.status = "No target"
		return
	end

	local flatDistance = ((targetRoot.Position - myRoot.Position) * Vector3.new(1, 0, 1)).Magnitude
	local distance = (targetRoot.Position - myRoot.Position).Magnitude
	local hpPercent = myHumanoid.Health / math.max(myHumanoid.MaxHealth, 1) * 100
	local retreat = Settings.botRetreatHp > 0 and hpPercent < Settings.botRetreatHp
	local blocking = blockDown or heldBlocks > 0 or now < blockUntil
	local competitive = Settings.botStyle == "Competitive"

	-- Always face them; the lock also keeps the block pointed at the attacker.
	startLock(targetRoot, true)

	if isRagdolled(myCharacter, myHumanoid) or techBusy then
		Bot.moveVector = Vector3.zero
		Bot.status = "Stunned"
		return
	end

	-- Is the target swinging at us right now?
	local attacking = false
	for _, entry in pairs(moves) do
		if entry.root == targetRoot and entry.threat then
			attacking = true
			break
		end
	end

	-- Phases: hold spacing, step in when they are open or a poke is due, step back out.
	if not competitive then
		Bot.mode = "PRESSURE"
	elseif Bot.mode == "NEUTRAL" then
		local hurt = now - (enemyHurtAt[targetHumanoid] or -9) < 0.5
		local whiffed = Settings.punishWhiff and now - (lastMoveEnd[targetRoot] or -9) < Settings.punishWindow
		local open = whiffed or hurt or isRagdolled(targetCharacter, targetHumanoid)

		if not attacking and not retreat and not blocking and (open or now >= Bot.nextPoke) then
			Bot.mode = "PRESSURE"
			Bot.modeUntil = now + 2
			Bot.hits = 0
			Bot.reason = open and "punish" or "poke"
			log(string.format("bot: pressure (%s)", whiffed and "whiff punish" or (open and "open" or "poke")))
		end
	elseif Bot.mode == "PRESSURE" then
		if attacking or retreat or (now > Bot.modeUntil and not Bot.comboRun) then
			Bot.endPressure(now)
		end
	elseif Bot.mode == "RESET" and now >= Bot.modeUntil then
		Bot.mode = "NEUTRAL"
	end

	Bot.updateMove(myRoot, targetRoot, distance, retreat, attacking, now)
	local pressure = Bot.mode == "PRESSURE"
	local reach = Settings.botReach
	Bot.rollLongArm(now)

	-- After a string: hook away from them or step straight back.
	if Bot.resetPending and now >= Bot.resetAt then
		Bot.resetPending = false
		if not blocking and now >= Bot.nextDash and flatDistance < Settings.backStepRange then
			local hook = Settings.hookAway and (not Settings.botBackStep or math.random() < Bot.hookShare())
			if hook then
				Bot.nextDash = now + 0.7
				Bot.hookUntil = now + 1.5
				Bot.faded = false
				Bot.dash(myRoot, targetRoot, math.random() < 0.5 and Enum.KeyCode.A or Enum.KeyCode.D, "away")
				log("bot: hook away")
			elseif Settings.botBackStep then
				Bot.nextDash = now + 1.2
				Bot.dash(myRoot, targetRoot, Enum.KeyCode.S, false)
			end
		end
	end

	-- Fade out of their counter dash after a hook.
	if Settings.hookFade and not Bot.faded and now < Bot.hookUntil and now >= Bot.nextDash then
		for _, entry in pairs(dashes) do
			if entry.root == targetRoot then
				Bot.faded = true
				Bot.nextDash = now + 1.2
				Bot.dash(myRoot, targetRoot, Enum.KeyCode.S, false)
				log("bot: fade out")
				break
			end
		end
	end

	-- Close the gap: front dash from far away, circle or long arm side dashes closer in.
	if pressure and not retreat and not blocking and not Bot.comboRun and Settings.botDashIn and now >= Bot.nextDash and flatDistance > reach + 3 then
		if flatDistance > Settings.botDashRange and not isOnCooldown("forward") then
			Bot.nextDash = now + 1.2
			if Settings.botUseTech then
				updateLock(myRoot, true)
				task.spawn(runTech, myRoot, targetRoot)
			else
				Bot.dash(myRoot, targetRoot, Enum.KeyCode.W, false)
			end
			log(string.format("bot: front dash (%d studs)", flatDistance))
		elseif Bot.approachSide(myRoot, targetRoot, flatDistance) then
			Bot.nextDash = now + 1.2
		end
	end

	-- Neutral side dashes
