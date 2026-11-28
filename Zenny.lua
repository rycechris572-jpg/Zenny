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
	card = Color3.fromRGB(12, 12, 12),
	accent = Color3.fromRGB(255, 255, 255),
	accentDark = Color3.fromRGB(165, 165, 165),
	text = Color3.fromRGB(245, 245, 245),
	dim = Color3.fromRGB(150, 150, 150),
	off = Color3.fromRGB(32, 32, 32),
	good = Color3.fromRGB(120, 255, 190),
	now = Color3.fromRGB(255, 240, 130),
	bad = Color3.fromRGB(255, 110, 130),
	warn = Color3.fromRGB(255, 200, 110),
	ink = Color3.fromRGB(0, 0, 0),
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
-- Features that can be toggled with a rebindable key.
local TOGGLE_BINDS = {
	{ setting = "autoBlock", key = "keyAutoBlock", title = "Auto Block" },
	{ setting = "consecBlock", key = "keyConsecBlock", title = "Consec Block" },
	{ setting = "frontBlock", key = "keyFrontBlock", title = "Front Dash Block" },
	{ setting = "shoveM1", key = "keyShoveM1", title = "Shove M1" },
	{ setting = "catchEnabled", key = "keySideDashM1", title = "Side Dash M1" },
	{ setting = "bdcCatch", key = "keyBackdashM1", title = "Backdash Cancel M1" },
	{ setting = "autoEvasive", key = "keyEvasive", title = "Auto Evasive" },
	{ setting = "punishBlock", key = "keyPunishBlock", title = "Punish M1" },
	{ setting = "punishConsec", key = "keyPunishConsec", title = "Punish Consec" },
	{ setting = "sideBoost", key = "keySideBoost", title = "Side Dash Boost" },
}
-- Swings at or under this length count as M1s for Punish Blocked M1.
local M1_MAX_LENGTH = 1.0
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
	selfLastM1 = nil,
	selfOpponent = nil,
	selfOpponentAt = 0,
	hookUntil = 0,
	faded = true,
	tile = 5,
	adapt = nil,
	armed = nil,
	tapTarget = nil,
	tapMarker = nil,
	lastTap = nil,
	frontLockAuto = false,
	frontLockUntil = nil,
	lines = nil,
	myHumanoid = nil,
	anticipateAt = 0,
	dashMemory = setmetatable({}, { __mode = "k" }),
	swings = setmetatable({}, { __mode = "k" }),
	backs = setmetatable({}, { __mode = "k" }),
	oppAt = 0,
	lastTick = 0,
	lastHealth = 0,
	bonusAt = 0,
	spaceBonus = 0,
	nextSurprise = 0,
	macroRun = nil,
	pendingTech = nil,
	lastTech = "none yet",
	rollAt = 0,
	longArmOk = false,
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
	popups = {},
	lastAction = nil,
	cancelCount = 0,
	cancelAt = 0,
	boosting = false,
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
		bdcCatch = true,
		shoveM1 = true,
		punishBlock = true,
		punishConsec = true,
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

Bot.adapt = shared.ZennyAdapt or {}
shared.ZennyAdapt = Bot.adapt
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
local pingAverage = nil
local pingDeviation = 0
local pingSampledAt = 0
local frameTime = 1 / 60
local punishLockedUntil = 0
local bindCapture = nil
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
	blockRate = 100,
	blockAfterMode = "Auto",
	blockAfter = 0.06,
	blockHoldMode = "Auto",
	frontRate = 100,
	catchRate = 100,
	bdcRate = 100,
	punishRate = 100,
	shoveRate = 100,
	evasiveChance = 100,
	blockFull = true,
	broadDetect = true,
	m1Method = "Remote+Mobile",
	adaptiveBlock = true,
	blockRange = 22,
	blockHold = 0.35,
	blockLead = 0.1,
	faceCheck = false,
	selfGrace = 0.1,
	blockTail = 0.25,
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
	catchAccurate = true,
	lagComp = true,
	lagMax = 300,
	lagJitter = 1,
	punishBlock = false,
	punishConsec = false,
	punishRange = 18,
	punishOffset = 0.03,
	sideBoost = false,
	boostLength = 1.65,
	dashCancelPopup = true,
	indicatorsAll = true,
	keyAutoBlock = "None",
	keyConsecBlock = "None",
	keyFrontBlock = "None",
	keyShoveM1 = "None",
	keySideDashM1 = "None",
	keyBackdashM1 = "None",
	keyEvasive = "None",
	keyPunishBlock = "None",
	keyPunishConsec = "None",
	keySideBoost = "None",
	bdcCatch = false,
	bdcRange = 25,
	bdcReach = 12,
	bdcDelay = 0,
	frontBlock = true,
	frontRange = 30,
	frontM1 = true,
	frontM1Range = 30,
	frontMaxHold = 0,
	frontTail = 0.4,
	frontLane = 9,
	frontLead = 0.15,
	bdcWindow = 0.4,
	counterBait = true,
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
	backStepRange = 11,
	backStepDelay = 0.05,
	botStringHits = 4,
	longArm = true,
	longArmChance = 10,
	longArmBacklash = 35,
	backlashName = "Backlash",
	backlashMode = "Auto",
	hookAway = true,
	hookAwayAngle = 60,
	hookWindow = 0.5,
	hookFade = true,
	spacePerfect = true,
	spaceTiles = 4,
	adapterOn = true,
	techWindow = 2,
	bulletDash = true,
	bulletMin = 14,
	bulletMax = 30,
	skibidiDash = true,
	skibidiOffset = 4,
	surprise = true,
	surpriseEvery = 6,
	assistLines = true,
	assistStrength = 75,
	assistJitter = 3,
	assistMaxTurn = 60,
	assistLead = 0.1,
	assistDashLength = 18,
	tapTarget = true,
	frontLock = true,
	frontLockRange = 18,
	frontLockTime = 1.2,
	dashPredictor = true,
	dashAnticipate = true,
	predictLead = 0.03,
	loopDash = true,
	loopHits = 2,
	loopDelay = 0.2,
	loopFollow = 0.25,
	bdcMacro = true,
	bdcHits = 3,
	cancelDelay = 0.15,
	bdcReturn = 0.35,
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
		print("[Slotted] " .. text)
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

---Sample ping and frame time so timing uses a smoothed value plus jitter.
---@param delta number
local function updateLag(delta)
	frameTime = frameTime * 0.9 + math.clamp(delta, 0.002, 0.1) * 0.1

	local now = os.clock()
	if now - pingSampledAt < 0.1 then
		return
	end
	pingSampledAt = now

	local ping = getPing()
	if ping <= 0 then
		return
	end

	if not pingAverage then
		pingAverage = ping
		return
	end

	pingDeviation = pingDeviation * 0.9 + math.abs(ping - pingAverage) * 0.1
	pingAverage = pingAverage * 0.9 + ping * 0.1
end

---Seconds to send an input early: the round trip (the animation we see is half a
---ping old and the input needs half a ping to arrive), plus jitter and one frame.
---@return number
local function getLead()
	if labRun then
		return Settings.labPing / 1000
	end

	if not Settings.lagComp then
		return getPing() / 1000
	end

	local base = pingAverage or getPing()
	local milliseconds = math.min(base + pingDeviation * Settings.lagJitter, Settings.lagMax)
	return milliseconds / 1000 + frameTime
end

---Roll a feature's rate: true when it should react to this trigger.
---@param rate number 0 to 100
---@return boolean
function Zenny.roll(rate)
	if rate >= 100 then
		return true
	end

	return rate > 0 and math.random() * 100 < rate
end

---Random reaction slop in seconds that grows as a rate drops below 100.
---@param rate number 0 to 100
---@param maximum number Slop at 0%.
---@return number
function Zenny.slop(rate, maximum)
	return (1 - math.clamp(rate, 0, 100) / 100) * maximum * math.random()
end

-- Timings per animation and the timing log survive re-executes.
Zenny.timings = shared.ZennyTimings or {}
shared.ZennyTimings = Zenny.timings
Zenny.timingLog = {}

---Add a line to the timing log.
---@param text string
function Zenny.timeLog(text)
	table.insert(Zenny.timingLog, string.format("%6.2f  %s", os.clock() % 1000, text))
	if #Zenny.timingLog > 80 then
		table.remove(Zenny.timingLog, 1)
	end
end

---Record a seen enemy animation in the timings table.
---@param ctx table
---@return string
function Zenny.noteTiming(ctx)
	local key = ctx.id or ("name:" .. ctx.track.Name)
	local row = Zenny.timings[key]
	if not row then
		row = { seen = 0 }
		Zenny.timings[key] = row
	end

	row.id = ctx.id
	row.name = ctx.track.Name
	row.kind = ctx.kind
	row.length = ctx.track.Length
	row.moveKey = ctx.id or "0"
	row.lastAt = os.clock()
	row.seen += 1

	Zenny.timeLog(string.format("%s %s len %.2fs d=%d", ctx.kind, ctx.id or ctx.track.Name, ctx.track.Length, ctx.distance))
	return key
end

---Text for the animation timings list: length, learned hit frame and our block timing.
---@return string
function Zenny.timingText()
	local rows = {}
	for _, row in pairs(Zenny.timings) do
		table.insert(rows, row)
	end

	table.sort(rows, function(a, b)
		return (a.lastAt or 0) > (b.lastAt or 0)
	end)

	local lines = {}
	for index = 1, math.min(#rows, 30) do
		local row = rows[index]
		local data = moveData[row.moveKey]
		local hit = data and data.hit and string.format("%.2fs x%d", data.hit, data.hits) or "-"
		local block = row.blockAt and string.format("%.2fs", row.blockAt) or "-"
		table.insert(lines, string.format("%-7s %-11s len %.2fs hit %s block %s seen %d", row.kind, (row.id or row.name):sub(1, 11), row.length or 0, hit, block, row.seen))
	end

	return #lines > 0 and table.concat(lines, "\n") or "No animations seen yet"
end

---Text for the timing logger: the latest lines.
---@return string
function Zenny.timingLogText()
	local log = Zenny.timingLog
	if #log == 0 then
		return "Nothing logged yet"
	end

	return table.concat(log, "\n", math.max(#log - 24, 1), #log)
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
	if now < evasiveLockedUntil or not Zenny.roll(Settings.evasiveChance) then
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
		Zenny.ragdollSkip = not Zenny.roll(Settings.evasiveChance)
		log("ragdolled: spamming dash")
	end

	-- Stop after a while so a long knockdown does not spam forever.
	if Zenny.ragdollSkip or now - ragdollSince > 4 or now < nextEvasiveAt then
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
	local lead = (Settings.catchPing and getLead() or 0) + 0.03
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
		BackgroundColor3 = Color3.fromRGB(10, 10, 10),
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

---Hold block while a front dash is aimed at us and about to arrive, let go if it veers off.
---@param entry table
---@param myRoot BasePart
function Zenny.updateFront(entry, myRoot)
	local now = os.clock()
	local offset = (myRoot.Position - entry.root.Position) * Vector3.new(1, 0, 1)
	local distance = offset.Magnitude
	local look = entry.root.CFrame.LookVector * Vector3.new(1, 0, 1)

	-- Aimed means we sit inside the lane their dash runs down.
	local aimed = distance < 6
	if not aimed and look.Magnitude > 0.1 and distance > 0.1 then
		local along = look.Unit:Dot(offset)
		local lateral = math.sqrt(math.max(distance * distance - along * along, 0))
		aimed = along > 0 and lateral <= Settings.frontLane
	end

	if aimed then
		entry.aimedAt = now
	end

	-- Closing speed over a short window, other players only update a few times a second.
	local history = entry.history
	if not history then
		history = {}
		entry.history = history
	end

	table.insert(history, { t = now, distance = distance })
	while #history > 2 and now - history[1].t > 0.15 do
		table.remove(history, 1)
	end

	local closing = 0
	local oldest = history[1]
	if oldest and now - oldest.t >= 0.03 then
		closing = (oldest.distance - distance) / (now - oldest.t)
	end

	if aimed then
		entry.peakSpeed = math.max(entry.peakSpeed or 0, closing)
	end

	-- Seconds until the dash is inside hit range; assume a fast dash until one is measured.
	local speed = math.max(closing, dashSpeeds.FRONT or 0, 40)
	local eta = math.max(distance - Settings.predictReach, 0) / speed

	if not entry.holding then
		if entry.rolled and aimed and eta <= getLead() + Settings.frontLead - entry.slop and holdBlock() then
			entry.holding = true

			-- Face them so the block covers the hit.
			if Settings.blockFace then
				startLock(entry.root, true)
				updateLock(myRoot, true)
			end

			log(string.format("front dash: holding block (arrives in %.2fs)", eta))
			Zenny.timeLog(string.format("front dash block, arrives in %.2fs", eta))
		end
	elseif now - (entry.aimedAt or 0) > 0.25 then
		entry.holding = false
		releaseBlock()
		log("front dash: veered off, block released")
	end
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

	if silent or entry.kind ~= "FRONT" or not Settings.frontM1 or not entry.rolled or not entry.root.Parent then
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
		if not silent and peak > 20 and peak < 200 then
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
		enabled, range = Settings.bdcCatch, Settings.bdcRange
	elseif kind == "FRONT" then
		enabled, range = Settings.autoBlock and Settings.frontBlock, Settings.frontRange
	else
		enabled = Settings.catchEnabled or Settings.catchVisual or Settings.catchFace or Settings.dashPredict
		range = math.max(Settings.catchRange, Settings.dashPredict and Settings.predictRange or 0)
	end

	if not enabled or ctx.distance > range then
		return
	end

	-- A backdash cancel is a move followed right away by a back dash. The move
	-- can register on either side of the dash animation, so check both orders.
	local cancel = false
	local cancelFrom = nil
	if kind == "BACK" then
		local now = os.clock()
		local swing = Bot.swings[ctx.root]
		if swing and now - swing.at <= math.min(swing.length, 3) + Settings.bdcWindow then
			cancel = true
			cancelFrom = swing.kind
		end

		if labRun ~= nil and ctx.character == labDummy then
			cancel = true
		end

		if not cancel then
			-- Their move may still be about to play: wait for it.
			ctx.seenAt = ctx.seenAt or now
			Bot.backs[ctx.root] = ctx
			return
		end

		Bot.backs[ctx.root] = nil
		Zenny.timeLog(string.format("backdash cancel from %s, d=%d", cancelFrom or "lab", ctx.distance))
	end

	local entry = {
		root = ctx.root,
		kind = kind,
		range = range,
		startedAt = ctx.seenAt or os.clock(),
		t0 = ctx.t0,
		fired = false,
		bdc = cancel,
		bdcFrom = cancelFrom,
	}

	-- The rate decides how often we react and how late we are when we do.
	local rate = (kind == "BACK" and Settings.bdcRate) or (kind == "FRONT" and Settings.frontRate) or Settings.catchRate
	entry.rolled = Zenny.roll(rate)
	entry.slop = Zenny.slop(rate, 0.1)
	entry.notBefore = entry.startedAt + entry.slop

	if dashes[ctx.track] then
		untrackDash(ctx.track, true)
	end
	dashes[ctx.track] = entry

	-- A dash we saw coming starts with the predictor already armed.
	local armed = Bot.armed
	entry.armed = Settings.dashAnticipate and armed ~= nil and armed.root == ctx.root and os.clock() < armed.untilAt
	if kind == "RIGHT" or kind == "LEFT" then
		Bot.noteSideDash(ctx.root)
	end

	if kind == "FRONT" then
		-- Judge the dash right away, the per frame update keeps watching it.
		local _, myRoot = getMe()
		if myRoot then
			Zenny.updateFront(entry, myRoot)
		end
	elseif Settings.catchFace then
		startLock(ctx.root)
	end

	-- Already inside reach: M1 now instead of waiting for the next frame.
	if kind ~= "FRONT" and Settings.catchSmart and entry.rolled and entry.slop < 0.02 then
		local reach = kind == "BACK" and Settings.bdcReach or Settings.catchReach
		local autoM1 = (kind == "BACK" and Settings.bdcCatch) or (kind ~= "BACK" and Settings.catchEnabled)
		local flat = Vector3.new(ctx.offset.X, 0, ctx.offset.Z).Magnitude
		local _, myRoot = getMe()

		-- A cancel moves away from us, so judge where they will be when the M1 lands.
		if kind == "BACK" then
			flat += (dashSpeeds.BACK or Settings.catchSpeed) * math.clamp(getLead() + Settings.catchOffset, 0, 0.4)
		end

		if autoM1 and myRoot and flat <= reach + (entry.armed and 2 or 0) and not (Settings.counterBait and isCountering(ctx.character)) then
			entry.fired = true
			updateLock(myRoot, true)
			clickM1(string.format("%s dash d=%d (instant)", kind, flat))
			Zenny.timeLog(string.format("%s M1 sent instantly, d=%.1f", entry.bdc and "BDC" or kind, flat))
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
	local lead = Settings.catchPing and (getLead() / 2) or 0
	Bot.anticipate(myRoot)

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
			Zenny.updateFront(entry, myRoot)
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

		-- Dashes run at a constant speed, so trust the measured dash speed over
		-- replicated positions that only update a few times a second.
		local knownSpeed = Settings.catchAccurate and dashSpeeds[entry.kind]
		if knownSpeed and knownSpeed > 10 then
			local measured = Vector3.new(velocity.X, 0, velocity.Z)
			local cframe = entry.root.CFrame
			local facing = (entry.kind == "RIGHT" and cframe.RightVector) or (entry.kind == "LEFT" and -cframe.RightVector) or (entry.kind == "BACK" and -cframe.LookVector) or nil
			local animDirection = facing and Vector3.new(facing.X, 0, facing.Z)

			local direction = nil
			if measured.Magnitude > 8 then
				direction = measured.Unit
			elseif animDirection and animDirection.Magnitude > 0.1 then
				direction = animDirection.Unit
			end

			if direction then
				velocity = direction * (measured.Magnitude * 0.35 + knownSpeed * 0.65)
			end
		end

		-- The animation we see is half a ping old and our M1 takes half a ping to
		-- arrive, so look a full ping ahead, plus the M1's own startup (the offset).
		local lookahead = (Settings.catchPing and getLead() or 0) + Settings.catchOffset + (Settings.dashPredictor and Settings.predictLead or 0)
		local relativeVelocity = (velocity - myRoot.AssemblyLinearVelocity) * Vector3.new(1, 0, 1)

		-- A dash stops, so never predict movement past its end.
		local duration = track.Length > 0 and track.Length or 0.4
		local travel = math.min(lookahead, math.max(duration - elapsed, 0))
		local predictedDistance = (flatOffset + relativeVelocity * travel).Magnitude
		local sideDash = entry.kind == "RIGHT" or entry.kind == "LEFT"
		local remainingDash = math.max(duration - elapsed, 0)
		local armBonus = entry.armed and 2 or 0

		-- Predictor: walk the whole dash path. M1 if they will be in reach, block if they
		-- will only get near enough to hit us, and send it a ping early.
		if Settings.dashPredictor and Settings.dashPredict and sideDash and not entry.predicted and flatDistance <= Settings.predictRange then
			local canCatch = Settings.catchEnabled and entry.rolled and Bot.pathIntercept(flatOffset, relativeVelocity, remainingDash, reach + armBonus)
			local threat = Bot.pathIntercept(flatOffset, relativeVelocity, remainingDash, Settings.predictReach)
			if threat and not canCatch and threat <= math.max(lookahead, 0) + 0.15 + (entry.armed and 0.1 or 0) then
				entry.predicted = true

				if Settings.blockFace then
					startLock(entry.root, true)
					updateLock(myRoot, true)
				end

				pressBlock(math.max(remainingDash, 0.2) + Settings.predictTail)
				log(string.format("side dash predictor: block in %.2fs", threat))
			end
		end

		-- Side dash prediction for blocking: work out the closest they will come
		-- along the dash, and have block up before they get there. Auto M1 catch
		-- handles side dashes itself when it is on.
		if not Settings.dashPredictor and Settings.dashPredict and (entry.kind == "RIGHT" or entry.kind == "LEFT") and not entry.predicted and not Settings.catchEnabled and flatDistance <= Settings.predictRange then
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
		local autoM1 = ((entry.kind == "BACK" and Settings.bdcCatch) or (entry.kind ~= "BACK" and Settings.catchEnabled)) and entry.rolled and os.clock() >= entry.notBefore
		local timeOk = Settings.catchSmart or remaining <= lead
		local interceptTime = Settings.dashPredictor and Bot.pathIntercept(flatOffset, relativeVelocity, remainingDash, reach + armBonus) or nil
		local inReach = flatDistance <= reach or predictedDistance <= reach or (interceptTime ~= nil and interceptTime <= math.max(lookahead, 0))
		if autoM1 and not entry.fired and not entry.countering and timeOk and inReach then
			entry.fired = true
			updateLock(myRoot, true)
			clickM1(string.format("%s dash d=%d", entry.kind, flatDistance))
			Zenny.timeLog(string.format("%s M1 sent %.2fs into the dash, d=%.1f", entry.bdc and "BDC" or entry.kind, elapsed, flatDistance))
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

	Zenny.timeLog(string.format("hit by %s at %.2fs %s", id, hitTime, pierced and "(through block)" or "(unblocked)"))
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

---Seconds until a swing's animation ends, or nil when that cannot be predicted.
---@param track AnimationTrack
---@param entry table
---@param elapsed number
---@return number?
local function punishRemaining(track, entry, elapsed)
	local length = entry.length or 0
	if track.Looped or length <= 0 or track.Speed <= 0.01 then
		return nil
	end

	local position = track.IsPlaying and track.TimePosition or elapsed
	return math.max(length - position, 0) / track.Speed
end

---Check whether a punish M1 may go out against this enemy right now.
---@param entry table
---@return boolean
local function canPunish(entry)
	if entry.hitUs or not entry.root.Parent then
		return false
	end

	local _, myRoot = getMe()
	local character = entry.root.Parent
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not myRoot or not humanoid or humanoid.Health <= 0 then
		return false
	end

	local flat = ((entry.root.Position - myRoot.Position) * Vector3.new(1, 0, 1)).Magnitude
	if flat > Settings.punishRange then
		return false
	end

	-- An M1 into a counter or a block is wasted.
	return not isCountering(character) and not isBlocking(character)
end

---Face the enemy and send the punish M1.
---@param entry table
---@param why string
local function firePunish(entry, why)
	entry.punishFired = true

	local now = os.clock()
	if now < punishLockedUntil or not canPunish(entry) then
		log(string.format("punish skipped (%s)", why))
		return
	end

	local _, myRoot = getMe()
	punishLockedUntil = now + 0.2
	startLock(entry.root, true)
	updateLock(myRoot, true)
	clickM1(string.format("punish %s (%s)", entry.punish, why))
end

---Mark a move so an M1 goes out when it ends.
---@param entry table
---@param kind string
local function armPunish(entry, kind)
	if not Zenny.roll(Settings.punishRate) then
		log("punish skipped: rate roll")
		return
	end

	entry.punish = kind
	entry.punishFired = false
	entry.punishSlop = Zenny.slop(Settings.punishRate, 0.1)
end

---Register an enemy attack animation and start any move-specific reaction.
---@param ctx table
local function onThreatTrack(ctx)
	local humanoid = ctx.humanoid
	local now = os.clock()

	-- Remember M1s, shoves and consecs so a back dash right after one reads as a backdash cancel.
	local isM1 = ctx.kind == "ATTACK" and ((ctx.id and learned.m1[ctx.id]) or ctx.track.Length <= M1_MAX_LENGTH)
	if isM1 or ctx.kind == "SHOVE" or ctx.kind == "BARRAGE" then
		Bot.swings[ctx.root] = { at = now, length = ctx.track.Length, kind = ctx.kind }
	end

	-- Back dash first, move right after: still a backdash cancel.
	local pending = Bot.backs[ctx.root]
	if pending and (isM1 or ctx.kind == "SHOVE" or ctx.kind == "BARRAGE") then
		Bot.backs[ctx.root] = nil
		local _, myRoot = getMe()
		if myRoot and pending.root.Parent and pending.track.IsPlaying and now - pending.seenAt <= Settings.bdcWindow then
			pending.offset = myRoot.Position - pending.root.Position
			pending.distance = pending.offset.Magnitude
			onDashTrack(pending)
		end
	end

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
		timingKey = ctx.timingKey,
		rolled = Zenny.roll(Settings.blockRate),
		slop = Zenny.slop(Settings.blockRate, 0.12),
	}
	-- A new swing from the same enemy means the window is gone.
	for otherTrack, other in pairs(moves) do
		if other.root == ctx.root and other.punish and not other.punishFired and otherTrack ~= ctx.track then
			other.punishFired = true
			log("punish cancelled: they swung again")
		end
	end

	local previous = moves[ctx.track]
	if previous and previous.holding then
		previous.holding = false
		releaseBlock()
	end
	moves[ctx.track] = entry
	labEvent("THREAT", { threat = entry.threat, distance = ctx.distance })

	if ctx.kind == "BARRAGE" and Settings.punishConsec and ctx.distance <= Settings.punishRange + 8 then
		armPunish(entry, "consec")
	end

	if ctx.kind == "BARRAGE" and Settings.consecBlock and ctx.distance <= Settings.consecRange then
		if math.random() * 100 < Settings.consecChance and holdBlock() then
			entry.holding = true
			entry.handled = true
			log("consec: holding block")
		end
	elseif ctx.kind == "SHOVE" and Settings.shoveM1 and ctx.distance <= Settings.shoveRange and Zenny.roll(Settings.shoveRate) then
		local targetRoot = ctx.root
		log("shove seen: M1 queued")
		task.delay(Settings.shoveDelay + Zenny.slop(Settings.shoveRate, 0.1), function()
			local _, myRoot = getMe()
			if myRoot and targetRoot.Parent then
				startLock(targetRoot, true)
				updateLock(myRoot, true)
				clickM1("shove")
			end
		end)
	end
end

---Check whether an enemy's move can reach us right now.
---@param root BasePart
---@param kind string
---@param strict boolean? Also require them to face us.
---@return boolean
function Zenny.canThreaten(root, kind, strict)
	local _, myRoot = getMe()
	if not myRoot or not root.Parent then
		return false
	end

	local offset = myRoot.Position - root.Position
	local distance = offset.Magnitude
	if distance > Settings.blockRange then
		return false
	end

	if kind == "SHOVE" and not Settings.blockShove then
		return false
	end

	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude < 0.1 then
		return true
	end

	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if look.Magnitude > 0.1 then
		local facing = look.Unit:Dot(flat.Unit)
		if strict and facing < 0.2 then
			return false
		end

		if Settings.faceCheck and distance >= 8 and facing < -0.1 then
			return false
		end
	end

	if Settings.blockFov < 359 then
		local ourLook = Vector3.new(myRoot.CFrame.LookVector.X, 0, myRoot.CFrame.LookVector.Z)
		if ourLook.Magnitude > 0.1 then
			local angle = math.deg(math.acos(math.clamp(ourLook.Unit:Dot((-flat).Unit), -1, 1)))
			if angle > Settings.blockFov / 2 then
				return false
			end
		end
	end

	return true
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

			-- They cancelled the move early: do not stay stuck in block for the rest of it.
			if entry.blockEnd and blockUntil == entry.blockEnd and (entry.length or 0) > 0 and elapsed < entry.length - 0.12 and not entry.hitUs then
				local keep = os.clock() + math.max(Settings.blockTail * 0.5, 0.1)
				local chained = false
				for otherTrack, other in pairs(moves) do
					if otherTrack ~= track then
						chained = chained or other.root == entry.root
						if other.blockEnd and other.blockEnd > keep then
							keep = other.blockEnd
						end
					end
				end

				-- A new swing from the same enemy keeps the block, so a string never drops it.
				if not chained and keep < blockUntil then
					blockUntil = keep
					blockHoldUntil = keep
					log("block cut short: move cancelled")
				end
			end

			-- Late fallback for swings whose end could not be predicted.
			if entry.punish and not entry.punishFired then
				firePunish(entry, "move ended")
			end

			if entry.root.Parent and not entry.hitUs then
				lastMoveEnd[entry.root] = os.clock()
			end
			moves[track] = nil
			continue
		end

		-- Send the punish early enough that it arrives as the swing ends.
		if entry.punish and not entry.punishFired and elapsed > 0.15 then
			local remaining = punishRemaining(track, entry, elapsed)
			if remaining and remaining <= getLead() + Settings.punishOffset - (entry.punishSlop or 0) then
				firePunish(entry, "timed")
			end
		end

		if entry.holding then
			blockHoldUntil = os.clock() + 0.2
			if elapsed > 4 then
				entry.holding = false
				releaseBlock()
			end
		end

		-- A move that started out of range can still come for us: check again early on.
		if not entry.threat and not entry.handled and elapsed < 0.7 and Zenny.canThreaten(entry.root, entry.kind, true) then
			entry.threat = true
			log(string.format("%s: late threat, now in range", entry.kind))
		end

		if entry.threat and not entry.handled then
			-- Learned hit timing is only trusted after a few hits, and never delays the block past 0.6s.
			local data = moveData[entry.id]
			local hitTime = Settings.adaptiveBlock and data and data.hits >= 3 and data.hit

			-- Block After: Auto learns it, Ping waits your average ping, Fixed uses the slider.
			local ready
			local sinceSeen = os.clock() - entry.startedAt
			if Settings.blockAfterMode == "Ping" then
				ready = sinceSeen >= (pingAverage or getPing()) / 1000 + entry.slop
			elseif Settings.blockAfterMode == "Fixed" then
				ready = sinceSeen >= Settings.blockAfter + entry.slop
			elseif hitTime then
				ready = elapsed >= math.min(hitTime - lead, 0.6) + entry.slop
			else
				ready = sinceSeen >= entry.slop
			end

			if ready then
				entry.handled = true

				-- Consec moves get dodged when evasive covers them.
				local evaded = false
				if Settings.autoEvasive and Settings.evasiveMode ~= "Ragdoll" and entry.kind == "BARRAGE" then
					evaded = pressEvasive()
				end

				if not evaded and Settings.autoBlock and not entry.rolled then
					log("block skipped: rate roll")
				end

				if not evaded and Settings.autoBlock and entry.rolled then
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
					if Settings.blockHoldMode == "Fixed" then
						duration = Settings.blockHold
					elseif hitTime then
						duration = math.max(hitTime - elapsed + 0.3, Settings.blockHold)
					elseif Settings.blockFull then
						duration = math.clamp((entry.length or 0.5) - elapsed + 0.1, Settings.blockHold, 1.4)
					end

					local expectedEnd = os.clock() + duration + Settings.blockTail
					pressBlock(duration + Settings.blockTail)

					-- Remember our own block end so a cancelled move can shorten it.
					if blockUntil <= expectedEnd + 0.001 then
						entry.blockEnd = blockUntil
					end

					-- Log when the block went down after the animation was seen.
					local row = entry.timingKey and Zenny.timings[entry.timingKey]
					if row then
						row.blockAt = row.blockAt and (row.blockAt * 0.7 + sinceSeen * 0.3) or sinceSeen
					end
					Zenny.timeLog(string.format("block %d ms after %s, hold %.2fs (%s/%s)", math.floor(sinceSeen * 1000), entry.kind, duration, Settings.blockAfterMode, Settings.blockHoldMode))

					-- Blocked an M1: punish it when the swing ends.
					if Settings.punishBlock and entry.kind == "ATTACK" and (learned.m1[entry.id] or (entry.length or 0) <= M1_MAX_LENGTH) then
						armPunish(entry, "block")
					end
				end
			end
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

	if not ownDash then
		Bot.lastAction = track
	end

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
	ctx.timingKey = Zenny.noteTiming(ctx)

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
		or Settings.bdcCatch
		or Settings.frontBlock
		or Settings.safeIndicator
		or Settings.counterBait
		or Settings.counterPunish
		or Settings.punishBlock
		or Settings.punishConsec
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
		BackgroundColor3 = Color3.fromRGB(10, 10, 10),
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
		BackgroundColor3 = Color3.fromRGB(10, 10, 10),
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

	data.adapt = Bot.adapt

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

	for name, entry in pairs(data.adapt or {}) do
		if type(entry) == "table" and type(entry.techs) == "table" then
			Bot.adapt[name] = { techs = entry.techs, block = entry.block or 0, aggro = entry.aggro or 0 }
		end
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

---Work out how to face for a dash to travel where we want.
---@param myRoot BasePart
---@param targetRoot BasePart
---@param dashKey Enum.KeyCode
---@param hook boolean|string Curve side dashes in toward the target.
---@param point Vector3? Aim here instead of at the target.
---@param human boolean? Blend toward the perfect aim by the assist strength instead of snapping.
---@param jitter boolean? Add the random wobble; the predictor line leaves it out.
---@return Vector3?, Vector3?, Vector3?
function Bot.solveDash(myRoot, targetRoot, dashKey, hook, point, human, jitter)
	local lead = human and Settings.assistLead or 0.1
	local predicted = point or (targetRoot.Position + targetRoot.AssemblyLinearVelocity * lead)
	local offset = (predicted - myRoot.Position) * Vector3.new(1, 0, 1)
	if offset.Magnitude < 0.1 then
		return nil
	end

	local toward = offset.Unit
	local look = toward
	local sideSign = dashKey == Enum.KeyCode.D and 1 or -1
	local side = dashKey == Enum.KeyCode.A or dashKey == Enum.KeyCode.D

	if side then
		-- Our right vector is (-look.Z, 0, look.X); the dash goes along it or its opposite.
		local tangent = Vector3.new(-toward.Z, 0, toward.X) * sideSign
		-- "away" bends outward for a hook; true bends inward for a circle dash.
		local angle = hook == "away" and -math.rad(Settings.hookAwayAngle) or (hook and math.rad(Settings.hookAngle) or 0)
		local desired = tangent * math.cos(angle) + toward * math.sin(angle)
		local right = desired * sideSign
		look = Vector3.new(right.Z, 0, -right.X)
	end

	if human then
		-- Turn part of the way from where we face, never more than the max turn.
		local current = myRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
		if current.Magnitude > 0.1 then
			current = current.Unit
			local delta = math.atan2(current:Cross(look).Y, current:Dot(look))
			local turn = math.clamp(delta * Settings.assistStrength / 100, -math.rad(Settings.assistMaxTurn), math.rad(Settings.assistMaxTurn))
			if jitter then
				turn += math.rad((math.random() * 2 - 1) * Settings.assistJitter)
			end

			look = CFrame.Angles(0, turn, 0):VectorToWorldSpace(current)
		end
	end

	local travel
	if side then
		travel = Vector3.new(-look.Z, 0, look.X) * sideSign
	elseif dashKey == Enum.KeyCode.S then
		travel = -look
	else
		travel = look
	end

	return look, travel, predicted
end

---Rotate our character so a dash of this key travels where we want.
---@param myRoot BasePart
---@param targetRoot BasePart
---@param dashKey Enum.KeyCode
---@param hook boolean|string Curve side dashes in toward the target.
---@param point Vector3? Aim here instead of at the target.
---@param human boolean? Blend instead of snapping.
function Bot.aimDash(myRoot, targetRoot, dashKey, hook, point, human)
	local look = Bot.solveDash(myRoot, targetRoot, dashKey, hook, point, human, human)
	if look then
		myRoot.CFrame = CFrame.lookAt(myRoot.Position, myRoot.Position + look)
	end
end

---Fire a dash of one key aimed at the target, then keep facing them.
---@param myRoot BasePart
---@param targetRoot BasePart
---@param dashKey Enum.KeyCode
---@param hook boolean|string
---@param point Vector3?
---@return boolean
function Bot.dash(myRoot, targetRoot, dashKey, hook, point)
	local remote = getRemote()
	if not remote then
		return false
	end

	Bot.aimDash(myRoot, targetRoot, dashKey, hook, point)
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
	if not (myRoot and targetRoot and myRoot.Parent and targetRoot.Parent) then
		return
	end

	local flat = ((targetRoot.Position - myRoot.Position) * Vector3.new(1, 0, 1)).Magnitude

	-- A front dash close to someone locks on to them for a moment.
	if dashKey == Enum.KeyCode.W and Settings.frontLock and flat <= Settings.frontLockRange then
		Bot.engageFrontLock(targetRoot.Parent)
	end

	if kind then
		-- Close dashes circle around them; far ones are long arms and stay straight.
		Bot.aimDash(myRoot, targetRoot, dashKey, Settings.assistHook and flat <= Settings.hookRange, nil, true)
	end
end

---Lock on to someone for a short while after a close front dash.
---@param character Model?
function Bot.engageFrontLock(character)
	if not character then
		return
	end

	if not Bot.lockOn then
		Bot.frontLockAuto = true
		Bot.lockOn = true
	end

	Bot.lockTarget = character
	Bot.frontLockUntil = os.clock() + Settings.frontLockTime
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

---Get the neutral spacing band: perfect spacing keeps them just outside their reach.
---@return number, number
function Bot.getSpacing()
	if Settings.spacePerfect then
		local low = Settings.spaceTiles * Bot.tile - 1 + Bot.spaceBonus
		return low, low + 3
	end

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
	Bot.frontLockAuto = false
	Bot.frontLockUntil = nil
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

	-- Shift lock turns the character with the camera, so the camera lock does the facing there.
	local root = Bot.lockTarget and Bot.getParts(Bot.lockTarget)
	if root and not Bot.active and Settings.lockFaceChar and not techBusy and not Bot.shiftLockOn() then
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

	-- Shift lock: the camera sits off the shoulder, so aim from where it is and turn the character with it.
	if Bot.shiftLockOn() then
		local position = camera.CFrame.Position
		local goal = CFrame.lookAt(position, aim)
		camera.CFrame = camera.CFrame:Lerp(goal, math.clamp(delta * Settings.lockSpeed * 1.5, 0, 1))

		local myRoot = Bot.myRoot
		if Settings.lockFaceChar and myRoot and myRoot.Parent and not techBusy then
			local flat = (aim - myRoot.Position) * Vector3.new(1, 0, 1)
			if flat.Magnitude > 0.1 then
				myRoot.CFrame = CFrame.lookAt(myRoot.Position, myRoot.Position + flat)
			end
		end
		return
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

---Whether shift lock is on, so the camera is what turns the character.
---@return boolean
function Bot.shiftLockOn()
	if userInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		return true
	end

	local ok, rotation = pcall(function()
		return UserSettings():GetService("UserGameSettings").RotationType
	end)
	return ok and rotation == Enum.RotationType.CameraRelative
end

---Pick who the dash assist aims at.
---@param myRoot BasePart
function Bot.updateAssistTarget(myRoot)
	if not (Settings.assistSide or Settings.assistFront or Settings.assistBack or Settings.frontLock or Settings.assistLines) then
		Bot.assistRoot = nil
		return
	end

	-- A double tapped player comes first, then the lock, then whoever is nearest.
	local tapRoot = Bot.tapTarget and Bot.tapTarget.Parent and Bot.getParts(Bot.tapTarget)
	if tapRoot and (tapRoot.Position - myRoot.Position).Magnitude <= Settings.assistRange * 2 then
		Bot.assistRoot = tapRoot
		return
	end

	local lockRoot = Bot.lockOn and Bot.lockTarget and Bot.getParts(Bot.lockTarget)
	Bot.assistRoot = lockRoot or getNearestTarget(myRoot, Settings.assistRange)
end

---Double tap a player's body to make them the side dash assist target; double tap them again or empty space to clear.
---@param input InputObject
---@param processed boolean
function Bot.onTap(input, processed)
	if processed or not Settings.tapTarget then
		return
	end

	local kind = input.UserInputType
	if kind ~= Enum.UserInputType.Touch and kind ~= Enum.UserInputType.MouseButton1 then
		return
	end

	local now = os.clock()
	local position = Vector2.new(input.Position.X, input.Position.Y)
	local last = Bot.lastTap
	Bot.lastTap = { t = now, position = position }
	if not last or now - last.t > 0.4 or (position - last.position).Magnitude > 45 then
		return
	end

	Bot.lastTap = nil
	Bot.pickTapTarget(position)
end

---Choose the player whose body is nearest a screen point.
---@param position Vector2
function Bot.pickTapTarget(position)
	local camera = workspace.CurrentCamera
	local myCharacter = getMe()
	if not camera then
		return
	end

	local container = workspace:FindFirstChild("Live") or workspace
	local best, bestDistance = nil, 90

	for _, character in ipairs(container:GetChildren()) do
		if character == myCharacter or not character:IsA("Model") or isIgnored(character) then
			continue
		end

		local root = Bot.getParts(character)
		if not root then
			continue
		end

		for _, part in ipairs({ root, character:FindFirstChild("Head") }) do
			local screen, onScreen = camera:WorldToScreenPoint(part.Position)
			if onScreen then
				local distance = (Vector2.new(screen.X, screen.Y) - position).Magnitude
				if distance < bestDistance then
					best, bestDistance = character, distance
				end
			end
		end
	end

	if best and best ~= Bot.tapTarget then
		Bot.tapTarget = best
		log("assist target: " .. best.Name)
	else
		Bot.tapTarget = nil
		log("assist target: cleared")
	end
end

---Create one world line or marker for the assist display.
---@param className string
---@param color Color3
---@return Instance
function Bot.makeAdornment(className, color)
	local adornment = newInstance(className, {
		Color3 = color,
		Transparency = 0.15,
		AlwaysOnTop = true,
		ZIndex = 5,
		Visible = false,
	}, holder)
	if className == "SphereHandleAdornment" then
		adornment.Radius = 0.7
	end

	return adornment
end

---Stretch a line adornment between two world points.
---@param line BoxHandleAdornment
---@param root BasePart
---@param from Vector3
---@param to Vector3
function Bot.placeLine(line, root, from, to)
	local delta = to - from
	if delta.Magnitude < 0.2 then
		line.Visible = false
		return
	end

	line.Adornee = root
	line.Size = Vector3.new(0.14, 0.14, delta.Magnitude)
	line.CFrame = root.CFrame:ToObjectSpace(CFrame.lookAt(from + delta / 2, to))
	line.Visible = true
end

---Put a sphere marker at a world point.
---@param marker SphereHandleAdornment
---@param root BasePart
---@param point Vector3
function Bot.placeMarker(marker, root, point)
	marker.Adornee = root
	marker.CFrame = root.CFrame:ToObjectSpace(CFrame.new(point))
	marker.Visible = true
end

---Draw the aim line and the pink predicted dash paths; runs every render step.
function Bot.updateLines()
	local lines = Bot.lines
	local myRoot, targetRoot = Bot.myRoot, Bot.assistRoot
	local pink = Color3.fromRGB(255, 105, 200)

	-- Mark the double tapped player.
	local tapped = Bot.tapTarget
	if tapped and (not tapped.Parent or not Bot.getParts(tapped)) then
		Bot.tapTarget = nil
		tapped = nil
	end
	if tapped and Settings.assistLines then
		if not Bot.tapMarker then
			Bot.tapMarker = newInstance("Highlight", {
				FillTransparency = 1,
				OutlineColor = pink,
				OutlineTransparency = 0.1,
				DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
			}, holder)
		end
		Bot.tapMarker.Adornee = tapped
	elseif Bot.tapMarker then
		Bot.tapMarker:Destroy()
		Bot.tapMarker = nil
	end

	local show = Settings.assistLines and Settings.assistSide and myRoot and targetRoot and myRoot.Parent and targetRoot.Parent
	if not show then
		if lines then
			for _, adornment in pairs(lines) do
				adornment.Visible = false
			end
		end
		return
	end

	if not lines or not lines.aim.Parent then
		lines = {
			aim = Bot.makeAdornment("BoxHandleAdornment", Color3.fromRGB(255, 255, 255)),
			aimMark = Bot.makeAdornment("SphereHandleAdornment", Color3.fromRGB(255, 255, 255)),
			pathA = Bot.makeAdornment("BoxHandleAdornment", pink),
			pathD = Bot.makeAdornment("BoxHandleAdornment", pink),
			endA = Bot.makeAdornment("SphereHandleAdornment", pink),
			endD = Bot.makeAdornment("SphereHandleAdornment", pink),
		}
		lines.aim.Transparency = 0.45
		lines.aimMark.Radius = 0.45
		Bot.lines = lines
	end

	-- White line from us to where the assist is aiming (their predicted spot).
	local from = myRoot.Position
	local predicted = targetRoot.Position + targetRoot.AssemblyLinearVelocity * Settings.assistLead
	Bot.placeLine(lines.aim, myRoot, from, predicted)
	Bot.placeMarker(lines.aimMark, myRoot, predicted)

	-- Which side dashes to preview: the one you are leaning into, or both.
	local wantA, wantD = true, true
	local humanoid = Bot.myHumanoid
	if humanoid then
		local lateral = humanoid.MoveDirection:Dot(myRoot.CFrame.RightVector)
		if userInputService:IsKeyDown(Enum.KeyCode.D) or lateral > 0.35 then
			wantA = false
		elseif userInputService:IsKeyDown(Enum.KeyCode.A) or lateral < -0.35 then
			wantD = false
		end
	end

	local flat = ((targetRoot.Position - myRoot.Position) * Vector3.new(1, 0, 1)).Magnitude
	local hook = Settings.assistHook and flat <= Settings.hookRange
	for _, info in ipairs({ { Enum.KeyCode.A, wantA, lines.pathA, lines.endA }, { Enum.KeyCode.D, wantD, lines.pathD, lines.endD } }) do
		local _, travel = Bot.solveDash(myRoot, targetRoot, info[1], hook, nil, true, false)
		if info[2] and travel then
			local finish = from + travel * Settings.assistDashLength
			Bot.placeLine(info[3], myRoot, from, finish)
			Bot.placeMarker(info[4], myRoot, finish)
		else
			info[3].Visible = false
			info[4].Visible = false
		end
	end
end

---Keep facing the target through our own dash and M1 at the end of it.
---@param kind string
---@param track AnimationTrack
function Bot.onOwnDash(kind, track)
	-- Dashing while an attack is still playing is a dash cancel.
	local now = os.clock()
	if Settings.dashCancelPopup and Bot.lastAction and Bot.lastAction ~= track and Bot.lastAction.IsPlaying then
		Bot.cancelCount = (now - Bot.cancelAt < 3) and Bot.cancelCount + 1 or 1
		Bot.cancelAt = now
		Bot.popup(string.format("+%d DASH CANCEL", Bot.cancelCount), COLORS.now, 0.62)
	end

	if Settings.sideBoost and (kind == "LEFT" or kind == "RIGHT") then
		Bot.boostDash(kind, track)
	end

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

---Stretch a side dash: once the game's own dash ends, keep pushing along it.
---@param kind string
---@param track AnimationTrack
function Bot.boostDash(kind, track)
	local character, myRoot, humanoid = getMe()
	if Bot.boosting or not (character and myRoot and humanoid) or Settings.boostLength <= 1.01 then
		return
	end

	local cframe = myRoot.CFrame
	local side = kind == "RIGHT" and cframe.RightVector or -cframe.RightVector
	local direction = Vector3.new(side.X, 0, side.Z)
	if direction.Magnitude < 0.1 then
		return
	end
	direction = direction.Unit

	Bot.boosting = true
	task.spawn(function()
		local length = track.Length > 0 and track.Length or 0.4
		local speed = dashSpeeds[kind] or Settings.catchSpeed
		local startedAt = os.clock()
		local endAt = startedAt + length * Settings.boostLength

		while os.clock() < endAt and myRoot.Parent and humanoid.Health > 0 do
			runService.Heartbeat:Wait()
			if isRagdolled(character, humanoid) then
				break
			end

			-- The game's own dash covers the first stretch.
			if os.clock() - startedAt >= length then
				local velocity = myRoot.AssemblyLinearVelocity
				myRoot.AssemblyLinearVelocity = Vector3.new(direction.X * speed, velocity.Y, direction.Z * speed)
			end
		end

		Bot.boosting = false
	end)
end

---Flash a short message on screen; a new one at the same height replaces the old.
---@param text string
---@param color Color3
---@param height number Screen height as a 0-1 scale.
function Bot.popup(text, color, height)
	if not gui then
		return
	end

	local previous = Bot.popups[height]
	if previous then
		previous:Destroy()
	end

	local label = newInstance("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, height),
		Size = UDim2.fromOffset(280, 30),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color,
		TextTransparency = 1,
		TextStrokeTransparency = 0.5,
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
	}, gui)
	Bot.popups[height] = label

	tween(label, { TextTransparency = 0, Position = UDim2.fromScale(0.5, height - 0.02) }, QUICK)
	task.delay(0.9, function()
		if not label.Parent then
			return
		end

		tween(label, { TextTransparency = 1, TextStrokeTransparency = 1 })
		task.delay(0.3, function()
			label:Destroy()
		end)
	end)
end

---Flip a feature from its toggle key and show the result.
---@param bind table
function Bot.toggle(bind)
	Settings[bind.setting] = not Settings[bind.setting]

	local refresh = uiRefreshers[bind.setting]
	if refresh then
		refresh(true)
	end

	local on = Settings[bind.setting]
	Bot.popup(string.format("%s %s", bind.title, on and "ON" or "OFF"), on and COLORS.good or COLORS.bad, 0.12)
	log(string.format("%s toggled %s", bind.title, on and "on" or "off"))
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

---Chance weights for a tech before any results: what the opponent seems to do decides them.
---@param name string
---@param entry table
---@return number
function Bot.techPrior(name, entry)
	local block = entry.block or 0
	local aggro = entry.aggro or 0
	if name == "bullet" then
		return 0.45 + 0.2 * (1 - block)
	elseif name == "skibidi" then
		return 0.5 + 0.25 * block
	elseif name == "circle" then
		return 0.5 + 0.15 * block
	elseif name == "longarm" then
		return 0.35
	elseif name == "bdc" then
		return 0.45 + 0.2 * aggro
	elseif name == "hook" then
		return 0.5 + 0.2 * aggro
	elseif name == "back" then
		return 0.4
	elseif name == "m1" then
		return 0.55
	end

	return 0.5
end

---Get the adapter's record of an opponent; "*" is everyone together.
---@param name string
---@return table
function Bot.adaptFor(name)
	local entry = Bot.adapt[name]
	if not entry then
		entry = { techs = {}, block = 0, aggro = 0 }
		Bot.adapt[name] = entry
	end

	return entry
end

---Pick a tech from the candidates, favoring what has worked on this opponent lately.
---@param candidates string[]
---@param targetName string
---@return string
function Bot.chooseTech(candidates, targetName)
	if #candidates == 1 then
		return candidates[1]
	end

	local entry = Bot.adaptFor(targetName)
	local everyone = Bot.adaptFor("*")
	local share = Bot.hookShare()
	local weights, total = {}, 0

	for index, name in ipairs(candidates) do
		local weight = 1
		if Settings.adapterOn then
			local prior = Bot.techPrior(name, entry)
			local global = everyone.techs[name]
			if global and global.tries >= 2 then
				prior = (prior + (global.wins + 1) / (global.tries + 2)) / 2
			end

			local stat = entry.techs[name] or { tries = 0, wins = 0 }
			weight = 0.15 + (stat.wins + prior * 2) / (stat.tries + 2)
		end

		-- What was learned about how often players hook instead of backing off.
		if name == "hook" then
			weight *= 0.5 + share
		elseif name == "back" then
			weight *= 1.5 - share
		end

		weights[index] = weight
		total += weight
	end

	if Settings.adapterOn and math.random() < 0.15 then
		return candidates[math.random(#candidates)]
	end

	local roll = math.random() * total
	for index, name in ipairs(candidates) do
		roll -= weights[index]
		if roll <= 0 then
			return name
		end
	end

	return candidates[#candidates]
end

---Store how a tech did against an opponent; old results fade so the adapter follows the present.
---@param targetName string
---@param name string
---@param success boolean
function Bot.recordTech(targetName, name, success)
	for _, key in ipairs({ targetName, "*" }) do
		local entry = Bot.adaptFor(key)
		local stat = entry.techs[name]
		if not stat then
			stat = { tries = 0, wins = 0 }
			entry.techs[name] = stat
		end

		stat.tries = stat.tries * 0.9 + 1
		stat.wins = stat.wins * 0.9 + (success and 1 or 0)
	end

	Bot.lastTech = name .. (success and " worked" or " failed")
end

---Start judging a tech: offensive ones need a hit, defensive ones need us to stay unhurt.
---@param name string
---@param targetCharacter Model
---@param targetHumanoid Humanoid
---@param myHumanoid Humanoid
---@param now number
function Bot.beginTech(name, targetCharacter, targetHumanoid, myHumanoid, now)
	Bot.pendingTech = {
		name = name,
		targetName = targetCharacter.Name,
		humanoid = targetHumanoid,
		targetHealth = targetHumanoid.Health,
		myHealth = myHumanoid.Health,
		startedAt = now,
		defensive = name == "hook" or name == "back",
	}
end

---Settle the tech being judged.
---@param now number
---@param myHumanoid Humanoid
---@param targetHumanoid Humanoid
function Bot.updateTech(now, myHumanoid, targetHumanoid)
	local pending = Bot.pendingTech
	if not pending then
		return
	end

	if pending.humanoid ~= targetHumanoid then
		Bot.pendingTech = nil
		return
	end

	if myHumanoid.Health < pending.myHealth - 0.5 then
		Bot.pendingTech = nil
		Bot.recordTech(pending.targetName, pending.name, false)
	elseif not pending.defensive and targetHumanoid.Health < pending.targetHealth - 0.5 then
		Bot.pendingTech = nil
		Bot.recordTech(pending.targetName, pending.name, true)
	elseif now - pending.startedAt >= Settings.techWindow then
		Bot.pendingTech = nil
		Bot.recordTech(pending.targetName, pending.name, pending.defensive)
	end
end

---Learn how the opponent plays: how much they block and how much they swing.
---@param targetCharacter Model
---@param flatDistance number
---@param attacking boolean
---@param now number
function Bot.updateOpponent(targetCharacter, flatDistance, attacking, now)
	if now - Bot.oppAt < 0.1 then
		return
	end

	local dt = math.min(now - Bot.oppAt, 0.5)
	Bot.oppAt = now
	if flatDistance > 30 then
		return
	end

	-- About a six second memory.
	local alpha = math.clamp(dt / 6, 0, 1)
	local entry = Bot.adaptFor(targetCharacter.Name)
	entry.block += ((isBlocking(targetCharacter) and 1 or 0) - entry.block) * alpha
	entry.aggro += ((attacking and 1 or 0) - entry.aggro) * alpha
end

---Run a list of macro steps on a target, giving up if we have to block.
---@param name string
---@param steps table
---@param targetRoot BasePart
---@return boolean
function Bot.runMacro(name, steps, targetRoot)
	if Bot.macroRun or Bot.comboRun then
		return false
	end

	local run = { name = name }
	Bot.macroRun = run
	log("macro: " .. name)

	task.spawn(function()
		for _, step in ipairs(steps) do
			if run.cancel then
				break
			end

			if step[1] == "wait" then
				task.wait(step[2])
			else
				local _, myRoot, myHumanoid = getMe()
				local blocked = Settings.comboCancel and (blockDown or os.clock() < blockUntil)
				if blocked or not (myRoot and myHumanoid) or myHumanoid.Health <= 0 or not targetRoot.Parent then
					break
				end

				if step[1] == "dash" then
					Bot.dash(myRoot, targetRoot, step[2], step[3])
				elseif step[1] == "skibidi" then
					Bot.dash(myRoot, targetRoot, Enum.KeyCode.W, false, Bot.behindPoint(targetRoot))
				elseif step[1] == "run" then
					step[2]()
				end
			end
		end

		Bot.macroRun = nil
	end)

	return true
end

---A spot behind the target, for the skibidi dash.
---@param targetRoot BasePart
---@return Vector3
function Bot.behindPoint(targetRoot)
	local look = targetRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
	local lead = targetRoot.AssemblyLinearVelocity * 0.1
	return targetRoot.Position + lead - (look.Magnitude > 0.1 and look.Unit or Vector3.zero) * Settings.skibidiOffset
end

---Which techs fit at this distance.
---@param flatDistance number
---@return string[]
function Bot.approachCandidates(flatDistance)
	local list = {}
	if Settings.botHook and flatDistance <= Settings.hookRange then
		table.insert(list, "circle")
	end

	if flatDistance >= Settings.bulletMin and flatDistance <= Settings.bulletMax and not isOnCooldown("forward") then
		if Settings.bulletDash then
			table.insert(list, "bullet")
		end
		if Settings.skibidiDash then
			table.insert(list, "skibidi")
		end
	end

	if Settings.longArm and Bot.longArmOk and flatDistance > Settings.hookRange and flatDistance <= Settings.hookRange * 2.2 then
		table.insert(list, "longarm")
	end

	return list
end

---Perform an approach tech and go into the pressure phase behind it.
---@param name string
---@param myRoot BasePart
---@param targetRoot BasePart
---@param targetCharacter Model
---@param targetHumanoid Humanoid
---@param myHumanoid Humanoid
---@param flatDistance number
---@param now number
function Bot.useTech(name, myRoot, targetRoot, targetCharacter, targetHumanoid, myHumanoid, flatDistance, now)
	local side = math.random() < 0.5 and Enum.KeyCode.A or Enum.KeyCode.D
	Bot.nextDash = now + 1.2

	if name == "circle" then
		Bot.dash(myRoot, targetRoot, side, true)
	elseif name == "longarm" then
		Bot.dash(myRoot, targetRoot, side, false)
	elseif name == "bullet" then
		Bot.dash(myRoot, targetRoot, Enum.KeyCode.W, false)
	elseif name == "skibidi" then
		Bot.dash(myRoot, targetRoot, Enum.KeyCode.W, false, Bot.behindPoint(targetRoot))
	end

	Bot.mode = "PRESSURE"
	Bot.modeUntil = now + 2.5
	Bot.hits = 0
	Bot.beginTech(name, targetCharacter, targetHumanoid, myHumanoid, now)
	log(string.format("bot: %s (%d studs)", name, flatDistance))
end

---Loop dash: circle around them between hits and keep the string going.
---@param targetRoot BasePart
---@return boolean
function Bot.loopMacro(targetRoot)
	local side = math.random() < 0.5 and Enum.KeyCode.A or Enum.KeyCode.D
	Bot.nextDash = os.clock() + 1.2
	return Bot.runMacro("loop dash", {
		{ "wait", Settings.loopDelay },
		{ "dash", side, true },
		{ "wait", Settings.loopFollow },
	}, targetRoot)
end

---Backdash cancel: cut the endlag with a back dash, then come back in with a bullet dash.
---@param targetRoot BasePart
---@return boolean
function Bot.bdcMacro(targetRoot)
	Bot.nextDash = os.clock() + 1.5
	return Bot.runMacro("backdash cancel", {
		{ "wait", Settings.cancelDelay },
		{ "dash", Enum.KeyCode.S, false },
		{ "wait", Settings.bdcReturn },
		{
			"run",
			function()
				Bot.mode = "PRESSURE"
				Bot.modeUntil = os.clock() + 2
				Bot.hits = 0
			end,
		},
		{ "dash", Enum.KeyCode.W, false },
	}, targetRoot)
end

---After a hit: maybe break into a loop dash or a backdash cancel.
---@param targetCharacter Model
---@param targetRoot BasePart
---@param targetHumanoid Humanoid
---@param myHumanoid Humanoid
---@param now number
function Bot.afterHit(targetCharacter, targetRoot, targetHumanoid, myHumanoid, now)
	if now < Bot.nextDash then
		return
	end

	local candidates = {}
	if Settings.loopDash and Bot.hits == Settings.loopHits then
		table.insert(candidates, "loop")
	end
	if Settings.bdcMacro and Bot.hits == Settings.bdcHits then
		table.insert(candidates, "bdc")
	end

	if #candidates == 0 then
		return
	end

	table.insert(candidates, "m1")
	local pick = Bot.chooseTech(candidates, targetCharacter.Name)
	if pick == "loop" and Bot.loopMacro(targetRoot) or pick == "bdc" and Bot.bdcMacro(targetRoot) then
		Bot.beginTech(pick, targetCharacter, targetHumanoid, myHumanoid, now)
	end
end

---Fight the target: spacing, pressure phases, dashes, macros, combos and M1 strings.
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
		if Bot.macroRun then
			Bot.macroRun.cancel = true
		end
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

	-- Adapt: hits taken while spacing mean the spacing is too tight, so widen it for a while.
	local health = myHumanoid.Health
	local dt = math.min(now - Bot.lastTick, 0.2)
	if Bot.lastTick == 0 then
		Bot.lastHealth = health
	end
	Bot.lastTick = now

	if Settings.adapterOn then
		if health < Bot.lastHealth - 0.5 and Bot.mode == "NEUTRAL" and not attacking and now - Bot.bonusAt > 1.5 then
			Bot.spaceBonus = math.min(Bot.spaceBonus + 1, 4)
			Bot.bonusAt = now
		end
		Bot.spaceBonus = math.max(Bot.spaceBonus - 0.1 * dt, 0)
		Bot.updateOpponent(targetCharacter, flatDistance, attacking, now)
		Bot.updateTech(now, myHumanoid, targetHumanoid)
	else
		Bot.spaceBonus = 0
		Bot.pendingTech = nil
	end
	Bot.lastHealth = health

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
		if attacking or retreat or (now > Bot.modeUntil and not Bot.comboRun and not Bot.macroRun) then
			Bot.endPressure(now)
		end
	elseif Bot.mode == "RESET" and now >= Bot.modeUntil then
		Bot.mode = "NEUTRAL"
	end

	-- A macro owns the next moments; only blocking can interrupt it.
	if Bot.macroRun then
		Bot.moveVector = Vector3.zero
		Bot.status = "Macro: " .. Bot.macroRun.name
		return
	end

	Bot.updateMove(myRoot, targetRoot, distance, retreat, attacking, now)
	local pressure = Bot.mode == "PRESSURE"
	local reach = Settings.botReach
	Bot.rollLongArm(now)

	-- After a string: hook away from them or step straight back, whichever has worked.
	if Bot.resetPending and now >= Bot.resetAt then
		Bot.resetPending = false
		if not blocking and now >= Bot.nextDash and flatDistance < Settings.backStepRange then
			local candidates = {}
			if Settings.hookAway then
				table.insert(candidates, "hook")
			end
			if Settings.botBackStep then
				table.insert(candidates, "back")
			end

			local pick = #candidates > 0 and Bot.chooseTech(candidates, targetCharacter.Name) or nil
			if pick == "hook" then
				Bot.nextDash = now + 0.7
				Bot.hookUntil = now + 1.5
				Bot.faded = false
				Bot.dash(myRoot, targetRoot, math.random() < 0.5 and Enum.KeyCode.A or Enum.KeyCode.D, "away")
				Bot.beginTech("hook", targetCharacter, targetHumanoid, myHumanoid, now)
				log("bot: hook away")
			elseif pick == "back" then
				Bot.nextDash = now + 1.2
				Bot.dash(myRoot, targetRoot, Enum.KeyCode.S, false)
				Bot.beginTech("back", targetCharacter, targetHumanoid, myHumanoid, now)
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

	-- Close the gap: the tech dash from far away, otherwise bullet, skibidi, circle or long arm.
	if pressure and not retreat and not blocking and not Bot.comboRun and Settings.botDashIn and now >= Bot.nextDash and flatDistance > reach + 3 then
		if Settings.botUseTech and flatDistance > Settings.botDashRange and not isOnCooldown("forward") then
			Bot.nextDash = now + 1.2
			updateLock(myRoot, true)
			task.spawn(runTech, myRoot, targetRoot)
			log(string.format("bot: tech dash (%d studs)", flatDistance))
		else
			local candidates = Bot.approachCandidates(flatDistance)
			if #candidates > 0 then
				Bot.useTech(Bot.chooseTech(candidates, targetCharacter.Name), myRoot, targetRoot, targetCharacter, targetHumanoid, myHumanoid, flatDistance, now)
			end
		end
	end

	-- Spacing and strafing, then a surprise bullet or skibidi dash out of neutral.
	if competitive and Bot.mode == "NEUTRAL" and Settings.surprise and not attacking and not blocking and not retreat and now >= Bot.nextSurprise and now >= Bot.nextDash then
		local candidates = Bot.approachCandidates(flatDistance)
		if #candidates > 0 then
			Bot.nextSurprise = now + Settings.surpriseEvery * (0.6 + math.random() * 0.8)
			Bot.useTech(Bot.chooseTech(candidates, targetCharacter.Name), myRoot, targetRoot, targetCharacter, targetHumanoid, myHumanoid, flatDistance, now)
			Bot.reason = "poke"
		end
	end

	-- Neutral side dashes change the angle without committing.
	if competitive and Bot.mode == "NEUTRAL" and Settings.neutralDash and not attacking and not blocking and now >= Bot.nextSide and now >= Bot.nextDash and flatDistance > reach + 1 then
		Bot.nextSide = now + Bot.sideInterval()
		Bot.nextDash = now + 1.2
		Bot.dash(myRoot, targetRoot, math.random() < 0.5 and Enum.KeyCode.A or Enum.KeyCode.D, false)
	end

	-- Recorded combo when they are close enough.
	if pressure and not blocking and not retreat and not Bot.comboRun and Settings.comboUse and flatDistance <= Settings.comboRange and now >= Bot.comboReadyAt then
		local reason = competitive and Bot.reason or nil
		if isBlocking(targetCharacter) then
			reason = "guard"
		elseif isRagdolled(targetCharacter, targetHumanoid) then
			reason = "ragdoll"
		end

		local slot = Bot.pickCombo(reason)
		if slot and Bot.playCombo(slot, targetRoot) then
			Bot.comboReadyAt = now + Settings.comboCooldown
			Bot.hits = 0
		end
	end

	-- M1 string: blocks hold F and F stops M1, so never swing while blocking.
	local canSwing = pressure and not Bot.comboRun and not blocking and not retreat and flatDistance <= reach and now >= Bot.nextM1
	if canSwing and Settings.botRespectBlock and isBlocking(targetCharacter) then
		canSwing = false
		Bot.status = "Target blocking"
	elseif canSwing and isCountering(targetCharacter) then
		canSwing = false
		Bot.status = "Target countering"
	end

	if canSwing then
		if now - Bot.lastM1 > 1 then
			Bot.hits = 0
		end

		updateLock(myRoot, true)
		if clickM1("bot") then
			Bot.lastM1 = now
			Bot.hits += 1

			if Bot.hits >= Settings.botStringHits then
				Bot.hits = 0
				Bot.nextM1 = now + Settings.botComboPause

				-- A taught finisher ends the string; it ends the pressure phase when it is done.
				local finisher = competitive and Bot.combos.Finisher
				if finisher and #finisher.events > 0 and Bot.playCombo("Finisher", targetRoot) then
					Bot.status = "Finisher"
				elseif competitive then
					Bot.endPressure(now)
				end
			else
				Bot.nextM1 = now + Settings.botM1Rate
				Bot.afterHit(targetCharacter, targetRoot, targetHumanoid, myHumanoid, now)
			end
		end

		Bot.status = "Attacking " .. targetCharacter.Name
	elseif Bot.comboRun then
		Bot.status = "Combo: " .. Bot.comboRun.slot
	elseif retreat then
		Bot.status = "Retreating"
	elseif blocking then
		Bot.status = "Blocking"
	elseif Bot.mode == "NEUTRAL" then
		Bot.status = "Spacing " .. targetCharacter.Name
	elseif Bot.mode == "RESET" then
		Bot.status = "Resetting"
	elseif flatDistance > reach then
		Bot.status = "Closing in on " .. targetCharacter.Name
	end
end

---Play the selected combo on the lock target or the nearest enemy.
function Bot.playSelected()
	local _, myRoot = getMe()
	local lockRoot = Bot.lockOn and Bot.lockTarget and Bot.getParts(Bot.lockTarget)
	local targetRoot = lockRoot or (myRoot and getNearestTarget(myRoot, 25))
	local slot = Bot.pickCombo()
	if targetRoot and slot then
		Bot.playCombo(slot, targetRoot)
	end
end

Bot.lessons = {
	{ id = "strafe", name = "Strafe & Spacing", detail = "Fight around a target for 30s", duration = 30 },
	{ id = "dash", name = "Dash Habits", detail = "Front, circle, long arm and hook for 40s", duration = 40 },
	{ id = "circle", name = "Circle Dash", detail = "Side dash close to a target for 40s", duration = 40 },
	{ id = "hookaway", name = "Hook Away", detail = "M1 then side dash away for 40s", duration = 40 },
	{ id = "punish", name = "Punish Combo", detail = "Record what you do after they miss" },
	{ id = "poke", name = "Poke Combo", detail = "Record the combo you start with" },
	{ id = "m1", name = "M1 Rhythm", detail = "M1 a target for 30s: speed, string, reach", duration = 30 },
	{ id = "back", name = "Back Step Habits", detail = "M1 then back dash for 40s", duration = 40 },
	{ id = "block", name = "Block Habits", detail = "Block attacks for 40s", duration = 40 },
	{ id = "escape", name = "Ragdoll Escape", detail = "Get ragdolled and dash out for 60s", duration = 60 },
	{ id = "ragdoll", name = "Ragdoll Combo", detail = "Record your combo on a ragdolled target" },
	{ id = "guard", name = "Guard Break", detail = "Record what you do into a blocker" },
	{ id = "finisher", name = "Finisher", detail = "Record what you do to end a string" },
	{ id = "combo1", name = "Combo 1", detail = "Record your first custom combo" },
	{ id = "combo2", name = "Combo 2", detail = "Record your second custom combo" },
	{ id = "combo3", name = "Combo 3", detail = "Record your third custom combo" },
	{ id = "combo4", name = "Combo 4", detail = "Record your fourth custom combo" },
	{ id = "loop", name = "Loop Dash", detail = "M1 then circle dash, repeat, for 40s", duration = 40 },
	{ id = "bdc", name = "Backdash Cancel", detail = "M1, back dash, then front dash for 40s", duration = 40 },
	{ id = "bullet", name = "Bullet Dash", detail = "Front dash at a target for 40s", duration = 40 },
	{ id = "spacing", name = "Perfect Spacing", detail = "Space a target the way you like for 30s", duration = 30 },
	{ id = "punishtime", name = "Punish Timing", detail = "Punish enemy misses for 60s (needs Auto Block on)", duration = 60 },
}

---Whether our own movement should feed the strafe style right now.
---@return boolean
function Bot.learningSelf()
	return Settings.styleLearnSelf or (Bot.lesson ~= nil and Bot.lesson.id == "strafe")
end

---Get the median of a list of numbers.
---@param list number[]
---@param fraction number? 0.5 for the median, 0.8 for the 80th percentile.
---@return number
function Bot.percentile(list, fraction)
	local sorted = table.clone(list)
	table.sort(sorted)
	return sorted[math.clamp(math.ceil(#sorted * (fraction or 0.5)), 1, #sorted)]
end

---Flat distance from us to the lesson target, if there is one.
---@return number?
function Bot.lessonDistance()
	local myRoot, targetRoot = Bot.myRoot, Bot.lessonRoot
	if not (myRoot and targetRoot and targetRoot.Parent) then
		return nil
	end

	return ((targetRoot.Position - myRoot.Position) * Vector3.new(1, 0, 1)).Magnitude
end

---Take a sample for the running lesson from one input the player sent.
---@param args table
function Bot.measure(args)
	local lesson = Bot.lesson
	if not lesson or lesson.slot then
		return
	end

	local now = os.clock()
	local id, goal = lesson.id, args.Goal

	if goal == "LeftClick" then
		lesson.lastClick = now
	end

	if id == "loop" or id == "bdc" then
		if goal == "LeftClick" then
			lesson.streak = (lesson.lastStreak and now - lesson.lastStreak < 0.7) and lesson.streak + 1 or 1
			lesson.lastStreak = now
		elseif goal == "KeyPress" and args.Dash then
			local since = lesson.lastClick and now - lesson.lastClick or nil
			local key = args.Dash
			if id == "loop" and (key == Enum.KeyCode.A or key == Enum.KeyCode.D) and since and since < 1 then
				table.insert(lesson.loops, { since = since, hits = math.max(lesson.streak, 1) })
			elseif id == "bdc" and key == Enum.KeyCode.S and since and since < 1 then
				table.insert(lesson.bdcs, { since = since, hits = math.max(lesson.streak, 1) })
				lesson.backAt = now
			elseif id == "bdc" and key == Enum.KeyCode.W and lesson.backAt and now - lesson.backAt < 1.5 then
				table.insert(lesson.returns, now - lesson.backAt)
				lesson.backAt = nil
			end
		end
	elseif (id == "dash" or id == "circle" or id == "hookaway" or id == "bullet") and args.Dash and goal == "KeyPress" then
		Bot.measureDash(args.Dash)
	elseif id == "m1" and goal == "LeftClick" then
		local distance = Bot.lessonDistance()
		table.insert(lesson.clicks, { t = now, distance = distance })
	elseif id == "back" then
		if goal == "LeftClick" then
			lesson.lastClick = now
		elseif args.Dash == Enum.KeyCode.S and goal == "KeyPress" then
			local distance = Bot.lessonDistance()
			if distance then
				table.insert(lesson.backs, { distance = distance, since = lesson.lastClick and now - lesson.lastClick or nil })
			end
		end
	elseif id == "block" and args.Key == BLOCK_KEY then
		if goal == "KeyPress" then
			lesson.pressedAt = now
		elseif goal == "KeyRelease" and lesson.pressedAt then
			table.insert(lesson.holds, now - lesson.pressedAt)
			lesson.pressedAt = nil
		end
	elseif id == "punishtime" and (goal == "LeftClick" or (args.Dash == Enum.KeyCode.W and goal == "KeyPress")) then
		local targetRoot = Bot.lessonRoot
		local endedAt = targetRoot and lastMoveEnd[targetRoot]
		if endedAt and endedAt ~= lesson.lastPunished and now - endedAt < 1.5 then
			lesson.lastPunished = endedAt
			table.insert(lesson.reactions, now - endedAt)
		end
	elseif id == "escape" and args.Dash and goal == "KeyPress" and Bot.ragdolled then
		table.insert(lesson.escapes, { key = args.Dash, t = now })
	end
end

---Note where the player dashes relative to the target during the dash lesson.
---@param dashKey Enum.KeyCode
function Bot.measureDash(dashKey)
	local lesson = Bot.lesson
	local myRoot, targetRoot = Bot.myRoot, Bot.lessonRoot
	if not lesson or not (myRoot and targetRoot and targetRoot.Parent) then
		return
	end

	local offset = (targetRoot.Position - myRoot.Position) * Vector3.new(1, 0, 1)
	if offset.Magnitude < 1 then
		return
	end

	if dashKey == Enum.KeyCode.W then
		if lesson.id == "dash" or lesson.id == "bullet" then
			table.insert(lesson.front, offset.Magnitude)
		end
	elseif dashKey == Enum.KeyCode.A or dashKey == Enum.KeyCode.D then
		local right = myRoot.CFrame.RightVector * Vector3.new(1, 0, 1)
		if right.Magnitude < 0.1 then
			return
		end

		-- Positive means the dash bends toward the target.
		local direction = right.Unit * (dashKey == Enum.KeyCode.D and 1 or -1)
		local inward = math.deg(math.asin(math.clamp(direction:Dot(offset.Unit), -1, 1)))
		local since = lesson.lastClick and os.clock() - lesson.lastClick or nil
		table.insert(lesson.sides, { angle = inward, distance = offset.Magnitude, hook = since ~= nil and since < Settings.hookWindow, since = since })
	end
end

---Get the median of a list of numbers.
---@param list number[]
---@return number
function Bot.median(list)
	return Bot.percentile(list, 0.5)
end

---Push a setting change to its row in the window.
---@param key string
function Bot.refreshSetting(key)
	local refresh = uiRefreshers[key]
	if refresh then
		refresh(true)
	end
end

---Start a lesson; a new one replaces the running one.
---@param id string
function Bot.startLesson(id)
	Bot.stopLesson()

	local info
	for _, candidate in ipairs(Bot.lessons) do
		if candidate.id == id then
			info = candidate
		end
	end
	if not info then
		return
	end

	local now = os.clock()
	local lesson = {
		id = id,
		info = info,
		startedAt = now,
		endsAt = info.duration and now + info.duration or nil,
		baseTime = Bot.style.time,
		front = {},
		sides = {},
		clicks = {},
		backs = {},
		holds = {},
		escapes = {},
		reactions = {},
		loops = {},
		bdcs = {},
		returns = {},
		dists = {},
		streak = 0,
	}

	local recordSlots = {
		punish = "Punish",
		poke = "Poke",
		ragdoll = "Ragdoll",
		guard = "Guard Break",
		finisher = "Finisher",
		combo1 = "Combo 1",
		combo2 = "Combo 2",
		combo3 = "Combo 3",
		combo4 = "Combo 4",
	}
	if recordSlots[id] then
		lesson.slot = recordSlots[id]
		lesson.before = Bot.combos[lesson.slot]
		Settings.comboSlot = lesson.slot
		Bot.refreshSetting("comboSlot")
		Bot.startRecording()
		if not Bot.recording then
			Bot.lessonResult = "recording needs the remote hook"
			return
		end
	end

	Bot.lesson = lesson
	Bot.lessonResult = "running"
	log("lesson started: " .. info.name)
end

---End the running lesson without learning from it.
function Bot.stopLesson()
	local lesson = Bot.lesson
	Bot.lesson = nil
	if not lesson then
		return
	end

	Bot.lessonResult = "stopped"
	if lesson.slot and Bot.recording then
		Bot.stopRecording()
		local combo = Bot.combos[lesson.slot]
		if combo ~= lesson.before then
			Bot.lessonResult = string.format("%s saved: %d inputs, %.1fs", lesson.slot, #combo.events, combo.length)
		end
	end
end

---Stop the lesson, any recording and any combo that is playing.
function Bot.stopAll()
	Bot.stopLesson()
	Bot.stopRecording()
	if Bot.comboRun then
		Bot.comboRun.cancel = true
	end
	if Bot.macroRun then
		Bot.macroRun.cancel = true
	end
end

Bot.finishers = {}

---Apply a list of { key, value, format } setting changes and describe them.
---@param changes table
---@return string?
function Bot.applyChanges(changes)
	local parts = {}
	for _, change in ipairs(changes) do
		Settings[change[1]] = change[2]
		Bot.refreshSetting(change[1])
		table.insert(parts, string.format(change[3], change[2]))
	end

	return #parts > 0 and table.concat(parts, ", ") or nil
end

---Setting changes from M1 swing samples of { t, distance }.
---@param clicks table
---@return table
function Bot.m1Changes(clicks)
	local changes = {}
	if #clicks < 4 then
		return changes
	end

	-- A gap over 0.7s ends a string; shorter gaps are the swing rhythm.
	local rhythm, lengths, rests, distances = {}, {}, {}, {}
	local length = 1
	for index = 2, #clicks do
		local gap = clicks[index].t - clicks[index - 1].t
		if gap < 0.7 then
			table.insert(rhythm, gap)
			length += 1
		else
			table.insert(lengths, length)
			if gap < 3 then
				table.insert(rests, gap)
			end
			length = 1
		end
	end
	table.insert(lengths, length)

	for _, click in ipairs(clicks) do
		if click.distance then
			table.insert(distances, click.distance)
		end
	end

	if #rhythm >= 3 then
		table.insert(changes, { "botM1Rate", math.clamp(math.floor(Bot.median(rhythm) * 100 + 0.5) / 100, 0.1, 0.5), "M1 every %.2fs" })
	end

	if #lengths >= 2 then
		table.insert(changes, { "botStringHits", math.clamp(math.floor(Bot.median(lengths)), 1, 8), "%d-hit strings" })
	end

	if #rests >= 2 then
		table.insert(changes, { "botComboPause", math.clamp(math.floor(Bot.median(rests) * 20 + 0.5) / 20, 0.2, 1.2), "%.2fs rest" })
	end

	if #distances >= 4 then
		table.insert(changes, { "botReach", math.clamp(math.floor(Bot.percentile(distances, 0.8) * 2 + 1) / 2, 3, 12), "reach %g" })
		table.insert(changes, { "botEngage", math.clamp(math.floor(Bot.median(distances) * 2 + 0.5) / 2, 2, 12), "spacing %g" })
	end

	return changes
end

---Setting changes from front dash distances and side dash samples of { angle, distance, hook, since }.
---@param fronts number[]
---@param sides table
---@return table
function Bot.dashChanges(fronts, sides)
	local changes = {}
	if #fronts >= 2 then
		table.insert(changes, { "botDashRange", math.clamp(math.floor(Bot.median(fronts)), 10, 60), "front dash from %d studs" })
	end

	-- Hooks follow a hit, circles are close, anything farther is a long arm.
	local circle, away, far = {}, {}, 0
	for _, side in ipairs(sides) do
		if side.hook then
			table.insert(away, -side.angle)
		elseif side.distance <= Settings.hookRange then
			table.insert(circle, side.angle)
		else
			far += 1
		end
	end

	if #circle >= 2 then
		table.insert(changes, { "hookAngle", math.clamp(math.floor(Bot.median(circle) / 5 + 0.5) * 5, 0, 80), "circle bend %d°" })
	end

	if #away >= 2 then
		table.insert(changes, { "hookAwayAngle", math.clamp(math.floor(Bot.median(away) / 5 + 0.5) * 5, 10, 90), "hook away %d°" })
	end

	local total = #circle + #away + far
	if total >= 4 then
		table.insert(changes, { "longArmChance", math.clamp(math.floor(far / total * 100 + 0.5), 0, 60), "long arm %d%%" })
	end

	return changes
end

---Setting changes from back dash samples of { distance, since }.
---@param backs table
---@return table
function Bot.backChanges(backs)
	local changes = {}
	if #backs < 2 then
		return changes
	end

	local distances, delays = {}, {}
	for _, back in ipairs(backs) do
		table.insert(distances, back.distance)
		if back.since and back.since < 1.5 then
			table.insert(delays, back.since)
		end
	end

	table.insert(changes, { "backStepRange", math.clamp(math.floor(Bot.percentile(distances, 0.75) + 1), 4, 20), "back step inside %d studs" })
	if #delays >= 2 then
		table.insert(changes, { "backStepDelay", math.clamp(math.floor(Bot.median(delays) * 20 + 0.5) / 20, 0, 0.6), "%.2fs after the string" })
	end

	return changes
end

---Setting changes from block hold durations.
---@param holds number[]
---@return table
function Bot.blockChanges(holds)
	if #holds < 3 then
		return {}
	end

	return { { "blockHold", math.clamp(math.floor(Bot.median(holds) * 20 + 0.5) / 20, 0.1, 1), "block hold %.2fs" } }
end

---@return string
function Bot.finishers.strafe(lesson)
	local low, high = Bot.getSpacing()
	local seconds = Bot.style.time - lesson.baseTime
	if seconds < 5 then
		return "no movement seen: lock or stay near an enemy"
	end

	return string.format("learned %ds, %d strafes, spacing %d-%d", seconds, #Bot.style.segments, low, high)
end

---@return string
function Bot.finishers.dash(lesson)
	return Bot.applyChanges(Bot.dashChanges(lesson.front, lesson.sides)) or "not enough dashes: dash at a target at least twice"
end

---@return string
function Bot.finishers.circle(lesson)
	local angles, distances = {}, {}
	for _, side in ipairs(lesson.sides) do
		if not side.hook then
			table.insert(angles, side.angle)
			table.insert(distances, side.distance)
		end
	end

	if #angles < 2 then
		return "not enough circle dashes: side dash close to a target at least twice"
	end

	return Bot.applyChanges({
		{ "hookAngle", math.clamp(math.floor(Bot.median(angles) / 5 + 0.5) * 5, 0, 80), "circle bend %d°" },
		{ "hookRange", math.clamp(math.floor(Bot.percentile(distances, 0.9) + 1), 6, 30), "circle range %d studs" },
	}) or ""
end

---@return string
function Bot.finishers.hookaway(lesson)
	local angles, delays = {}, {}
	for _, side in ipairs(lesson.sides) do
		if side.hook then
			table.insert(angles, -side.angle)
			table.insert(delays, side.since)
		end
	end

	if #angles < 2 then
		return "not enough hooks: M1 then side dash away at least twice"
	end

	local changes = { { "hookAwayAngle", math.clamp(math.floor(Bot.median(angles) / 5 + 0.5) * 5, 10, 90), "hook away %d°" } }
	table.insert(changes, { "backStepDelay", math.clamp(math.floor(Bot.median(delays) * 20 + 0.5) / 20, 0, 0.6), "%.2fs after the hit" })
	return Bot.applyChanges(changes) or ""
end

---@return string
function Bot.finishers.loop(lesson)
	if #lesson.loops < 2 then
		return "not enough loops: M1 then circle dash at least twice"
	end

	local delays, hits = {}, {}
	for _, loop in ipairs(lesson.loops) do
		table.insert(delays, loop.since)
		table.insert(hits, loop.hits)
	end

	return Bot.applyChanges({
		{ "loopDelay", math.clamp(math.floor(Bot.median(delays) * 100 + 0.5) / 100, 0.05, 0.6), "dash %.2fs after the hit" },
		{ "loopHits", math.clamp(math.floor(Bot.median(hits)), 1, 8), "after hit %d" },
	}) or ""
end

---@return string
function Bot.finishers.bdc(lesson)
	if #lesson.bdcs < 2 then
		return "not enough cancels: M1 then back dash at least twice"
	end

	local delays, hits = {}, {}
	for _, cancel in ipairs(lesson.bdcs) do
		table.insert(delays, cancel.since)
		table.insert(hits, cancel.hits)
	end

	local changes = {
		{ "cancelDelay", math.clamp(math.floor(Bot.median(delays) * 100 + 0.5) / 100, 0.05, 0.8), "back dash %.2fs after the hit" },
		{ "bdcHits", math.clamp(math.floor(Bot.median(hits)), 1, 8), "after hit %d" },
	}
	if #lesson.returns >= 2 then
		table.insert(changes, { "bdcReturn", math.clamp(math.floor(Bot.median(lesson.returns) * 100 + 0.5) / 100, 0.1, 1.2), "return %.2fs later" })
	end

	return Bot.applyChanges(changes) or ""
end

---@return string
function Bot.finishers.bullet(lesson)
	if #lesson.front < 2 then
		return "not enough front dashes: dash at a target at least twice"
	end

	local low = math.clamp(math.floor(Bot.percentile(lesson.front, 0.1)), 8, 60)
	local high = math.clamp(math.ceil(Bot.percentile(lesson.front, 0.9)), low + 2, 80)
	return Bot.applyChanges({
		{ "bulletMin", low, "bullet from %d" },
		{ "bulletMax", high, "to %d studs" },
	}) or ""
end

---@return string
function Bot.finishers.spacing(lesson)
	if #lesson.dists < 10 then
		return "no spacing seen: stay near an enemy"
	end

	local tiles = math.clamp(math.floor(Bot.median(lesson.dists) / Bot.tile * 2 + 0.5) / 2, 2, 8)
	Settings.spacePerfect = true
	Bot.refreshSetting("spacePerfect")
	return Bot.applyChanges({ { "spaceTiles", tiles, "spacing %g tiles" } }) or ""
end

---@return string
function Bot.finishers.m1(lesson)
	return Bot.applyChanges(Bot.m1Changes(lesson.clicks)) or "not enough M1s: swing at a target at least four times"
end

---@return string
function Bot.finishers.back(lesson)
	return Bot.applyChanges(Bot.backChanges(lesson.backs)) or "not enough back dashes: M1 then back dash at least twice"
end

---@return string
function Bot.finishers.block(lesson)
	return Bot.applyChanges(Bot.blockChanges(lesson.holds)) or "not enough blocks: block at least three times"
end

---@return string
function Bot.finishers.punishtime(lesson)
	if #lesson.reactions < 3 then
		return "not enough punishes: swing or dash right after an enemy misses, at least three times"
	end

	local window = math.clamp(math.floor((Bot.percentile(lesson.reactions, 0.8) + 0.1) * 20 + 0.5) / 20, 0.2, 1.2)
	return Bot.applyChanges({ { "punishWindow", window, "punish window %.2fs" } })
end

---@return string
function Bot.finishers.escape(lesson)
	local escapes = lesson.escapes
	if #escapes < 3 then
		return "not enough dashes while ragdolled: get ragdolled and dash out"
	end

	local counts = { Back = 0, Left = 0, Right = 0 }
	local gaps = {}
	for index, escape in ipairs(escapes) do
		local name = escape.key == Enum.KeyCode.S and "Back" or (escape.key == Enum.KeyCode.A and "Left" or (escape.key == Enum.KeyCode.D and "Right" or nil))
		if name then
			counts[name] += 1
		end

		local gap = index > 1 and escape.t - escapes[index - 1].t or nil
		if gap and gap < 1 then
			table.insert(gaps, gap)
		end
	end

	local best = "Back"
	for name, count in pairs(counts) do
		if count > counts[best] then
			best = name
		end
	end

	local changes = { { "evasiveDirection", best, "escape dash %s" } }
	if #gaps >= 2 then
		table.insert(changes, { "evasiveRate", math.clamp(math.floor(Bot.median(gaps) * 100 + 0.5) / 100, 0.02, 0.2), "every %.2fs" })
	end

	return Bot.applyChanges(changes) or ""
end

---Turn the samples of a finished timed lesson into settings.
function Bot.finishLesson()
	local lesson = Bot.lesson
	Bot.lesson = nil
	if not lesson then
		return
	end

	local result = Bot.finishers[lesson.id](lesson)
	Bot.lessonResult = result
	Bot.save()
	log("lesson done: " .. result)
end

---Advance the running lesson.
---@param now number
---@param myRoot BasePart?
function Bot.updateLesson(now, myRoot)
	local lesson = Bot.lesson
	if not lesson then
		return
	end

	if lesson.slot then
		if not Bot.recording then
			Bot.lesson = nil
			local combo = Bot.combos[lesson.slot]
			Bot.lessonResult = combo ~= lesson.before and string.format("%s saved: %d inputs, %.1fs", lesson.slot, #combo.events, combo.length) or "nothing recorded"
		end
		return
	end

	if myRoot then
		local lockRoot = Bot.lockOn and Bot.lockTarget and Bot.getParts(Bot.lockTarget)
		Bot.lessonRoot = lockRoot or getNearestTarget(myRoot, 45)

		if lesson.id == "spacing" and Bot.lessonRoot and now - (lesson.sampleAt or 0) >= 0.2 then
			lesson.sampleAt = now
			local flat = ((Bot.lessonRoot.Position - myRoot.Position) * Vector3.new(1, 0, 1)).Magnitude
			if flat <= 35 and flat > Settings.botReach then
				table.insert(lesson.dists, flat)
			end
		end
	end

	if now >= lesson.endsAt then
		Bot.finishLesson()
	end
end

---Describe the lesson in progress for the window and the quick pad.
---@return string
function Bot.lessonText()
	local lesson = Bot.lesson
	if not lesson then
		return Bot.recording and string.format("Recording %s: %d inputs", Bot.recording.slot, #Bot.recording.events) or ""
	end

	if lesson.slot then
		return string.format("%s: do it now (%d inputs)", lesson.info.name, Bot.recording and #Bot.recording.events or 0)
	end

	local left = math.max(math.ceil(lesson.endsAt - os.clock()), 0)
	local id = lesson.id
	local progress
	if id == "strafe" then
		progress = string.format("%ds seen", Bot.style.time - lesson.baseTime)
	elseif id == "dash" then
		progress = string.format("%d front, %d side", #lesson.front, #lesson.sides)
	elseif id == "circle" or id == "hookaway" then
		progress = string.format("%d side dashes", #lesson.sides)
	elseif id == "m1" then
		progress = string.format("%d swings", #lesson.clicks)
	elseif id == "back" then
		progress = string.format("%d back dashes", #lesson.backs)
	elseif id == "block" then
		progress = string.format("%d blocks", #lesson.holds)
	elseif id == "punishtime" then
		progress = string.format("%d punishes", #lesson.reactions)
	elseif id == "loop" then
		progress = string.format("%d loops", #lesson.loops)
	elseif id == "bdc" then
		progress = string.format("%d cancels", #lesson.bdcs)
	elseif id == "bullet" then
		progress = string.format("%d front dashes", #lesson.front)
	elseif id == "spacing" then
		progress = string.format("%d samples", #lesson.dists)
	else
		progress = string.format("%d escapes", #lesson.escapes)
	end

	return string.format("%s: %ds left, %s", lesson.info.name, left, progress)
end

---Add a value to a list, dropping the oldest past a cap.
---@param list table
---@param value any
---@param cap number
function Bot.push(list, value, cap)
	table.insert(list, value)
	if #list > cap then
		table.remove(list, 1)
	end
end

---Copy the last few entries of a list.
---@param list table
---@param count number
---@return table
function Bot.tail(list, count)
	local out = {}
	for index = math.max(#list - count + 1, 1), #list do
		table.insert(out, list[index])
	end

	return out
end

---Make styles safe for JSON.
---@param style table
---@return table
function Bot.packStyle(style)
	local dist = {}
	for bucket, seconds in pairs(style.dist) do
		dist[tostring(bucket)] = seconds
	end

	Bot.ensureTypes(style)
	return { segments = style.segments, time = style.time, pokes = style.pokes, dashes = style.dashes, dist = dist, types = style.types }
end

---Read a saved style back.
---@param saved table
---@return table
function Bot.unpackStyle(saved)
	local style = { segments = saved.segments or {}, dist = {}, time = saved.time or 0, pokes = saved.pokes or 0, dashes = saved.dashes or 0, types = saved.types }
	Bot.ensureTypes(style)
	for bucket, seconds in pairs(saved.dist or {}) do
		style.dist[tonumber(bucket)] = seconds
	end

	return style
end

---The style the bot plays from.
---@return table
function Bot.activeStyle()
	return Bot.style
end

---Name a side dash by the tips: a hook follows a hit, circles are close, long arms use the full range.
---@param distance number
---@param sinceM1 number? Seconds since their last M1.
---@return string
function Bot.classifySide(distance, sinceM1)
	if sinceM1 and sinceM1 < Settings.hookWindow then
		return "hook"
	end

	return distance <= Settings.hookRange and "circle" or "longarm"
end

---Count one dash of a kind in a style.
---@param style table
---@param kind string FRONT, BACK or SIDE.
---@param distance number
---@param sinceM1 number?
function Bot.countDash(style, kind, distance, sinceM1)
	Bot.ensureTypes(style)
	if kind == "FRONT" then
		style.types.front += 1
	elseif kind == "BACK" then
		style.types.back += 1
	else
		local side = Bot.classifySide(distance, sinceM1)
		style.types[side] += 1
	end
end

---Count a dash the player just pressed while the style is learning from them.
---@param dashKey Enum.KeyCode
function Bot.countOwnDash(dashKey)
	if not Bot.learningSelf() then
		return
	end

	local style = Bot.style
	style.dashes += 1

	local now = os.clock()
	local myRoot, opponent = Bot.myRoot, Bot.selfOpponent
	local distance = 0
	if myRoot and opponent and opponent.Parent and now - Bot.selfOpponentAt < 0.5 then
		distance = ((opponent.Position - myRoot.Position) * Vector3.new(1, 0, 1)).Magnitude
	end

	local since = Bot.selfLastM1 and now - Bot.selfLastM1 or nil
	if dashKey == Enum.KeyCode.W then
		Bot.countDash(style, "FRONT", distance, since)
	elseif dashKey == Enum.KeyCode.S then
		Bot.countDash(style, "BACK", distance, since)
	elseif distance > 0 then
		Bot.countDash(style, "SIDE", distance, since)
	end
end

---Read a move's cooldown from the game's bar: nil when it is not shown.
---@param name string
---@return boolean?
function Bot.cooldownState(name)
	local bar = playerGui:FindFirstChild("Bar")
	local magic = bar and bar:FindFirstChild("MagicHealth")
	local cooldowns = magic and magic:FindFirstChild("cdholder")
	local entry = cooldowns and cooldowns:FindFirstChild(name, true)
	local template = entry and entry:FindFirstChild("template")
	local fill = template and template:FindFirstChild("Fill")
	if not fill then
		return nil
	end

	return fill.Size.Y.Scale > 0.01
end

---Whether Backlash is available.
---@return boolean
function Bot.backlashReady()
	if Settings.backlashMode == "Always" then
		return true
	elseif Settings.backlashMode == "Never" then
		return false
	end

	return Bot.cooldownState(Settings.backlashName) == false
end

---Roll whether a long arm is worth it: common with Backlash up, a rare surprise otherwise.
---@return boolean
function Bot.longArmAllowed()
	local chance = Bot.backlashReady() and Settings.longArmBacklash or Settings.longArmChance

	-- Players who use long arms more than usual make the bot use them more.
	local types = Bot.activeStyle().types
	if Settings.styleUse and types then
		local total = types.circle + types.longarm + types.hook
		if total >= 6 then
			chance = math.clamp(chance * (types.longarm / total) / 0.15, 0, 60)
		end
	end

	return math.random() * 100 < chance
end

---Re-roll the long arm decision every couple of seconds.
---@param now number
function Bot.rollLongArm(now)
	if now >= Bot.rollAt then
		Bot.rollAt = now + 2
		Bot.longArmOk = Bot.longArmAllowed()
	end
end

---How often to hook away instead of backing straight off, from what was learned.
---@return number
function Bot.hookShare()
	local types = Bot.activeStyle().types
	if Settings.styleUse and types then
		local total = types.hook + types.back
		if total >= 6 then
			return types.hook / total
		end
	end

	return 0.6
end

Bot.tips = {
	{ key = "botHook", title = "Circle Dash", short = "Close side dash that wraps to their back" },
	{ key = "longArm", title = "Long Arm", short = "Full range: only with Backlash or as a surprise" },
	{ key = "hookAway", title = "Hook Away", short = "Dash away after a hit so they cannot M1 catch" },
}

---Time until a point moving at a velocity first comes within a radius, or nil if it never does.
---@param offset Vector3 Flat offset from us to them.
---@param velocity Vector3 Flat velocity relative to us.
---@param remaining number Seconds the movement lasts.
---@param radius number
---@return number?
function Bot.pathIntercept(offset, velocity, remaining, radius)
	if offset.Magnitude <= radius then
		return 0
	end

	-- Solve |offset + velocity * t| = radius for the first time they get inside.
	local a = velocity:Dot(velocity)
	if a < 1e-4 then
		return nil
	end

	local b = 2 * offset:Dot(velocity)
	local c = offset:Dot(offset) - radius * radius
	local discriminant = b * b - 4 * a * c
	if discriminant < 0 then
		return nil
	end

	local time = (-b - math.sqrt(discriminant)) / (2 * a)
	if time < 0 or time > remaining then
		return nil
	end

	return time
end

---Remember a side dash so chained dashes can be expected.
---@param root BasePart
function Bot.noteSideDash(root)
	local now = os.clock()
	local record = Bot.dashMemory[root]
	if not record or now - record.last > 3 then
		record = { count = 0, last = now }
		Bot.dashMemory[root] = record
	end

	record.count += 1
	record.last = now
end

---Guess that the nearest enemy is about to side dash, before the animation reaches us.
---Chained dashes, a just-finished move and fast sideways movement all raise the score.
---@param myRoot BasePart
function Bot.anticipate(myRoot)
	local now = os.clock()
	if not Settings.dashAnticipate or not Settings.dashPredictor or now - Bot.anticipateAt < 0.05 then
		return
	end

	Bot.anticipateAt = now
	local root = getNearestTarget(myRoot, Settings.predictRange)
	if not root then
		Bot.armed = nil
		return
	end

	local offset = (root.Position - myRoot.Position) * Vector3.new(1, 0, 1)
	if offset.Magnitude < 0.1 then
		return
	end

	local score = 0
	local record = Bot.dashMemory[root]
	if record and now - record.last < 2.5 then
		score += 0.35 + 0.1 * math.min(record.count, 3)
	end

	local endedAt = lastMoveEnd[root]
	if endedAt and now - endedAt < Settings.hookWindow + 0.3 then
		score += 0.4
	end

	local velocity = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	local direction = offset.Unit
	local sideways = (velocity - direction * velocity:Dot(direction)).Magnitude
	if sideways > 8 then
		score += 0.3
	end

	if score >= 0.5 then
		Bot.armed = { root = root, untilAt = now + 0.4 }
	elseif Bot.armed and (Bot.armed.root ~= root or now > Bot.armed.untilAt) then
		Bot.armed = nil
	end
end

---Describe what the adapter has found works, best tech first.
---@return string
function Bot.adaptSummary()
	local everyone = Bot.adapt["*"]
	if not everyone then
		return "nothing yet"
	end

	local best, bestRate = nil, -1
	for name, stat in pairs(everyone.techs) do
		if stat.tries >= 2 then
			local rate = stat.wins / stat.tries
			if rate > bestRate then
				best, bestRate = name, rate
			end
		end
	end

	return best and string.format("%s works %d%%", best, math.floor(bestRate * 100 + 0.5)) or "nothing yet"
end

---Run every frame: recording, lock, study, assists and the fight bot.
function Bot.update()
	local now = os.clock()
	local myCharacter, myRoot, myHumanoid = getMe()
	Bot.myRoot = myRoot
	Bot.myHumanoid = myHumanoid
	if Bot.frontLockUntil and now >= Bot.frontLockUntil then
		Bot.frontLockUntil = nil
		if Bot.frontLockAuto then
			Bot.setLock(false)
		end
	end
	Bot.ragdolled = myCharacter ~= nil and myHumanoid ~= nil and isRagdolled(myCharacter, myHumanoid)
	Bot.updateRecording(now)
	Bot.updateLesson(now, myRoot)

	if Settings.botEnabled ~= Bot.active then
		Bot.active = Settings.botEnabled
		Bot.applyProfile(Bot.active)
		Bot.target = nil
		Bot.moveVector = Vector3.zero
		Bot.hits = 0
		Bot.mode = "NEUTRAL"

		if not Bot.active then
			if myHumanoid then
				myHumanoid:Move(Vector3.zero, false)
			end
			if Bot.comboRun then
				Bot.comboRun.cancel = true
			end
			if Bot.macroRun then
				Bot.macroRun.cancel = true
			end
			if not Bot.lockOn then
				stopLock()
			end
			Bot.status = "Off"
		end
	end

	if not (myCharacter and myRoot and myHumanoid) or myHumanoid.Health <= 0 then
		Bot.moveVector = Vector3.zero
		Bot.assistRoot = nil
		Bot.status = Bot.active and "Waiting for respawn" or "Off"
		return
	end

	Bot.updateLockTarget(myCharacter, myRoot, now)
	Bot.updateAssistTarget(myRoot)
	Bot.updateStudy(myRoot, now)

	if Bot.active then
		Bot.fight(now, myCharacter, myRoot, myHumanoid)
	end
end

---Feed the bot's walk direction to the humanoid each frame.
function Bot.applyMove()
	Bot.updateLines()

	if not Bot.active or Bot.moveVector.Magnitude < 0.01 then
		return
	end

	local _, _, humanoid = getMe()
	if humanoid and humanoid.Health > 0 then
		local move = Bot.moveVector
		humanoid:Move(move.Magnitude > 1 and move.Unit or move, false)
	end
end

---Handle the bot's hotkeys.
---@param input InputObject
---@param processed boolean
function Bot.onKey(input, processed)
	-- A keybind row is waiting for its key.
	if bindCapture and input.UserInputType == Enum.UserInputType.Keyboard then
		bindCapture(input.KeyCode)
		return
	end

	if processed then
		return
	end

	local code = input.KeyCode
	if code == Bot.keys.bot then
		Settings.botEnabled = not Settings.botEnabled
		local refresh = uiRefreshers.botEnabled
		if refresh then
			refresh(true)
		end
	elseif code == Bot.keys.lock then
		Bot.setLock(not Bot.lockOn)
	elseif code == Bot.keys.cycle then
		Bot.cycleLock()
	elseif code == Bot.keys.combo then
		Bot.playSelected()
	else
		for _, bind in ipairs(TOGGLE_BINDS) do
			if Settings[bind.key] == code.Name then
				Bot.toggle(bind)
				break
			end
		end
	end
end

---Apply settings that need a one-time write when changed.
---@param key string
local function onSettingChanged(key)
	lightingService.GlobalShadows = not Settings.noShadows and originalShadows
end

---Get the file name for the selected preset slot.
---@return string
local function getPresetName()
	return (Settings.presetSlot:gsub("%s", "_")) .. ".json"
end

---Save the current settings to the selected slot.
local function savePreset()
	local data = {}
	for key, value in pairs(Settings) do
		local kind = type(value)
		if key ~= "presetSlot" and (kind == "number" or kind == "boolean" or kind == "string") then
			data[key] = value
		end
	end

	local encoded = httpService:JSONEncode(data)
	local name = getPresetName()

	shared.ZennyPresets = shared.ZennyPresets or {}
	shared.ZennyPresets[name] = encoded

	local saved = false
	if writefile then
		saved = pcall(function()
			if makefolder and isfolder and not isfolder("Zenny") then
				makefolder("Zenny")
			end
			writefile("Zenny/" .. name, encoded)
		end)
	end

	presetStatus = string.format("Saved %s%s", Settings.presetSlot, saved and "" or " (memory only)")
end

---Load settings from the selected slot.
local function loadPreset()
	local name = getPresetName()
	local encoded = shared.ZennyPresets and shared.ZennyPresets[name]

	if readfile and isfile then
		pcall(function()
			if isfile("Zenny/" .. name) then
				encoded = readfile("Zenny/" .. name)
			end
		end)
	end

	if not encoded then
		presetStatus = string.format("%s is empty", Settings.presetSlot)
		return
	end

	local ok, data = pcall(function()
		return httpService:JSONDecode(encoded)
	end)
	if not ok or type(data) ~= "table" then
		presetStatus = "Could not read " .. Settings.presetSlot
		return
	end

	for key, value in pairs(data) do
		if key ~= "presetSlot" and type(Settings[key]) == type(value) then
			Settings[key] = value
			local refresh = uiRefreshers[key]
			if refresh then
				refresh(true)
			end
		end
	end

	onSettingChanged("preset")
	presetStatus = "Loaded " .. Settings.presetSlot
end

---Log every remote under our character to help find the input remote.
local function scanRemotes()
	local character = localPlayer.Character
	if not character then
		log("scan: no character")
		return
	end

	local count = 0
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") then
			count += 1
			log(string.format("remote: %s (%s) in %s", descendant.Name, descendant.ClassName, descendant.Parent.Name))
		end
	end

	log(string.format("scan: %d remotes, input remote %s", count, getRemote() and "FOUND" or "MISSING"))
end

---Log every visible button in the player gui to help find the M1 button.
local function scanButtons()
	local count = 0
	for _, descendant in ipairs(playerGui:GetDescendants()) do
		if descendant:IsA("GuiButton") and descendant.Visible and count < 40 then
			count += 1
			local text = descendant:IsA("TextButton") and descendant.Text or ""
			log(string.format("button: %s / %s %s", descendant.Parent and descendant.Parent.Name or "?", descendant.Name, text ~= "" and ("'" .. text .. "'") or ""))
		end
	end

	log(string.format("scan: %d buttons shown, M1 button %s", count, findM1Button() and findM1Button().Name or "none"))
end

---Try each M1 method one after another so you can see which one punches.
local function testAllM1()
	task.spawn(function()
		for index, method in ipairs({ "Remote+Mobile", "Remote", "Signal", "Button" }) do
			log(string.format("TEST %d/4: %s", index, method))
			sendM1(method, "test")
			task.wait(1.5)
		end

		log("TEST done: tell me which number punched")
	end)
end

-- Combat lab.
local LAB_DASH_TIME = 0.4
local LAB_FRONT_LAG = 0.12
local LAB_TEST_NAMES = {
	"Side Dash In",
	"Side Dash Away",
	"Block: Side Dash",
	"Backdash",
	"Front Dash",
	"Block: Uppercut",
	"Block: Consec",
	"Block: Shove",
	"Block: M1 String",
}
local LAB_TESTS = {
	["Side Dash In"] = { type = "dash", kind = "LEFT" },
	["Side Dash Away"] = { type = "dash", kind = "RIGHT" },
	["Block: Side Dash"] = { type = "dash", kind = "LEFT", block = true },
	["Backdash"] = { type = "dash", kind = "BACK" },
	["Front Dash"] = { type = "dash", kind = "FRONT" },
	["Block: Uppercut"] = { type = "attack" },
	["Block: Consec"] = { type = "attack" },
	["Block: Shove"] = { type = "attack" },
	["Block: M1 String"] = { type = "string" },
}

local labRunning = false
local labResultCallback = nil
local labHistory = {}

---Keep only the flat part of a vector and normalize it.
---@param vector Vector3
---@return Vector3
local function flatten(vector)
	local flat = Vector3.new(vector.X, 0, vector.Z)
	return flat.Magnitude > 0 and flat.Unit or Vector3.new(0, 0, -1)
end

---Pick the animation id for a dash kind, preferring a learned one.
---@param kind string
---@return string?
local function getDashAnimationId(kind)
	if kind == "BACK" and next(learned.back) then
		return (next(learned.back))
	end

	if kind == "FRONT" and next(learned.front) then
		return (next(learned.front))
	end

	for id, dashKind in pairs(DASH_TYPES) do
		if dashKind == kind then
			return id
		end
	end

	return nil
end

---Get the animation ids a block test plays.
---@param testName string
---@return table
local function getAttackIds(testName)
	if testName == "Block: Uppercut" then
		return { "10503381238" }
	end

	if testName == "Block: Consec" then
		local id = next(learned.barrage) or next(SEED_IDS.barrage)
		return id and { id } or {}
	end

	if testName == "Block: Shove" then
		local id = next(learned.shove) or next(SEED_IDS.shove)
		return id and { id } or {}
	end

	local ids = {}
	for id in pairs(learned.m1) do
		table.insert(ids, id)
	end
	table.sort(ids)

	return ids
end

---Copy our character into a script-free practice target.
---@return Model?
local function getLabDummy()
	if labDummy and labDummy.Parent then
		return labDummy
	end

	local character = localPlayer.Character
	if not character then
		return nil
	end

	local archivable = character.Archivable
	character.Archivable = true
	local clone = character:Clone()
	character.Archivable = archivable
	if not clone then
		return nil
	end

	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
		end
	end

	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	local root = clone:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root) then
		clone:Destroy()
		return nil
	end

	clone.Name = "ZennyDummy"
	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Health = humanoid.MaxHealth
	if not humanoid:FindFirstChildOfClass("Animator") then
		newInstance("Animator", {}, humanoid)
	end

	labDummy = clone
	return clone
end

---Remove the practice target.
local function removeLabDummy()
	if labDummy then
		labDummy:Destroy()
		labDummy = nil
	end
end

---Play an animation id on the practice target.
---@param animator Animator
---@param id string
---@return AnimationTrack?
local function playLabTrack(animator, id)
	local animation = newInstance("Animation", { AnimationId = "rbxassetid://" .. id }, nil)
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok or not track then
		return nil
	end

	track:Play(0.05)
	return track
end

---Get the distance at a time by looking through the recorded samples.
---@param samples table
---@param time number
---@return number
local function distanceAt(samples, time)
	local last = math.huge
	for _, sample in ipairs(samples) do
		last = sample.distance
		if sample.t >= time then
			return sample.distance
		end
	end

	return last
end

---Turn block events into intervals in lab time.
---@param events table
---@param total number
---@return table
local function buildIntervals(events, total)
	local intervals, open = {}, nil
	for _, event in ipairs(events) do
		if event.name == "BLOCK" then
			table.insert(intervals, { from = event.t, to = event.t + (event.data.duration or 0.3) })
		elseif event.name == "HOLD" then
			open = event.t
		elseif event.name == "RELEASE" and open then
			table.insert(intervals, { from = open, to = event.t })
			open = nil
		end
	end

	if open then
		table.insert(intervals, { from = open, to = total })
	end

	return intervals
end

---Check whether a block covers a hit once the ping delay is applied.
---@param intervals table
---@param hitTime number
---@param ping number
---@return string, number
local function checkCoverage(intervals, hitTime, ping)
	if #intervals == 0 then
		return "NONE", 0
	end

	local state, gap = "LATE", math.huge
	for _, interval in ipairs(intervals) do
		local lands, ends = interval.from + ping, interval.to + ping
		if lands <= hitTime and ends >= hitTime then
			return "BLOCKED", math.min(hitTime - lands, ends - hitTime)
		end

		if lands > hitTime and lands - hitTime < gap then
			state, gap = "LATE", lands - hitTime
		elseif ends < hitTime and hitTime - ends < gap then
			state, gap = "EARLY", hitTime - ends
		end
	end

	return state, gap
end

---Explain why nothing happened, from the events that were recorded.
---@param events table
---@return string
local function explainMiss(events)
	local detected, threat, ignored = false, nil, nil
	for _, event in ipairs(events) do
		if event.name == "DETECT" then
			detected = true
		elseif event.name == "THREAT" then
			threat = event.data
		elseif event.name == "IGNORED" then
			ignored = event.data.reason
		end
	end

	if ignored then
		return "Detected but ignored (" .. ignored .. ")."
	end

	if not detected then
		return "Slotted never detected the animation. Learn it first, or check Broad Detection."
	end

	if threat and not threat.threat then
		return string.format("Detected at %d studs but not counted as a threat (range or facing).", threat.distance)
	end

	return "Detected, but no action was taken."
end

---Score a dash catch test.
---@param run table
---@param test table
---@param distance number
---@return table
local function evaluateDash(run, test, distance)
	local ping = Settings.labPing / 1000
	local startup = Settings.labStartup
	local reach = Settings.labReach
	local m1Event
	for _, event in ipairs(run.events) do
		if event.name == "M1" then
			m1Event = event
			break
		end
	end

	local windowStart, windowEnd
	for _, sample in ipairs(run.samples) do
		if sample.distance <= reach then
			windowStart = windowStart or sample.t
			windowEnd = sample.t
		end
	end

	local timeline = {
		total = 1,
		bars = { { from = 0, to = LAB_DASH_TIME, lane = 0, color = COLORS.accentDark } },
		ticks = {},
	}
	if windowStart then
		table.insert(timeline.bars, { from = windowStart, to = windowEnd, lane = 1, color = COLORS.good })
	end

	local result = { lines = {}, timeline = timeline }
	local enabled = test.kind == "BACK" and Settings.bdcCatch or Settings.catchEnabled

	if windowStart then
		table.insert(
			result.lines,
			string.format("Best M1 window: %d to %d ms", math.max(windowStart - ping - startup, 0) * 1000, math.max(windowEnd - ping - startup, 0) * 1000)
		)
	else
		table.insert(result.lines, string.format("They never got within %g studs of you.", reach))
	end

	if not m1Event then
		result.ok = false
		result.title = "NO M1"
		table.insert(result.lines, 1, enabled and explainMiss(run.events) or "Auto M1 for this dash is turned off.")
		return result
	end

	local landing = m1Event.t + ping + startup
	local landed = distanceAt(run.samples, landing)
	result.ok = landed <= reach
	result.title = result.ok and "HIT" or "WHIFF"
	table.insert(timeline.ticks, { at = landing, color = result.ok and COLORS.good or COLORS.bad })
	table.insert(result.lines, 1, string.format("M1 fired %d ms in and landed %.1f studs away (reach %g).", m1Event.t * 1000, landed, reach))

	if not result.ok then
		table.insert(result.lines, landed > reach and "Too far: raise Hit Reach or lower the delay." or "")
	end

	return result
end

---Score a front dash block test.
---@param run table
---@return table
local function evaluateFront(run)
	local ping = Settings.labPing / 1000
	local hitTime = LAB_DASH_TIME + LAB_FRONT_LAG
	local intervals = buildIntervals(run.events, 1)
	local state, gap = checkCoverage(intervals, hitTime, ping)

	local timeline = {
		total = 1,
		bars = { { from = 0, to = LAB_DASH_TIME, lane = 0, color = COLORS.accentDark } },
		ticks = { { at = hitTime, color = COLORS.bad } },
	}
	for _, interval in ipairs(intervals) do
		table.insert(timeline.bars, { from = interval.from + ping, to = interval.to + ping, lane = 1, color = COLORS.accent })
	end

	local result = { lines = {}, timeline = timeline }
	result.ok = state == "BLOCKED"

	if state == "BLOCKED" then
		result.title = "BLOCKED"
		table.insert(result.lines, string.format("A hit %d ms after the dash ended was covered by %d ms.", LAB_FRONT_LAG * 1000, gap * 1000))
	elseif state == "NONE" then
		result.title = "NO BLOCK"
		table.insert(result.lines, Settings.frontBlock and explainMiss(run.events) or "Front Dash Block is turned off.")
	elseif state == "LATE" then
		result.title = "TOO LATE"
		table.insert(result.lines, string.format("Block landed %d ms after the hit.", gap * 1000))
	else
		result.title = "RELEASED EARLY"
		table.insert(result.lines, string.format("Block ended %d ms before the hit: raise Chain Tail.", gap * 1000))
	end

	return result
end

---Score the side dash block test: a hit lands shortly after they arrive.
---@param run table
---@return table
local function evaluateSideBlock(run)
	local ping = Settings.labPing / 1000
	local arrival
	for _, sample in ipairs(run.samples) do
		if sample.distance <= Settings.labReach then
			arrival = sample.t
			break
		end
	end

	if not arrival then
		return { ok = false, title = "NO ARRIVAL", lines = { "They never came within hit reach, so nothing would hit you." } }
	end

	local hitTime = arrival + 0.12
	local intervals = buildIntervals(run.events, hitTime + 0.6)
	local state, gap = checkCoverage(intervals, hitTime, ping)

	local timeline = {
		total = 1,
		bars = { { from = 0, to = LAB_DASH_TIME, lane = 0, color = COLORS.accentDark } },
		ticks = { { at = hitTime, color = COLORS.bad } },
	}
	for _, interval in ipairs(intervals) do
		table.insert(timeline.bars, { from = interval.from + ping, to = interval.to + ping, lane = 1, color = COLORS.accent })
	end

	local result = { lines = {}, timeline = timeline, ok = state == "BLOCKED" }
	if state == "BLOCKED" then
		result.title = "BLOCKED"
		table.insert(result.lines, string.format("A hit %d ms after they arrived was covered by %d ms.", 120, gap * 1000))
	elseif state == "NONE" then
		result.title = "NO BLOCK"
		local reason = "Side Dash Block is turned off."
		if Settings.dashPredict then
			reason = Settings.catchEnabled and "Auto M1 catch is on, which handles side dashes instead of blocking." or explainMiss(run.events)
		end
		table.insert(result.lines, reason)
	elseif state == "LATE" then
		result.title = "TOO LATE"
		table.insert(result.lines, string.format("Block landed %d ms after the hit.", gap * 1000))
	else
		result.title = "RELEASED EARLY"
		table.insert(result.lines, string.format("Block ended %d ms before the hit: raise Block After.", gap * 1000))
	end

	return result
end

---Score a block test against one or more hits.
---@param run table
---@param hits table
---@return table
local function evaluateBlock(run, hits)
	local ping = Settings.labPing / 1000
	local total = hits[#hits] + 0.6
	local intervals = buildIntervals(run.events, total)

	local timeline = { total = total, bars = {}, ticks = {} }
	for _, interval in ipairs(intervals) do
		table.insert(timeline.bars, { from = interval.from + ping, to = interval.to + ping, lane = 1, color = COLORS.accent })
	end

	local result = { lines = {}, timeline = timeline }
	local passed, worst = 0, nil

	for index, hitTime in ipairs(hits) do
		local state, gap = checkCoverage(intervals, hitTime, ping)
		local ok = state == "BLOCKED"
		if ok then
			passed += 1
		elseif not worst then
			worst = { state = state, gap = gap, index = index }
		end

		table.insert(timeline.ticks, { at = hitTime, color = ok and COLORS.good or COLORS.bad })
		if #hits > 1 then
			table.insert(result.lines, string.format("Hit %d: %s%s", index, state, ok and string.format(" (+%d ms)", gap * 1000) or string.format(" (%d ms)", gap * 1000)))
		end
	end

	result.ok = passed == #hits

	if #hits > 1 then
		result.title = string.format("%d/%d BLOCKED", passed, #hits)
	elseif result.ok then
		result.title = "BLOCKED"
		local _, margin = checkCoverage(intervals, hits[1], ping)
		table.insert(result.lines, string.format("Block was up %d ms of margin.", margin * 1000))
	elseif worst and worst.state == "NONE" then
		result.title = "NO BLOCK"
		table.insert(result.lines, Settings.autoBlock and explainMiss(run.events) or "Auto Block is turned off.")
	elseif worst and worst.state == "LATE" then
		result.title = "TOO LATE"
		table.insert(result.lines, string.format("Block landed %d ms after the hit: raise Block Lead.", worst.gap * 1000))
	else
		result.title = "RELEASED EARLY"
		table.insert(result.lines, string.format("Block ended %d ms before the hit: raise Chain Tail or Hold Time.", (worst and worst.gap or 0) * 1000))
	end

	return result
end

---Run one lab test and return its result.
---@param testName string
---@param distance number
---@return table
local function runLabOnce(testName, distance)
	local test = LAB_TESTS[testName]
	local _, myRoot = getMe()
	if not myRoot then
		return { ok = false, title = "NO CHARACTER", lines = { "Spawn in first." } }
	end

	local dummy = getLabDummy()
	if not dummy then
		return { ok = false, title = "CLONE FAILED", lines = { "Could not copy your character." } }
	end

	local root = dummy:FindFirstChild("HumanoidRootPart")
	local humanoid = dummy:FindFirstChildOfClass("Humanoid")
	local animator = humanoid:FindFirstChildOfClass("Animator")
	dummy.Parent = workspace:FindFirstChild("Live") or workspace

	local look = flatten(myRoot.CFrame.LookVector)
	local right = flatten(myRoot.CFrame.RightVector)
	local origin = myRoot.Position

	-- Where the target stands, which way it faces, and which way it moves.
	local position, facing, motion
	if testName == "Side Dash In" or testName == "Block: Side Dash" then
		position, facing, motion = origin + right * distance, look, -right
	elseif testName == "Side Dash Away" then
		position, facing, motion = origin + right * 4, look, right
	elseif testName == "Backdash" then
		position, facing, motion = origin + look * distance, -look, look
	elseif testName == "Front Dash" then
		position, facing, motion = origin + look * distance, -look, -look
	else
		position, facing, motion = origin + look * Settings.labAttackDist, -look, Vector3.zero
	end

	local function place()
		root.CFrame = CFrame.lookAt(position, position + facing)
		root.AssemblyLinearVelocity = Vector3.zero
	end

	place()
	-- Give Zenny a moment to notice the new target.
	task.wait(0.35)
	place()

	if test.type == "dash" then
		local id = getDashAnimationId(test.kind)
		if not id then
			return { ok = false, title = "NO ANIMATION", lines = { "No animation id known for this dash. Learn it first." } }
		end

		labRun = { t0 = os.clock(), events = {}, samples = {} }
		local track = playLabTrack(animator, id)
		if not track then
			labRun = nil
			return { ok = false, title = "NO ANIMATION", lines = { "The dash animation could not play on the target." } }
		end

		local startTime = os.clock()
		while true do
			local moving = os.clock() - startTime < LAB_DASH_TIME
			local velocity = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = moving and Vector3.new(motion.X * Settings.labSpeed, velocity.Y, motion.Z * Settings.labSpeed)
				or Vector3.new(0, velocity.Y, 0)

			table.insert(labRun.samples, {
				t = os.clock() - labRun.t0,
				distance = ((root.Position - myRoot.Position) * Vector3.new(1, 0, 1)).Magnitude,
			})

			if os.clock() - startTime > LAB_DASH_TIME + 0.6 then
				break
			end
			runService.Heartbeat:Wait()
		end

		local run = labRun
		labRun = nil
		track:Stop(0.1)

		if test.block then
			return evaluateSideBlock(run)
		end

		if test.kind == "FRONT" then
			return evaluateFront(run)
		end

		return evaluateDash(run, test, distance)
	end

	-- Block tests: play one attack, or a string of attacks.
	local ids = getAttackIds(testName)
	if #ids == 0 then
		return { ok = false, title = "NO ANIMATION", lines = { "No animation known for this move. Use its Learn button first." } }
	end

	local gap = 0.45
	local starts, hits = {}, {}
	for index, id in ipairs(ids) do
		starts[index] = (index - 1) * gap
		local learnedHit = moveData[id] and moveData[id].hit
		hits[index] = starts[index] + (learnedHit or Settings.labHit)
	end

	labRun = { t0 = os.clock(), events = {}, samples = {} }
	local tracks = {}
	for index, id in ipairs(ids) do
		task.delay(starts[index], function()
			if labRun then
				local track = playLabTrack(animator, id)
				if track then
					table.insert(tracks, track)
				end
			end
		end)
	end

	task.wait(hits[#hits] + 0.7)

	local run = labRun
	labRun = nil
	for _, track in ipairs(tracks) do
		track:Stop(0.1)
	end

	if #tracks == 0 then
		return { ok = false, title = "NO ANIMATION", lines = { "The animation could not play on the target." } }
	end

	return evaluateBlock(run, hits)
end

---Show the latest pass rate in the result text.
---@return string
local function getLabSummary()
	if #labHistory == 0 then
		return "No runs yet"
	end

	local passed = 0
	for _, ok in ipairs(labHistory) do
		if ok then
			passed += 1
		end
	end

	return string.format("Last %d runs: %d passed", #labHistory, passed)
end

---Run a lab test once, or a batch with a little random distance.
---@param count number
local function startLab(count)
	if labRunning then
		return
	end

	labRunning = true
	task.spawn(function()
		local testName = Settings.labTest
		local ok, err = pcall(function()
			table.clear(labHistory)
			local passes, last = 0, nil

			for index = 1, count do
				local distance = Settings.labDistance
				if count > 1 then
					distance = math.clamp(distance + math.random(-2, 2), 3, 25)
				end

				last = runLabOnce(testName, distance)
				table.insert(labHistory, last.ok == true)
				if last.ok then
					passes += 1
				end

				if labResultCallback then
					local shown = table.clone(last)
					if count > 1 then
						shown.title = string.format("%s  (%d/%d)", last.title, passes, index)
					end
					shown.summary = getLabSummary()
					labResultCallback(shown)
				end

				if index < count then
					task.wait(0.8)
				end
			end

			log(string.format("lab %s: %d/%d", testName, passes, count))
		end)

		labRun = nil
		labRunning = false
		removeLabDummy()

		if not ok then
			log("lab error: " .. tostring(err))
			if labResultCallback then
				labResultCallback({ ok = false, title = "LAB ERROR", lines = { tostring(err) }, summary = getLabSummary() })
			end
		end
	end)
end

---Check whether an input is a click or touch.
---@param input InputObject
---@return boolean
local function isPointer(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

---Check whether an input is pointer movement.
---@param input InputObject
---@return boolean
local function isPointerMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

---Add rounded corners to a gui object.
---@param parent GuiObject
---@param radius number
local function corner(parent, radius)
	return newInstance("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

---Add a thin green outline to a gui object.
---@param parent GuiObject
---@param transparency number
---@param thickness number?
local function outline(parent, transparency, thickness)
	return newInstance("UIStroke", {
		Color = COLORS.accent,
		Transparency = transparency,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local rowOrder = setmetatable({}, { __mode = "k" })
local rowRegistry = {}
local sectionHeaders = setmetatable({}, { __mode = "k" })
local pageOfScroll = setmetatable({}, { __mode = "k" })
local infoRows = {}

---Get the next layout order for a parent.
---@param parent Instance
---@return number
local function nextOrder(parent)
	rowOrder[parent] = (rowOrder[parent] or 0) + 1
	return rowOrder[parent]
end

---Register a refresh function for a setting; several rows can share one key.
---@param key string
---@param fn function
local function registerRefresher(key, fn)
	local previous = uiRefreshers[key]
	uiRefreshers[key] = function(animated)
		if previous then
			pcall(previous, animated)
		end

		fn(animated)
	end
end

---Add a press-scale effect to a gui object.
---@param target GuiObject
local function addPress(target)
	local scale = newInstance("UIScale", { Scale = 1 }, target)

	connect(target.InputBegan, function(input)
		if isPointer(input) then
			tween(scale, { Scale = 0.95 }, QUICK)
		end
	end)
	connect(target.InputEnded, function(input)
		if isPointer(input) then
			tween(scale, { Scale = 1 }, QUICK)
		end
	end)
end

---Add a titled card to a page and return the card.
---@param page ScrollingFrame
---@param title string
---@return Frame
local function addSection(page, title)
	local header = newInstance("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Text = string.upper(title),
		TextColor3 = COLORS.dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		LayoutOrder = nextOrder(page),
	}, page)

	local card = newInstance("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = COLORS.card,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		LayoutOrder = nextOrder(page),
	}, page)
	corner(card, 14)
	outline(card, 0.82)
	newInstance("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, card)

	sectionHeaders[card] = header
	return card
end

---Create a row with a title and optional subtitle.
---@param card Frame
---@param title string
---@param subtitle string?
---@param className string
---@return GuiObject, TextLabel
local function createRow(card, title, subtitle, className)
	local row = newInstance(className, {
		Size = UDim2.new(1, 0, 0, subtitle and 48 or 40),
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(card),
	}, card)
	if className == "TextButton" then
		row.Text = ""
		row.AutoButtonColor = false
	end

	local titleLabel = newInstance("TextLabel", {
		Position = UDim2.fromOffset(14, subtitle and 6 or 0),
		Size = UDim2.new(0.55, -14, 0, subtitle and 20 or 40),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = COLORS.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
	}, row)

	if subtitle then
		newInstance("TextLabel", {
			Position = UDim2.fromOffset(14, 26),
			Size = UDim2.new(0.55, -14, 0, 16),
			BackgroundTransparency = 1,
			Text = subtitle,
			TextColor3 = COLORS.dim,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.Gotham,
			TextSize = 11,
		}, row)
	end

	newInstance("Frame", {
		Position = UDim2.new(0, 14, 1, -1),
		Size = UDim2.new(1, -28, 0, 1),
		BackgroundColor3 = COLORS.accent,
		BackgroundTransparency = 0.92,
		BorderSizePixel = 0,
	}, row)

	table.insert(rowRegistry, { row = row, title = title:lower(), card = card })
	return row, titleLabel
end

---Add a switch row bound to a boolean setting.
---@param card Frame
---@param title string
---@param subtitle string?
---@param key string
local function addSwitch(card, title, subtitle, key)
	local row = createRow(card, title, subtitle, "TextButton")

	local track = newInstance("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(40, 22),
		BorderSizePixel = 0,
	}, row)
	newInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, track)

	local knob = newInstance("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, track)
	newInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)

	local function refresh(animated)
		local on = Settings[key]
		local trackGoal = { BackgroundColor3 = on and COLORS.accent or COLORS.off }
		local knobGoal = {
			Position = on and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
			BackgroundColor3 = on and COLORS.ink or COLORS.dim,
		}

		if animated then
			tween(track, trackGoal)
			tween(knob, knobGoal)
			return
		end

		track.BackgroundColor3 = trackGoal.BackgroundColor3
		knob.Position = knobGoal.Position
		knob.BackgroundColor3 = knobGoal.BackgroundColor3
	end

	refresh(false)
	registerRefresher(key, refresh)
	connect(row.MouseButton1Click, function()
		Settings[key] = not Settings[key]
		refresh(true)
		onSettingChanged(key)
	end)
end

---Add a slider row bound to a number setting.
---@param card Frame
---@param title string
---@param subtitle string?
---@param key string
---@param min number
---@param max number
---@param step number
---@param suffix string
local function addSlider(card, title, subtitle, key, min, max, step, suffix)
	local row = createRow(card, title, subtitle, "Frame")
	local scroll = card.Parent

	local hit = newInstance("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0.55, 0, 0.5, 0),
		Size = UDim2.new(0.45, -86, 0, 30),
		BackgroundTransparency = 1,
		Active = true,
	}, row)

	local bar = newInstance("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = COLORS.off,
		BorderSizePixel = 0,
	}, hit)
	newInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, bar)

	local fill = newInstance("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = COLORS.accent,
		BorderSizePixel = 0,
	}, bar)
	newInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)

	local knob = newInstance("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, bar)
	newInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)

	local value = newInstance("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(64, 20),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.text,
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
	}, row)

	local function render(animated)
		local alpha = math.clamp((Settings[key] - min) / (max - min), 0, 1)
		if animated then
			tween(fill, { Size = UDim2.fromScale(alpha, 1) }, QUICK)
			tween(knob, { Position = UDim2.new(alpha, 0, 0.5, 0) }, QUICK)
		else
			fill.Size = UDim2.fromScale(alpha, 1)
			knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		end

		value.Text = string.format("%g%s", Settings[key], suffix)
	end

	local function setFromX(x)
		local alpha = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		Settings[key] = math.floor((min + (max - min) * alpha) / step + 0.5) * step
		render(true)
	end

	local dragging = false
	render(false)
	registerRefresher(key, render)

	connect(hit.InputBegan, function(input)
		if isPointer(input) then
			dragging = true
			scroll.ScrollingEnabled = false
			setFromX(input.Position.X)
		end
	end)
	connect(userInputService.InputChanged, function(input)
		if dragging and isPointerMove(input) then
			setFromX(input.Position.X)
		end
	end)
	connect(userInputService.InputEnded, function(input)
		if dragging and isPointer(input) then
			dragging = false
			scroll.ScrollingEnabled = true
		end
	end)
end

---Add a row that cycles through string options.
---@param card Frame
---@param title string
---@param subtitle string?
---@param key string
---@param options table
local function addCycle(card, title, subtitle, key, options)
	local row = createRow(card, title, subtitle, "TextButton")

	local value = newInstance("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(110, 20),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.accent,
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		Text = Settings[key],
	}, row)

	registerRefresher(key, function()
		value.Text = Settings[key]
	end)

	connect(row.MouseButton1Click, function()
		local index = table.find(options, Settings[key]) or 0
		Settings[key] = options[index % #options + 1]
		value.Text = Settings[key]
	end)
end

---Add a row that binds a toggle key; Backspace clears it and Escape cancels.
---@param card Frame
---@param title string
---@param subtitle string?
---@param key string
local function addKeybind(card, title, subtitle, key)
	local row = createRow(card, title, subtitle, "TextButton")

	local pill = newInstance("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(74, 24),
		BackgroundColor3 = COLORS.off,
		TextColor3 = COLORS.accent,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		Text = Settings[key],
	}, row)
	newInstance("UICorner", { CornerRadius = UDim.new(0, 8) }, pill)

	registerRefresher(key, function()
		pill.Text = Settings[key]
	end)

	connect(row.MouseButton1Click, function()
		-- Cancel any other row that is still listening.
		if bindCapture then
			bindCapture(Enum.KeyCode.Escape)
		end

		pill.Text = "..."
		bindCapture = function(code)
			bindCapture = nil
			if code == Enum.KeyCode.Backspace then
				Settings[key] = "None"
			elseif code ~= Enum.KeyCode.Escape then
				Settings[key] = code.Name
			end
			pill.Text = Settings[key]
		end
	end)
end

---Add a row with an action button.
---@param card Frame
---@param title string
---@param subtitle string?
---@param buttonText string
---@param callback function
local function addAction(card, title, subtitle, buttonText, callback)
	local row = createRow(card, title, subtitle, "Frame")

	local button = newInstance("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(92, 26),
		BackgroundColor3 = COLORS.accent,
		Text = buttonText,
		TextColor3 = COLORS.ink,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		AutoButtonColor = false,
	}, row)
	newInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, button)
	addPress(button)
	connect(button.MouseButton1Click, callback)
end

---Add a row showing text that refreshes twice a second.
---@param card Frame
---@param title string
---@param getText function
local function addInfo(card, title, getText)
	local row = createRow(card, title, nil, "Frame")

	local value = newInstance("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.new(0.45, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = getText(),
		TextColor3 = COLORS.dim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
	}, row)

	table.insert(infoRows, { label = value, get = getText })
end

---Count the learned ids of a move.
---@param name string
---@return number
local function countLearned(name)
	local count = 0
	for _ in pairs(learned[name]) do
		count += 1
	end

	return count
end

---Format seconds as a short runtime.
---@param seconds number
---@return string
local function formatRuntime(seconds)
	seconds = math.floor(seconds)
	if seconds >= 3600 then
		return string.format("%dh %02dm", seconds // 3600, (seconds % 3600) // 60)
	end

	return string.format("%dm %02ds", seconds // 60, seconds % 60)
end

local INDICATOR_LIST = {
	{ "autoBlock", "Auto Block" },
	{ "adaptiveBlock", "Adaptive Timing" },
	{ "autoEvasive", "Auto Evasive" },
	{ "consecBlock", "Consec Block" },
	{ "punishBlock", "Punish M1" },
	{ "punishConsec", "Punish Consec" },
	{ "shoveM1", "Shove M1" },
	{ "catchEnabled", "Side Dash M1" },
	{ "bdcCatch", "Backdash Cancel M1" },
	{ "frontBlock", "Front Dash Block" },
	{ "catchFace", "Lock" },
	{ "techLoop", "Tech" },
	{ "counterBait", "Counter Bait" },
	{ "sideBoost", "Side Dash Boost" },
	{ "lagComp", "Lag Comp" },
	{ "botEnabled", "Bot" },
}

---Build the window, pages, quick pills and indicators.
local function buildGui()
	gui = newInstance("ScreenGui", { Name = "Slotted", ResetOnSpawn = false, DisplayOrder = 50 }, nil)

	local parented = pcall(function()
		gui.Parent = (gethui and gethui()) or coreGuiService
	end)
	if not parented or not gui.Parent then
		gui.Parent = playerGui
	end

	holder = newInstance("Folder", { Name = "ZennyObjects" }, gui)

	local loadedAt = os.clock()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(800, 400)
	local width = math.min(viewport.X - 24, 720)
	local height = math.min(viewport.Y - 24, 380)
	local mainWidth = width - 20

	local window = newInstance("CanvasGroup", {
		Name = "Window",
		Size = UDim2.fromOffset(width, height),
		Position = UDim2.fromOffset(math.floor((viewport.X - width) / 2), math.floor((viewport.Y - height) / 2)),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Visible = false,
	}, gui)
	corner(window, 24)
	newInstance("UIGradient", {
		Rotation = 135,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(14, 14, 14)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(0, 0, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 18, 18)),
		}),
	}, window)

	-- Glowing edge that fades from the bottom left like the mockup.
	local edge = newInstance("UIStroke", { Color = COLORS.accent, Thickness = 2, Transparency = 0 }, window)
	newInstance("UIGradient", {
		Rotation = 45,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(0.5, 0.85),
			NumberSequenceKeypoint.new(1, 0.4),
		}),
	}, edge)
	local windowScale = newInstance("UIScale", { Scale = 0.94 }, window)

	-- Soft inner glow along the window border and a faint light from the top.
	local innerGlow = newInstance("Frame", {
		Name = "InnerGlow",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, window)
	corner(innerGlow, 24)
	newInstance("UIStroke", { Color = COLORS.accent, Thickness = 10, Transparency = 0.93 }, innerGlow)
	local topLight = newInstance("Frame", {
		Name = "TopLight",
		Size = UDim2.new(1, 0, 0, 110),
		BackgroundColor3 = COLORS.accent,
		BorderSizePixel = 0,
	}, window)
	newInstance("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.9),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, topLight)

	-- White particles drifting in the background; each one has a halo that twinkles.
	local particleLayer = newInstance("Frame", {
		Name = "Particles",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, window)
	local particles = {}
	for index = 1, 36 do
		local size = math.random(2, 4)
		local dot = newInstance("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = COLORS.accent,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
		}, particleLayer)
		newInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
		local halo = newInstance("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size * 6, size * 6),
			BackgroundColor3 = COLORS.accent,
			BackgroundTransparency = 0.92,
			BorderSizePixel = 0,
		}, dot)
		newInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, halo)

		particles[index] = {
			dot = dot,
			halo = halo,
			x = math.random(),
			y = math.random(),
			vx = (math.random() - 0.5) * 0.02,
			vy = -(0.008 + math.random() * 0.03),
			phase = math.random() * 6.28,
			speed = 0.6 + math.random() * 1.6,
		}
	end

	local glowClock = 0
	connect(runService.Heartbeat, function(delta)
		if not window.Visible then
			return
		end

		glowClock += delta
		for _, particle in ipairs(particles) do
			particle.x = (particle.x + particle.vx * delta) % 1
			particle.y = (particle.y + particle.vy * delta) % 1
			local twinkle = 0.5 + 0.5 * math.sin(glowClock * particle.speed + particle.phase)
			particle.dot.Position = UDim2.fromScale(particle.x, particle.y)
			particle.dot.BackgroundTransparency = 0.8 - 0.65 * twinkle
			particle.halo.BackgroundTransparency = 0.96 - 0.1 * twinkle
		end

		edge.Transparency = 0.05 + 0.2 * (0.5 + 0.5 * math.sin(glowClock * 1.4))
	end)

	-- Main area: top bar and pages.
	local main = newInstance("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 1, -20),
		BackgroundTransparency = 1,
	}, window)

	local topBar = newInstance("Frame", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Active = true,
	}, main)

	-- Logo; dragging it moves the window like the top bar.
	local logoRow = newInstance("Frame", {
		Size = UDim2.fromOffset(112, 40),
		BackgroundTransparency = 1,
		Active = true,
	}, topBar)
	local badge = newInstance("Frame", {
		Position = UDim2.fromOffset(2, 6),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = COLORS.accent,
		BorderSizePixel = 0,
	}, logoRow)
	corner(badge, 8)
	newInstance("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), COLORS.accentDark),
	}, badge)
	newInstance("UIStroke", { Color = COLORS.accent, Thickness = 3, Transparency = 0.8 }, badge)
	newInstance("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "S",
		TextColor3 = COLORS.ink,
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
	}, badge)
	newInstance("TextLabel", {
		Position = UDim2.fromOffset(38, 0),
		Size = UDim2.new(1, -38, 1, 0),
		BackgroundTransparency = 1,
		Text = "Slotted",
		TextColor3 = COLORS.text,
		TextStrokeColor3 = COLORS.accent,
		TextStrokeTransparency = 0.8,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
		TextSize = 19,
	}, logoRow)

	local search = newInstance("Frame", {
		Size = UDim2.new(1, -(118 + 240), 0, 34),
		Position = UDim2.fromOffset(118, 3),
		BackgroundColor3 = COLORS.card,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	}, topBar)
	newInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, search)
	outline(search, 0.75)
	newInstance("TextLabel", {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.fromOffset(20, 34),
		BackgroundTransparency = 1,
		Text = "🔍",
		TextColor3 = COLORS.dim,
		TextSize = 14,
		Font = Enum.Font.Gotham,
	}, search)
	local searchBox = newInstance("TextBox", {
		Position = UDim2.fromOffset(36, 0),
		Size = UDim2.new(1, -44, 1, 0),
		BackgroundTransparency = 1,
		PlaceholderText = "Search features...",
		PlaceholderColor3 = COLORS.dim,
		Text = "",
		TextColor3 = COLORS.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Font = Enum.Font.Gotham,
		TextSize = 13,
	}, search)

	-- Window controls on the far right.
	local closeButton = newInstance("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1,
		Text = "✕",
		TextColor3 = COLORS.dim,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		AutoButtonColor = false,
	}, topBar)
	local minimizeButton = newInstance("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -30, 0.5, 0),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1,
		Text = "—",
		TextColor3 = COLORS.dim,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		AutoButtonColor = false,
	}, topBar)

	-- User chip.
	local chip = newInstance("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -62, 0.5, 0),
		Size = UDim2.fromOffset(132, 36),
		BackgroundColor3 = COLORS.card,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	}, topBar)
	newInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, chip)
	outline(chip, 0.75)

	local avatar = newInstance("ImageLabel", {
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = COLORS.off,
		Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", localPlayer.UserId),
		BorderSizePixel = 0,
	}, chip)
	newInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, avatar)
	outline(avatar, 0.2, 1.5)

	newInstance("TextLabel", {
		Position = UDim2.fromOffset(38, 3),
		Size = UDim2.new(1, -44, 0, 16),
		BackgroundTransparency = 1,
		Text = localPlayer.DisplayName,
		TextColor3 = COLORS.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
	}, chip)
	newInstance("TextLabel", {
		Position = UDim2.fromOffset(38, 18),
		Size = UDim2.new(1, -44, 0, 14),
		BackgroundTransparency = 1,
		Text = "● Online",
		TextColor3 = COLORS.accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.Gotham,
		TextSize = 10,
	}, chip)

	local bell = newInstance("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -200, 0.5, 0),
		Size = UDim2.fromOffset(32, 32),
		BackgroundTransparency = 1,
		Text = "🔔",
		TextColor3 = COLORS.dim,
		Font = Enum.Font.Gotham,
		TextSize = 16,
		AutoButtonColor = false,
	}, topBar)

	-- Horizontal tab strip under the top bar.
	local nav = newInstance("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.X,
	}, main)
	newInstance("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, nav)
	newInstance("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2) }, nav)

	local unload = newInstance("TextButton", {
		Size = UDim2.fromOffset(70, 28),
		BackgroundTransparency = 1,
		Text = "Unload",
		TextColor3 = COLORS.accent,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		AutoButtonColor = false,
		LayoutOrder = 99,
	}, nav)
	newInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, unload)
	outline(unload, 0.4, 1.5)
	addPress(unload)
	connect(unload.MouseButton1Click, function()
		Zenny.detach()
	end)

	local content = newInstance("Frame", {
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 1, -84),
		BackgroundTransparency = 1,
	}, main)

	-- Tabs and pages.
	local tabs = {}
	local tabOrder = {}
	local activeTab = nil

	local function selectTab(name)
		activeTab = name
		for tabName, entry in pairs(tabs) do
			local active = tabName == name
			if active then
				entry.page.Visible = true
			else
				task.delay(0.22, function()
					if activeTab ~= tabName then
						entry.page.Visible = false
					end
				end)
			end

			tween(entry.page, { GroupTransparency = active and 0 or 1 })
			tween(entry.tab, {
				BackgroundTransparency = active and 0.88 or 1,
				TextColor3 = active and COLORS.text or COLORS.dim,
			})
			tween(entry.indicator, { BackgroundTransparency = active and 0 or 1 })
		end
	end

	local function addPage(name, order, icon)
		local tab = newInstance("TextButton", {
			Size = UDim2.fromOffset(0, 28),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = COLORS.accent,
			BackgroundTransparency = 1,
			Text = icon .. "  " .. name,
			TextColor3 = COLORS.dim,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			AutoButtonColor = false,
			LayoutOrder = order,
		}, nav)
		newInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, tab)
		newInstance("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, tab)

		local indicator = newInstance("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.new(0.5, 0, 0, 2),
			BackgroundColor3 = COLORS.accent,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, tab)
		newInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, indicator)

		local page = newInstance("CanvasGroup", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			GroupTransparency = 1,
			Visible = false,
		}, content)
		local scroll = newInstance("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 0,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ScrollingDirection = Enum.ScrollingDirection.Y,
		}, page)
		newInstance("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
		newInstance("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 12), PaddingRight = UDim.new(0, 2) }, scroll)

		tabs[name] = { tab = tab, page = page, indicator = indicator }
		pageOfScroll[scroll] = name
		table.insert(tabOrder, name)
		connect(tab.MouseButton1Click, function()
			selectTab(name)
		end)

		return scroll
	end

	-- Home.
	local home = addPage("Home", 0, "🏠")

	local hero = newInstance("Frame", {
		Size = UDim2.new(1, 0, 0, 162),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = 1,
	}, home)
	corner(hero, 20)
	outline(hero, 0.7)
	newInstance("UIGradient", {
		Rotation = 20,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 30, 30)),
		}),
	}, hero)

	newInstance("TextLabel", {
		Position = UDim2.fromOffset(20, 12),
		Size = UDim2.fromOffset(200, 20),
		BackgroundTransparency = 1,
		Text = "Welcome to",
		TextColor3 = COLORS.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.Gotham,
		TextSize = 15,
	}, hero)
	local heroTitle = newInstance("TextLabel", {
		Position = UDim2.fromOffset(20, 30),
		Size = UDim2.fromOffset(240, 46),
		BackgroundTransparency = 1,
		Text = "Slotted",
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = COLORS.accent,
		TextStrokeTransparency = 0.85,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBlack,
		TextSize = 42,
	}, hero)
	newInstance("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), COLORS.accentDark),
	}, heroTitle)
	newInstance("TextLabel", {
		Position = UDim2.fromOffset(20, 80),
		Size = UDim2.fromOffset(260, 20),
		BackgroundTransparency = 1,
		Text = "Smarter. Faster. Stronger.",
		TextColor3 = COLORS.accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
	}, hero)
	newInstance("TextLabel", {
		Position = UDim2.fromOffset(20, 102),
		Size = UDim2.fromOffset(250, 16),
		BackgroundTransparency = 1,
		Text = "Your TSB combat assistant.",
		TextColor3 = COLORS.dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.Gotham,
		TextSize = 11,
	}, hero)

	local getStarted = newInstance("TextButton", {
		Position = UDim2.fromOffset(20, 124),
		Size = UDim2.fromOffset(118, 30),
		BackgroundColor3 = COLORS.accent,
		Text = "Get Started  ➜",
		TextColor3 = COLORS.ink,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		AutoButtonColor = false,
	}, hero)
	newInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, getStarted)
	addPress(getStarted)

	local explore = newInstance("TextButton", {
		Position = UDim2.fromOffset(146, 124),
		Size = UDim2.fromOffset(116, 30),
		BackgroundTransparency = 1,
		Text = "Explore Tools",
		TextColor3 = COLORS.text,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		AutoButtonColor = false,
	}, hero)
	newInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, explore)
	outline(explore, 0.4, 1.5)
	addPress(explore)

	-- Orbit ring around a big Z, like the logo in the mockup.
	local emblem = newInstance("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -26, 0.5, 0),
		Size = UDim2.fromOffset(132, 132),
		BackgroundTransparency = 1,
	}, hero)
	local glow = newInstance("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(96, 96),
		BackgroundColor3 = COLORS.accent,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
	}, emblem)
	newInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, glow)
	local ring = newInstance("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(128, 128),
		BackgroundTransparency = 1,
	}, emblem)
	newInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
	local ringStroke = outline(ring, 0, 3)
	newInstance("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.55, 0.9),
			NumberSequenceKeypoint.new(1, 0),
		}),
	}, ringStroke)
	local bigZ = newInstance("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "S",
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBlack,
		TextSize = 78,
	}, emblem)
	newInstance("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), COLORS.accentDark),
	}, bigZ)

	connect(runService.RenderStepped, function(delta)
		ring.Rotation = (ring.Rotation + delta * 40) % 360
	end)

	connect(getStarted.MouseButton1Click, function()
		selectTab("Combat")
	end)
	connect(explore.MouseButton1Click, function()
		selectTab("Dashes")
	end)

	-- Stat cards.
	local statsRow = newInstance("Frame", {
		Size = UDim2.new(1, 0, 0, 66),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
	}, home)
	newInstance("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, statsRow)

	---Build one stat card with a value and a small bar chart.
	---@param order number
	---@param icon string
	---@param title string
	---@param barCount number
	---@return TextLabel, table
	local function addStat(order, icon, title, barCount)
		local card = newInstance("Frame", {
			Size = UDim2.new(1 / 3, -6, 1, 0),
			BackgroundColor3 = COLORS.card,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			LayoutOrder = order,
		}, statsRow)
		corner(card, 14)
		outline(card, 0.8)

		local box = newInstance("TextLabel", {
			Position = UDim2.fromOffset(10, 15),
			Size = UDim2.fromOffset(36, 36),
			BackgroundColor3 = COLORS.off,
			Text = icon,
			TextColor3 = COLORS.accent,
			Font = Enum.Font.GothamBold,
			TextSize = 16,
		}, card)
		corner(box, 10)

		newInstance("TextLabel", {
			Position = UDim2.fromOffset(54, 12),
			Size = UDim2.new(0.5, -40, 0, 14),
			BackgroundTransparency = 1,
			Text = title,
			TextColor3 = COLORS.dim,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.Gotham,
			TextSize = 10,
		}, card)
		local value = newInstance("TextLabel", {
			Position = UDim2.fromOffset(54, 28),
			Size = UDim2.new(0.5, -40, 0, 26),
			BackgroundTransparency = 1,
			Text = "-",
			TextColor3 = COLORS.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.GothamBold,
			TextSize = 17,
		}, card)

		local bars = newInstance("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -10, 1, -10),
			Size = UDim2.new(0.34, 0, 0, 34),
			BackgroundTransparency = 1,
		}, card)
		newInstance("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 2),
		}, bars)

		local list = {}
		for index = 1, barCount do
			local bar = newInstance("Frame", {
				Size = UDim2.new(1 / barCount, -2, 0.2, 0),
				BackgroundColor3 = COLORS.accent,
				BackgroundTransparency = 0.2,
				BorderSizePixel = 0,
				LayoutOrder = index,
			}, bars)
			newInstance("UICorner", { CornerRadius = UDim.new(0, 2) }, bar)
			list[index] = bar
		end

		return value, list
	end

	local fpsValue, fpsBars = addStat(1, "⚡", "FPS", 8)
	local moduleValue, moduleBars = addStat(2, "▣", "Active Modules", 8)
	local runtimeValue, runtimeBars = addStat(3, "🕒", "Runtime", 8)

	-- Quick actions and system status.
	local lowerRow = newInstance("Frame", {
		Size = UDim2.new(1, 0, 0, 126),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
	}, home)
	newInstance("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, lowerRow)

	local quickCard = newInstance("Frame", {
		Size = UDim2.new(0.66, -4, 1, 0),
		BackgroundColor3 = COLORS.card,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		LayoutOrder = 1,
	}, lowerRow)
	corner(quickCard, 14)
	outline(quickCard, 0.8)
	newInstance("TextLabel", {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.fromOffset(140, 22),
		BackgroundTransparency = 1,
		Text = "Quick Actions",
		TextColor3 = COLORS.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
	}, quickCard)
	local viewAll = newInstance("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(70, 22),
		BackgroundTransparency = 1,
		Text = "View All ➜",
		TextColor3 = COLORS.dim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		AutoButtonColor = false,
	}, quickCard)
	connect(viewAll.MouseButton1Click, function()
		selectTab("Combat")
	end)

	local tileGrid = newInstance("Frame", {
		Position = UDim2.fromOffset(10, 34),
		Size = UDim2.new(1, -20, 1, -42),
		BackgroundTransparency = 1,
	}, quickCard)
	local tileWidth = math.max(math.floor((mainWidth * 0.66 - 4 - 20 - 18) / 4), 44)
	newInstance("UIGridLayout", {
		CellSize = UDim2.fromOffset(tileWidth, 78),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, tileGrid)

	local tiles = {}
	for index, info in ipairs({
		{ "Auto Block", "autoBlock", "🛡" },
		{ "Side Dash M1", "catchEnabled", "💨" },
		{ "BDC M1", "bdcCatch", "⏪" },
		{ "Front Dash Block", "frontBlock", "⚡" },
	}) do
		local tile = newInstance("TextButton", {
			BackgroundColor3 = COLORS.off,
			BackgroundTransparency = 0.45,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = index,
		}, tileGrid)
		corner(tile, 12)
		local tileStroke = outline(tile, 0.85)
		addPress(tile)

		newInstance("TextLabel", {
			Position = UDim2.fromOffset(8, 6),
			Size = UDim2.fromOffset(28, 26),
			BackgroundTransparency = 1,
			Text = info[3],
			TextColor3 = COLORS.accent,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.Gotham,
			TextSize = 20,
		}, tile)
		newInstance("TextLabel", {
			Position = UDim2.fromOffset(8, 36),
			Size = UDim2.new(1, -12, 0, 34),
			BackgroundTransparency = 1,
			Text = info[1],
			TextColor3 = COLORS.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
		}, tile)

		tiles[index] = { tile = tile, stroke = tileStroke, key = info[2] }
		connect(tile.MouseButton1Click, function()
			Settings[info[2]] = not Settings[info[2]]
			local refresh = uiRefreshers[info[2]]
			if refresh then
				refresh(true)
			end
			onSettingChanged(info[2])
		end)
	end

	local statusCard = newInstance("Frame", {
		Size = UDim2.new(0.34, -4, 1, 0),
		BackgroundColor3 = COLORS.card,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		LayoutOrder = 2,
	}, lowerRow)
	corner(statusCard, 14)
	outline(statusCard, 0.8)
	newInstance("TextLabel", {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 22),
		BackgroundTransparency = 1,
		Text = "System Status",
		TextColor3 = COLORS.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
	}, statusCard)
	local statusDot = newInstance("Frame", {
		Position = UDim2.fromOffset(14, 42),
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = COLORS.accent,
		BorderSizePixel = 0,
	}, statusCard)
	newInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, statusDot)
	local statusText = newInstance("TextLabel", {
		Position = UDim2.fromOffset(28, 36),
		Size = UDim2.new(1, -36, 0, 20),
		BackgroundTransparency = 1,
		Text = "All Systems Operational",
		TextColor3 = COLORS.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Font = Enum.Font.Gotham,
		TextSize = 11,
	}, statusCard)
	local statusDetail = newInstance("TextLabel", {
		Position = UDim2.fromOffset(14, 62),
		Size = UDim2.new(1, -28, 0, 50),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = COLORS.dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Font = Enum.Font.Gotham,
		TextSize = 10,
	}, statusCard)

	-- Combat.
	local combat = addPage("Combat", 1, "⚔️")

	local block = addSection(combat, "Auto Block")
	addSwitch(block, "Auto Block", "Hold F when an attack starts", "autoBlock")
	addKeybind(block, "Toggle Key", "Backspace clears it", "keyAutoBlock")
	addSlider(block, "Auto Block Rate", "100% blocks everything on time, lower misses more", "blockRate", 0, 100, 5, "%")
	addAction(block, "Whitelist", "Skip friends and chosen players", "Open", function()
		selectTab("Whitelist")
	end)

	block = addSection(combat, "Front Dash Block")
	addSwitch(block, "Front Dash Block", "Block bullet dashes aimed at you, M1 as they land", "frontBlock")
	addKeybind(block, "Toggle Key", "Backspace clears it", "keyFrontBlock")
	addSlider(block, "Front Dash Block Rate", "100% never misses a dash, lower misses more", "frontRate", 0, 100, 5, "%")
	addAction(block, "Learn Front Dash", "Then front dash yourself", "Learn", function()
		learning = "front"
		log("learning front dash: front dash now")
	end)
	addInfo(block, "Learned", function()
		return learning == "front" and "waiting..." or (countLearned("front") .. " ids")
	end)

	block = addSection(combat, "Consec Block")
	addSwitch(block, "Consec Block", "Hold F during consecutive punches", "consecBlock")
	addKeybind(block, "Toggle Key", "Backspace clears it", "keyConsecBlock")
	addSlider(block, "Consec Block Rate", "100% reacts to every barrage, lower misses more", "consecChance", 0, 100, 5, "%")
	addAction(block, "Learn Consec", "Then use your own consec", "Learn", function()
		learning = "barrage"
		log("learning consec: use your consecutive punches now")
	end)
	addInfo(block, "Learned", function()
		return learning == "barrage" and "waiting..." or (countLearned("barrage") .. " ids")
	end)

	block = addSection(combat, "Punish")
	addSwitch(block, "Punish Blocked M1", "Send a timed M1 back after blocking an M1", "punishBlock")
	addKeybind(block, "Toggle Key", "Backspace clears it", "keyPunishBlock")
	addSwitch(block, "Punish Consec", "Wait for a consec to end, then send a timed M1", "punishConsec")
	addKeybind(block, "Toggle Key", "Backspace clears it", "keyPunishConsec")
	addSlider(block, "Punish Rate", "100% punishes every time, lower misses more", "punishRate", 0, 100, 5, "%")

	local evade = addSection(combat, "Auto Evasive")
	addSwitch(evade, "Enabled", "Spams dash to cancel ragdoll", "autoEvasive")
	addKeybind(evade, "Toggle Key", "Backspace clears it", "keyEvasive")
	addSlider(evade, "Auto Evasive Rate", "100% dashes out of every ragdoll, lower misses more", "evasiveChance", 0, 100, 5, "%")

	local shove = addSection(combat, "Shove Auto M1")
	addSwitch(shove, "Enabled", "M1 when a shove is seen", "shoveM1")
	addKeybind(shove, "Toggle Key", "Backspace clears it", "keyShoveM1")
	addSwitch(shove, "Also Block", "Block shoves too", "blockShove")
	addSlider(shove, "Shove M1 Rate", "100% punishes every shove, lower misses more", "shoveRate", 0, 100, 5, "%")
	addAction(shove, "Learn Move", "Then use your own shove", "Learn", function()
		learning = "shove"
		log("learning shove: use your shove now")
	end)
	addInfo(shove, "Learned", function()
		return learning == "shove" and "waiting..." or (countLearned("shove") .. " ids")
	end)

	-- Macros and Assist pages. Scoped so their sections do not count against the function's locals.
	do
		local macroPage = addPage("Macros", 3, "⚡")
		local assistPage = addPage("Assist", 6, "🎯")

		local loop = addSection(macroPage, "Loop Dash")
		addSwitch(loop, "Loop Dash", "Circle dash between hits to keep the combo going", "loopDash")
		addSlider(loop, "After Hit", "Loop after this many hits", "loopHits", 1, 8, 1, "")
		addSlider(loop, "Dash Delay", "Wait after the hit before dashing", "loopDelay", 0.05, 0.6, 0.01, "s")
		addSlider(loop, "Follow Up", "Pause after the dash before swinging", "loopFollow", 0.05, 0.8, 0.01, "s")

		local bdc = addSection(macroPage, "Backdash Cancel")
		addSwitch(bdc, "Backdash Cancel", "Cancel the endlag with a back dash, then come back in", "bdcMacro")
		addSlider(bdc, "After Hit", "Cancel after this many hits", "bdcHits", 1, 8, 1, "")
		addSlider(bdc, "Back Dash Delay", "Wait after the hit", "cancelDelay", 0.05, 0.8, 0.01, "s")
		addSlider(bdc, "Return Delay", "Wait before the front dash back in", "bdcReturn", 0.1, 1.2, 0.01, "s")
		addInfo(bdc, "Macro", function()
			return Bot.macroRun and Bot.macroRun.name or "idle"
		end)

		local techs = addSection(macroPage, "Front Dash Techs")
		addSwitch(techs, "Bullet Dash", "Front dash straight at them", "bulletDash")
		addSwitch(techs, "Skibidi Dash", "Front dash aimed at their back", "skibidiDash")
		addSlider(techs, "Skibidi Offset", "How far behind them to aim", "skibidiOffset", 1, 10, 0.5, " studs")
		addSlider(techs, "Front Dash Min", "Closest distance for a bullet or skibidi", "bulletMin", 8, 40, 1, " studs")
		addSlider(techs, "Front Dash Max", "Farthest distance for a bullet or skibidi", "bulletMax", 14, 60, 1, " studs")
		addSwitch(techs, "Surprise Tech", "Throw one out of neutral while strafing", "surprise")
		addSlider(techs, "Surprise Every", "Average time between surprises", "surpriseEvery", 2, 20, 0.5, "s")

		local adapter = addSection(macroPage, "Adapter")
		addSwitch(adapter, "Adapter", "Learn what works on this opponent as the fight goes", "adapterOn")
		addSlider(adapter, "Judge Window", "Time to see if a tech worked", "techWindow", 0.5, 4, 0.1, "s")
		addInfo(adapter, "Last Tech", function()
			return Bot.lastTech
		end)
		addInfo(adapter, "Best Overall", Bot.adaptSummary)
		addInfo(adapter, "Opponent", function()
			local entry = Bot.target and Bot.adapt[Bot.target.Name]
			if not entry then
				return "none"
			end

			return string.format("blocks %d%%, swings %d%%", math.floor(entry.block * 100 + 0.5), math.floor(entry.aggro * 100 + 0.5))
		end)
		addAction(adapter, "Reset Adapter", "Forget every tech result", "Reset", function()
			for name in pairs(table.clone(Bot.adapt)) do
				Bot.adapt[name] = nil
			end
			Bot.lastTech = "none yet"
		end)

		local tips = addSection(macroPage, "Competitive Tips")
		for _, tip in ipairs(Bot.tips) do
			addSwitch(tips, tip.title, tip.short, tip.key)
		end
		addSlider(tips, "Long Arm Chance", "Surprise long arms", "longArmChance", 0, 60, 5, "%")
		addSlider(tips, "Long Arm + Backlash", "Chance while Backlash is up", "longArmBacklash", 0, 80, 5, "%")
		addCycle(tips, "Backlash", "Auto reads the cooldown bar", "backlashMode", { "Auto", "Always", "Never" })
		addSlider(tips, "Hook Away Angle", "How far a hook bends away", "hookAwayAngle", 10, 90, 5, "°")
		addSlider(tips, "Hook Window", "Side dash this soon after M1 is a hook", "hookWindow", 0.2, 1, 0.05, "s")
		addSwitch(tips, "Fade Counter Dash", "Dash out when they counter dash", "hookFade")

		local combos = addSection(macroPage, "Custom Combos")
		addCycle(combos, "Slot", "Slot to record or play", "comboSlot", Bot.allSlots)
		addAction(combos, "Record", "Then do your combo", "Record", function()
			Bot.startRecording()
		end)
		addAction(combos, "Stop", "Also stops after 2.5s idle", "Stop", function()
			Bot.stopRecording()
		end)
		addAction(combos, "Play", "On your lock target (G)", "Play", function()
			Bot.playSelected()
		end)
		addAction(combos, "Clear", "Delete the slot", "Clear", function()
			Bot.combos[Settings.comboSlot] = nil
		end)
		addInfo(combos, "Slot Info", function()
			if Bot.recording then
				return string.format("recording: %d inputs", #Bot.recording.events)
			end

			local combo = Bot.combos[Settings.comboSlot]
			return combo and string.format("%d inputs, %.2fs", #combo.events, combo.length) or "empty"
		end)
		addSwitch(combos, "Bot Uses Combos", "Play them when pressing in", "comboUse")
		addCycle(combos, "Bot Mode", "Selected slot or rotate all", "comboUseMode", { "Selected", "Rotate" })
		addSlider(combos, "Start Range", "Combo only inside this", "comboRange", 4, 20, 1, " studs")
		addSlider(combos, "Cooldown", "Between combos", "comboCooldown", 0.5, 8, 0.5, "s")
		addSwitch(combos, "Cancel To Block", "Stop mid combo to block", "comboCancel")

		local lock = addSection(assistPage, "Lock On")
		addInfo(lock, "Locked", function()
			return Bot.lockOn and (Bot.lockTarget and Bot.lockTarget.Name or "searching") or "off"
		end)
		addAction(lock, "Lock", "Toggle with C", "Toggle", function()
			Bot.setLock(not Bot.lockOn)
		end)
		addAction(lock, "Next Target", "Cycle with V", "Next", function()
			Bot.cycleLock()
		end)
		addSwitch(lock, "Camera Lock", "Turn the camera at them", "lockCamera")
		addSwitch(lock, "Face Them", "Turn your character at them", "lockFaceChar")
		addSwitch(lock, "Lead Movement", "Aim slightly ahead of them", "lockPredict")
		addSlider(lock, "Lock Range", "Pick targets inside", "lockRange", 20, 200, 5, " studs")
		addSlider(lock, "Camera Speed", "Higher snaps faster", "lockSpeed", 4, 60, 1, "")

		local frontLock = addSection(assistPage, "Front Dash Lock")
		addSwitch(frontLock, "Front Dash Lock", "Lock on when you front dash close to someone", "frontLock")
		addSlider(frontLock, "Lock Range", "Counts as close inside this", "frontLockRange", 5, 40, 1, " studs")
		addSlider(frontLock, "Lock Time", "How long the lock stays on", "frontLockTime", 0.3, 3, 0.1, "s")
		addSwitch(frontLock, "Front Dash Aim", "Aim your W dash at the target", "assistFront")

		local assist = addSection(assistPage, "Side Dash Assist")
		addSwitch(assist, "Side Dash Assist", "Aim your A/D dash at the target", "assistSide")
		addSwitch(assist, "Aim Lines", "White aim line and pink predicted dash paths", "assistLines")
		addSwitch(assist, "Double Tap Target", "Double tap a player to pick them", "tapTarget")
		addInfo(assist, "Target", function()
			if Bot.tapTarget then
				return Bot.tapTarget.Name .. " (tapped)"
			end

			return Bot.assistRoot and Bot.assistRoot.Parent and Bot.assistRoot.Parent.Name or "none"
		end)
		addAction(assist, "Clear Target", "Go back to lock or nearest", "Clear", function()
			Bot.tapTarget = nil
		end)
		addSwitch(assist, "Circle Bend", "Bend close side dashes into a circle", "assistHook")
		addSwitch(assist, "Back Dash Aim", "Face them through your S dash", "assistBack")
		addSwitch(assist, "M1 After Dash", "Swing when the dash ends in reach", "assistM1")
		addSlider(assist, "Assist Strength", "How much of the correction is applied", "assistStrength", 10, 100, 5, "%")
		addSlider(assist, "Max Turn", "Largest correction, keeps it looking human", "assistMaxTurn", 10, 120, 5, "°")
		addSlider(assist, "Wobble", "Random aim error", "assistJitter", 0, 10, 0.5, "°")
		addSlider(assist, "Predict Lead", "Aim ahead of their movement", "assistLead", 0, 0.4, 0.01, "s")
		addSlider(assist, "Path Length", "How far the pink line reaches", "assistDashLength", 8, 40, 1, " studs")
		addSlider(assist, "Assist Range", "Nearest target inside", "assistRange", 10, 100, 1, " studs")
		addSlider(assist, "Face Tail", "Keep facing after the dash", "assistTail", 0, 0.8, 0.05, "s")
	end

	-- Combat Lab.
	local lab = addPage("Lab", 7, "🧪")

	local labTop = newInstance("Frame", {
		Size = UDim2.new(1, 0, 0, 244),
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(lab),
	}, lab)

	-- Rotating copy of your character.
	local previewCard = newInstance("Frame", {
		Size = UDim2.new(0, 150, 1, 0),
		BackgroundColor3 = COLORS.card,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	}, labTop)
	corner(previewCard, 14)
	outline(previewCard, 0.8)

	local previewHolder = newInstance("Frame", {
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -34),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, previewCard)
	newInstance("TextLabel", {
		Position = UDim2.new(0, 0, 1, -26),
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = "Drag to spin",
		TextColor3 = COLORS.dim,
		Font = Enum.Font.Gotham,
		TextSize = 10,
	}, previewCard)

	local previewViewport = newInstance("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 190, 175),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-0.5, -1, -0.6),
		Active = true,
	}, previewHolder)
	local previewCamera = newInstance("Camera", { FieldOfView = 40 }, previewViewport)
	previewViewport.CurrentCamera = previewCamera

	local previewModel, previewPivot = nil, nil
	local previewAngle, spinPausedUntil = 0, 0

	local function rebuildPreview()
		if previewModel then
			previewModel:Destroy()
			previewModel = nil
		end

		local character = localPlayer.Character
		if not character then
			return
		end

		local archivable = character.Archivable
		character.Archivable = true
		local clone = character:Clone()
		character.Archivable = archivable
		if not clone then
			return
		end

		for _, descendant in ipairs(clone:GetDescendants()) do
			if descendant:IsA("Script") or descendant:IsA("LocalScript") then
				descendant:Destroy()
			end
		end

		clone:PivotTo(CFrame.new(0, 0, 0))
		clone.Parent = previewViewport
		previewModel = clone
		previewPivot = clone:GetPivot()

		local center, size = clone:GetBoundingBox()
		local distance = (size.Y / 2) / math.tan(math.rad(20)) * 1.3 + size.Z / 2
		previewCamera.CFrame = CFrame.lookAt(center.Position + Vector3.new(0, size.Y * 0.05, -distance), center.Position)
	end

	task.defer(function()
		pcall(rebuildPreview)
	end)
	connect(localPlayer.CharacterAdded, function()
		task.delay(1.5, function()
			pcall(rebuildPreview)
		end)
	end)

	connect(runService.RenderStepped, function(delta)
		if previewModel and previewPivot and os.clock() > spinPausedUntil then
			previewAngle += delta * 0.8
			previewModel:PivotTo(previewPivot * CFrame.Angles(0, previewAngle, 0))
		end
	end)

	local previewDragging = false
	connect(previewViewport.InputBegan, function(input)
		if isPointer(input) then
			previewDragging = true
			spinPausedUntil = os.clock() + 2
		end
	end)
	connect(userInputService.InputChanged, function(input)
		if previewDragging and previewModel and previewPivot and isPointerMove(input) then
			previewAngle += input.Delta.X * 0.015
			spinPausedUntil = os.clock() + 2
			previewModel:PivotTo(previewPivot * CFrame.Angles(0, previewAngle, 0))
		end
	end)
	connect(userInputService.InputEnded, function(input)
		if previewDragging and isPointer(input) then
			previewDragging = false
		end
	end)

	-- Result card.
	local resultCard = newInstance("Frame", {
		Position = UDim2.fromOffset(158, 0),
		Size = UDim2.new(1, -158, 1, 0),
		BackgroundColor3 = COLORS.card,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	}, labTop)
	corner(resultCard, 14)
	outline(resultCard, 0.8)

	newInstance("TextLabel", {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 14),
		BackgroundTransparency = 1,
		Text = "RESULT",
		TextColor3 = COLORS.dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
		TextSize = 10,
	}, resultCard)
	local resultTitle = newInstance("TextLabel", {
		Position = UDim2.fromOffset(14, 22),
		Size = UDim2.new(1, -28, 0, 30),
		BackgroundTransparency = 1,
		Text = "Ready",
		TextColor3 = COLORS.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Font = Enum.Font.GothamBlack,
		TextSize = 22,
	}, resultCard)
	local resultDetail = newInstance("TextLabel", {
		Position = UDim2.fromOffset(14, 54),
		Size = UDim2.new(1, -28, 0, 70),
		BackgroundTransparency = 1,
		Text = "Pick a test below, then tap Run Test.",
		TextColor3 = COLORS.dim,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Enum.Font.Gotham,
		TextSize = 11,
	}, resultCard)

	local timelineFrame = newInstance("Frame", {
		Position = UDim2.fromOffset(14, 132),
		Size = UDim2.new(1, -28, 0, 28),
		BackgroundColor3 = COLORS.off,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
	}, resultCard)
	corner(timelineFrame, 6)

	newInstance("TextLabel", {
		Position = UDim2.fromOffset(14, 164),
		Size = UDim2.new(1, -28, 0, 14),
		BackgroundTransparency = 1,
		Text = "top bar: dash   green: in reach   accent: block   tick: M1 or hit",
		TextColor3 = COLORS.dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.Gotham,
		TextSize = 9,
	}, resultCard)
	local summaryLabel = newInstance("TextLabel", {
		Position = UDim2.fromOffset(14, 180),
		Size = UDim2.new(1, -28, 0, 16),
		BackgroundTransparency = 1,
		Text = "No runs yet",
		TextColor3 = COLORS.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
	}, resultCard)

	---Draw the timeline bars and ticks of a result.
	---@param timeline table?
	local function renderTimeline(timeline)
		for _, child in ipairs(timelineFrame:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		if not timeline then
			return
		end

		for _, bar in ipairs(timeline.bars) do
			local from = math.clamp(bar.from / timeline.total, 0, 1)
			local to = math.clamp(bar.to / timeline.total, 0, 1)
			if to > from then
				local frame = newInstance("Frame", {
					Position = UDim2.new(from, 0, bar.lane * 0.5, bar.lane == 1 and 1 or 0),
					Size = UDim2.new(to - from, 0, 0.5, -1),
					BackgroundColor3 = bar.color,
					BackgroundTransparency = 0.15,
					BorderSizePixel = 0,
				}, timelineFrame)
				corner(frame, 3)
			end
		end

		for _, tick in ipairs(timeline.ticks) do
			newInstance("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(math.clamp(tick.at / timeline.total, 0, 1), 0, 0, -3),
				Size = UDim2.new(0, 3, 1, 6),
				BackgroundColor3 = tick.color,
				BorderSizePixel = 0,
			}, timelineFrame)
		end
	end

	---Show a lab result in the card.
	---@param result table
	local function showResult(result)
		resultTitle.Text = result.title or "-"
		resultTitle.TextColor3 = result.ok and COLORS.good or COLORS.bad

		local lines = {}
		for _, line in ipairs(result.lines or {}) do
			if line ~= "" then
				table.insert(lines, line)
			end
		end
		resultDetail.Text = table.concat(lines, "\n")
		summaryLabel.Text = result.summary or getLabSummary()
		renderTimeline(result.timeline)
	end
	labResultCallback = showResult

	local runOnce = newInstance("TextButton", {
		Position = UDim2.fromOffset(14, 204),
		Size = UDim2.fromOffset(108, 28),
		BackgroundColor3 = COLORS.accent,
		Text = "Run Test",
		TextColor3 = COLORS.ink,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		AutoButtonColor = false,
	}, resultCard)
	newInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, runOnce)
	addPress(runOnce)
	connect(runOnce.MouseButton1Click, function()
		if labRunning then
			return
		end

		showResult({ title = "Running...", ok = true, lines = { "Testing " .. Settings.labTest .. "." }, summary = getLabSummary() })
		startLab(1)
	end)

	local runBatch = newInstance("TextButton", {
		Position = UDim2.fromOffset(130, 204),
		Size = UDim2.fromOffset(108, 28),
		BackgroundTransparency = 1,
		Text = "Run x10",
		TextColor3 = COLORS.text,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		AutoButtonColor = false,
	}, resultCard)
	newInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, runBatch)
	outline(runBatch, 0.4, 1.5)
	addPress(runBatch)
	connect(runBatch.MouseButton1Click, function()
		if labRunning then
			return
		end

		showResult({ title = "Running...", ok = true, lines = { "Running 10 of " .. Settings.labTest .. "." }, summary = "" })
		startLab(10)
	end)

	local scenario = addSection(lab, "Scenario")
	addCycle(scenario, "Test", "What to simulate", "labTest", LAB_TEST_NAMES)
	addSlider(scenario, "Start Distance", "Dash tests", "labDistance", 3, 25, 1, " studs")
	addSlider(scenario, "Attack Distance", "Block tests", "labAttackDist", 3, 14, 1, " studs")
	addSlider(scenario, "Simulated Ping", "Network delay", "labPing", 0, 250, 5, " ms")
	addSlider(scenario, "Dash Speed", "Enemy dash speed", "labSpeed", 30, 100, 5, "")
	addSlider(scenario, "True M1 Reach", "Includes the M1 lunge", "labReach", 3, 20, 0.5, " studs")
	addSlider(scenario, "M1 Startup", "Click to hit delay", "labStartup", 0, 0.3, 0.01, "s")
	addSlider(scenario, "Hit Frame", "Attack lands after", "labHit", 0.1, 0.8, 0.01, "s")
	addSwitch(scenario, "Dry Run", "Don't send real inputs", "labDryRun")

	local tune = addSection(lab, "Tune")
	addSwitch(tune, "Auto Block", "Needed for block tests", "autoBlock")
	addSlider(tune, "Block Lead", "React this early", "blockLead", 0, 0.3, 0.01, "s")
	addSlider(tune, "Chain Tail", "Extra hold after a move", "blockTail", 0, 0.6, 0.05, "s")
	addSlider(tune, "Hold Time", "Minimum time F is held", "blockHold", 0.1, 1, 0.05, "s")
	addSwitch(tune, "Side Dash Auto M1", "Needed for side dash tests", "catchEnabled")
	addSlider(tune, "Hit Reach", "M1 only fires inside this", "catchReach", 4, 30, 1, " studs")
	addSwitch(tune, "Smart Timing", "Predict arrival, skip fixed delays", "catchSmart")
	addSlider(tune, "Timing Offset", "Fire earlier (+) or later (-)", "catchOffset", -0.15, 0.25, 0.01, "s")
	addSlider(tune, "Close Delay", "Wait before M1", "catchCloseDelay", 0, 0.6, 0.01, "s")
	addSlider(tune, "Far Delay", "Wait before M1", "catchFarDelay", 0, 0.6, 0.01, "s")
	addSwitch(tune, "Backdash Cancel M1", "Needed for backdash tests", "bdcCatch")
	addSlider(tune, "Backdash Reach", "M1 only fires inside this", "bdcReach", 4, 30, 1, " studs")
	addSlider(tune, "Backdash Delay", "Wait before M1", "bdcDelay", 0, 0.6, 0.01, "s")
	addSwitch(tune, "Front Dash Block", "Needed for front dash tests", "frontBlock")
	addSwitch(tune, "Side Dash Block", "Needed for the side dash block test", "dashPredict")
	addSlider(tune, "Front Chain Tail", "Keep blocking after it ends", "frontTail", 0, 0.8, 0.05, "s")

	local learnCard = addSection(lab, "Learn Animations")
	addAction(learnCard, "Learn M1 String", "Then swing for 5 seconds", "Learn", function()
		learning = "m1"
		log("learning M1 string: swing now")
		task.delay(5, function()
			if learning == "m1" then
				learning = nil
				log("M1 learning finished")
			end
		end)
	end)
	addInfo(learnCard, "Learned M1", function()
		return learning == "m1" and "swing now..." or (countLearned("m1") .. " ids")
	end)

	-- Dashes.
	local dashPage = addPage("Dashes", 8, "💨")

	local input = addSection(dashPage, "M1 Input")
	addCycle(input, "M1 Method", "How M1s are sent", "m1Method", { "Remote+Mobile", "Remote", "Signal", "Button" })
	addAction(input, "Test M1", "Send one M1", "Test", function()
		clickM1("test")
	end)
	addSwitch(input, "Lag Compensation", "Send inputs early by ping, jitter and one frame", "lagComp")

	local side = addSection(dashPage, "Side Dash")
	addSwitch(side, "Auto M1", "M1 on a side dash", "catchEnabled")
	addKeybind(side, "Toggle Key", "Backspace clears it", "keySideDashM1")
	addSlider(side, "Auto M1 Catch Rate", "100% catches every side dash on time, lower misses more", "catchRate", 0, 100, 5, "%")
	addSwitch(side, "Predict And Block", "Block side dashes that will reach you", "dashPredict")
	addSwitch(side, "Visualizer", "Rings and timing line", "catchVisual")

	local boost = addSection(dashPage, "Side Dash Boost")
	addSwitch(boost, "Boost", "Longer side dash", "sideBoost")
	addKeybind(boost, "Toggle Key", "Backspace clears it", "keySideBoost")

	local back = addSection(dashPage, "Backdash Cancel M1")
	addSwitch(back, "Enabled", "Perfectly timed M1 when someone backdash cancels", "bdcCatch")
	addKeybind(back, "Toggle Key", "Backspace clears it", "keyBackdashM1")
	addSlider(back, "Backdash Cancel M1 Rate", "100% punishes every cancel on time, lower misses more", "bdcRate", 0, 100, 5, "%")
	addAction(back, "Learn Backdash", "Then backdash yourself", "Learn", function()
		learning = "back"
		log("learning backdash: backdash now")
	end)
	addInfo(back, "Learned", function()
		return learning == "back" and "waiting..." or (countLearned("back") .. " ids")
	end)

	local counters = addSection(dashPage, "Counters")
	addSwitch(counters, "Counter Bait", "No M1 into a counter", "counterBait")
	addSwitch(counters, "Counter Punish", "M1 when a counter ends", "counterPunish")

	-- Timing. Scoped so its sections do not count against the function's locals.
	do
		local timingPage = addPage("Timing", 9, "⏱")

		local blockTiming = addSection(timingPage, "Block Timing")
		addCycle(blockTiming, "Block After", "Auto learns it, Ping waits your average ping", "blockAfterMode", { "Auto", "Ping", "Fixed" })
		addSlider(blockTiming, "Fixed Block After", "Used when Block After is Fixed", "blockAfter", 0, 0.4, 0.01, "s")
		addCycle(blockTiming, "Hold", "Auto holds through the whole move", "blockHoldMode", { "Auto", "Fixed" })
		addSlider(blockTiming, "Fixed Hold", "Used when Hold is Fixed", "blockHold", 0.1, 1, 0.05, "s")
		addInfo(blockTiming, "Avg Ping", function()
			return string.format("%d ms", math.floor(pingAverage or getPing()))
		end)

		local timingTools = addSection(timingPage, "Tools")
		addAction(timingTools, "Clear Logger", "Empty the timing log", "Clear", function()
			table.clear(Zenny.timingLog)
		end)
		addAction(timingTools, "Clear Timings", "Forget every animation timing", "Clear", function()
			table.clear(Zenny.timings)
		end)

		---Add a card holding one block of text that refreshes while the tab is open.
		---@param title string
		---@param getText function
		local function addTextCard(title, getText)
			local card = addSection(timingPage, title)
			local label = newInstance("TextLabel", {
				Size = UDim2.new(1, -24, 0, 0),
				Position = UDim2.fromOffset(12, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Text = "",
				TextColor3 = COLORS.dim,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Font = Enum.Font.Code,
				TextSize = 11,
				LayoutOrder = 1,
			}, card)
			newInstance("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, card)

			table.insert(infoRows, {
				label = label,
				get = function()
					return activeTab == "Timing" and getText() or label.Text
				end,
			})
		end

		addTextCard("Timing Logger", Zenny.timingLogText)
		addTextCard("Animation Timings", Zenny.timingText)
	end

	-- Visuals.
	local visualsPage = addPage("Visuals", 10, "👁")
	local esp = addSection(visualsPage, "Players")
	addSwitch(esp, "ESP", "Highlight and health", "esp")
	addSwitch(esp, "Self Chams", "Highlight yourself", "selfChams")
	addSwitch(esp, "Safe-to-Hit", "Open, punish, counter markers", "safeIndicator")
	addSlider(esp, "Safe Range", "Marker distance", "safeRange", 10, 60, 1, " studs")
	addSwitch(esp, "Combo Counter", "Hit streak pill", "comboCounter")

	local world = addSection(visualsPage, "World")
	addSwitch(world, "Custom FOV", "Override field of view", "fovEnabled")
	addSlider(world, "Field of View", "Degrees", "fov", 40, 120, 1, "°")
	addSwitch(world, "No Smoke", "Hide smoke and dust", "noSmoke")
	addSwitch(world, "No Shadows", "Turn global shadows off", "noShadows")

	-- Whitelist.
	local whitelistPage = addPage("Whitelist", 11, "✅")
	local friends = addSection(whitelistPage, "Friends")
	addSwitch(friends, "Friend Check", "Skip Roblox friends", "friendCheck")

	local playersCard = addSection(whitelistPage, "Players")
	local function refreshWhitelist()
		for _, child in ipairs(playersCard:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		local added = false
		for _, player in ipairs(playersService:GetPlayers()) do
			if player ~= localPlayer then
				local key = "wl_" .. player.Name
				if Settings[key] == nil then
					Settings[key] = false
				end

				addSwitch(playersCard, player.Name, "Skipped by every feature", key)
				added = true
			end
		end

		if not added then
			createRow(playersCard, "No other players", nil, "Frame")
		end
	end

	refreshWhitelist()
	connect(playersService.PlayerAdded, function()
		task.delay(0.3, refreshWhitelist)
	end)
	connect(playersService.PlayerRemoving, function()
		task.delay(0.3, refreshWhitelist)
	end)

	-- Misc.
	local miscPage = addPage("Misc", 12, "☰")
	local interface = addSection(miscPage, "Interface")
	addSwitch(interface, "Quick Pills", "Toggle buttons on the left", "quickPills")
	addSwitch(interface, "Indicators", "Feature list on the left", "indicators")
	addSwitch(interface, "Show Inactive", "Dim off features in the list", "indicatorsAll")
	addSwitch(interface, "Dash Cancel Popup", "+1 DASH CANCEL when you dash out of a move", "dashCancelPopup")

	local presets = addSection(miscPage, "Presets")
	addCycle(presets, "Slot", "Preset slot", "presetSlot", { "Slot 1", "Slot 2", "Slot 3" })
	addAction(presets, "Save", "Store current settings", "Save", savePreset)
	addAction(presets, "Load", "Restore saved settings", "Load", loadPreset)
	addInfo(presets, "Status", function()
		return presetStatus
	end)

	local data = addSection(miscPage, "Data")
	addAction(data, "Reset Learned", "Clears timings and moves", "Reset", function()
		table.clear(moveData)
		table.clear(learned.barrage)
		table.clear(learned.shove)
		table.clear(learned.uppercut)
		table.clear(learned.back)
		table.clear(learned.front)
		table.clear(learned.m1)
		table.clear(dashSpeeds)
	end)
	addAction(data, "Unload", "Remove Slotted", "Unload", function()
		Zenny.detach()
	end)

	-- Debug.
	local debugPage = addPage("Debug", 13, "🐞")
	local tools = addSection(debugPage, "Tools")
	addInfo(tools, "Input remote", function()
		return getRemote() and "found" or "MISSING"
	end)
	addAction(tools, "Test M1", "Fire one M1", "Test", function()
		clickM1("test")
	end)
	addAction(tools, "Test All M1", "Tries every method in turn", "Run", testAllM1)
	addAction(tools, "Scan Buttons", "List on-screen buttons", "Scan", scanButtons)
	addAction(tools, "Test Block", "Hold F briefly", "Test", function()
		pressBlock(0.5)
	end)
	addAction(tools, "Scan Remotes", "List remotes in the log", "Scan", scanRemotes)
	addAction(tools, "Clear Log", "Empty the log", "Clear", function()
		table.clear(logLines)
	end)
	addSwitch(tools, "Console Log", "Also print to the console", "debugConsole")

	local logCard = addSection(debugPage, "Log")
	local logLabel = newInstance("TextLabel", {
		Size = UDim2.new(1, -24, 0, 0),
		Position = UDim2.fromOffset(12, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = COLORS.dim,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Enum.Font.Code,
		TextSize = 11,
		LayoutOrder = 1,
	}, logCard)
	newInstance("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, logCard)

	connect(bell.MouseButton1Click, function()
		selectTab("Debug")
	end)

	-- Search filters rows on every page and jumps to a page with matches.
	local function applySearch(query)
		query = query:lower()
		local counts = {}
		local visibleCards = {}

		for _, entry in ipairs(rowRegistry) do
			if entry.row.Parent then
				local match = query == "" or entry.title:find(query, 1, true) ~= nil
				entry.row.Visible = match

				if match then
					visibleCards[entry.card] = true
					local pageName = pageOfScroll[entry.card.Parent]
					if pageName then
						counts[pageName] = (counts[pageName] or 0) + 1
					end
				end
			end
		end

		for card, header in pairs(sectionHeaders) do
			if card.Parent then
				local visible = query == "" or visibleCards[card] == true
				card.Visible = visible
				header.Visible = visible
			end
		end

		return counts
	end

	connect(searchBox:GetPropertyChangedSignal("Text"), function()
		local counts = applySearch(searchBox.Text)
		if searchBox.Text ~= "" and not counts[activeTab] then
			for _, name in ipairs(tabOrder) do
				if counts[name] then
					selectTab(name)
					break
				end
			end
		end
	end)

	-- Refresh the home stats, info rows and log twice a second.
	local frames, statsElapsed = 0, 0
	local fpsHistory = {}
	connect(runService.Heartbeat, function(delta)
		frames += 1
		statsElapsed += delta
		if statsElapsed < 0.5 then
			return
		end

		local fps = frames / statsElapsed
		frames, statsElapsed = 0, 0

		table.insert(fpsHistory, fps)
		if #fpsHistory > #fpsBars then
			table.remove(fpsHistory, 1)
		end

		fpsValue.Text = string.format("%d", fps)
		for index, bar in ipairs(fpsBars) do
			local sample = fpsHistory[index] or 0
			tween(bar, { Size = UDim2.new(1 / #fpsBars, -2, math.clamp(sample / 70, 0.08, 1), 0) }, QUICK)
		end

		local active = 0
		for _, info in ipairs(INDICATOR_LIST) do
			if Settings[info[1]] then
				active += 1
			end
		end
		moduleValue.Text = tostring(active)
		for index, bar in ipairs(moduleBars) do
			local lit = index <= math.ceil(active / (#INDICATOR_LIST / #moduleBars))
			tween(bar, {
				Size = UDim2.new(1 / #moduleBars, -2, 0.2 + 0.8 * index / #moduleBars, 0),
				BackgroundTransparency = (lit and active > 0) and 0.1 or 0.7,
			}, QUICK)
		end

		runtimeValue.Text = formatRuntime(os.clock() - loadedAt)
		for index, bar in ipairs(runtimeBars) do
			tween(bar, { Size = UDim2.new(1 / #runtimeBars, -2, 0.25 + 0.5 * math.abs(math.sin(os.clock() / 3 + index)), 0) }, SMOOTH)
		end

		for _, tile in ipairs(tiles) do
			local on = Settings[tile.key]
			tween(tile.tile, { BackgroundColor3 = on and COLORS.accentDark or COLORS.off, BackgroundTransparency = on and 0.35 or 0.45 }, QUICK)
			tween(tile.stroke, { Transparency = on and 0.1 or 0.85 }, QUICK)
		end

		local remoteFound = getRemote() ~= nil
		statusDot.BackgroundColor3 = remoteFound and COLORS.accent or COLORS.bad
		statusText.Text = remoteFound and "All Systems Operational" or "Input remote missing"
		statusDetail.Text = string.format("Ping %d ms\nLearned %d moves", getPing(), countLearned("barrage") + countLearned("shove") + countLearned("uppercut"))

		for _, info in ipairs(infoRows) do
			if info.label.Parent then
				info.label.Text = info.get()
			end
		end

		if activeTab == "Debug" then
			local first = math.max(#logLines - 24, 1)
			logLabel.Text = table.concat(logLines, "\n", first, #logLines)
		end
	end)

	-- Open and close with a fade and scale.
	local windowOpen = false
	local function setWindowOpen(state)
		windowOpen = state
		if state then
			window.Visible = true
		else
			task.delay(0.22, function()
				if not windowOpen then
					window.Visible = false
				end
			end)
		end

		tween(window, { GroupTransparency = state and 0 or 1 })
		tween(windowScale, { Scale = state and 1 or 0.94 })
	end

	connect(minimizeButton.MouseButton1Click, function()
		setWindowOpen(false)
	end)

	-- Close needs a second tap so it is not hit by accident.
	local closeArmed = false
	connect(closeButton.MouseButton1Click, function()
		if closeArmed then
			Zenny.detach()
			return
		end

		closeArmed = true
		closeButton.TextColor3 = COLORS.bad
		task.delay(2, function()
			closeArmed = false
			if closeButton.Parent then
				closeButton.TextColor3 = COLORS.dim
			end
		end)
	end)

	-- Floating opener for when the window is hidden.
	local opener = newInstance("TextButton", {
		Position = UDim2.fromOffset(12, math.floor(viewport.Y / 2) - 20),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = COLORS.accent,
		Text = "Z",
		TextColor3 = COLORS.ink,
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		AutoButtonColor = false,
	}, gui)
	newInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, opener)
	newInstance("UIStroke", { Color = COLORS.accent, Transparency = 0.5, Thickness = 3 }, opener)
	addPress(opener)
	connect(opener.MouseButton1Click, function()
		setWindowOpen(not windowOpen)
	end)

	connect(userInputService.InputBegan, function(input, processed)
		if not processed and input.KeyCode == TOGGLE_KEY then
			setWindowOpen(not windowOpen)
		end
	end)

	-- Drag the window from the top bar or the logo.
	local dragStart, startPosition
	local function beginDrag(input)
		if isPointer(input) then
			dragStart, startPosition = input.Position, window.Position
		end
	end
	connect(topBar.InputBegan, beginDrag)
	connect(logoRow.InputBegan, beginDrag)
	connect(userInputService.InputChanged, function(input)
		if dragStart and isPointerMove(input) then
			local delta = input.Position - dragStart
			local screen = workspace.CurrentCamera.ViewportSize
			local x = math.clamp(startPosition.X.Offset + delta.X, 0, math.max(screen.X - width, 0))
			local y = math.clamp(startPosition.Y.Offset + delta.Y, 0, math.max(screen.Y - height, 0))
			window.Position = UDim2.fromOffset(x, y)
		end
	end)
	connect(userInputService.InputEnded, function(input)
		if dragStart and isPointer(input) then
			dragStart = nil
		end
	end)

	-- Quick toggle pills for fast changes mid-fight.
	local quick = newInstance("Frame", {
		Position = UDim2.fromOffset(12, math.floor(viewport.Y / 2) + 34),
		Size = UDim2.fromOffset(96, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, gui)
	newInstance("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, quick)

	local quickEntries = {}
	for index, info in ipairs({ { "Block", "autoBlock" }, { "Evasive", "autoEvasive" }, { "Catch", "catchEnabled" }, { "Lock", "catchFace" } }) do
		local pill = newInstance("TextButton", {
			Size = UDim2.fromOffset(96, 30),
			BackgroundColor3 = COLORS.off,
			BackgroundTransparency = 0.3,
			Text = info[1],
			TextColor3 = COLORS.dim,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			AutoButtonColor = false,
			LayoutOrder = index,
		}, quick)
		newInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, pill)
		local stroke = newInstance("UIStroke", { Color = COLORS.accent, Transparency = 0.7, Thickness = 1 }, pill)
		addPress(pill)
		quickEntries[index] = { pill = pill, stroke = stroke, key = info[2] }

		connect(pill.MouseButton1Click, function()
			Settings[info[2]] = not Settings[info[2]]
			local refresh = uiRefreshers[info[2]]
			if refresh then
				refresh(true)
			end
			onSettingChanged(info[2])
		end)
	end

	local quickElapsed = 0
	connect(runService.Heartbeat, function(delta)
		quickElapsed += delta
		if quickElapsed < 0.15 then
			return
		end

		quickElapsed = 0
		quick.Visible = Settings.quickPills

		for _, entry in ipairs(quickEntries) do
			local on = Settings[entry.key]
			if entry.shown ~= on then
				entry.shown = on
				tween(entry.pill, {
					BackgroundColor3 = on and COLORS.accent or COLORS.off,
					BackgroundTransparency = on and 0.1 or 0.3,
					TextColor3 = on and COLORS.ink or COLORS.dim,
				})
				tween(entry.stroke, { Transparency = on and 0.2 or 0.7 })
			end
		end
	end)

	-- Active feature list on the left.
	local indicatorLabel = newInstance("TextLabel", {
		Position = UDim2.fromOffset(14, 96),
		Size = UDim2.fromOffset(190, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		TextColor3 = COLORS.accent,
		TextStrokeTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		RichText = true,
		Text = "",
	}, gui)

	local indicatorElapsed = 0
	connect(runService.Heartbeat, function(delta)
		indicatorElapsed += delta
		if indicatorElapsed < 0.25 then
			return
		end

		indicatorElapsed = 0
		indicatorLabel.Visible = Settings.indicators

		-- Active features light up; the rest stay dim so the whole kit is visible.
		local lines = { string.format('<font color="#%s"><b>Slotted</b></font>', COLORS.accent:ToHex()) }
		for _, info in ipairs(INDICATOR_LIST) do
			if Settings[info[1]] then
				table.insert(lines, string.format('<font color="#%s">%s</font>', COLORS.good:ToHex(), info[2]))
			elseif Settings.indicatorsAll then
				table.insert(lines, string.format('<font color="#%s">%s</font>', COLORS.dim:ToHex(), info[2]))
			end
		end
		indicatorLabel.Text = table.concat(lines, "\n")
	end)

	selectTab("Home")
	setWindowOpen(true)
end

---Initialize the script.
function Zenny.init()
	buildGui()

	connect(runService.Heartbeat, function(delta)
		updateLag(delta)
		scanOwn()
		scanEnemies()
		updateThreats()
		updateDashes()
		updateEvasive()
		Bot.update()
		updateBlockController()
		updateCounterBait()
		updateLockFrame()
		updateEsp()
		updateSelfChams()
		updateSafeIndicator()
		updateComboCounter()
	end)

	Bot.load()
	Bot.installHook()
	runService:BindToRenderStep("ZennyLock", Enum.RenderPriority.Camera.Value + 1, Bot.updateCamera)
	connect(userInputService.InputBegan, Bot.onKey)
	connect(userInputService.InputBegan, Bot.onTap)

	connect(runService.RenderStepped, function()
		Bot.applyMove()
		local camera = workspace.CurrentCamera
		if Settings.fovEnabled and camera then
			camera.FieldOfView = Settings.fov
		end
	end)

	connect(workspace.DescendantAdded, onDescendantAdded)
	connect(playersService.PlayerRemoving, removeEsp)

	log("Slotted loaded; input remote " .. (getRemote() and "found" or "missing"))
end

---Tear everything down and restore touched state.
function Zenny.detach()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)

	for player in pairs(espObjects) do
		removeEsp(player)
	end

	for track in pairs(dashes) do
		untrackDash(track, true)
	end

	for _, entry in pairs(moves) do
		if entry.holding then
			entry.holding = false
			releaseBlock()
		end
	end
	table.clear(moves)
	table.clear(infoRows)
	table.clear(rowRegistry)

	if blockDown then
		local remote = getRemote()
		if remote then
			remote:FireServer({ Goal = "KeyRelease", Key = BLOCK_KEY })
		end
		blockDown = false
	end

	shared.ZennyRecord = nil
	pcall(function()
		runService:UnbindFromRenderStep("ZennyLock")
	end)
	Bot.recording = nil
	Bot.lesson = nil
	Bot.studySubject = nil
	Bot.lockOn = false
	Bot.lockTarget = nil
	if Bot.comboRun then
		Bot.comboRun.cancel = true
	end
	if Bot.macroRun then
		Bot.macroRun.cancel = true
	end

	if Bot.active then
		Bot.active = false
		Settings.botEnabled = false
		Bot.applyProfile(false)
		Bot.moveVector = Vector3.zero
	end

	labRun = nil
	removeLabDummy()
	stopLock()
	lightingService.GlobalShadows = originalShadows

	if gui then
		gui:Destroy()
	end
end

---@param error string
local function onInitializeError(error)
	warn("Slotted failed to initialize.")
	warn(error)
	warn(debug.traceback())
	Zenny.detach()
end

-- Shared-state singleton.
if shared.Zenny then
	shared.Zenny.detach()
end
shared.Zenny = Zenny

xpcall(Zenny.init, onInitializeError)
