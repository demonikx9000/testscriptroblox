--[[
    PRISM UI  |  v1.4.1
    Responsive, customizable UI library for Roblox (Luau).

    ---------------------------------------------------------------
    USAGE
    ---------------------------------------------------------------
    local Library = loadstring(readfile("PrismUI.lua"))()

    local Window = Library:CreateWindow({
        Title     = "PrismUI",
        Size      = Vector2.new(700, 440),
        ToggleKey = Enum.KeyCode.RightShift,
    })

    local Tab     = Window:Tab({ Name = "Main", Icon = "rbxassetid://0" }) -- Icon: asset id, glyph, or nil
    local Section = Tab:Section({ Name = "Section", Side = "Left" })       -- Side: "Left" | "Right" | nil (auto)

    Section:Toggle({
        Name = "Toggle", Flag = "Toggle", Default = false,
        Tooltip = { Title = "Toggle", Description = "Tooltip text." },
        Keybind = true,                       -- adds the "--" key chip (true | Enum.KeyCode)
        Callback = function(value) end,
    })
    Section:Slider({ Name = "Slider", Flag = "Slider", Min = 0, Max = 100, Default = 50, Increment = 1, Suffix = "", Callback = function(v) end })
    Section:Dropdown({ Name = "Dropdown", Flag = "Dropdown", Options = { "A", "B", "C" }, Default = "A", Multi = false, Callback = function(v) end })
    Section:Keybind({ Name = "Keybind", Flag = "Keybind", Default = Enum.KeyCode.F, Mode = "Press", Callback = function(active) end })
    Section:ColorPicker({ Name = "Color", Flag = "Color", Default = Color3.fromRGB(88, 86, 238), Callback = function(c) end })
    Section:Textbox({ Name = "Textbox", Flag = "Textbox", Default = "", Placeholder = "Type...", Callback = function(text) end })
    Section:Button({ Name = "Button", ButtonText = "Run", Variant = "Primary", Callback = function() end })
    Section:Checkbox({ Name = "Checkbox", Default = true, Callback = function(v) end })
    Section:Numberbox({ Name = "Amount", Min = 0, Max = 100, Default = 10 })
    Section:RangeSlider({ Name = "Range", Min = 0, Max = 100, Default = {20, 80} })
    Section:SearchDropdown({ Name = "Search", Options = {"A", "B"} })
    Section:ProgressBar({ Name = "Progress", Default = 40 })
    Section:TextArea({ Name = "Notes", Default = "" })
    Section:Paragraph({ Title = "Info", Content = "Description" })
    Section:Badge({ Text = "Ready" })
    Section:KeyValue({ Name = "Version", Value = "1.2.0" })
    Section:Image({ Image = "rbxassetid://0", Height = 90 })
    Section:Label("Plain label text")
    Section:Divider()

    Window:Minimize() / Window:Restore()
    Window:Dialog({ Title = "Confirm", Content = "Continue?", OnConfirm = function() end })
    Window:SetTransparency(0.1) / Window:SetDraggable(false)
    Window:SetAnimationSpeed(1.25) / Window:SetSnapToEdge(true)
    Window:LoadPreset("Wide") / Window:SavePreset("MyLayout")
    local Card = Section:Card({ Name = "Advanced" })
    Card:Toggle({ Name = "Nested toggle" })

    Library:Notify({ Title = "Title", Content = "Content", Icon = "✓", ActionText = "Open", OnAction = function() end, Duration = 4 }) -- Duration = 0 keeps it open
    Library.MaxNotifications = 6        -- oldest toast is dismissed past this many

    Library.Flags.Toggle            -- current value of any flagged element
    Library.Options.Toggle:SetValue(true)
    Library:SaveConfig("default") / Library:LoadConfig("default")
    Library:SetTheme({ Accent = Color3.fromRGB(255, 80, 120) })
    -- v1.4: pastel prism themes, frosted glass, density, tab badges / locks
    Library:SetPreset("Ocean")           -- Prism | Midnight | Amoled | Rose | Ocean | Mocha | Nord | Light (colours tween)
    Library:SetAccent(Color3.fromRGB(255, 160, 200))   -- re-tints the whole prism around one colour
    Library:SetDensity("Compact")        -- "Comfortable" | "Compact"
    Window:SetGlass(true, 0.6)           -- translucent window + blurred scene behind it
    Window:Tab({ Name = "Main", Icon = "home", Badge = 3, Locked = false })  -- Icon names: home, bolt, eye, shield, target,
                                                                              -- sliders, user, bell, sparkle, code, globe, key, lock ...
    Tab:SetBadge(true | 5 | nil) / Tab:SetLocked(true)
    Section:ColorPicker({ Name = "Tint", Alpha = true, Callback = function(color, alpha) end })
    Library:Unload()
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

------------------------------------------------------------------------
-- Library root
------------------------------------------------------------------------
local Library = {
    Version = "1.4.1",
    MaxNotifications = 6,
    Animations = true,
    AnimationSpeed = 1,
    Density = "Comfortable", -- "Comfortable" | "Compact"
    _gradients = setmetatable({}, { __mode = "k" }),
    Flags = {},
    Options = {},
    Windows = {},
    IconSet = {},
    ConfigFolder = "PrismUI",
    Theme = {},
    Prism = {},
    Presets = {},
    PresetOrder = {},
    PresetName = "Prism",
    _notifCount = 0,
    _refreshers = {},
    _rows = setmetatable({}, { __mode = "k" }),
    _active = true,
}

------------------------------------------------------------------------
-- Design tokens
------------------------------------------------------------------------
local R = { Window = 16, Card = 12, Control = 10, Chip = 8 } -- corner radii
local S = { XS = 4, SM = 8, MD = 12, LG = 16, XL = 24 }       -- 4px spacing scale

------------------------------------------------------------------------
-- Theme presets (pastel prism by default)
------------------------------------------------------------------------
local function rgb(r, g, b)
    return Color3.fromRGB(r, g, b)
end

local function addPreset(name, theme, prism)
    Library.Presets[name] = { Theme = theme, Prism = prism }
    table.insert(Library.PresetOrder, name)
end

local PRISM_DARK = {
    Background = rgb(15, 14, 25), Panel = rgb(22, 21, 35), Row = rgb(31, 29, 48), RowHover = rgb(42, 39, 64),
    Stroke = rgb(56, 52, 82), Accent = rgb(198, 172, 255), Accent2 = rgb(150, 214, 255), Accent3 = rgb(255, 170, 214),
    Text = rgb(247, 244, 255), SubText = rgb(176, 170, 202), Dim = rgb(120, 114, 150),
    Off = rgb(60, 56, 86), Track = rgb(43, 40, 64),
    Success = rgb(150, 236, 200), Warning = rgb(255, 214, 152), Danger = rgb(255, 140, 168),
    OnAccent = rgb(26, 21, 46), Shadow = rgb(4, 3, 12), Highlight = rgb(255, 255, 255),
}

local function derive(over)
    local t = table.clone(PRISM_DARK)
    for k, v in pairs(over) do
        t[k] = v
    end
    return t
end

local PASTEL = {
    rgb(255, 172, 214), rgb(255, 204, 168), rgb(255, 240, 176),
    rgb(170, 240, 210), rgb(156, 214, 255), rgb(200, 178, 255),
}

addPreset("Prism", derive({}), PASTEL)
addPreset("Midnight", derive({
    Background = rgb(9, 12, 24), Panel = rgb(14, 19, 36), Row = rgb(21, 28, 50), RowHover = rgb(30, 40, 68),
    Stroke = rgb(40, 52, 88), Accent = rgb(132, 166, 255), Accent2 = rgb(120, 220, 255), Accent3 = rgb(176, 150, 255),
    Text = rgb(236, 242, 255), SubText = rgb(150, 166, 200), Dim = rgb(100, 114, 150),
    Off = rgb(40, 52, 86), Track = rgb(28, 38, 64), OnAccent = rgb(10, 16, 36), Shadow = rgb(2, 4, 12),
}), { rgb(132, 166, 255), rgb(120, 220, 255), rgb(160, 240, 235), rgb(176, 150, 255), rgb(110, 190, 255), rgb(150, 170, 255) })
addPreset("Amoled", derive({
    Background = rgb(0, 0, 0), Panel = rgb(9, 9, 11), Row = rgb(18, 18, 22), RowHover = rgb(28, 28, 34),
    Stroke = rgb(40, 40, 48), Accent = rgb(206, 196, 255), Accent2 = rgb(170, 226, 255), Accent3 = rgb(255, 190, 225),
    Text = rgb(250, 250, 252), SubText = rgb(160, 160, 176), Dim = rgb(104, 104, 120),
    Off = rgb(46, 46, 56), Track = rgb(30, 30, 38), OnAccent = rgb(12, 10, 20), Shadow = rgb(0, 0, 0),
}), PASTEL)
addPreset("Rose", derive({
    Background = rgb(23, 12, 18), Panel = rgb(32, 18, 26), Row = rgb(44, 26, 37), RowHover = rgb(60, 36, 50),
    Stroke = rgb(80, 50, 66), Accent = rgb(255, 160, 196), Accent2 = rgb(255, 200, 170), Accent3 = rgb(232, 160, 255),
    Text = rgb(255, 240, 246), SubText = rgb(200, 166, 182), Dim = rgb(146, 112, 128),
    Off = rgb(84, 52, 68), Track = rgb(58, 34, 47), OnAccent = rgb(44, 14, 28), Shadow = rgb(12, 2, 6),
}), { rgb(255, 160, 196), rgb(255, 190, 170), rgb(255, 220, 180), rgb(238, 170, 255), rgb(255, 150, 170), rgb(255, 200, 226) })
addPreset("Ocean", derive({
    Background = rgb(7, 19, 27), Panel = rgb(11, 28, 40), Row = rgb(16, 40, 56), RowHover = rgb(23, 56, 76),
    Stroke = rgb(34, 72, 94), Accent = rgb(120, 222, 240), Accent2 = rgb(150, 200, 255), Accent3 = rgb(160, 240, 210),
    Text = rgb(232, 250, 255), SubText = rgb(140, 184, 200), Dim = rgb(90, 132, 150),
    Off = rgb(30, 66, 88), Track = rgb(20, 48, 66), OnAccent = rgb(6, 28, 38), Shadow = rgb(1, 6, 10),
}), { rgb(120, 222, 240), rgb(150, 200, 255), rgb(160, 240, 210), rgb(190, 230, 255), rgb(110, 200, 220), rgb(180, 220, 250) })
addPreset("Mocha", derive({
    Background = rgb(24, 19, 17), Panel = rgb(33, 27, 24), Row = rgb(45, 37, 33), RowHover = rgb(60, 50, 44),
    Stroke = rgb(78, 66, 58), Accent = rgb(236, 190, 146), Accent2 = rgb(214, 170, 200), Accent3 = rgb(186, 216, 168),
    Text = rgb(250, 240, 230), SubText = rgb(190, 172, 158), Dim = rgb(136, 120, 108),
    Off = rgb(80, 68, 60), Track = rgb(56, 47, 42), OnAccent = rgb(40, 26, 16), Shadow = rgb(8, 4, 2),
}), { rgb(236, 190, 146), rgb(244, 208, 170), rgb(214, 170, 200), rgb(186, 216, 168), rgb(250, 226, 176), rgb(230, 180, 160) })
addPreset("Nord", derive({
    Background = rgb(36, 41, 51), Panel = rgb(46, 52, 64), Row = rgb(59, 66, 82), RowHover = rgb(67, 76, 94),
    Stroke = rgb(78, 88, 108), Accent = rgb(136, 192, 208), Accent2 = rgb(129, 161, 193), Accent3 = rgb(180, 142, 173),
    Text = rgb(236, 239, 244), SubText = rgb(190, 198, 212), Dim = rgb(136, 146, 164),
    Off = rgb(76, 86, 106), Track = rgb(59, 66, 82),
    Success = rgb(163, 190, 140), Warning = rgb(235, 203, 139), Danger = rgb(214, 120, 130),
    OnAccent = rgb(30, 36, 46), Shadow = rgb(14, 17, 24),
}), { rgb(143, 188, 187), rgb(136, 192, 208), rgb(129, 161, 193), rgb(180, 142, 173), rgb(163, 190, 140), rgb(235, 203, 139) })
addPreset("Light", derive({
    Background = rgb(243, 242, 250), Panel = rgb(252, 251, 255), Row = rgb(236, 233, 247), RowHover = rgb(226, 222, 242),
    Stroke = rgb(214, 210, 234), Accent = rgb(150, 118, 246), Accent2 = rgb(90, 170, 240), Accent3 = rgb(232, 110, 170),
    Text = rgb(34, 30, 52), SubText = rgb(98, 92, 124), Dim = rgb(140, 134, 164),
    Off = rgb(204, 200, 226), Track = rgb(222, 218, 238),
    Success = rgb(52, 176, 126), Warning = rgb(226, 150, 40), Danger = rgb(228, 80, 112),
    OnAccent = rgb(255, 255, 255), Shadow = rgb(70, 60, 120),
}), { rgb(255, 150, 200), rgb(255, 190, 140), rgb(240, 214, 120), rgb(130, 220, 180), rgb(120, 190, 250), rgb(180, 150, 250) })

Library.Theme = table.clone(Library.Presets.Prism.Theme)
Library.Prism = table.clone(PASTEL)

-- Inter for text and Roboto Mono for values / keybinds (both ship with Roblox).
local INTER = "rbxasset://fonts/families/Inter.json"
local MONO = "rbxasset://fonts/families/RobotoMono.json"
local FONT = {
    Regular = Font.new(INTER, Enum.FontWeight.Regular),
    Medium = Font.new(INTER, Enum.FontWeight.Medium),
    Semi = Font.new(INTER, Enum.FontWeight.SemiBold),
    Bold = Font.new(INTER, Enum.FontWeight.Bold),
    Mono = Font.new(MONO, Enum.FontWeight.Medium),
    MonoBold = Font.new(MONO, Enum.FontWeight.Bold),
}

local AS_X = Enum.AutomaticSize.X
local AS_Y = Enum.AutomaticSize.Y
local AS_XY = Enum.AutomaticSize.XY
local LEFT = Enum.TextXAlignment.Left
local RIGHT = Enum.TextXAlignment.Right
local HORIZ = Enum.FillDirection.Horizontal
local VERT = Enum.FillDirection.Vertical

------------------------------------------------------------------------
-- Tween helpers
------------------------------------------------------------------------
local EASE_FAST = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local EASE_MED = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local EASE_SLOW = TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local EASE_SPRING = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out) -- overshoots, then settles
local EASE_POP = TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local EASE_SLIDE = TweenInfo.new(0.46, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local EASE_COLLAPSE = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, 0.06)

local channels = setmetatable({}, { __mode = "k" })
local scaledInfos = {}

-- TweenInfo is immutable, so cache the speed-scaled copies instead of
-- allocating a fresh one on every hover / state change.
local function scaledInfo(info, speed)
    local bySpeed = scaledInfos[info]
    if not bySpeed then
        bySpeed = {}
        scaledInfos[info] = bySpeed
    end
    local scaled = bySpeed[speed]
    if not scaled then
        scaled = TweenInfo.new(info.Time / speed, info.EasingStyle, info.EasingDirection, info.RepeatCount, info.Reverses, info.DelayTime / speed)
        bySpeed[speed] = scaled
    end
    return scaled
end

-- Several properties of one instance can animate on independent channels
-- (e.g. a knob's position and its stretch) without cancelling each other.
local function playOn(inst, channel, info, props)
    local set = channels[inst]
    if not set then
        set = {}
        channels[inst] = set
    end
    local prev = set[channel]
    if prev then
        prev:Cancel()
        set[channel] = nil
    end
    if Library.Animations == false then
        for key, value in pairs(props) do
            inst[key] = value
        end
        return nil
    end
    local speed = math.clamp(tonumber(Library.AnimationSpeed) or 1, 0.05, 5)
    if speed ~= 1 then
        info = scaledInfo(info, math.floor(speed * 100 + 0.5) / 100)
    end
    local tween = TweenService:Create(inst, info, props)
    set[channel] = tween
    tween.Completed:Once(function()
        if set[channel] == tween then
            set[channel] = nil
        end
    end)
    tween:Play()
    return tween
end

local function play(inst, info, props)
    return playOn(inst, "main", info, props)
end

local function apply(inst, props, animate, info)
    if animate then
        return play(inst, info or EASE_MED, props)
    end
    local set = channels[inst]
    if set and set.main then
        set.main:Cancel()
        set.main = nil
    end
    for k, v in pairs(props) do
        inst[k] = v
    end
end

------------------------------------------------------------------------
-- Signal / Maid
------------------------------------------------------------------------
local Signal = {}
Signal.__index = Signal

function Signal.new()
    return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn)
    local handler = { fn = fn }
    table.insert(self._handlers, handler)
    return {
        Disconnect = function()
            local i = table.find(self._handlers, handler)
            if i then
                table.remove(self._handlers, i)
            end
        end,
    }
end

function Signal:Fire(...)
    for _, handler in ipairs(table.clone(self._handlers)) do
        task.spawn(handler.fn, ...)
    end
end

local Maid = {}
Maid.__index = Maid

function Maid.new()
    return setmetatable({ _tasks = {} }, Maid)
end

function Maid:Give(item)
    table.insert(self._tasks, item)
    return item
end

function Maid:Clean()
    for _, item in ipairs(self._tasks) do
        local kind = typeof(item)
        if kind == "RBXScriptConnection" then
            item:Disconnect()
        elseif kind == "Instance" then
            item:Destroy()
        elseif kind == "function" then
            pcall(item)
        elseif kind == "table" and item.Disconnect then
            item.Disconnect()
        end
    end
    table.clear(self._tasks)
end

------------------------------------------------------------------------
-- Theme binding + instance factory
------------------------------------------------------------------------
local themed = setmetatable({}, { __mode = "k" })

local function bindTheme(inst, map)
    local entry = themed[inst]
    if not entry then
        entry = {}
        themed[inst] = entry
    end
    for prop, key in pairs(map) do
        entry[prop] = key
        inst[prop] = Library.Theme[key]
    end
end

local function applyThemeEntry(inst, entry)
    local theme = Library.Theme
    for prop, key in pairs(entry) do
        inst[prop] = theme[key]
    end
end

------------------------------------------------------------------------
-- Prism flow: every gradient in the UI is driven by one shared driver, so
-- the pastel colours drift in sync and cost a single update per tick.
------------------------------------------------------------------------
local Flow = { phase = 0, speed = 0.045, acc = 0, items = setmetatable({}, { __mode = "k" }) }

local function palColor(t)
    local pal = Library.Prism
    local n = #pal
    t = t % 1
    local x = t * n
    local i = math.floor(x)
    local f = x - i
    f = f * f * (3 - 2 * f)
    return pal[i % n + 1]:Lerp(pal[(i + 1) % n + 1], f)
end

local function flowSequence(shift, periods)
    local keys = table.create(13)
    local base = Flow.phase + shift
    for i = 0, 12 do
        keys[i + 1] = ColorSequenceKeypoint.new(i / 12, palColor(base + (i / 12) * periods))
    end
    return ColorSequence.new(keys)
end

function Flow.refresh()
    local cache = {}
    for gradient, cfg in pairs(Flow.items) do
        if gradient.Parent then
            if gradient.Enabled and (not cfg.scope or cfg.scope.Visible) then
                local seq = cache[cfg.key]
                if not seq then
                    seq = flowSequence(cfg.shift, cfg.periods)
                    cache[cfg.key] = seq
                end
                gradient.Color = seq
            end
        else
            Flow.items[gradient] = nil
        end
    end
end

local function ensureFlow()
    if Flow.conn then
        return
    end
    Flow.conn = RunService.Heartbeat:Connect(function(dt)
        if Library.Animations == false or not Library._active then
            return
        end
        Flow.acc = Flow.acc + dt
        if Flow.acc < 1 / 30 then
            return
        end
        local step = Flow.acc
        Flow.acc = 0
        Flow.phase = (Flow.phase + step * Flow.speed * math.clamp(tonumber(Library.AnimationSpeed) or 1, 0.1, 5)) % 1
        Flow.refresh()
    end)
end

function Library:_refreshFlow()
    Flow.refresh()
end

function Library:_updateActive()
    local any = false
    for _, w in ipairs(self.Windows) do
        if w.Visible then
            any = true
            break
        end
    end
    self._active = any
end

function Library:_flushTheme()
    self._themePending = false
    for inst, entry in pairs(themed) do
        pcall(applyThemeEntry, inst, entry)
    end
    Flow.refresh()
    for _, refresh in pairs(self._refreshers) do
        pcall(refresh)
    end
end

-- Theme changes are applied once per frame, so dragging a colour picker or
-- slider that calls SetTheme every input event doesn't re-skin the whole
-- UI several times per frame.
function Library:SetTheme(overrides)
    for key, value in pairs(overrides) do
        self.Theme[key] = value
    end
    if self._themePending then
        return
    end
    self._themePending = true
    RunService.Heartbeat:Once(function()
        self:_flushTheme()
    end)
end

-- Colours glide to the new theme instead of snapping.
function Library:TweenTheme(targetTheme, targetPrism, duration)
    self._themeToken = (self._themeToken or 0) + 1
    local token = self._themeToken
    local fromTheme = table.clone(self.Theme)
    local fromPrism = table.clone(self.Prism)
    targetPrism = targetPrism or self.Prism
    duration = duration or 0.55
    if duration <= 0 or self.Animations == false then
        for k, v in pairs(targetTheme) do
            self.Theme[k] = v
        end
        for i, c in ipairs(targetPrism) do
            self.Prism[i] = c
        end
        self:_flushTheme()
        return
    end
    local startTime = os.clock()
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if self._themeToken ~= token then
            conn:Disconnect()
            return
        end
        local a = math.clamp((os.clock() - startTime) / duration, 0, 1)
        local e = 1 - (1 - a) ^ 3
        for k, v in pairs(targetTheme) do
            self.Theme[k] = (fromTheme[k] or v):Lerp(v, e)
        end
        for i, c in ipairs(targetPrism) do
            self.Prism[i] = (fromPrism[i] or c):Lerp(c, e)
        end
        self:_flushTheme()
        if a >= 1 then
            conn:Disconnect()
        end
    end)
end

function Library:SetPreset(name, instant)
    local preset = self.Presets[name]
    if not preset then
        return false
    end
    self.PresetName = name
    self:TweenTheme(preset.Theme, preset.Prism, instant and 0 or 0.55)
    return true
end

function Library:GetPresets()
    return table.clone(self.PresetOrder)
end

function Library:AddPreset(name, theme, prism)
    local merged = table.clone(PRISM_DARK)
    for k, v in pairs(theme or {}) do
        merged[k] = v
    end
    if not self.Presets[name] then
        table.insert(self.PresetOrder, name)
    end
    self.Presets[name] = { Theme = merged, Prism = prism or table.clone(PASTEL) }
end

-- Pick one accent and get a matching pastel prism around it.
function Library:SetAccent(color)
    local h, s = color:ToHSV()
    local pal = {}
    for i, dh in ipairs({ 0, 0.06, 0.12, -0.06, -0.12, 0.18 }) do
        pal[i] = Color3.fromHSV((h + dh) % 1, math.clamp(s * 0.85, 0.22, 0.62), 1)
    end
    self.Theme.Accent = color
    self.Theme.Accent2 = pal[3]
    self.Theme.Accent3 = pal[5]
    for i = 1, 6 do
        self.Prism[i] = pal[i]
    end
    self:SetTheme({})
end

local TEXT_CLASSES = { TextLabel = true, TextButton = true, TextBox = true }

local function new(class, props, children)
    props = props or {}
    local inst = Instance.new(class)
    local map = {}

    if inst:IsA("GuiObject") then
        inst.BorderSizePixel = 0
        if TEXT_CLASSES[class] then
            inst.BackgroundTransparency = 1
            inst.FontFace = FONT.Medium
            inst.TextSize = 13
            map.TextColor3 = "Text"
        elseif class == "ImageLabel" or class == "ImageButton" then
            inst.BackgroundTransparency = 1
        end
        if class == "TextButton" or class == "ImageButton" then
            inst.AutoButtonColor = false
        end
        if class == "TextBox" then
            inst.ClearTextOnFocus = false
        end
    end

    if props.Theme then
        for k, v in pairs(props.Theme) do
            map[k] = v
        end
    end
    if next(map) then
        bindTheme(inst, map)
    end

    for k, v in pairs(props) do
        if k ~= "Theme" and k ~= "Parent" then
            if k == "Font" and typeof(v) == "Font" then
                inst.FontFace = v
            else
                inst[k] = v
            end
            if map[k] and not (props.Theme and props.Theme[k]) then
                themed[inst][k] = nil
            end
        end
    end

    if children then
        for _, child in ipairs(children) do
            child.Parent = inst
        end
    end
    if props.Parent then
        inst.Parent = props.Parent
    end
    return inst
end

local function corner(parent, radius)
    return new("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

local function stroke(parent, key, thickness, transparency)
    return new("UIStroke", {
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Theme = { Color = key or "Stroke" },
        Parent = parent,
    })
end

local function pad(parent, l, t, r, b)
    return new("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0),
        PaddingTop = UDim.new(0, t or 0),
        PaddingRight = UDim.new(0, r or 0),
        PaddingBottom = UDim.new(0, b or 0),
        Parent = parent,
    })
end

local function list(parent, padding, direction, hAlign, vAlign)
    return new("UIListLayout", {
        Padding = UDim.new(0, padding or 0),
        FillDirection = direction or VERT,
        HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
        VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = parent,
    })
end

local function rowH()
    return Library.Density == "Compact" and 34 or 42
end

-- A flowing pastel-prism gradient. o: rotation, shift, periods, transparency, scope
local function flowGradient(parent, o)
    o = o or {}
    local gradient = Instance.new("UIGradient")
    gradient.Rotation = o.rotation or 0
    if o.transparency then
        gradient.Transparency = o.transparency
    end
    local shift, periods = o.shift or 0, o.periods or 1
    Flow.items[gradient] = { shift = shift, periods = periods, scope = o.scope, key = shift .. ":" .. periods }
    gradient.Color = flowSequence(shift, periods)
    gradient.Parent = parent
    Library._gradients[gradient] = true
    ensureFlow()
    return gradient
end

-- kept for API compatibility with earlier versions
local function animatedGradient(parent, maid, duration)
    local gradient = flowGradient(parent, { rotation = 0 })
    if maid then
        maid:Give(function()
            Flow.items[gradient] = nil
            Library._gradients[gradient] = nil
        end)
    end
    return gradient
end

local function seq(...)
    local keys = {}
    for _, p in ipairs({ ... }) do
        table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2]))
    end
    return NumberSequence.new(keys)
end

local EDGE_FADE = seq({ 0, 1 }, { 0.5, 0.86 }, { 1, 1 })
local STROKE_FADE = seq({ 0, 0 }, { 1, 0.72 })

-- 1px lighter line along the top edge: makes surfaces look slightly raised
local function highlight(parent, inset, alpha)
    local line = new("Frame", {
        Name = "Highlight", Position = UDim2.fromOffset(inset or 8, 1), Size = UDim2.new(1, -(inset or 8) * 2, 0, 1),
        Theme = { BackgroundColor3 = "Highlight" }, Parent = parent,
    })
    local a = alpha or 0.86
    new("UIGradient", { Transparency = seq({ 0, 1 }, { 0.5, a }, { 1, 1 }), Parent = line })
    return line
end

-- stroke that fades from bright to transparent
local function strokeFade(st, rotation, from, to)
    new("UIGradient", {
        Rotation = rotation or 90,
        Transparency = seq({ 0, from or 0.05 }, { 1, to or 0.78 }),
        Parent = st,
    })
end

-- soft layered shadow / glow that follows a target. opts:
--   Parent, Layers, Spread, OffsetY, Strength, Radius, ColorKey, Abs (mirror absolute rect),
--   Scale (fn -> ui scale, for Abs), MirrorScale (UIScale to copy)
local function halo(target, o)
    o = o or {}
    local parent = o.Parent or target.Parent
    local layers = o.Layers or 6
    local spread = o.Spread or 18
    local offY = o.OffsetY or 0
    local radius = o.Radius or R.Card
    local strength = o.Strength or 0.5
    local per = 1 - (1 - strength) ^ (1 / layers)
    local baseT = 1 - per
    local holder = new("Frame", {
        Name = o.Name or "Shadow", BackgroundTransparency = 1, Visible = target.Visible,
        ZIndex = o.ZIndex or (target.ZIndex - 1), Parent = parent,
    })
    local scaleObj
    if o.MirrorScale then
        scaleObj = new("UIScale", { Scale = o.MirrorScale.Scale, Parent = holder })
    end
    local parts = {}
    for i = 1, layers do
        local g = spread * i / layers
        local f = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1, g * 2, 1, g * 2), BackgroundTransparency = baseT,
            Theme = { BackgroundColor3 = o.ColorKey or "Shadow" }, Parent = holder,
        })
        corner(f, radius + g)
        parts[i] = f
    end

    local function sync()
        if not target.Parent or not holder.Parent then
            return
        end
        if o.Abs then
            local s = math.max(o.Scale and o.Scale() or 1, 0.01)
            local size = target.AbsoluteSize / s
            local p = (target.AbsolutePosition - parent.AbsolutePosition) / s
            holder.AnchorPoint = Vector2.new(0, 0)
            holder.Position = UDim2.fromOffset(p.X, p.Y + offY)
            holder.Size = UDim2.fromOffset(size.X, size.Y)
            holder.Visible = target.Visible and size.Y > 2
        else
            local p = target.Position
            holder.AnchorPoint = target.AnchorPoint
            holder.Position = UDim2.new(p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset + offY)
            holder.Size = target.Size
            holder.Visible = target.Visible and target.AbsoluteSize.Y > 4
        end
    end

    local conns = {}
    local watch = o.Abs and { "AbsoluteSize", "AbsolutePosition", "Visible" }
        or { "Position", "Size", "AnchorPoint", "Visible", "AbsoluteSize" }
    for _, prop in ipairs(watch) do
        table.insert(conns, target:GetPropertyChangedSignal(prop):Connect(sync))
    end
    if scaleObj then
        table.insert(conns, o.MirrorScale:GetPropertyChangedSignal("Scale"):Connect(function()
            scaleObj.Scale = o.MirrorScale.Scale
        end))
    end
    local obj = { Frame = holder }
    function obj.SetFade(t, animate) -- 0 = fully visible, 1 = hidden
        for _, f in ipairs(parts) do
            apply(f, { BackgroundTransparency = baseT + (1 - baseT) * t }, animate, EASE_MED)
        end
    end
    function obj.Destroy()
        for _, c in ipairs(conns) do
            c:Disconnect()
        end
        if holder.Parent then
            holder:Destroy()
        end
    end
    table.insert(conns, target.Destroying:Connect(obj.Destroy))
    sync()
    return obj
end

-- glow that lives *inside* a transparent container, behind its siblings
local function glow(parent, o)
    o = o or {}
    local layers = o.Layers or 5
    local spread = o.Spread or 8
    local per = 1 - (1 - (o.Strength or 0.45)) ^ (1 / layers)
    local holder = new("Frame", {
        Name = "Glow", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = o.ZIndex or 1, Parent = parent,
    })
    local parts = {}
    for i = 1, layers do
        local g = spread * i / layers
        local f = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1, g * 2, 1, g * 2), BackgroundTransparency = 1,
            Theme = { BackgroundColor3 = o.ColorKey or "Accent" }, Parent = holder,
        })
        corner(f, (o.Radius or R.Control) + g)
        parts[i] = f
    end
    local obj = { Frame = holder }
    function obj.SetAlpha(a, animate)
        for _, f in ipairs(parts) do
            apply(f, { BackgroundTransparency = 1 - per * a }, animate, EASE_MED)
        end
    end
    obj.SetAlpha(o.Alpha or 0, false)
    return obj
end

-- Section titles: small caps with a touch of letter spacing
local function spaced(text)
    local ok, out = pcall(function()
        local chars = {}
        for _, code in utf8.codes(tostring(text):upper()) do
            table.insert(chars, utf8.char(code))
        end
        return table.concat(chars, "\u{200A}")
    end)
    return ok and out or tostring(text):upper()
end

-- thin auto-fading scrollbar that tints to the accent on hover
local function smartScroll(sf, maid)
    sf.ScrollBarThickness = 3
    sf.ScrollBarImageTransparency = 1
    sf.ScrollBarImageColor3 = Library.Theme.Dim
    bindTheme(sf, { ScrollBarImageColor3 = "Dim" })
    local token = 0
    local function wake()
        token = token + 1
        local mine = token
        play(sf, EASE_FAST, { ScrollBarImageTransparency = 0.35 })
        task.delay(0.9, function()
            if mine == token and sf.Parent then
                play(sf, EASE_SLOW, { ScrollBarImageTransparency = 1 })
            end
        end)
    end
    local conns = {
        sf:GetPropertyChangedSignal("CanvasPosition"):Connect(wake),
        sf.MouseEnter:Connect(function()
            bindTheme(sf, { ScrollBarImageColor3 = "Accent" })
            wake()
        end),
        sf.MouseLeave:Connect(function()
            bindTheme(sf, { ScrollBarImageColor3 = "Dim" })
        end),
    }
    if maid then
        for _, c in ipairs(conns) do
            maid:Give(c)
        end
    end
end

------------------------------------------------------------------------
-- Misc helpers
------------------------------------------------------------------------
local function isPress(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
end

local function roundTo(n, inc)
    return math.floor(n / inc + 0.5) * inc
end

local function decimals(n)
    local s = (string.format("%.10f", n):gsub("0+$", ""))
    local d = s:match("%.(%d*)$")
    return d and #d or 0
end

local function randomName()
    return HttpService:GenerateGUID(false):gsub("-", ""):sub(1, 14)
end

local function getGuiParent()
    local ok, hui = pcall(function()
        return gethui and gethui()
    end)
    if ok and hui then
        return hui
    end
    local okCore = pcall(function()
        return CoreGui.Name
    end)
    if okCore then
        return CoreGui
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local KEY_NAMES = {
    LeftShift = "LShift", RightShift = "RShift", LeftControl = "LCtrl", RightControl = "RCtrl",
    LeftAlt = "LAlt", RightAlt = "RAlt", Return = "Enter", Backspace = "Bksp", Escape = "Esc",
    MouseButton1 = "M1", MouseButton2 = "M2", MouseButton3 = "M3",
}

local function keyName(key)
    if not key then
        return "--"
    end
    if typeof(key) == "EnumItem" then
        return KEY_NAMES[key.Name] or key.Name
    end
    return tostring(key)
end

local function safeCall(fn, ...)
    if not fn then
        return
    end
    local args = table.pack(...)
    task.spawn(function()
        local ok, err = pcall(fn, table.unpack(args, 1, args.n))
        if not ok then
            warn("[PrismUI] callback error: " .. tostring(err))
        end
    end)
end

-- serialization (config files)
local function encode(v)
    local kind = typeof(v)
    if kind == "Color3" then
        return { __c = { v.R, v.G, v.B } }
    elseif kind == "EnumItem" then
        return { __e = tostring(v) }
    elseif kind == "table" then
        -- Preserve dense 1-based arrays as arrays. JSON object keys are strings,
        -- so stringifying numeric keys here used to turn { low, high } into
        -- { ["1"] = low, ["2"] = high } and broke controls such as RangeSlider.
        local count, highest, isArray = 0, 0, true
        for k in pairs(v) do
            if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then
                isArray = false
                break
            end
            count = count + 1
            highest = math.max(highest, k)
        end
        if isArray and count > 0 and highest == count then
            local out = table.create(count)
            for i = 1, highest do
                out[i] = encode(v[i])
            end
            return out
        end

        local out = {}
        for k, x in pairs(v) do
            out[tostring(k)] = encode(x)
        end
        return out
    end
    return v
end

local function decode(v)
    if type(v) == "table" then
        if v.__c then
            return Color3.new(v.__c[1], v.__c[2], v.__c[3])
        end
        if v.__e then
            local parts = string.split(v.__e, ".")
            local ok, result = pcall(function()
                return Enum[parts[2]][parts[3]]
            end)
            return ok and result or nil
        end
        local out = {}
        for k, x in pairs(v) do
            out[k] = decode(x)
        end
        return out
    end
    return v
end

local function canFile()
    return typeof(writefile) == "function" and typeof(readfile) == "function"
        and typeof(isfolder) == "function" and typeof(makefolder) == "function"
end

------------------------------------------------------------------------
-- Drawn icons (no external assets needed)
------------------------------------------------------------------------
local Icons = {}
local ICON_DEFS = {}

local function def(name, fn)
    ICON_DEFS[name] = fn
end

-- Lucide-style stroke icons, drawn on a 24x24 grid from rounded pills and
-- rings (so caps are round and edges stay smooth at any scale).
def("check", function(d) d.pl({ { 5, 12.5 }, { 10, 17.5 }, { 19, 7 } }) end)
def("x", function(d) d.line(6, 6, 18, 18) d.line(18, 6, 6, 18) end)
def("plus", function(d) d.line(12, 5, 12, 19) d.line(5, 12, 19, 12) end)
def("minus", function(d) d.line(5, 12, 19, 12) end)
def("chevdown", function(d) d.pl({ { 6, 9.5 }, { 12, 15.5 }, { 18, 9.5 } }) end)
def("chevup", function(d) d.pl({ { 6, 14.5 }, { 12, 8.5 }, { 18, 14.5 } }) end)
def("chevright", function(d) d.pl({ { 9.5, 6 }, { 15.5, 12 }, { 9.5, 18 } }) end)
def("chevleft", function(d) d.pl({ { 14.5, 6 }, { 8.5, 12 }, { 14.5, 18 } }) end)
def("search", function(d) d.ring(10.5, 10.5, 6.5) d.line(15.5, 15.5, 20, 20) end)
def("grid", function(d)
    d.rect(4, 4, 6.5, 6.5, 1.8) d.rect(13.5, 4, 6.5, 6.5, 1.8)
    d.rect(4, 13.5, 6.5, 6.5, 1.8) d.rect(13.5, 13.5, 6.5, 6.5, 1.8)
end)
def("columns", function(d) d.rect(3.5, 4.5, 17, 15, 3.2) d.line(12, 5, 12, 19) end)
def("restore", function(d) d.rect(6, 6, 12, 12, 3) end)
def("lock", function(d)
    d.rect(5, 11, 14, 9.5, 2.8)
    d.pl({ { 8.5, 11 }, { 8.5, 8.2 }, { 9.4, 5.9 }, { 12, 4.8 }, { 14.6, 5.9 }, { 15.5, 8.2 }, { 15.5, 11 } })
end)
def("info", function(d) d.ring(12, 12, 9) d.line(12, 11, 12, 16.5) d.dot(12, 7.8, 1.2) end)
def("alert", function(d) d.ring(12, 12, 9) d.line(12, 7, 12, 12.6) d.dot(12, 16.4, 1.2) end)
def("user", function(d)
    d.ring(12, 8, 4)
    d.pl({ { 4.5, 20 }, { 5.3, 17 }, { 8, 14.6 }, { 12, 14.2 }, { 16, 14.6 }, { 18.7, 17 }, { 19.5, 20 } })
end)
def("home", function(d)
    d.pl({ { 3.5, 11 }, { 12, 3.8 }, { 20.5, 11 } })
    d.pl({ { 5.5, 9.6 }, { 5.5, 20 }, { 18.5, 20 }, { 18.5, 9.6 } })
    d.pl({ { 9.6, 20 }, { 9.6, 14 }, { 14.4, 14 }, { 14.4, 20 } })
end)
def("bolt", function(d)
    d.pl({ { 13, 3 }, { 5, 13.5 }, { 11.5, 13.5 }, { 10.5, 21 }, { 19, 10 }, { 12.5, 10 }, { 13, 3 } })
end)
def("eye", function(d) d.rect(2.5, 6.5, 19, 11, 5.5) d.dot(12, 12, 2.7) end)
def("shield", function(d)
    d.pl({ { 12, 3 }, { 19.5, 6 }, { 19.5, 12 }, { 17, 17 }, { 12, 21 }, { 7, 17 }, { 4.5, 12 }, { 4.5, 6 }, { 12, 3 } })
end)
def("target", function(d) d.ring(12, 12, 9) d.ring(12, 12, 5) d.dot(12, 12, 1.3) end)
def("crosshair", function(d)
    d.ring(12, 12, 6.5) d.line(12, 2.5, 12, 6) d.line(12, 18, 12, 21.5) d.line(2.5, 12, 6, 12) d.line(18, 12, 21.5, 12)
end)
def("sliders", function(d)
    d.line(4, 7, 20, 7) d.line(4, 12, 20, 12) d.line(4, 17, 20, 17)
    d.dot(9, 7, 2.3) d.dot(15, 12, 2.3) d.dot(8, 17, 2.3)
end)
def("bell", function(d)
    d.pl({ { 5.5, 17 }, { 7, 15.4 }, { 7, 10.5 }, { 9, 6.6 }, { 12, 5.4 }, { 15, 6.6 }, { 17, 10.5 }, { 17, 15.4 }, { 18.5, 17 }, { 5.5, 17 } })
    d.line(10, 20.4, 14, 20.4)
end)
def("sparkle", function(d)
    d.pl({ { 12, 3 }, { 14, 10 }, { 21, 12 }, { 14, 14 }, { 12, 21 }, { 10, 14 }, { 3, 12 }, { 10, 10 }, { 12, 3 } })
end)
def("code", function(d)
    d.pl({ { 8, 7 }, { 3, 12 }, { 8, 17 } }) d.pl({ { 16, 7 }, { 21, 12 }, { 16, 17 } }) d.line(13.6, 5, 10.4, 19)
end)
def("globe", function(d) d.ring(12, 12, 9) d.line(3, 12, 21, 12) d.rect(8, 3, 8, 18, 4) end)
def("key", function(d) d.ring(8, 15.5, 4) d.line(11, 12.5, 20, 3.5) d.line(17, 6.5, 19.5, 9) end)
def("dot", function(d) d.dot(12, 12, 4) end)

local function paintFrame(inst, color)
    if type(color) == "string" then
        bindTheme(inst, { BackgroundColor3 = color })
    else
        inst.BackgroundColor3 = color
    end
end

local function paintStroke(inst, color)
    if type(color) == "string" then
        bindTheme(inst, { Color = color })
    else
        inst.Color = color
    end
end

-- color: Theme key (stays themed) or Color3 (static, recolour with Icons.SetColor)
function Icons.Draw(parent, name, size, color, weight)
    local build = ICON_DEFS[name]
    if not build then
        return nil
    end
    size = size or 16
    color = color or "SubText"
    local k = size / 24
    local th = math.max(1.5, 2 * k * (weight or 1))
    local holder = new("Frame", {
        Name = "Icon_" .. name, BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), Parent = parent,
    })
    local d = {}
    function d.line(x1, y1, x2, y2)
        local dx, dy = (x2 - x1) * k, (y2 - y1) * k
        local f = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((x1 + x2) / 2 * k, (y1 + y2) / 2 * k),
            Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + th, th), Rotation = math.deg(math.atan2(dy, dx)),
            Parent = holder,
        })
        corner(f, th / 2)
        paintFrame(f, color)
    end
    function d.pl(points)
        for i = 1, #points - 1 do
            d.line(points[i][1], points[i][2], points[i + 1][1], points[i + 1][2])
        end
    end
    function d.dot(cx, cy, r)
        local dia = r * 2 * k
        local f = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx * k, cy * k),
            Size = UDim2.fromOffset(dia, dia), Parent = holder,
        })
        corner(f, dia / 2)
        paintFrame(f, color)
    end
    function d.ring(cx, cy, r)
        local dia = math.max(2, r * 2 * k - th)
        local f = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx * k, cy * k),
            Size = UDim2.fromOffset(dia, dia), BackgroundTransparency = 1, Parent = holder,
        })
        corner(f, dia / 2 + th)
        local s = new("UIStroke", { Thickness = th, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = f })
        paintStroke(s, color)
    end
    function d.rect(x, y, w, h, r)
        local wp, hp = math.max(2, w * k - th), math.max(2, h * k - th)
        local f = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((x + w / 2) * k, (y + h / 2) * k),
            Size = UDim2.fromOffset(wp, hp), BackgroundTransparency = 1, Parent = holder,
        })
        corner(f, math.max(0, (r or 2) * k))
        local s = new("UIStroke", { Thickness = th, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = f })
        paintStroke(s, color)
    end
    build(d)
    return holder
end

function Icons.Has(name)
    return ICON_DEFS[name] ~= nil
end

-- re-bind a drawn icon to another theme key (stays theme-safe), optionally easing the colour over
function Icons.Bind(holder, key, animate)
    local goal = Library.Theme[key]
    for _, piece in ipairs(holder:GetChildren()) do
        if piece:IsA("Frame") then
            local stroked = false
            for _, s in ipairs(piece:GetChildren()) do
                if s:IsA("UIStroke") then
                    stroked = true
                    local old = s.Color
                    bindTheme(s, { Color = key })
                    if animate then
                        s.Color = old
                        play(s, EASE_FAST, { Color = goal })
                    end
                end
            end
            if not stroked then
                local old = piece.BackgroundColor3
                bindTheme(piece, { BackgroundColor3 = key })
                if animate then
                    piece.BackgroundColor3 = old
                    play(piece, EASE_FAST, { BackgroundColor3 = goal })
                end
            end
        end
    end
end

-- recolour a drawn icon (unbinds it from the theme)
function Icons.SetColor(holder, color, animate)
    for _, piece in ipairs(holder:GetChildren()) do
        if piece:IsA("Frame") then
            themed[piece] = nil
            if piece.BackgroundTransparency < 1 or piece:GetAttribute("Solid") then
                apply(piece, { BackgroundColor3 = color }, animate, EASE_MED)
            end
            for _, s in ipairs(piece:GetChildren()) do
                if s:IsA("UIStroke") then
                    themed[s] = nil
                    apply(s, { Color = color }, animate, EASE_MED)
                end
            end
        end
    end
end

function Icons.SetAlpha(holder, alpha, animate)
    for _, piece in ipairs(holder:GetChildren()) do
        if piece:IsA("Frame") then
            local stroked = false
            for _, s in ipairs(piece:GetChildren()) do
                if s:IsA("UIStroke") then
                    stroked = true
                    apply(s, { Transparency = alpha }, animate, EASE_MED)
                end
            end
            if not stroked then
                apply(piece, { BackgroundTransparency = alpha }, animate, EASE_MED)
            end
        end
    end
end

-- compatibility wrappers (older call sites)
function Icons.Search(parent, key)
    return Icons.Draw(parent, "search", 14, key or "SubText")
end

function Icons.Chevron(parent, key)
    return Icons.Draw(parent, "chevdown", 14, key or "SubText")
end

function Icons.Close(parent, key)
    local holder = Icons.Draw(parent, "x", 14, key or "SubText")
    holder.AnchorPoint = Vector2.new(0.5, 0.5)
    holder.Position = UDim2.fromScale(0.5, 0.5)
    return holder
end

function Icons.Grid(parent, key)
    local holder = Icons.Draw(parent, "columns", 16, key or "SubText")
    holder.AnchorPoint = Vector2.new(0.5, 0.5)
    holder.Position = UDim2.fromScale(0.5, 0.5)
    return holder
end

function Icons.Check(parent)
    local holder = Icons.Draw(parent, "check", 12, "OnAccent", 1.2)
    holder.AnchorPoint = Vector2.new(0.5, 0.5)
    holder.Position = UDim2.fromScale(0.5, 0.5)
    return holder
end

function Icons.Info(parent)
    local btn = new("TextButton", { Name = "Info", Text = "", Size = UDim2.fromOffset(14, 14), Parent = parent })
    local icon = Icons.Draw(btn, "info", 14, "Dim", 0.85)
    icon.Position = UDim2.fromOffset(0, 0)
    btn.MouseEnter:Connect(function()
        Icons.Bind(icon, "Accent", true)
    end)
    btn.MouseLeave:Connect(function()
        Icons.Bind(icon, "Dim", true)
    end)
    return btn
end

-- The prism hexagon: three faceted pieces, each carrying its own slice of the flowing palette.
function Icons.Hex(parent, diameter, outerKey, innerKey)
    local holder = new("Frame", {
        Name = "Hex", BackgroundTransparency = 1, Size = UDim2.fromOffset(diameter, diameter), Parent = parent,
    })
    local function hexagon(d, key, name, shift)
        local half = d / 2
        local h = math.floor(half * 1.732 + 0.5)
        local w = math.floor(half + 0.5)
        local group = new("Frame", {
            Name = name, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(d, d), Parent = holder,
        })
        for i, rot in ipairs({ 30, 90, 150 }) do
            local piece = new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromOffset(w, h), Rotation = rot,
                BackgroundColor3 = Color3.new(1, 1, 1), Parent = group,
            })
            corner(piece, 3)
            if shift then
                flowGradient(piece, { rotation = 28 + i * 40, shift = shift + i * 0.11, periods = 0.9 })
            else
                bindTheme(piece, { BackgroundColor3 = key })
            end
        end
    end
    hexagon(diameter, outerKey, "Outer", 0)
    hexagon(math.floor(diameter * 0.62), innerKey, "Mid", nil)
    hexagon(math.floor(diameter * 0.28), outerKey, "Core", 0.5)
    return holder
end

------------------------------------------------------------------------
-- Classes
------------------------------------------------------------------------
local function class(parent)
    local c = {}
    c.__index = c
    if parent then
        setmetatable(c, { __index = parent })
    end
    return c
end

local Window = class()
local Tab = class()
local Section = class()
local Element = class()
local Toggle = class(Element)
local Slider = class(Element)
local Dropdown = class(Element)
local Keybind = class(Element)
local Textbox = class(Element)
local ColorPicker = class(Element)
local Button = class(Element)
local Checkbox = class(Element)
local ProgressBar = class(Element)
local Numberbox = class(Element)
local TextArea = class(Element)
local RangeSlider = class(Element)

------------------------------------------------------------------------
-- Library: gui host, notifications, configs
------------------------------------------------------------------------
------------------------------------------------------------------------
-- Library: blur (frosted glass / dialog backdrop)
------------------------------------------------------------------------
Library.DialogBlur = true

function Library:_setBlur(id, size)
    self._blurDemand = self._blurDemand or {}
    self._blurDemand[id] = (size and size > 0) and size or nil
    local want = 0
    for _, v in pairs(self._blurDemand) do
        want = math.max(want, v)
    end
    if want > 0 and not (self._blur and self._blur.Parent) then
        local ok, effect = pcall(function()
            local b = Instance.new("BlurEffect")
            b.Name = randomName()
            b.Size = 0
            b.Parent = game:GetService("Lighting")
            return b
        end)
        if ok then
            self._blur = effect
        end
    end
    local blur = self._blur
    if blur and blur.Parent then
        local tween = TweenService:Create(blur, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = want })
        tween:Play()
        if want == 0 then
            tween.Completed:Once(function()
                if self._blur == blur and blur.Size <= 0.05 then
                    blur:Destroy()
                    self._blur = nil
                end
            end)
        end
    end
end

function Library:SetDensity(name)
    self.Density = (tostring(name):lower() == "compact") and "Compact" or "Comfortable"
    for row in pairs(self._rows) do
        if row.Parent then
            row.Size = UDim2.new(1, 0, 0, rowH())
        end
    end
end

function Library:SetIcons(map)
    for name, id in pairs(map) do
        self.IconSet[name] = id
    end
end

function Library:_ensureGui()
    if self._gui and self._gui.Parent then
        return self._gui
    end
    local parent = getGuiParent()
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("ScreenGui") and (child:GetAttribute("PrismUI") or child:GetAttribute("AxiomUI")) then
            child:Destroy()
        end
    end
    local gui = new("ScreenGui", {
        Name = randomName(), ResetOnSpawn = false, DisplayOrder = 999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    gui:SetAttribute("PrismUI", true)
    gui.Parent = parent

    local holder = new("Frame", {
        Name = "Notifications", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -20, 1, -20), Size = UDim2.new(0, 330, 1, -40), Parent = gui,
    })
    list(holder, 8, VERT, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom)

    self._gui = gui
    return gui
end

function Library:Notify(cfg)
    if type(cfg) == "string" then
        cfg = { Content = cfg }
    end
    cfg = cfg or {}
    local gui = self:_ensureGui()
    local holder = gui:FindFirstChild("Notifications")
    local kind = cfg.Type or "Info"
    local colorKey = ({ Info = "Accent", Success = "Success", Warning = "Warning", Error = "Danger" })[kind] or "Accent"
    local iconName = ({ Info = "info", Success = "check", Warning = "alert", Error = "x" })[kind] or "info"
    local duration = cfg.Duration
    if duration == nil then duration = 4 end
    duration = math.max(0, tonumber(duration) or 4)
    if cfg.Persist == true then duration = 0 end

    self._notifCount = self._notifCount + 1
    local wrap = new("Frame", {
        Name = "Wrap", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = AS_Y, LayoutOrder = self._notifCount, Parent = holder,
    })
    local card = new("CanvasGroup", {
        Name = "Card", AnchorPoint = Vector2.new(1, 0), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AS_Y,
        Position = UDim2.new(1, 80, 0, 16), GroupTransparency = 1, Theme = { BackgroundColor3 = "Panel" }, Parent = wrap,
    })
    corner(card, R.Card)
    strokeFade(stroke(card, "Stroke", 1), 120, 0, 0.7)
    new("UISizeConstraint", { MinSize = Vector2.new(0, 60), Parent = card })
    local depth = new("UIScale", { Scale = 1, Parent = card })
    highlight(card, 14, 0.82)

    local shadow = halo(card, {
        Parent = wrap, Abs = true, Layers = 6, Spread = 16, Strength = 0.5, Radius = R.Card, ZIndex = 0,
    })

    local badge = new("Frame", {
        Name = "Badge", Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(32, 32),
        BackgroundTransparency = 0.8, Theme = { BackgroundColor3 = colorKey }, Parent = card,
    })
    corner(badge, 16)
    stroke(badge, colorKey, 1, 0.55)
    local customIcon = cfg.Icon and tostring(cfg.Icon)
    if customIcon and not Icons.Has(customIcon) then
        if tonumber(customIcon) then customIcon = "rbxassetid://" .. customIcon end
        if customIcon:find("^rbxassetid://") or customIcon:find("^rbxasset://") or customIcon:find("^https?://") then
            new("ImageLabel", {
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromOffset(18, 18), Image = customIcon, Parent = badge,
            })
        else
            new("TextLabel", {
                Size = UDim2.fromScale(1, 1), Text = customIcon, TextSize = 16, Theme = { TextColor3 = colorKey }, Parent = badge,
            })
        end
    else
        local ic = Icons.Draw(badge, customIcon or iconName, 16, colorKey, 1.1)
        ic.AnchorPoint = Vector2.new(0.5, 0.5)
        ic.Position = UDim2.fromScale(0.5, 0.5)
    end

    local inner = new("Frame", {
        Name = "Inner", BackgroundTransparency = 1, Position = UDim2.fromOffset(58, 0),
        Size = UDim2.new(1, -70, 0, 0), AutomaticSize = AS_Y, Parent = card,
    })
    pad(inner, 0, 14, 0, 16)
    list(inner, 2)
    if cfg.Title then
        new("TextLabel", {
            Name = "Title", Text = cfg.Title, Size = UDim2.new(1, 0, 0, 18), Font = FONT.Semi,
            TextXAlignment = LEFT, LayoutOrder = 1, Parent = inner,
        })
    end
    if cfg.Content then
        new("TextLabel", {
            Name = "Content", Text = cfg.Content, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AS_Y,
            Font = FONT.Regular, TextSize = 12, TextWrapped = true, TextXAlignment = LEFT,
            LayoutOrder = 2, Theme = { TextColor3 = "SubText" }, Parent = inner,
        })
    end
    local actionButton
    if cfg.ActionText then
        actionButton = new("TextButton", {
            Name = "Action", Text = tostring(cfg.ActionText), Size = UDim2.fromOffset(0, 26), AutomaticSize = AS_X,
            TextSize = 11, Font = FONT.Semi, BackgroundTransparency = 0.82,
            Theme = { BackgroundColor3 = colorKey, TextColor3 = colorKey }, LayoutOrder = 3, Parent = inner,
        })
        corner(actionButton, R.Chip)
        pad(actionButton, 12, 0, 12, 0)
        local spacer = new("Frame", { Name = "Gap", Size = UDim2.fromOffset(1, 4), BackgroundTransparency = 1, LayoutOrder = 2.5, Parent = inner })
        spacer.Name = "Gap"
    end
    local progress = new("Frame", {
        Name = "Progress", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 2), BackgroundTransparency = 0.3, Theme = { BackgroundColor3 = colorKey }, Parent = card,
    })

    local open = self._openNotifs
    if not open then
        open = {}
        self._openNotifs = open
    end
    local stack = self._toastStack
    if not stack then
        stack = {}
        self._toastStack = stack
    end
    local entry = { Card = card, Scale = depth }

    local function restack()
        for i, t in ipairs(stack) do
            local k = #stack - i
            if t.Card.Parent then
                play(t.Scale, EASE_MED, { Scale = math.max(0.9, 1 - 0.028 * k) })
                playOn(t.Card, "fade", EASE_MED, { GroupTransparency = math.min(0.55, 0.1 * k) })
            end
        end
    end

    local closed = false
    local function close()
        if closed then
            return
        end
        closed = true
        local idx = table.find(open, close)
        if idx then
            table.remove(open, idx)
        end
        local sIdx = table.find(stack, entry)
        if sIdx then
            table.remove(stack, sIdx)
        end
        playOn(card, "pos", EASE_MED, { Position = UDim2.new(1, 80, 0, 0) })
        playOn(card, "fade", EASE_MED, { GroupTransparency = 1 })
        shadow.SetFade(1, true)
        restack()
        -- collapse this toast's slot so the ones above glide down instead of jumping
        local height = wrap.AbsoluteSize.Y
        wrap.AutomaticSize = Enum.AutomaticSize.None
        wrap.Size = UDim2.new(1, 0, 0, height)
        wrap.ClipsDescendants = true
        local collapse = play(wrap, EASE_COLLAPSE, { Size = UDim2.new(1, 0, 0, 0) })
        if collapse then
            collapse.Completed:Once(function()
                shadow.Destroy()
                wrap:Destroy()
            end)
        else
            shadow.Destroy()
            wrap:Destroy()
        end
    end

    table.insert(stack, entry)
    playOn(card, "pos", EASE_SPRING, { Position = UDim2.new(1, 0, 0, 0) })
    playOn(card, "fade", EASE_MED, { GroupTransparency = 0 })
    restack()
    table.insert(open, close)
    while #open > math.max(1, tonumber(self.MaxNotifications) or 6) do
        open[1]()
    end
    if duration > 0 then
        TweenService:Create(progress, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) }):Play()
        task.delay(duration, close)
    else
        progress.Visible = false
    end
    if actionButton then
        local used = false
        actionButton.MouseButton1Click:Connect(function()
            if used then return end
            used = true
            safeCall(cfg.OnAction)
            if cfg.CloseOnAction ~= false then close() end
        end)
    end
    card.InputBegan:Connect(function(input)
        if not isPress(input) then
            return
        end
        if actionButton then
            local p, s = actionButton.AbsolutePosition, actionButton.AbsoluteSize
            local at = input.Position
            if at.X >= p.X and at.X <= p.X + s.X and at.Y >= p.Y and at.Y <= p.Y + s.Y then
                return
            end
        end
        close()
    end)

    return { Close = close }
end

function Library:GetConfig()
    local out = {}
    for flag, el in pairs(self.Options) do
        if el.Serialize then
            out[flag] = encode(el:Serialize())
        end
    end
    return out
end

function Library:SetConfig(data)
    if type(data) ~= "table" then
        return false, "config data must be a table"
    end
    for flag, value in pairs(data) do
        local el = self.Options[flag]
        if el and el.Deserialize then
            pcall(el.Deserialize, el, decode(value))
        end
    end
    return true
end

local function configPath(name)
    local clean = (tostring(name or ""):gsub("[^%w_%-%s]", ""))
    return Library.ConfigFolder .. "/" .. clean .. ".json", clean
end

function Library:SaveConfig(name)
    if not canFile() then
        return false, "file functions unavailable"
    end
    local path, clean = configPath(name)
    if clean == "" then
        return false, "invalid name"
    end

    local ok, err = pcall(function()
        if not isfolder(self.ConfigFolder) then
            makefolder(self.ConfigFolder)
        end
        local payload = HttpService:JSONEncode(self:GetConfig())
        writefile(path, payload)
    end)
    if not ok then
        return false, tostring(err)
    end
    return true
end

function Library:LoadConfig(name)
    if not canFile() then
        return false, "file functions unavailable"
    end
    if typeof(isfile) ~= "function" then
        return false, "file check function unavailable"
    end
    local path, clean = configPath(name)
    if clean == "" then
        return false, "invalid name"
    end

    local existsOk, exists = pcall(isfile, path)
    if not existsOk then
        return false, tostring(exists)
    end
    if not exists then
        return false, "config not found"
    end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)
    if not ok then
        return false, "corrupted config: " .. tostring(data)
    end
    if type(data) ~= "table" then
        return false, "invalid config format"
    end
    return self:SetConfig(data)
end

function Library:ListConfigs()
    local out = {}
    if not canFile() or typeof(listfiles) ~= "function" then
        return out
    end
    local ok, files = pcall(function()
        if not isfolder(self.ConfigFolder) then
            return {}
        end
        return listfiles(self.ConfigFolder)
    end)
    if not ok or type(files) ~= "table" then
        return out
    end
    for _, file in ipairs(files) do
        local name = tostring(file):match("([^/\\]+)%.json$")
        if name then
            table.insert(out, name)
        end
    end
    table.sort(out)
    return out
end

function Library:Unload()
    for _, window in ipairs(table.clone(self.Windows)) do
        window:Destroy()
    end
    if self._gui then
        self._gui:Destroy()
        self._gui = nil
    end
    table.clear(self.Flags)
    table.clear(self.Options)
    table.clear(self._refreshers)
    self._openNotifs = nil
    self._toastStack = nil
    if self._blur then
        pcall(function() self._blur:Destroy() end)
        self._blur = nil
    end
    self._blurDemand = nil
    if Flow.conn then
        Flow.conn:Disconnect()
        Flow.conn = nil
    end
end

------------------------------------------------------------------------
-- Shared drag helper
------------------------------------------------------------------------
-- smooth  : glide toward the cursor (frame-rate independent) instead of snapping to it
-- clampPos: optional pure function UDim2 -> UDim2 applied to the drag goal
local function makeDraggable(maid, handle, target, afterMove, onClick, canDrag, onRelease, smooth, clampPos)
    local dragging, moved = false, false
    local startMouse, startPos, goal
    local stepConn

    local function stopStep()
        if stepConn then
            stepConn:Disconnect()
            stepConn = nil
        end
    end

    local function settle()
        stopStep()
        if goal then
            target.Position = goal
            if afterMove then
                afterMove()
            end
        end
        if onRelease then
            onRelease()
        end
    end

    local function step(dt)
        if not goal then
            if not dragging then
                stopStep()
            end
            return
        end
        local alpha = 1 - math.exp(-dt * 30)
        local nextPos = target.Position:Lerp(goal, alpha)
        target.Position = nextPos
        if afterMove then
            afterMove()
        end
        if not dragging
            and math.abs(goal.X.Offset - nextPos.X.Offset) + math.abs(goal.Y.Offset - nextPos.Y.Offset) < 0.5 then
            settle()
        end
    end

    maid:Give(stopStep)
    maid:Give(handle.InputBegan:Connect(function(input)
        if isPress(input) and (not canDrag or canDrag()) then
            dragging, moved = true, false
            startMouse = Vector2.new(input.Position.X, input.Position.Y)
            startPos = target.Position
        end
    end))
    maid:Give(UserInputService.InputChanged:Connect(function(input)
        if dragging and isMove(input) then
            local d = Vector2.new(input.Position.X, input.Position.Y) - startMouse
            if d.Magnitude > 4 then
                moved = true
            end
            if moved then
                local raw = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + d.X,
                    startPos.Y.Scale, startPos.Y.Offset + d.Y
                )
                goal = clampPos and clampPos(raw) or raw
                if smooth then
                    if not stepConn then
                        stepConn = RunService.RenderStepped:Connect(step)
                    end
                else
                    target.Position = goal
                    if afterMove then
                        afterMove()
                    end
                end
            end
        end
    end))
    maid:Give(UserInputService.InputEnded:Connect(function(input)
        if dragging and isPress(input) then
            dragging = false
            if not moved then
                if onClick then
                    onClick()
                end
            elseif smooth and stepConn then
                -- the step loop keeps running until the window has caught up, then settles
            elseif onRelease then
                onRelease()
            end
        end
    end))
end

------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------
function Library:CreateWindow(cfg)
    cfg = cfg or {}
    if cfg.Animations ~= nil then self.Animations = cfg.Animations and true or false end
    if cfg.AnimationSpeed ~= nil then self.AnimationSpeed = math.clamp(tonumber(cfg.AnimationSpeed) or 1, 0.1, 5) end
    if cfg.Density then self.Density = (tostring(cfg.Density):lower() == "compact") and "Compact" or "Comfortable" end
    if cfg.Preset and self.Presets[cfg.Preset] then self:SetPreset(cfg.Preset, true) end
    local gui = self:_ensureGui()
    local size = cfg.Size or Vector2.new(700, 440)

    local window = setmetatable({
        Library = self,
        Gui = gui,
        Title = cfg.Title or "PrismUI",
        BaseSize = size,
        Size = size,
        MinSize = cfg.MinSize or Vector2.new(500, 330),
        ToggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift,
        Tabs = {},
        Maid = Maid.new(),
        Scale = 1,
        UserScale = 1,
        Visible = true,
        Minimized = false,
        Draggable = cfg.Draggable ~= false,
        SnapToEdge = cfg.SnapToEdge == true,
        Transparency = math.clamp(tonumber(cfg.Transparency) or 0, 0, 0.85),
        Glass = cfg.Glass == true,
        GlassIntensity = math.clamp(tonumber(cfg.GlassIntensity) or 0.5, 0, 1),
        Query = "",
        ForceSingle = false,
        Presets = {},
        _keybinds = {},
        _lastListenEnd = 0,
        _ambient = {},
        _refKeys = {},
        _blurKey = {},
    }, Window)
    table.insert(self.Windows, window)
    self:_updateActive()
    local maid = window.Maid
    local function scaleFn()
        return window._uiscale and window._uiscale.Scale or 1
    end
    window._scaleFn = scaleFn

    -- main frame -------------------------------------------------------
    local main = new("Frame", {
        Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(size.X, size.Y), ClipsDescendants = true,
        BackgroundTransparency = window.Transparency, Theme = { BackgroundColor3 = "Background" }, Parent = gui,
    })
    corner(main, R.Window)
    window.Main = main
    window._uiscale = new("UIScale", { Parent = main })
    new("UIGradient", {
        Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.8, 0.79, 0.86)), Parent = main,
    })
    local mainStroke = new("UIStroke", {
        Thickness = 1.25, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.new(1, 1, 1), Parent = main,
    })
    flowGradient(mainStroke, { rotation = 45, transparency = seq({ 0, 0.15 }, { 0.5, 0.7 }, { 1, 0.92 }) })
    window._shadow = { SetFade = function() end, Destroy = function() end }

    -- ambient aurora: two very faint pastel orbs drifting behind the content
    local function orb(colorKey, anchor, a, b, dia, strength)
        local dummy = new("Frame", {
            Name = "Orb", BackgroundTransparency = 1, AnchorPoint = anchor, Position = a,
            Size = UDim2.fromOffset(dia, dia), ZIndex = 0, Parent = main,
        })
        halo(dummy, { Parent = main, Layers = 9, Spread = 110, Strength = strength, Radius = dia / 2, ColorKey = colorKey, ZIndex = 0, Name = "Aurora" })
        local tween = TweenService:Create(dummy, TweenInfo.new(18, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = b })
        table.insert(window._ambient, tween)
        if self.Animations ~= false then tween:Play() end
    end
    orb("Accent3", Vector2.new(1, 0), UDim2.new(1, -30, 0, 20), UDim2.new(1, -90, 0, 70), 120, 0.16)
    orb("Accent2", Vector2.new(0, 1), UDim2.new(0, 60, 1, -10), UDim2.new(0, 140, 1, -50), 120, 0.14)

    -- topbar -------------------------------------------------------------
    local topbar = new("Frame", { Name = "Topbar", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), Parent = main })
    local gradientLine = new("Frame", {
        Name = "GradientAccent", Position = UDim2.new(0, 16, 1, -1), Size = UDim2.new(1, -32, 0, 1),
        BackgroundColor3 = Color3.new(1, 1, 1), Parent = topbar,
    })
    local lineGradient = flowGradient(gradientLine, { shift = 0.1, transparency = seq({ 0, 1 }, { 0.12, 0.45 }, { 0.88, 0.45 }, { 1, 1 }) })
    if cfg.AnimatedGradient == false then
        Flow.items[lineGradient] = nil
    end
    local logo = Icons.Hex(topbar, 24, "Accent", "Background")
    if cfg.Logo then
        logo.Visible = false
        local logoImage = tostring(cfg.Logo)
        if tonumber(logoImage) then logoImage = "rbxassetid://" .. logoImage end
        local customLogo = new("ImageLabel", {
            Name = "CustomLogo", Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(24, 24),
            Image = logoImage, Parent = topbar,
        })
        corner(customLogo, 6)
        window.Logo = customLogo
    else
        window.Logo = logo
    end
    logo.Position = UDim2.fromOffset(14, 14)
    window.BrandLabel = new("TextLabel", {
        Name = "Brand", Text = tostring(cfg.Title or "PrismUI"), Position = UDim2.fromOffset(47, 0),
        Size = UDim2.new(0, math.max(82, #tostring(cfg.Title or "PrismUI") * 9), 0, 52), TextXAlignment = LEFT,
        TextYAlignment = Enum.TextYAlignment.Center, Font = FONT.Bold, TextSize = 15,
        TextColor3 = Color3.new(1, 1, 1), Parent = topbar,
    })
    flowGradient(window.BrandLabel, { shift = 0.25, periods = 0.8 })
    new("Frame", {
        Name = "Separator", Position = UDim2.fromOffset(136, 16), Size = UDim2.fromOffset(1, 20),
        Theme = { BackgroundColor3 = "Stroke" }, Parent = topbar,
    })

    local searchFrame = new("Frame", {
        Name = "Search", Position = UDim2.fromOffset(148, 10), Size = UDim2.new(1, -286, 0, 32),
        Theme = { BackgroundColor3 = "Panel" }, Parent = topbar,
    })
    corner(searchFrame, R.Control)
    local searchStroke = stroke(searchFrame, "Stroke")
    strokeFade(searchStroke, 90, 0, 0.6)
    local searchGlow = halo(searchFrame, {
        Parent = topbar, Abs = true, Scale = scaleFn, Layers = 5, Spread = 8, Strength = 0.4, Radius = R.Control,
        ColorKey = "Accent", ZIndex = 0, Name = "SearchGlow",
    })
    searchGlow.SetFade(1, false)
    local searchIcon = Icons.Draw(searchFrame, "search", 14, "Dim")
    searchIcon.AnchorPoint = Vector2.new(0, 0.5)
    searchIcon.Position = UDim2.new(0, 12, 0.5, 0)
    local searchInput = new("TextBox", {
        Name = "Input", Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -44, 1, 0), Text = "",
        PlaceholderText = "Search settings", TextXAlignment = LEFT, TextSize = 13, Font = FONT.Medium,
        Theme = { TextColor3 = "Text", PlaceholderColor3 = "Dim" }, Parent = searchFrame,
    })
    window.SearchInput = searchInput
    window.SearchFrame = searchFrame
    maid:Give(searchInput.Focused:Connect(function()
        play(searchStroke, EASE_FAST, { Color = Library.Theme.Accent })
        Icons.Bind(searchIcon, "Accent", true)
        searchGlow.SetFade(0, true)
    end))
    maid:Give(searchInput.FocusLost:Connect(function()
        play(searchStroke, EASE_FAST, { Color = Library.Theme.Stroke })
        Icons.Bind(searchIcon, "Dim", true)
        searchGlow.SetFade(1, true)
    end))
    local searchToken = 0
    maid:Give(searchInput:GetPropertyChangedSignal("Text"):Connect(function()
        searchToken = searchToken + 1
        if searchInput.Text == "" then
            window:_applySearch("")
            return
        end
        local mine = searchToken
        task.delay(0.1, function()
            if mine == searchToken then
                window:_applySearch(searchInput.Text)
            end
        end)
    end))

    local function topButton(name, xFromRight, iconName, tintKey)
        local btn = new("TextButton", {
            Name = name, Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -xFromRight, 0, 10),
            Size = UDim2.fromOffset(32, 32), BackgroundTransparency = 1, Theme = { BackgroundColor3 = tintKey }, Parent = topbar,
        })
        corner(btn, 16)
        local icon = Icons.Draw(btn, iconName, 16, "SubText")
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.Position = UDim2.fromScale(0.5, 0.5)
        btn.MouseEnter:Connect(function()
            play(btn, EASE_FAST, { BackgroundTransparency = 0.82 })
            Icons.Bind(icon, tintKey == "Danger" and "Danger" or "Text", true)
        end)
        btn.MouseLeave:Connect(function()
            play(btn, EASE_FAST, { BackgroundTransparency = 1 })
            Icons.Bind(icon, "SubText", true)
        end)
        btn.MouseButton1Down:Connect(function()
            playOn(icon, "scale", EASE_FAST, { Size = UDim2.fromOffset(13, 13) })
        end)
        btn.MouseButton1Up:Connect(function()
            playOn(icon, "scale", EASE_POP, { Size = UDim2.fromOffset(16, 16) })
        end)
        return btn, icon
    end
    local gridBtn = topButton("Layout", 92, "columns", "Accent")
    local minimizeBtn, minIcon = topButton("Minimize", 52, "minus", "Accent")
    local restoreIcon = Icons.Draw(minimizeBtn, "restore", 16, "SubText")
    restoreIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    restoreIcon.Position = UDim2.fromScale(0.5, 0.5)
    restoreIcon.Visible = false
    window._minIcons = { minus = minIcon, restore = restoreIcon }
    local closeBtn = topButton("Close", 12, "x", "Danger")
    window.LayoutButton = gridBtn
    window.MinimizeButton = minimizeBtn
    window.CloseButton = closeBtn

    maid:Give(gridBtn.MouseButton1Click:Connect(function()
        window:SetSingleColumn(not window.ForceSingle)
        if cfg.OnLayout then
            safeCall(cfg.OnLayout, window.ForceSingle)
        end
    end))
    maid:Give(closeBtn.MouseButton1Click:Connect(function()
        window:SetVisible(false)
        if cfg.OnClose then
            safeCall(cfg.OnClose)
        end
    end))
    maid:Give(minimizeBtn.MouseButton1Click:Connect(function()
        window:SetMinimized(not window.Minimized)
    end))

    -- sidebar --------------------------------------------------------------
    local sidebar = new("Frame", {
        Name = "Sidebar", Position = UDim2.fromOffset(10, 58), Size = UDim2.new(0, 46, 1, -68),
        Theme = { BackgroundColor3 = "Panel" }, Parent = main,
    })
    corner(sidebar, R.Card)
    strokeFade(stroke(sidebar, "Stroke"), 90, 0, 0.7)
    highlight(sidebar, 12, 0.84)
    local tabList = new("ScrollingFrame", {
        Name = "Tabs", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 1, -66),
        CanvasSize = UDim2.new(), AutomaticCanvasSize = AS_Y, ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y, Parent = sidebar,
    })
    local tabItems = new("Frame", {
        Name = "Items", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AS_Y, ZIndex = 2, Parent = tabList,
    })
    list(tabItems, 6, VERT, Enum.HorizontalAlignment.Left)
    pad(tabItems, 6, 0, 6, 0)
    window.TabList = tabList
    window.TabItems = tabItems
    window.Sidebar = sidebar
    window.SidebarExpanded = false

    -- one pill glides between the tab buttons
    local indicator = new("Frame", {
        Name = "Indicator", Position = UDim2.fromOffset(6, 0), Size = UDim2.fromOffset(34, 34),
        BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.84, Visible = false, ZIndex = 1, Parent = tabList,
    })
    corner(indicator, R.Control)
    flowGradient(indicator, { rotation = 35, shift = 0.05, periods = 0.7 })
    local indStroke = stroke(indicator, "Accent", 1, 0.55)
    local bar = new("Frame", {
        Name = "Bar", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(3, 16),
        BackgroundColor3 = Color3.new(1, 1, 1), Parent = indicator,
    })
    corner(bar, 2)
    flowGradient(bar, { rotation = 90, shift = 0.4, periods = 0.6 })
    window._indicator = indicator
    window._indicatorGlow = halo(indicator, {
        Parent = tabList, Layers = 5, Spread = 10, Strength = 0.28, Radius = R.Control, ColorKey = "Accent", Name = "IndicatorGlow",
    })
    local pulse = TweenService:Create(indicator, TweenInfo.new(2.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.74 })
    local pulse2 = TweenService:Create(indStroke, TweenInfo.new(2.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.35 })
    table.insert(window._ambient, pulse)
    table.insert(window._ambient, pulse2)
    if self.Animations ~= false then pulse:Play() pulse2:Play() end
    maid:Give(tabList:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        window:_syncIndicator(false)
    end))

    local moreChevron = Icons.Draw(sidebar, "chevdown", 12, "Dim")
    moreChevron.AnchorPoint = Vector2.new(0.5, 1)
    moreChevron.Position = UDim2.new(0.5, 0, 1, -50)
    moreChevron.Visible = false
    local function updateMore()
        moreChevron.Visible = tabList.AbsoluteCanvasSize.Y > tabList.AbsoluteSize.Y + 1
    end
    maid:Give(tabList:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updateMore))
    maid:Give(tabList:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateMore))

    -- avatar: status ring, and the player's name when the sidebar expands
    local avatarBtn = new("TextButton", {
        Name = "Avatar", Text = "", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6),
        Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 1, Parent = sidebar,
    })
    local avatarImg = new("ImageLabel", {
        Name = "Headshot", Position = UDim2.fromOffset(2, 2), Size = UDim2.fromOffset(30, 30),
        BackgroundTransparency = 0, Theme = { BackgroundColor3 = "Row" }, Parent = avatarBtn,
    })
    corner(avatarImg, 15)
    local ring = new("Frame", { Name = "Ring", BackgroundTransparency = 1, Size = UDim2.fromOffset(34, 34), Parent = avatarBtn })
    corner(ring, 17)
    local ringStroke = new("UIStroke", {
        Thickness = 2, Transparency = 0.45, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.new(1, 1, 1), Parent = ring,
    })
    flowGradient(ringStroke, { rotation = 45, shift = 0.3 })
    window._avatarStroke = ringStroke
    local statusDot = new("Frame", {
        Name = "Status", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0, 33, 0, 33), Size = UDim2.fromOffset(10, 10),
        Theme = { BackgroundColor3 = "Success" }, Parent = avatarBtn,
    })
    corner(statusDot, 5)
    stroke(statusDot, "Panel", 2)
    local nameLabel = new("TextLabel", {
        Name = "Name", Text = LocalPlayer and LocalPlayer.DisplayName or "Player", Position = UDim2.fromOffset(44, 3),
        Size = UDim2.new(1, -48, 0, 16), TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd, TextSize = 12,
        Font = FONT.Semi, TextTransparency = 1, Visible = false, Parent = avatarBtn,
    })
    local subLabel = new("TextLabel", {
        Name = "Sub", Text = "Settings", Position = UDim2.fromOffset(44, 18), Size = UDim2.new(1, -48, 0, 13),
        TextXAlignment = LEFT, TextSize = 10, Font = FONT.Regular, TextTransparency = 1, Visible = false,
        Theme = { TextColor3 = "Dim" }, Parent = avatarBtn,
    })
    task.spawn(function()
        local ok, content = pcall(function()
            return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
        end)
        if ok and avatarImg.Parent then
            avatarImg.Image = content
        end
    end)
    window.AvatarButton = avatarBtn

    -- content + overlay ------------------------------------------------------
    window.Content = new("Frame", {
        Name = "Content", BackgroundTransparency = 1, ClipsDescendants = true,
        Position = UDim2.fromOffset(66, 58), Size = UDim2.new(1, -76, 1, -68), Parent = main,
    })

    -- Expand the icon rail into a labeled navigation panel while hovered.
    sidebar.ZIndex = 4
    sidebar.Active = true
    local sidebarToken = 0
    local function setSidebarExpanded(expanded)
        expanded = expanded and true or false
        sidebarToken = sidebarToken + 1
        if window.SidebarExpanded == expanded then
            return
        end
        window.SidebarExpanded = expanded
        play(sidebar, EASE_SLIDE, { Size = UDim2.new(0, expanded and 166 or 46, 1, -68) })
        for _, existingTab in ipairs(window.Tabs) do
            local navLabel = existingTab._navLabel
            local navButton = existingTab._navButton
            if navLabel and navButton and navButton.Parent then
                if expanded then
                    navLabel.Visible = true
                end
                play(navLabel, EASE_MED, { TextTransparency = expanded and 0 or 1 })
                play(navButton, EASE_SLIDE, {
                    Size = expanded and UDim2.new(1, 0, 0, 34) or UDim2.fromOffset(34, 34),
                })
            end
        end
        nameLabel.Visible, subLabel.Visible = true, true
        play(nameLabel, EASE_MED, { TextTransparency = expanded and 0 or 1 })
        play(subLabel, EASE_MED, { TextTransparency = expanded and 0 or 1 })
        play(avatarBtn, EASE_SLIDE, { Size = UDim2.fromOffset(expanded and 150 or 34, 34) })
        window:_syncIndicator(true)
    end
    window._setSidebarExpanded = setSidebarExpanded
    maid:Give(sidebar.MouseEnter:Connect(function()
        setSidebarExpanded(true)
    end))
    maid:Give(sidebar.MouseLeave:Connect(function()
        sidebarToken = sidebarToken + 1
        local mine = sidebarToken
        task.delay(0.12, function()
            if mine == sidebarToken then
                setSidebarExpanded(false)
            end
        end)
    end))

    window.Overlay = new("Frame", {
        Name = "Overlay", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = main,
    })
    window._blocker = new("TextButton", {
        Name = "Blocker", Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 1, Visible = false, Parent = window.Overlay,
    })
    maid:Give(window._blocker.MouseButton1Click:Connect(function()
        if window._dialog then
            window:_closeDialog()
        else
            window:_closePopup()
        end
    end))
    window:_buildTooltip()

    -- resize grip: matches the icon style, edges light up on hover ---------------
    if cfg.Resizable ~= false then
        local edgeBottom = new("Frame", {
            Name = "EdgeBottom", Position = UDim2.new(0, 20, 1, -2), Size = UDim2.new(1, -60, 0, 2),
            BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = 4, Parent = main,
        })
        flowGradient(edgeBottom, { shift = 0.2 })
        local edgeRight = new("Frame", {
            Name = "EdgeRight", Position = UDim2.new(1, -2, 0, 64), Size = UDim2.new(0, 2, 1, -100),
            BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = 4, Parent = main,
        })
        flowGradient(edgeRight, { rotation = 90, shift = 0.6 })
        local grip = new("TextButton", {
            Name = "Grip", Text = "", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -4),
            Size = UDim2.fromOffset(18, 18), ZIndex = 5, Parent = main,
        })
        local dots = {}
        for _, p in ipairs({ { 13, 13 }, { 8, 13 }, { 13, 8 } }) do
            local dot = new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(p[1], p[2]), Size = UDim2.fromOffset(3, 3),
                Theme = { BackgroundColor3 = "Dim" }, Parent = grip,
            })
            corner(dot, 2)
            table.insert(dots, dot)
        end
        window.Grip = grip
        local resizing, startMouse, startSize, startPos = false, nil, nil, nil
        local function gripLight(on)
            for _, dot in ipairs(dots) do
                play(dot, EASE_FAST, { BackgroundColor3 = on and Library.Theme.Accent or Library.Theme.Dim })
            end
            play(edgeBottom, EASE_MED, { BackgroundTransparency = on and 0.45 or 1 })
            play(edgeRight, EASE_MED, { BackgroundTransparency = on and 0.45 or 1 })
        end
        maid:Give(grip.MouseEnter:Connect(function() gripLight(true) end))
        maid:Give(grip.MouseLeave:Connect(function() if not resizing then gripLight(false) end end))
        maid:Give(grip.InputBegan:Connect(function(input)
            if isPress(input) then
                resizing = true
                startMouse = Vector2.new(input.Position.X, input.Position.Y)
                startSize = window.Size
                startPos = main.Position
            end
        end))
        maid:Give(UserInputService.InputChanged:Connect(function(input)
            if resizing and isMove(input) then
                local d = Vector2.new(input.Position.X, input.Position.Y) - startMouse
                local vp = gui.AbsoluteSize
                local maxX = math.max(window.MinSize.X, (vp.X - 16) / window.Scale)
                local maxY = math.max(window.MinSize.Y, (vp.Y - 16) / window.Scale)
                local newSize = Vector2.new(
                    math.clamp(startSize.X + d.X / window.Scale, window.MinSize.X, maxX),
                    math.clamp(startSize.Y + d.Y / window.Scale, window.MinSize.Y, maxY)
                )
                local grow = (newSize - startSize) * window.Scale
                window.Size = newSize
                main.Size = UDim2.fromOffset(newSize.X, newSize.Y)
                main.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + grow.X / 2,
                    startPos.Y.Scale, startPos.Y.Offset + grow.Y / 2
                )
            end
        end))
        maid:Give(UserInputService.InputEnded:Connect(function(input)
            if resizing and isPress(input) then
                resizing = false
                gripLight(false)
            end
        end))
    end

    -- dragging -------------------------------------------------------------
    makeDraggable(maid, topbar, main, nil, nil, function()
        return window.Draggable
    end, function()
        if window.SnapToEdge then window:_snapToEdges() end
    end, true, function(pos)
        return window:_clampPosition(pos)
    end)

    -- input (keybinds, toggle key, mouse tracking) ------------------------------
    maid:Give(UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            window._mouse = Vector2.new(input.Position.X, input.Position.Y)
            window:_moveTip()
        end
    end))
    maid:Give(UserInputService.InputBegan:Connect(function(input)
        if window._listening then
            local cb = window._listening
            if input.UserInputType == Enum.UserInputType.Keyboard then
                window._listening = nil
                if input.KeyCode == Enum.KeyCode.Escape then
                    cb(false)
                elseif input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
                    cb(nil)
                else
                    cb(input.KeyCode)
                end
            elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
                window._listening = nil
                cb(input.UserInputType)
            elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
                window._listening = nil
                cb(false)
            end
            return
        end
        if UserInputService:GetFocusedTextBox() then
            return
        end
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == window.ToggleKey then
            window:SetVisible(not window.Visible)
            return
        end
        for _, kb in ipairs(window._keybinds) do
            local key = kb.Get()
            if key and (input.KeyCode == key or input.UserInputType == key) then
                kb.Down()
            end
        end
    end))
    maid:Give(UserInputService.InputEnded:Connect(function(input)
        for _, kb in ipairs(window._keybinds) do
            local key = kb.Get()
            if key and kb.Up and (input.KeyCode == key or input.UserInputType == key) then
                kb.Up()
            end
        end
    end))

    -- responsive scale -----------------------------------------------------------
    maid:Give(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        window:_updateScale()
        window:_clamp()
    end))
    window:_updateScale()

    -- fade veil: the window's content fades in over its own background
    window._veil = new("Frame", {
        Name = "Veil", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, ZIndex = 200, Theme = { BackgroundColor3 = "Background" }, Parent = main,
    })
    corner(window._veil, R.Window)
    window._uiscale.Scale = window.Scale * 0.92
    window._shadow.SetFade(1, false)
    window._shadow.SetFade(0, true)
    play(window._uiscale, EASE_SPRING, { Scale = window.Scale })
    local veilTween = play(window._veil, EASE_SLOW, { BackgroundTransparency = 1 })
    local function dropVeil()
        if window._veil and window.Visible then window._veil.Visible = false end
    end
    if veilTween then veilTween.Completed:Once(dropVeil) else dropVeil() end

    -- mobile toggle button ---------------------------------------------------------
    local wantMobile = cfg.MobileButton
    if wantMobile == nil then
        wantMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    end
    if wantMobile then
        local fab = new("Frame", {
            Name = "MobileToggle", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -40, 0, 90),
            Size = UDim2.fromOffset(44, 44), Theme = { BackgroundColor3 = "Panel" }, Parent = gui,
        })
        corner(fab, 22)
        local fabStroke = new("UIStroke", { Thickness = 1.5, Color = Color3.new(1, 1, 1), Parent = fab })
        flowGradient(fabStroke, { rotation = 45 })
        local fabHalo = halo(fab, { Layers = 6, Spread = 14, OffsetY = 4, Strength = 0.5, Radius = 22 })
        local fabLogo = Icons.Hex(fab, 22, "Accent", "Panel")
        fabLogo.AnchorPoint = Vector2.new(0.5, 0.5)
        fabLogo.Position = UDim2.fromScale(0.5, 0.5)
        makeDraggable(maid, fab, fab, nil, function()
            window:SetVisible(not window.Visible)
        end)
        maid:Give(function() fabHalo.Destroy() end)
        maid:Give(fab)
    end

    -- built-in settings page (opened by the avatar button) ----------------------------
    if cfg.Settings ~= false then
        window:_buildSettings()
    end

    maid:Give(avatarBtn.MouseButton1Click:Connect(function()
        if window.SettingsTab then
            window:Select(window.SettingsTab)
        end
    end))
    maid:Give(main)
    window:_applyTransparency()
    window:_applyBlur()
    window:_syncIndicator(false)

    return window
end

function Window:_syncIndicator(animate)
    local ind = self._indicator
    if not ind then return end
    local tab = self.ActiveTab
    if not tab or tab.IsSettings or not tab.Button or not tab.Button.Parent then
        ind.Visible = false
        return
    end
    local s = math.max(self.Scale, 0.01)
    local rel = (tab.Button.AbsolutePosition - self.TabList.AbsolutePosition) / s
    local y = rel.Y + self.TabList.CanvasPosition.Y / s
    local goalPos = UDim2.fromOffset(6, y)
    local goalSize = UDim2.fromOffset(self.SidebarExpanded and 154 or 34, 34)
    if not ind.Visible then
        animate = false
    end
    ind.Visible = true
    if animate then
        playOn(ind, "pos", EASE_SLIDE, { Position = goalPos, Size = goalSize })
    else
        local set = channels[ind]
        if set and set.pos then set.pos:Cancel() end
        ind.Position, ind.Size = goalPos, goalSize
    end
end

function Window:_setMinIcon(minimized)
    local icons = self._minIcons
    if icons then
        icons.minus.Visible = not minimized
        icons.restore.Visible = minimized
    end
end

-- keep a refresher alive only as long as this window
function Window:_refresher(key, fn)
    Library._refreshers[key] = fn
    table.insert(self._refKeys, key)
end

function Window:_applyTransparency()
    if not self.Main then return end
    local t = self.Transparency
    if self.Glass then
        t = math.max(t, 0.1 + 0.3 * (self.GlassIntensity or 0.5))
    end
    apply(self.Main, { BackgroundTransparency = t }, true, EASE_MED)
end

function Window:_applyBlur()
    local size = 0
    if self.Glass and self.Visible and not self.Minimized then
        size = 4 + 20 * (self.GlassIntensity or 0.5)
    end
    Library:_setBlur(self._blurKey, size)
end

function Window:SetGlass(enabled, intensity)
    self.Glass = enabled and true or false
    if intensity ~= nil then
        self.GlassIntensity = math.clamp(tonumber(intensity) or 0.5, 0, 1)
    end
    self:_applyTransparency()
    self:_applyBlur()
end

function Window:SetPreset(name, instant)
    return Library:SetPreset(name, instant)
end

function Window:SetDensity(name)
    Library:SetDensity(name)
end

function Window:_updateScale()
    local vp = self.Gui.AbsoluteSize
    if vp.X <= 0 or vp.Y <= 0 then
        return
    end
    local fit = math.min((vp.X - 24) / self.BaseSize.X, (vp.Y - 24) / self.BaseSize.Y, 1)
    self.Scale = math.clamp(fit, 0.4, 1) * self.UserScale
    if self.Visible then
        self._uiscale.Scale = self.Scale
    end
    for _, tab in ipairs(self.Tabs) do
        tab:_layout()
    end
end

function Window:SetScale(multiplier)
    self.UserScale = math.clamp(multiplier, 0.5, 1.5)
    self:_updateScale()
    self:_clamp()
end

function Window:_clampPosition(pos)
    local vp = self.Gui.AbsoluteSize
    local half = self.Main.AbsoluteSize / 2
    local maxX = vp.X / 2 + half.X - 80
    local minY = -vp.Y / 2 + half.Y
    local maxY = vp.Y / 2 + half.Y - 56
    local nx = math.clamp(pos.X.Offset, -maxX, maxX)
    local ny = math.clamp(pos.Y.Offset, minY, math.max(minY, maxY))
    return UDim2.new(pos.X.Scale, nx, pos.Y.Scale, ny)
end

function Window:_clamp()
    local main = self.Main
    local pos = main.Position
    local clamped = self:_clampPosition(pos)
    if clamped ~= pos then
        main.Position = clamped
    end
end

function Window:_setGradientRunning(running)
    for _, tween in ipairs(self._ambient or {}) do
        if running and Library.Animations ~= false then
            tween:Play()
        else
            tween:Pause()
        end
    end
end

function Window:SetVisible(visible)
    if visible == self.Visible then
        return
    end
    self.Visible = visible
    Library:_updateActive()
    self:_setGradientRunning(visible)
    local veil = self._veil
    if visible then
        self.Main.Visible = true
        self._uiscale.Scale = self.Scale * 0.94
        veil.Visible = true
        veil.BackgroundTransparency = 0
        local tween = play(veil, EASE_SLOW, { BackgroundTransparency = 1 })
        local function finish()
            if self.Visible then veil.Visible = false end
        end
        if tween then tween.Completed:Once(finish) else finish() end
        play(self._uiscale, EASE_SPRING, { Scale = self.Scale })
        self._shadow.SetFade(1, false)
        self._shadow.SetFade(0, true)
    else
        self:_closePopup()
        self:_hideTip()
        if self._setSidebarExpanded then
            self._setSidebarExpanded(false)
        end
        veil.Visible = true
        play(veil, EASE_FAST, { BackgroundTransparency = 0.45 })
        play(self._uiscale, EASE_FAST, { Scale = self.Scale * 0.95 })
        self._shadow.SetFade(1, true)
        task.delay(0.15, function()
            if not self.Visible then
                self.Main.Visible = false
                self._uiscale.Scale = self.Scale
                veil.Visible = false
            end
        end)
    end
    self:_applyBlur()
end

function Window:_setBodyVisible(visible)
    if self.Sidebar then self.Sidebar.Visible = visible end
    if self.Content then self.Content.Visible = visible end
    if self.Grip then self.Grip.Visible = visible end
    if self.Overlay then self.Overlay.Visible = visible end
    if self.SearchFrame then self.SearchFrame.Visible = visible end
    if self.LayoutButton then self.LayoutButton.Visible = visible end
end

function Window:SetMinimized(state)
    state = state and true or false
    if state == self.Minimized or not self.Main then return end
    local main = self.Main
    local currentPos = main.Position
    self._minToken = (self._minToken or 0) + 1
    local token = self._minToken
    if state then
        self._restoreSize = self.Size
        self._restorePosition = currentPos
        self._restoreHeight = self.Size.Y
        self.Minimized = true
        self:_closePopup()
        self:_hideTip()
        if self._setSidebarExpanded then self._setSidebarExpanded(false) end
        local offset = math.max(0, (self._restoreHeight - 52) / 2)
        local targetPos = UDim2.new(currentPos.X.Scale, currentPos.X.Offset,
            currentPos.Y.Scale, currentPos.Y.Offset - offset)
        local tween = play(main, EASE_MED, {
            Size = UDim2.fromOffset(self.Size.X, 52), Position = targetPos,
        })
        self._minimizeTween = tween
        -- let the window fold shut first (Main clips its children), then stop rendering the body
        local function hideBody()
            if self.Minimized and self._minToken == token then
                self:_setBodyVisible(false)
            end
        end
        if tween then
            tween.Completed:Once(hideBody)
        else
            hideBody()
        end
        self:_setMinIcon(true)
        self:_applyBlur()
    else
        self.Minimized = false
        local height = self._restoreHeight or self.Size.Y
        local offset = math.max(0, (height - 52) / 2)
        local targetPos = UDim2.new(currentPos.X.Scale, currentPos.X.Offset,
            currentPos.Y.Scale, currentPos.Y.Offset + offset)
        self:_setBodyVisible(true)
        self._minimizeTween = play(main, EASE_MED, {
            Size = UDim2.fromOffset(self.Size.X, height), Position = targetPos,
        })
        self:_setMinIcon(false)
        self:_applyBlur()
    end
end

function Window:Minimize()
    self:SetMinimized(true)
end

function Window:Restore()
    self:SetMinimized(false)
end

function Window:SetTitle(title)
    self.Title = tostring(title or "PrismUI")
    if self.BrandLabel then
        self.BrandLabel.Text = self.Title
        self.BrandLabel.Size = UDim2.new(0, math.max(82, #self.Title * 9), 0, 52)
    end
end

function Window:SetLogo(image)
    if not self.Main then return end
    if self.Logo and self.Logo.Parent then self.Logo:Destroy() end
    if not image or image == "" then
        local topbar = self.Main:FindFirstChild("Topbar")
        if not topbar then return end
        self.Logo = Icons.Hex(topbar, 24, "Accent", "Background")
        self.Logo.Position = UDim2.fromOffset(14, 14)
        return
    end
    local source = tostring(image)
    if tonumber(source) then source = "rbxassetid://" .. source end
    local topbar = self.Main:FindFirstChild("Topbar")
    if not topbar then return end
    self.Logo = new("ImageLabel", { Name = "CustomLogo", Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(24, 24), Image = source, Parent = topbar })
    corner(self.Logo, 6)
end

function Window:SetSize(size)
    if typeof(size) ~= "Vector2" then return end
    self.Size = Vector2.new(math.max(self.MinSize.X, size.X), math.max(self.MinSize.Y, size.Y))
    self.BaseSize = self.Size
    if self.Minimized then
        self._restoreHeight = self.Size.Y
    else
        self.Main.Size = UDim2.fromOffset(self.Size.X, self.Size.Y)
    end
    self:_updateScale()
    self:_clamp()
end

function Window:SetPosition(position)
    if typeof(position) == "UDim2" and self.Main then
        self.Main.Position = position
        self:_clamp()
    end
end

function Window:SavePreset(name)
    name = tostring(name or "")
    if name == "" then return false end
    local position = self.Main.Position
    if self.Minimized then
        local offset = math.max(0, ((self._restoreHeight or self.Size.Y) - 52) / 2)
        position = UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset + offset)
    end
    self.Presets[name] = {
        Size = self.Size,
        Position = position,
        UserScale = self.UserScale,
        ForceSingle = self.ForceSingle,
        Transparency = self.Transparency,
        Minimized = self.Minimized,
    }
    return true
end

function Window:LoadPreset(name)
    name = tostring(name or "")
    local preset = self.Presets[name]
    if not preset then
        local builtins = {
            Compact = Vector2.new(560, 360),
            Standard = Vector2.new(700, 440),
            Wide = Vector2.new(900, 480),
            Large = Vector2.new(860, 580),
        }
        local size = builtins[name]
        if not size then
            for key, value in pairs(builtins) do
                if key:lower() == name:lower() then size = value; break end
            end
        end
        if not size then return false end
        self:SetMinimized(false)
        self:SetSize(size)
        return true
    end
    self:SetMinimized(false)
    self:SetSize(preset.Size)
    self:SetScale(preset.UserScale or 1)
    self:SetSingleColumn(preset.ForceSingle or false)
    self:SetTransparency(preset.Transparency or 0)
    if preset.Position then self:SetPosition(preset.Position) end
    self:SetMinimized(preset.Minimized or false)
    return true
end

function Window:SetDraggable(enabled)
    self.Draggable = enabled and true or false
end

function Window:SetSnapToEdge(enabled)
    self.SnapToEdge = enabled and true or false
    if self.SnapToEdge then self:_snapToEdges() end
end

function Window:_snapToEdges()
    if not self.Main or self.Minimized then return end
    local vp = self.Gui.AbsoluteSize
    local half = self.Main.AbsoluteSize / 2
    local pos = self.Main.Position
    local x, y = pos.X.Offset, pos.Y.Offset
    local left = -vp.X / 2 + half.X + 12
    local right = vp.X / 2 - half.X - 12
    local top = -vp.Y / 2 + half.Y + 12
    local bottom = vp.Y / 2 - half.Y - 12
    if math.abs(x - left) < 28 then x = left elseif math.abs(x - right) < 28 then x = right end
    if math.abs(y - top) < 28 then y = top elseif math.abs(y - bottom) < 28 then y = bottom end
    play(self.Main, EASE_MED, { Position = UDim2.new(pos.X.Scale, x, pos.Y.Scale, y) })
end

function Window:SetTransparency(alpha)
    self.Transparency = math.clamp(tonumber(alpha) or 0, 0, 0.85)
    self:_applyTransparency()
end

function Window:SetAnimationSpeed(speed)
    Library.AnimationSpeed = math.clamp(tonumber(speed) or 1, 0.1, 5)
end

function Window:SetAnimations(enabled)
    Library.Animations = enabled and true or false
    self:_setGradientRunning(self.Visible)
end

function Window:Find(flag)
    return Library.Options[flag]
end

function Window:Dialog(cfg)
    cfg = cfg or {}
    self:_closeDialog()
    self:_closePopup()
    self:_hideTip()
    local overlay = self.Overlay
    overlay.Visible = true
    self._blocker.Visible = true
    self._dlgKey = self._dlgKey or {}
    if Library.DialogBlur and cfg.Blur ~= false then
        Library:_setBlur(self._dlgKey, 14)
    end
    local shade = new("Frame", {
        Name = "DialogShade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1, ZIndex = 55, Parent = overlay,
    })
    corner(shade, R.Window)
    new("UIGradient", { Rotation = 90, Transparency = seq({ 0, 0 }, { 0.5, 0.35 }, { 1, 0 }), Parent = shade })
    local card = new("CanvasGroup", {
        Name = "Dialog", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(0, cfg.Width or 360, 0, 0), AutomaticSize = AS_Y, ZIndex = 60, GroupTransparency = 1,
        Theme = { BackgroundColor3 = "Panel" }, Parent = overlay,
    })
    local cardScale = new("UIScale", { Scale = 0.9, Parent = card })
    corner(card, R.Window - 2)
    strokeFade(stroke(card, "Stroke", 1.25), 120, 0, 0.6)
    highlight(card, 24, 0.8)
    pad(card, S.XL, S.XL, S.XL, S.LG + 4)
    list(card, S.MD, VERT, Enum.HorizontalAlignment.Center)
    local shadow = halo(card, {
        Parent = overlay, Abs = true, Scale = self._scaleFn, Layers = 8, Spread = 36, OffsetY = 12, Strength = 0.62,
        Radius = R.Window - 2, ZIndex = 58, Name = "DialogShadow",
    })
    shadow.SetFade(1, false)

    local danger = cfg.Danger == true
    local badge = new("Frame", {
        Name = "Badge", Size = UDim2.fromOffset(48, 48), BackgroundColor3 = Color3.new(1, 1, 1),
        LayoutOrder = 1, Parent = card,
    })
    corner(badge, 24)
    if danger then
        bindTheme(badge, { BackgroundColor3 = "Danger" })
    else
        flowGradient(badge, { rotation = 40, periods = 0.9 })
    end
    local badgeHalo = glow(badge, { Layers = 5, Spread = 12, Strength = 0.4, Radius = 24, ColorKey = danger and "Danger" or "Accent", Alpha = 1, ZIndex = 0 })
    badgeHalo.Frame.ZIndex = 0
    local icon = Icons.Draw(badge, cfg.Icon and Icons.Has(cfg.Icon) and cfg.Icon or (danger and "alert" or "sparkle"), 22, "OnAccent", 1.1)
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Position = UDim2.fromScale(0.5, 0.5)
    icon.ZIndex = 2
    local title = new("TextLabel", {
        Name = "Title", Text = cfg.Title or "Confirm action", Size = UDim2.new(1, 0, 0, 22),
        TextSize = 17, Font = FONT.Bold, LayoutOrder = 2, ZIndex = 61, Parent = card,
    })
    local content = new("TextLabel", {
        Name = "Content", Text = cfg.Content or cfg.Description or "Are you sure?",
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AS_Y, TextSize = 13, Font = FONT.Regular, TextWrapped = true,
        LayoutOrder = 3, ZIndex = 61, Theme = { TextColor3 = "SubText" }, Parent = card,
    })
    local actions = new("Frame", {
        Name = "Actions", Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, LayoutOrder = 4, ZIndex = 61, Parent = card,
    })
    list(actions, S.SM, HORIZ, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
    local dialog = { Frame = card, Shade = shade, Closed = false }
    local escConn
    local function close(confirmed)
        if dialog.Closed then return end
        dialog.Closed = true
        if escConn then escConn:Disconnect() end
        self._dialog = nil
        self._blocker.Visible = false
        Library:_setBlur(self._dlgKey, 0)
        play(card, EASE_FAST, { GroupTransparency = 1 })
        play(cardScale, EASE_FAST, { Scale = 0.95 })
        play(shade, EASE_FAST, { BackgroundTransparency = 1 })
        shadow.SetFade(1, true)
        task.delay(0.16, function()
            shadow.Destroy()
            if card.Parent then card:Destroy() end
            if shade.Parent then shade:Destroy() end
        end)
        if confirmed then safeCall(cfg.OnConfirm) else safeCall(cfg.OnCancel) end
    end
    local function dialogButton(text, primary, order)
        local btn = new("TextButton", {
            Name = primary and "Confirm" or "Cancel", Text = text, Size = UDim2.new(0.5, -4, 1, 0), LayoutOrder = order,
            Font = FONT.Semi, TextSize = 13, ZIndex = 62, ClipsDescendants = true,
            BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, Parent = actions,
        })
        corner(btn, R.Control)
        if primary then
            if danger then
                bindTheme(btn, { BackgroundColor3 = "Danger", TextColor3 = "OnAccent" })
            else
                bindTheme(btn, { TextColor3 = "OnAccent" })
                flowGradient(btn, { rotation = 20, shift = 0.15 })
            end
            btn.FontFace = FONT.Semi
        else
            bindTheme(btn, { BackgroundColor3 = "Row", TextColor3 = "SubText" })
            strokeFade(stroke(btn, "Stroke"), 90, 0, 0.6)
        end
        local ui = new("UIScale", { Scale = 1, Parent = btn })
        btn.MouseEnter:Connect(function()
            if primary then
                play(ui, EASE_MED, { Scale = 1.02 })
            else
                play(btn, EASE_FAST, { BackgroundColor3 = Library.Theme.RowHover })
            end
        end)
        btn.MouseLeave:Connect(function()
            play(ui, EASE_MED, { Scale = 1 })
            if not primary then play(btn, EASE_FAST, { BackgroundColor3 = Library.Theme.Row }) end
        end)
        btn.MouseButton1Down:Connect(function() play(ui, EASE_FAST, { Scale = 0.97 }) end)
        btn.MouseButton1Up:Connect(function() play(ui, EASE_MED, { Scale = 1 }) end)
        return btn
    end
    escConn = UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.Escape and not dialog.Closed then
            close(false)
        end
    end)
    local cancel = dialogButton(cfg.CancelText or "Cancel", false, 1)
    local confirm = dialogButton(cfg.ConfirmText or "Confirm", true, 2)
    cancel.MouseButton1Click:Connect(function() close(false) end)
    confirm.MouseButton1Click:Connect(function() close(true) end)
    self._dialog = dialog
    dialog.Close = function() close(false) end
    dialog.Confirm = function() close(true) end
    play(card, EASE_MED, { GroupTransparency = 0 })
    play(cardScale, EASE_SPRING, { Scale = 1 })
    play(shade, EASE_MED, { BackgroundTransparency = 0.5 })
    shadow.SetFade(0, true)
    return dialog
end

function Window:_closeDialog()
    local dialog = self._dialog
    if dialog and not dialog.Closed then
        dialog.Close()
    end
end

function Window:Confirm(cfg)
    return self:Dialog(cfg)
end

function Window:Toggle()
    self:SetVisible(not self.Visible)
end

function Window:SetSingleColumn(state)
    self.ForceSingle = state and true or false
    for _, tab in ipairs(self.Tabs) do
        tab:_layout()
    end
    if self._singleToggle then
        self._singleToggle:SetValue(self.ForceSingle, true)
    end
end

function Window:Notify(cfg)
    return self.Library:Notify(cfg)
end

function Window:Destroy()
    if self._destroyed then
        return
    end
    self._destroyed = true

    -- Remove this window's Flag owners without erasing controls registered by
    -- another live window under the same Flag.
    for _, owner in pairs(self.Library.Options) do
        local current = owner
        while current do
            if current.Window == self then
                current._destroyed = true
            end
            current = current._previousFlagOwner
        end
    end
    for flag, owner in pairs(self.Library.Options) do
        if owner.Window == self then
            local previous = owner._previousFlagOwner
            while previous and previous._destroyed do
                previous = previous._previousFlagOwner
            end
            if previous then
                self.Library.Options[flag] = previous
                self.Library.Flags[flag] = previous.Value
            else
                self.Library.Options[flag] = nil
                self.Library.Flags[flag] = nil
            end
        end
    end

    local i = table.find(self.Library.Windows, self)
    if i then
        table.remove(self.Library.Windows, i)
    end
    for _, tab in ipairs(self.Tabs) do
        Library._refreshers[tab] = nil
    end
    for _, key in ipairs(self._refKeys or {}) do
        Library._refreshers[key] = nil
    end
    for _, tween in ipairs(self._ambient or {}) do
        pcall(function() tween:Cancel() end)
    end
    Library:_setBlur(self._blurKey, 0)
    Library:_setBlur(self._dlgKey or {}, 0)
    Library:_updateActive()
    self.Maid:Clean()
end

-- tooltip -----------------------------------------------------------------------
function Window:_buildTooltip()
    local wrap = new("Frame", {
        Name = "Tooltip", Visible = false, ZIndex = 20, AutomaticSize = AS_XY, Size = UDim2.fromOffset(0, 0),
        BackgroundTransparency = 1, Parent = self.Overlay,
    })
    pad(wrap, 0, 0, 0, 6)
    local card = new("CanvasGroup", {
        Name = "Card", Position = UDim2.fromOffset(0, 6), AutomaticSize = AS_XY, Size = UDim2.fromOffset(0, 0),
        GroupTransparency = 1, Theme = { BackgroundColor3 = "Panel" }, Parent = wrap,
    })
    corner(card, R.Control)
    strokeFade(stroke(card, "Stroke"), 90, 0, 0.55)
    new("UISizeConstraint", { MaxSize = Vector2.new(280, 400), Parent = card })
    pad(card, 12, 9, 12, 10)
    list(card, 4)
    local head = new("Frame", { Name = "Head", AutomaticSize = AS_XY, Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, LayoutOrder = 1, Parent = card })
    list(head, 8, HORIZ, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
    local title = new("TextLabel", {
        Name = "Title", AutomaticSize = AS_XY, Size = UDim2.fromOffset(0, 16), Font = FONT.Semi, TextSize = 13,
        TextXAlignment = LEFT, LayoutOrder = 1, Parent = head,
    })
    local keyChip = new("TextLabel", {
        Name = "Key", AutomaticSize = AS_X, Size = UDim2.fromOffset(0, 18), Font = FONT.Mono, TextSize = 10,
        LayoutOrder = 2, Theme = { BackgroundColor3 = "Row", TextColor3 = "SubText" }, BackgroundTransparency = 0, Parent = head,
    })
    corner(keyChip, 5)
    pad(keyChip, 6, 0, 6, 0)
    stroke(keyChip, "Stroke", 1, 0.3)
    local desc = new("TextLabel", {
        Name = "Description", AutomaticSize = AS_XY, Size = UDim2.fromOffset(0, 0), Font = FONT.Regular, TextSize = 12,
        TextXAlignment = LEFT, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2,
        Theme = { TextColor3 = "SubText" }, Parent = card,
    })
    new("UISizeConstraint", { MaxSize = Vector2.new(236, 400), Parent = desc })
    local arrow = new("Frame", {
        Name = "Arrow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(18, 4), Size = UDim2.fromOffset(9, 9),
        Rotation = 45, Theme = { BackgroundColor3 = "Panel" }, Parent = wrap,
    })
    corner(arrow, 2)
    local shadow = halo(card, {
        Parent = wrap, Abs = true, Scale = self._scaleFn, Layers = 5, Spread = 14, OffsetY = 4, Strength = 0.5,
        Radius = R.Control, ZIndex = 0, Name = "TipShadow",
    })
    shadow.SetFade(1, false)
    self._tip = { Frame = wrap, Card = card, Title = title, Desc = desc, Key = keyChip, Arrow = arrow, Shadow = shadow }
end

function Window:_showTip(data)
    if type(data) == "string" then
        data = { Description = data }
    end
    if type(data) ~= "table" then
        return
    end
    local t = self._tip
    local titleText = data.Title or ""
    local descText = data.Description or ""
    local keyText = data.Keybind and tostring(data.Keybind) or ""
    t.Title.Visible = titleText ~= ""
    t.Desc.Visible = descText ~= ""
    t.Key.Visible = keyText ~= ""
    t.Title.Text = titleText
    t.Desc.Text = descText
    t.Key.Text = keyText
    local fresh = not t.Frame.Visible
    t.Frame.Visible = true
    self:_moveTip()
    if fresh then
        t.Card.GroupTransparency = 1
        t.Arrow.BackgroundTransparency = 1
        t.Shadow.SetFade(1, false)
    end
    playOn(t.Card, "fade", EASE_MED, { GroupTransparency = 0 })
    playOn(t.Arrow, "fade", EASE_MED, { BackgroundTransparency = 0 })
    t.Shadow.SetFade(0, true)
end

function Window:_hideTip()
    local t = self._tip
    if t and t.Frame.Visible then
        t.Frame.Visible = false
        t.Card.GroupTransparency = 1
    end
end

function Window:_moveTip()
    local t = self._tip
    local f = t and t.Frame
    if not f or not f.Visible or not self._mouse then
        return
    end
    local s = math.max(self.Scale, 0.01)
    local o = self.Overlay.AbsolutePosition
    local ov = self.Overlay.AbsoluteSize / s
    local size = f.AbsoluteSize / s
    local mx = (self._mouse.X - o.X) / s
    local my = (self._mouse.Y - o.Y) / s
    local x = math.clamp(mx - 14, 4, math.max(4, ov.X - size.X - 4))
    local y = my + 14
    local flipped = false
    if y + size.Y > ov.Y - 4 then
        y = my - size.Y - 10
        flipped = true
    end
    f.Position = UDim2.fromOffset(x, math.max(4, y))
    t.Card.Position = UDim2.fromOffset(0, flipped and 0 or 6)
    t.Arrow.Position = UDim2.new(0, math.clamp(mx - x, 14, math.max(14, size.X - 14)), flipped and 1 or 0, flipped and -2 or 4)
end

function Window:_tooltip(obj, getter, delay)
    local token = 0
    local enter = obj.MouseEnter:Connect(function()
        token = token + 1
        local mine = token
        task.delay(delay or 0.35, function()
            if mine == token and obj.Parent then
                local data = getter()
                if data then
                    self:_showTip(data)
                end
            end
        end)
    end)
    local leave = obj.MouseLeave:Connect(function()
        token = token + 1
        self:_hideTip()
    end)
    local press = obj.InputBegan:Connect(function(input)
        if isPress(input) then
            token = token + 1
            self:_hideTip()
        end
    end)
    self.Maid:Give(enter)
    self.Maid:Give(leave)
    self.Maid:Give(press)
end

-- popups ------------------------------------------------------------------------------
function Window:_placePopup(p)
    local a = p.Anchor
    local s = self.Scale
    local o = self.Overlay.AbsolutePosition
    local ov = self.Overlay.AbsoluteSize / s
    local ax = (a.AbsolutePosition.X - o.X) / s
    local ay = (a.AbsolutePosition.Y - o.Y) / s
    local aw = a.AbsoluteSize.X / s
    local ah = a.AbsoluteSize.Y / s
    local x = ax
    if p.AlignRight then
        x = ax + aw - p.Size.X
    end
    x = math.clamp(x, 4, math.max(4, ov.X - p.Size.X - 4))
    local y = ay + ah + 6
    p._above = false
    if y + p.Size.Y > ov.Y - 4 then
        y = math.max(4, ay - p.Size.Y - 6)
        p._above = true
    end
    p.Frame.Position = UDim2.fromOffset(x, y)
end

function Window:_openPopup(p)
    if self._popup and self._popup ~= p then
        self:_closePopup()
    end
    self._popup = p
    self:_hideTip()
    self._blocker.Visible = true
    local f = p.Frame
    if not p.Shadow then
        p.Shadow = halo(f, { Layers = 6, Spread = 20, OffsetY = 8, Strength = 0.55, Radius = R.Card, Name = "PopupShadow" })
    end
    f.Visible = true
    f.Size = UDim2.fromOffset(p.Size.X, p.Size.Y)
    self:_placePopup(p)
    local final = f.Position
    f.Position = UDim2.new(final.X.Scale, final.X.Offset, final.Y.Scale, final.Y.Offset + (p._above and 10 or -10))
    f.GroupTransparency = 1
    playOn(f, "fade", EASE_MED, { GroupTransparency = 0 })
    playOn(f, "pos", EASE_SPRING, { Position = final })
    p.Shadow.SetFade(1, false)
    p.Shadow.SetFade(0, true)
    if p.OnOpen then
        p.OnOpen()
    end
end

function Window:_closePopup()
    local p = self._popup
    if not p then
        return
    end
    self._popup = nil
    self._blocker.Visible = false
    if p.OnClose then
        p.OnClose()
    end
    local f = p.Frame
    local cur = f.Position
    playOn(f, "fade", EASE_FAST, { GroupTransparency = 1 })
    playOn(f, "pos", EASE_FAST, { Position = UDim2.new(cur.X.Scale, cur.X.Offset, cur.Y.Scale, cur.Y.Offset + (p._above and 6 or -6)) })
    if p.Shadow then p.Shadow.SetFade(1, true) end
    task.delay(0.16, function()
        if self._popup ~= p and f.Parent then
            f.Visible = false
        end
    end)
end

-- keybinds --------------------------------------------------------------------------------
function Window:_registerKeybind(entry)
    table.insert(self._keybinds, entry)
    return entry
end

function Window:_unregisterKeybind(entry)
    local i = table.find(self._keybinds, entry)
    if i then
        table.remove(self._keybinds, i)
    end
end

function Window:_listenKey(cb)
    if self._listening or (os.clock() - self._lastListenEnd) < 0.25 then
        return false
    end
    self._listening = function(result)
        self._lastListenEnd = os.clock()
        cb(result)
    end
    return true
end

function Window:_keybindChip(parent, initial, onBind)
    local chip = { Key = initial }
    local wrap = new("Frame", {
        Name = "KeyChip", AutomaticSize = AS_X, Size = UDim2.fromOffset(0, 25), BackgroundTransparency = 1, Parent = parent,
    })
    -- the lower edge is a second, darker copy of the cap: it reads as a raised keycap
    local edge = new("Frame", {
        Name = "Edge", Position = UDim2.fromOffset(0, 3), Size = UDim2.new(1, 0, 0, 22),
        Theme = { BackgroundColor3 = "Off" }, ZIndex = 1, Parent = wrap,
    })
    corner(edge, 7)
    local face = new("TextButton", {
        Name = "Face", AutomaticSize = AS_X, Size = UDim2.fromOffset(0, 22), Text = "",
        Theme = { BackgroundColor3 = "Panel" }, ZIndex = 2, Parent = wrap,
    })
    corner(face, 7)
    local faceStroke = stroke(face, "Stroke")
    strokeFade(faceStroke, 90, 0, 0.5)
    highlight(face, 5, 0.78)
    new("UISizeConstraint", { MinSize = Vector2.new(36, 22), Parent = face })
    pad(face, 9, 0, 9, 0)
    list(face, 0, HORIZ, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
    local lbl = new("TextLabel", {
        Name = "Key", AutomaticSize = AS_X, Size = UDim2.fromOffset(0, 22), Text = keyName(initial),
        TextSize = 11, Font = FONT.Mono, Theme = { TextColor3 = "SubText" }, Parent = face,
    })
    chip.Frame = wrap
    chip.Face = face

    local function render()
        lbl.Text = keyName(chip.Key)
        play(lbl, EASE_FAST, { TextColor3 = chip.Key and Library.Theme.Text or Library.Theme.SubText })
        play(faceStroke, EASE_FAST, { Color = Library.Theme.Stroke })
    end
    function chip.Set(key)
        chip.Key = key
        render()
    end
    self.Maid:Give(face.MouseButton1Down:Connect(function()
        playOn(face, "press", EASE_FAST, { Position = UDim2.fromOffset(0, 2) })
    end))
    self.Maid:Give(face.MouseButton1Up:Connect(function()
        playOn(face, "press", EASE_POP, { Position = UDim2.fromOffset(0, 0) })
    end))
    self.Maid:Give(face.MouseButton1Click:Connect(function()
        local started = self:_listenKey(function(result)
            if result ~= false then
                chip.Key = result
                if onBind then
                    onBind(result)
                end
            end
            render()
        end)
        if started then
            lbl.Text = "..."
            play(lbl, EASE_FAST, { TextColor3 = Library.Theme.Accent })
            play(faceStroke, EASE_FAST, { Color = Library.Theme.Accent })
        end
    end))
    return chip
end

-- search ---------------------------------------------------------------------------------
function Window:_refreshItem(item)
    item.Frame.Visible = (not item.Hidden) and (self.Query == "" or item.Match)
end

function Window:_applySearch(text)
    local q = ((text or ""):lower()):match("^%s*(.-)%s*$")
    self.Query = q
    local firstMatch
    for _, tab in ipairs(self.Tabs) do
        local total = 0
        for _, sec in ipairs(tab.Sections) do
            local count = 0
            local nameHit = q ~= "" and sec.Name:lower():find(q, 1, true) ~= nil
            for _, item in ipairs(sec.Entries) do
                item.Match = q == "" or nameHit or (item.Name ~= "" and item.Name:find(q, 1, true) ~= nil)
                self:_refreshItem(item)
                if item.Match and not item.Hidden then
                    count = count + 1
                end
            end
            sec.Frame.Visible = q == "" or count > 0
            total = total + count
        end
        tab._matches = total
        if tab._dot then
            tab._dot.Visible = q ~= "" and total > 0
        end
        if total > 0 and not firstMatch and not tab.Hidden then
            firstMatch = tab
        end
    end
    if q ~= "" and self.ActiveTab and self.ActiveTab._matches == 0 and firstMatch then
        self:Select(firstMatch)
    end
end

-- tabs -----------------------------------------------------------------------------------------
-- re-bind a property to a theme key, easing the colour over (stays theme-safe)
local function bindKey(inst, prop, key, animate)
    local old = inst[prop]
    bindTheme(inst, { [prop] = key })
    if animate then
        inst[prop] = old
        play(inst, EASE_FAST, { [prop] = Library.Theme[key] })
    end
end

local function buildIcon(parent, icon, tabName)
    local key = icon and (Library.IconSet[icon] or icon)
    if type(key) == "string" and Icons.Has(key) then
        local h = Icons.Draw(parent, key, 18, "SubText")
        return h, function(k, animate)
            Icons.Bind(h, k, animate)
        end
    end
    if type(key) == "string" and (key:find("^rbxassetid://") or key:find("^rbxasset://") or key:find("^https?://") or tonumber(key)) then
        if tonumber(key) then
            key = "rbxassetid://" .. key
        end
        local i = new("ImageLabel", { Name = "Icon", Size = UDim2.fromOffset(18, 18), Image = key, Theme = { ImageColor3 = "SubText" }, Parent = parent })
        return i, function(k, animate)
            bindKey(i, "ImageColor3", k, animate)
        end
    end
    local text
    if type(icon) == "string" and icon ~= "" and #icon <= 2 then
        text = icon
    else
        text = (tabName or "?"):sub(1, 1):upper()
    end
    local l = new("TextLabel", {
        Name = "Icon", Size = UDim2.fromOffset(18, 18), Text = text, Font = FONT.Bold, TextSize = 14,
        Theme = { TextColor3 = "SubText" }, Parent = parent,
    })
    return l, function(k, animate)
        bindKey(l, "TextColor3", k, animate)
    end
end

function Window:Tab(cfg)
    if type(cfg) == "string" then
        cfg = { Name = cfg }
    end
    return self:_makeTab(cfg or {}, false)
end

function Window:_makeTab(cfg, isSettings)
    local tab = setmetatable({
        Window = self,
        Name = cfg.Name or "Tab",
        Sections = {},
        Hidden = isSettings,
        IsSettings = isSettings,
        Locked = cfg.Locked == true,
        _matches = 0,
        _sideCount = 0,
    }, Tab)

    local page = new("ScrollingFrame", {
        Name = tab.Name, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(),
        AutomaticCanvasSize = AS_Y, ScrollingDirection = Enum.ScrollingDirection.Y,
        Visible = false, Parent = self.Content,
    })
    smartScroll(page, self.Maid)
    pad(page, 0, 0, 10, 8)
    local cols = new("Frame", {
        Name = "Columns", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AS_Y, Parent = page,
    })
    tab.Layout = list(cols, S.LG, HORIZ)
    local function makeCol(name, order)
        local f = new("Frame", {
            Name = name, BackgroundTransparency = 1, Size = UDim2.new(0.5, -8, 0, 0), AutomaticSize = AS_Y,
            LayoutOrder = order, Parent = cols,
        })
        list(f, S.LG)
        return f
    end
    tab.Page = page
    tab.Columns = { Left = makeCol("Left", 1), Right = makeCol("Right", 2) }
    self.Maid:Give(page:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        tab:_layout()
    end))

    local btn
    if isSettings then
        btn = self.AvatarButton
        tab._setActive = function(active, animate)
            apply(self._avatarStroke, { Transparency = active and 0 or 0.45 }, animate ~= false, EASE_MED)
        end
    else
        btn = new("TextButton", {
            Name = tab.Name, Text = "", BackgroundTransparency = 1,
            Size = self.SidebarExpanded and UDim2.new(1, 0, 0, 34) or UDim2.fromOffset(34, 34),
            LayoutOrder = #self.Tabs + 1, Theme = { BackgroundColor3 = "Row" }, Parent = self.TabItems,
        })
        corner(btn, R.Control)
        local icon, setIcon = buildIcon(btn, cfg.Icon, tab.Name)
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.Position = UDim2.fromOffset(17, 17)
        local navLabel = new("TextLabel", {
            Name = "Label", Text = tab.Name, Position = UDim2.fromOffset(42, 0),
            Size = UDim2.new(1, -66, 1, 0), Visible = self.SidebarExpanded == true,
            TextTransparency = self.SidebarExpanded and 0 or 1, TextXAlignment = LEFT,
            TextTruncate = Enum.TextTruncate.AtEnd, TextSize = 12, Font = FONT.Medium,
            Theme = { TextColor3 = "SubText" }, Parent = btn,
        })
        tab._navButton = btn
        tab._navLabel = navLabel
        tab._icon = icon
        tab._dot = new("Frame", {
            Name = "MatchDot", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -3, 0, 3),
            Size = UDim2.fromOffset(6, 6), Visible = false, Theme = { BackgroundColor3 = "Accent" }, Parent = btn,
        })
        corner(tab._dot, 3)
        -- badge: a dot, or a small number pill
        tab._badge = new("Frame", {
            Name = "Badge", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(0, 31, 0, 2), Size = UDim2.fromOffset(8, 8),
            Visible = false, ZIndex = 3, Theme = { BackgroundColor3 = "Accent3" }, Parent = btn,
        })
        corner(tab._badge, 7)
        stroke(tab._badge, "Panel", 1.5)
        tab._badgeText = new("TextLabel", {
            Size = UDim2.fromScale(1, 1), Text = "", Font = FONT.MonoBold, TextSize = 9,
            Theme = { TextColor3 = "OnAccent" }, Parent = tab._badge,
        })
        -- locked tabs show a small lock on the icon
        tab._lock = Icons.Draw(btn, "lock", 11, "Warning", 1.2)
        tab._lock.AnchorPoint = Vector2.new(1, 1)
        tab._lock.Position = UDim2.new(0, 33, 0, 33)
        tab._lock.ZIndex = 3
        tab._lock.Visible = tab.Locked
        tab._setActive = function(active, animate)
            local go = animate ~= false
            setIcon(active and "Accent" or "SubText", go)
            bindKey(navLabel, "TextColor3", active and "Text" or "SubText", go)
            if tab.Locked then icon.Visible = true end
        end
        self.Maid:Give(btn.MouseEnter:Connect(function()
            if self.ActiveTab ~= tab then
                play(btn, EASE_FAST, { BackgroundTransparency = 0.7 })
                setIcon("Text", true)
            end
        end))
        self.Maid:Give(btn.MouseLeave:Connect(function()
            play(btn, EASE_FAST, { BackgroundTransparency = 1 })
            if self.ActiveTab ~= tab then
                setIcon("SubText", true)
            end
        end))
        tab._shake = function()
            if tab._shaking then return end
            tab._shaking = true
            local base = UDim2.fromOffset(17, 17)
            task.spawn(function()
                for _, dx in ipairs({ 4, -4, 3, -2, 0 }) do
                    playOn(icon, "shake", TweenInfo.new(0.05), { Position = UDim2.fromOffset(17 + dx, 17) })
                    task.wait(0.055)
                end
                icon.Position = base
                tab._shaking = false
            end)
        end
        if cfg.Badge ~= nil then
            tab:SetBadge(cfg.Badge)
        end
    end
    tab.Button = btn
    self.Maid:Give(btn.MouseButton1Click:Connect(function()
        self:Select(tab)
    end))
    self:_tooltip(btn, function()
        return { Title = tab.Name .. (tab.Locked and "  (locked)" or "") }
    end, 0.5)

    table.insert(self.Tabs, tab)
    if isSettings then
        self.SettingsTab = tab
    elseif not self.ActiveTab then
        self:Select(tab)
    end
    tab:_layout()
    return tab
end

function Tab:SetBadge(value)
    local badge = self._badge
    if not badge then return end
    if value == nil or value == false then
        badge.Visible = false
        return
    end
    badge.Visible = true
    if value == true then
        self._badgeText.Text = ""
        badge.Size = UDim2.fromOffset(8, 8)
    else
        local text = tostring(value)
        self._badgeText.Text = text
        badge.Size = UDim2.fromOffset(math.max(14, #text * 6 + 8), 14)
    end
    badge.Position = UDim2.new(0, 33, 0, 1)
    badge.AnchorPoint = Vector2.new(1, 0)
    playOn(badge, "pop", EASE_POP, { Size = badge.Size })
end

function Tab:SetLocked(locked)
    self.Locked = locked and true or false
    if self._lock then self._lock.Visible = self.Locked end
    if self.Locked and self.Window.ActiveTab == self then
        local first
        for _, t in ipairs(self.Window.Tabs) do
            if t ~= self and not t.Locked and not t.Hidden then first = t break end
        end
        if first then self.Window:Select(first) end
    end
end

function Window:Select(tab)
    if type(tab) == "string" then
        for _, t in ipairs(self.Tabs) do
            if t.Name == tab then
                tab = t
                break
            end
        end
    end
    if type(tab) ~= "table" or tab == self.ActiveTab then
        return
    end
    if tab.Locked then
        if tab._shake then tab._shake() end
        return
    end
    self:_closePopup()
    local prev = self.ActiveTab
    local dir = 1
    if prev then
        local pi, ni = table.find(self.Tabs, prev), table.find(self.Tabs, tab)
        if pi and ni and ni < pi then dir = -1 end
        prev.Page.Visible = false
        prev._setActive(false)
    end
    self.ActiveTab = tab
    tab.Page.Visible = true
    tab.Page.Position = UDim2.fromOffset(0, 12 * dir)
    play(tab.Page, EASE_SPRING, { Position = UDim2.fromOffset(0, 0) })
    tab._setActive(true)
    tab:_layout()
    if prev then
        self:_syncIndicator(true)
        tab:_enter()
    else
        task.defer(function() self:_syncIndicator(false) end)
        task.delay(0.15, function() self:_syncIndicator(false) end)
    end
end

-- staggered entrance: sections slide up into place ~30ms apart
function Tab:_enter()
    local window = self.Window
    if Library.Animations == false or not window.Visible or window.Query ~= "" then
        return
    end
    self._enterToken = (self._enterToken or 0) + 1
    local token = self._enterToken
    local scale = math.max(window.Scale, 0.01)
    task.defer(function()
        if self._enterToken ~= token then return end
        local order = 0
        for _, sec in ipairs(self.Sections) do
            local f = sec.Frame
            if f.Parent and f.Visible and f.AutomaticSize == AS_Y then
                local h = f.AbsoluteSize.Y / scale
                if h > 0 then
                    order = order + 1
                    local shift = f:FindFirstChild("EnterPad") or new("UIPadding", { Name = "EnterPad", Parent = f })
                    f.AutomaticSize = Enum.AutomaticSize.None
                    f.Size = UDim2.new(1, 0, 0, h)
                    f.ClipsDescendants = true
                    shift.PaddingTop = UDim.new(0, 20)
                    task.delay((order - 1) * 0.03, function()
                        local function finish()
                            if f.Parent then
                                f.AutomaticSize = AS_Y
                                f.Size = UDim2.new(1, 0, 0, 0)
                                f.ClipsDescendants = false
                                shift.PaddingTop = UDim.new(0, 0)
                            end
                        end
                        if not f.Parent then return end
                        local tween = play(shift, EASE_SLIDE, { PaddingTop = UDim.new(0, 0) })
                        if tween then tween.Completed:Once(finish) else finish() end
                    end)
                end
            end
        end
    end)
end

function Tab:_layout()
    local w = self.Page.AbsoluteSize.X / math.max(self.Window.Scale, 0.01)
    local single = self.Window.ForceSingle or (w > 0 and w < 430)
    if self._single == single then
        return
    end
    self._single = single
    self.Layout.FillDirection = single and VERT or HORIZ
    local size = single and UDim2.new(1, 0, 0, 0) or UDim2.new(0.5, -6, 0, 0)
    self.Columns.Left.Size = size
    self.Columns.Right.Size = size
end

function Tab:_lockScroll(locked)
    self.Page.ScrollingEnabled = not locked
end

function Tab:Section(cfg)
    if type(cfg) == "string" then
        cfg = { Name = cfg }
    end
    cfg = cfg or {}
    local side = cfg.Side
    if side ~= "Left" and side ~= "Right" then
        side = (#self.Sections % 2 == 0) and "Left" or "Right"
    end
    local frame = new("Frame", {
        Name = cfg.Name or "Section", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = AS_Y, LayoutOrder = #self.Sections + 1, Parent = self.Columns[side],
    })
    list(frame, cfg.SectionSpacing or S.SM)
    local header = new(cfg.Collapsible and "TextButton" or "TextLabel", {
        Name = "Header", Text = spaced(cfg.Name or "Section"), Size = UDim2.new(1, 0, 0, 22), TextSize = 11,
        Font = FONT.Semi, TextXAlignment = LEFT, LayoutOrder = 0, BackgroundTransparency = 1,
        Theme = { TextColor3 = "Dim" }, Parent = frame,
    })
    if cfg.Collapsible then
        header.AutoButtonColor = false
    end
    pad(header, 14, 0, 26, 0)
    local tick = new("Frame", {
        Name = "Tick", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -11, 0.5, 0), Size = UDim2.fromOffset(3, 12),
        BackgroundColor3 = Color3.new(1, 1, 1), Parent = header,
    })
    corner(tick, 2)
    flowGradient(tick, { rotation = 90, shift = (#self.Sections % 6) * 0.13, periods = 0.55, scope = self.Page })
    local description
    if cfg.Description and cfg.Description ~= "" then
        description = new("TextLabel", {
            Name = "Description", Text = cfg.Description, Size = UDim2.new(1, -6, 0, 0),
            AutomaticSize = AS_Y, TextWrapped = true, TextSize = 11, TextXAlignment = LEFT,
            Font = FONT.Regular, LayoutOrder = 1, Theme = { TextColor3 = "Dim" }, Parent = frame,
        })
        pad(description, 14, 0, 3, 2)
    end
    local items = new("Frame", {
        Name = "Items", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AS_Y,
        LayoutOrder = description and 2 or 1, Parent = frame,
    })
    list(items, cfg.Spacing or S.SM)
    if type(cfg.Padding) == "number" then
        pad(items, cfg.Padding, cfg.Padding, cfg.Padding, cfg.Padding)
    elseif type(cfg.Padding) == "table" then
        pad(items, cfg.Padding.Left or 0, cfg.Padding.Top or 0, cfg.Padding.Right or 0, cfg.Padding.Bottom or 0)
    end

    local section = setmetatable({
        Window = self.Window, Tab = self, Name = cfg.Name or "Section",
        Frame = frame, Header = header, DescriptionLabel = description, Content = items, Entries = {},
        Collapsible = cfg.Collapsible == true, Collapsed = cfg.Collapsed == true,
    }, Section)
    if section.Collapsible then
        section._chevron = Icons.Draw(header, "chevdown", 12, "Dim")
        section._chevron.AnchorPoint = Vector2.new(1, 0.5)
        section._chevron.Position = UDim2.new(1, 22, 0.5, 0)
        section._chevron.Rotation = section.Collapsed and -90 or 0
        header.MouseButton1Click:Connect(function()
            section:SetCollapsed(not section.Collapsed)
        end)
        items.Visible = not section.Collapsed
    end
    table.insert(self.Sections, section)
    return section
end

function Tab:Group(cfg)
    return self:Section(cfg)
end

function Section:SetName(name)
    self.Name = name
    self.Header.Text = spaced(name)
end

function Section:SetDescription(description)
    if not self.DescriptionLabel and description and description ~= "" then
        self.DescriptionLabel = new("TextLabel", {
            Name = "Description", Text = description, Size = UDim2.new(1, -6, 0, 0),
            AutomaticSize = AS_Y, TextWrapped = true, TextSize = 11, TextXAlignment = LEFT,
            Font = FONT.Regular, LayoutOrder = 1, Theme = { TextColor3 = "SubText" }, Parent = self.Frame,
        })
        pad(self.DescriptionLabel, 3, 0, 3, 2)
        if self.Content then self.Content.LayoutOrder = 2 end
    elseif self.DescriptionLabel then
        self.DescriptionLabel.Text = description or ""
        self.DescriptionLabel.Visible = description ~= nil and description ~= ""
    end
end

function Section:SetCollapsed(state)
    if not self.Collapsible then
        return
    end
    state = state and true or false
    self.Collapsed = state
    if self._chevron then
        play(self._chevron, EASE_POP, { Rotation = state and -90 or 0 })
    end

    local content = self.Content
    local window = self.Window
    self._collapseToken = (self._collapseToken or 0) + 1
    local token = self._collapseToken

    local function finish()
        if token ~= self._collapseToken then
            return
        end
        content.ClipsDescendants = false
        content.AutomaticSize = AS_Y
        content.Size = UDim2.new(1, 0, 0, 0)
        content.Visible = not state
    end

    local canAnimate = Library.Animations ~= false and window.Visible and not window.Minimized
        and self.Tab.Page.Visible and content.Parent ~= nil
    if not canAnimate then
        finish()
        return
    end

    local scale = math.max(window.Scale, 0.01)
    if state then
        local height = content.AbsoluteSize.Y / scale
        if height <= 0 then
            finish()
            return
        end
        content.AutomaticSize = Enum.AutomaticSize.None
        content.ClipsDescendants = true
        content.Size = UDim2.new(1, 0, 0, height)
        local tween = play(content, EASE_MED, { Size = UDim2.new(1, 0, 0, 0) })
        if tween then
            tween.Completed:Once(function()
                if token == self._collapseToken then
                    content.Visible = false
                    finish()
                end
            end)
        else
            finish()
        end
    else
        -- show at natural size for a frame so its height can be measured, then grow from zero
        content.AutomaticSize = AS_Y
        content.Visible = true
        task.spawn(function()
            RunService.RenderStepped:Wait()
            if token ~= self._collapseToken then
                return
            end
            local height = content.AbsoluteSize.Y / scale
            if height <= 0 then
                finish()
                return
            end
            content.AutomaticSize = Enum.AutomaticSize.None
            content.ClipsDescendants = true
            content.Size = UDim2.new(1, 0, 0, 0)
            local tween = play(content, EASE_MED, { Size = UDim2.new(1, 0, 0, height) })
            if tween then
                tween.Completed:Once(finish)
            else
                finish()
            end
        end)
    end
end

function Section:ToggleCollapsed()
    self:SetCollapsed(not self.Collapsed)
end

function Section:SetSpacing(spacing)
    local layout = self.Content and self.Content:FindFirstChildOfClass("UIListLayout")
    if layout then layout.Padding = UDim.new(0, math.max(0, tonumber(spacing) or 6)) end
end

function Section:SetPadding(left, top, right, bottom)
    local existing = self.Content and self.Content:FindFirstChildOfClass("UIPadding")
    if existing then existing:Destroy() end
    pad(self.Content, left or 0, top or 0, right or 0, bottom or 0)
end

function Section:Group(cfg)
    return self:Card(cfg)
end

------------------------------------------------------------------------
-- Section helpers
------------------------------------------------------------------------
function Section:_entry(frame, name)
    local item = { Frame = frame, Name = (name or ""):lower(), Hidden = false, Match = true }
    local q = self.Window.Query
    if q ~= "" then
        item.Match = item.Name ~= "" and item.Name:find(q, 1, true) ~= nil
        frame.Visible = item.Match
    end
    table.insert(self.Entries, item)
    return item
end

function Section:_row(cfg, height)
    local window = self.Window
    local std = (height == nil or height == 38)
    local row = new("Frame", {
        Name = cfg.Name or "Row", Size = UDim2.new(1, 0, 0, std and rowH() or height),
        Theme = { BackgroundColor3 = "Row" }, Parent = self.Content,
    })
    if std then
        Library._rows[row] = true
    end
    corner(row, R.Control)
    local rowStroke = stroke(row, "Stroke")
    strokeFade(rowStroke, 90, 0, 0.7)
    highlight(row, 12, 0.9)
    -- hover sheen: a soft light that follows the cursor across the row
    local sheen = new("Frame", {
        Name = "Sheen", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 1),
        Size = UDim2.new(0, 170, 1, -2), BackgroundTransparency = 1, Theme = { BackgroundColor3 = "Highlight" }, Parent = row,
    })
    corner(sheen, R.Control)
    new("UIGradient", { Transparency = seq({ 0, 1 }, { 0.5, 0.93 }, { 1, 1 }), Parent = sheen })
    local hit = new("TextButton", { Name = "Hit", Text = "", Size = UDim2.fromScale(1, 1), Parent = row })
    local maid = window.Maid
    maid:Give(hit.MouseEnter:Connect(function()
        play(row, EASE_FAST, { BackgroundColor3 = Library.Theme.RowHover })
        play(rowStroke, EASE_FAST, { Color = Library.Theme.Stroke:Lerp(Library.Theme.Accent, 0.32) })
        playOn(sheen, "fade", EASE_MED, { BackgroundTransparency = 0 })
    end))
    maid:Give(hit.MouseLeave:Connect(function()
        play(row, EASE_FAST, { BackgroundColor3 = Library.Theme.Row })
        play(rowStroke, EASE_MED, { Color = Library.Theme.Stroke })
        playOn(sheen, "fade", EASE_MED, { BackgroundTransparency = 1 })
    end))
    maid:Give(hit.MouseMoved:Connect(function(x)
        local rel = (x - row.AbsolutePosition.X) / math.max(window._uiscale.Scale, 0.01)
        playOn(sheen, "x", EASE_FAST, { Position = UDim2.new(0, rel, 0, 1) })
    end))
    return row, hit
end

local function initElement(el, section, kind, cfg, row, hit)
    el.Kind = kind
    el.Section = section
    el.Window = section.Window
    el.Cfg = cfg
    el.Row = row
    el.Hit = hit
    el.Changed = Signal.new()
    el.Flag = cfg.Flag
    el._tip = cfg.Tooltip or (cfg.Description and { Title = cfg.Name or kind, Description = cfg.Description })
    el.Description = cfg.Description
    el.Name = cfg.Name or kind
    el._item = section:_entry(row, el.Name)
    if el.Flag then
        local previous = Library.Options[el.Flag]
        if previous and previous ~= el then
            warn("[PrismUI] duplicate Flag '" .. tostring(el.Flag) .. "'; the newest control owns this Flag.")
            el._previousFlagOwner = previous
        end
        Library.Options[el.Flag] = el
    end
    if hit then
        el.Window:_tooltip(hit, function()
            return el._tip
        end, 0.5)
    end
    Library._refreshers[el] = function()
        if el._visual then
            el:_visual(false)
        end
    end
end

local function publish(el)
    -- An older control with a duplicate Flag must not overwrite the newer owner.
    if el.Flag and Library.Options[el.Flag] == el then
        Library.Flags[el.Flag] = el.Value
    end
end

local function buildLeft(el, row, cfg, fallback, rightFrame)
    local left = new("Frame", {
        Name = "Left", BackgroundTransparency = 1, AutomaticSize = AS_X, Size = UDim2.new(0, 0, 1, 0),
        Position = UDim2.fromOffset(14, 0), Parent = row,
    })
    list(left, 7, HORIZ, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
    local label = new("TextLabel", {
        Name = "Label", Text = cfg.Name or fallback, AutomaticSize = AS_X, Size = UDim2.new(0, 0, 1, 0),
        TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = 1, Parent = left,
    })
    local constraint = new("UISizeConstraint", { MaxSize = Vector2.new(9999, 9999), Parent = label })
    local info = Icons.Info(left)
    info.LayoutOrder = 2
    info.Visible = cfg.Tooltip ~= nil
    el._label = label
    el._info = info
    el.Window:_tooltip(info, function()
        return el._tip
    end, 0.15)

    local function fit()
        local scale = math.max(el.Window.Scale, 0.01)
        local rightW = rightFrame and rightFrame.AbsoluteSize.X / scale or 0
        local avail = row.AbsoluteSize.X / scale - rightW - 46 - (info.Visible and 21 or 0)
        constraint.MaxSize = Vector2.new(math.max(40, avail), 9999)
    end
    el.Window.Maid:Give(row:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))
    if rightFrame then
        el.Window.Maid:Give(rightFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))
    end
    task.defer(fit)
    return left
end

local function buildRight(row, spacing)
    local right = new("Frame", {
        Name = "Right", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0), AutomaticSize = AS_X, Size = UDim2.fromOffset(0, 26), Parent = row,
    })
    list(right, spacing or 8, HORIZ, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
    return right
end

------------------------------------------------------------------------
-- Element base
------------------------------------------------------------------------
function Element:_commit()
    -- Disabled blocks user input, not deliberate programmatic SetValue calls.
    -- Keep Flags and observers in sync when a script updates a disabled control.
    publish(self)
    self.Changed:Fire(self.Value)
    safeCall(self.Cfg.Callback, self.Value)
end

function Element:Get()
    return self.Value
end

function Element:OnChanged(fn)
    return self.Changed:Connect(fn)
end

function Element:Serialize()
    return self.Value
end

function Element:Deserialize(v)
    self:SetValue(v)
end

function Element:SetVisible(visible)
    self._item.Hidden = not visible
    self.Window:_refreshItem(self._item)
end

function Element:SetTooltip(tip)
    self._tip = tip
    if self._info then
        self._info.Visible = tip ~= nil
    end
end

function Element:SetDescription(description)
    self.Description = description
    self._tip = description and { Title = self.Name, Description = description } or self.Cfg.Tooltip
    if self._info then
        self._info.Visible = self._tip ~= nil
    end
end

function Element:SetCallback(callback)
    self.Cfg.Callback = callback
end

function Element:SetDisabled(disabled)
    self.Disabled = disabled and true or false
    if self.Disabled and self._onDisabled then
        pcall(self._onDisabled)
    end
    if self.Row then
        self.Row.BackgroundTransparency = self.Disabled and 0.28 or 0
        self.Row.Active = not self.Disabled
        for _, child in ipairs(self.Row:GetDescendants()) do
            if child:IsA("GuiObject") then
                pcall(function() child.Active = not self.Disabled end)
            end
            if child:IsA("GuiButton") then
                child.Selectable = not self.Disabled
            elseif child:IsA("TextBox") then
                child.TextEditable = not self.Disabled
            end
        end
        if self.Hit then
            self.Hit.Active = not self.Disabled
        end
    end
end

function Element:SetName(name)
    name = tostring(name or self.Name)
    self.Name = name
    self._item.Name = name:lower()
    if self._label then
        self._label.Text = name
    end
    if self.Window then
        self.Window:_applySearch(self.Window.Query)
    end
end

function Element:Destroy()
    if self._destroyed then
        return
    end
    self._destroyed = true
    Library._refreshers[self] = nil
    local i = table.find(self.Section.Entries, self._item)
    if i then
        table.remove(self.Section.Entries, i)
    end
    if self.Flag and Library.Options[self.Flag] == self then
        local previous = self._previousFlagOwner
        while previous and previous._destroyed do
            previous = previous._previousFlagOwner
        end
        if previous then
            Library.Options[self.Flag] = previous
            Library.Flags[self.Flag] = previous.Value
        else
            Library.Flags[self.Flag] = nil
            Library.Options[self.Flag] = nil
        end
    end
    if self._onDestroy then
        pcall(self._onDestroy)
    end
    if self.Row and self.Row.Parent then
        self.Row:Destroy()
    end
end

------------------------------------------------------------------------
-- Toggle
------------------------------------------------------------------------
function Section:Toggle(cfg)
    cfg = cfg or {}
    local window = self.Window
    local row, hit = self:_row(cfg, 38)
    local el = setmetatable({}, Toggle)
    initElement(el, self, "Toggle", cfg, row, hit)
    el.Value = cfg.Default == true

    local right = buildRight(row, 8)
    buildLeft(el, row, cfg, "Toggle", right)

    if cfg.Keybind ~= nil and cfg.Keybind ~= false then
        el.Key = typeof(cfg.Keybind) == "EnumItem" and cfg.Keybind or nil
        el._chip = window:_keybindChip(right, el.Key, function(key)
            el.Key = key
            if el.Flag then
                el.Changed:Fire(el.Value)
            end
        end)
        el._chip.Frame.LayoutOrder = 1
        el._kb = window:_registerKeybind({
            Get = function()
                if el.Disabled or el._destroyed then return nil end
                return el.Key
            end,
            Down = function()
                if el.Disabled or el._destroyed then return end
                el:SetValue(not el.Value)
            end,
        })
    end

    local switch = new("Frame", { Name = "Switch", Size = UDim2.fromOffset(40, 22), BackgroundTransparency = 1, LayoutOrder = 2, Parent = right })
    el._glow = glow(switch, { Layers = 5, Spread = 9, Strength = 0.42, Radius = 11, ZIndex = 1 })
    local track = new("Frame", { Name = "Track", Size = UDim2.fromScale(1, 1), ZIndex = 2, Theme = { BackgroundColor3 = "Off" }, Parent = switch })
    corner(track, 11)
    stroke(track, "Stroke", 1, 0.35)
    local fill = new("Frame", {
        Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1,
        ZIndex = 2, Parent = track,
    })
    corner(fill, 11)
    el._fillGrad = flowGradient(fill, { rotation = 0, shift = 0.05, periods = 0.9, scope = self.Tab.Page })
    el._fillGrad.Enabled = false
    local knob = new("Frame", {
        Name = "Knob", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.fromOffset(16, 16), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = switch,
    })
    corner(knob, 8)
    local tick = Icons.Draw(knob, "check", 10, Color3.fromRGB(96, 72, 160), 1.3)
    tick.AnchorPoint = Vector2.new(0.5, 0.5)
    tick.Position = UDim2.fromScale(0.5, 0.5)
    el._tick = tick
    el._switch, el._knob, el._fill = switch, knob, fill

    window.Maid:Give(hit.MouseButton1Click:Connect(function()
        el:SetValue(not el.Value)
    end))
    el._onDestroy = function()
        if el._kb then
            window:_unregisterKeybind(el._kb)
        end
    end

    el:_visual(false)
    publish(el)
    return el
end

function Toggle:_visual(animate)
    local on = self.Value
    local knob = self._knob
    local goal = on and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
    if on then
        self._fillGrad.Enabled = true
    else
        task.delay(0.3, function()
            if not self.Value and self._fillGrad.Parent then
                self._fillGrad.Enabled = false
            end
        end)
    end
    apply(self._fill, { BackgroundTransparency = on and 0 or 1 }, animate, EASE_MED)
    self._glow.SetAlpha(on and 1 or 0, animate)
    Icons.SetAlpha(self._tick, on and 0 or 1, animate)
    if animate then
        playOn(knob, "pos", EASE_SPRING, { Position = goal })
        playOn(knob, "size", EASE_FAST, { Size = UDim2.fromOffset(22, 16) })
        task.delay(0.12, function()
            if knob.Parent then
                playOn(knob, "size", EASE_POP, { Size = UDim2.fromOffset(16, 16) })
            end
        end)
    else
        local set = channels[knob]
        if set then
            if set.pos then set.pos:Cancel() end
            if set.size then set.size:Cancel() end
        end
        knob.Position = goal
        knob.Size = UDim2.fromOffset(16, 16)
    end
end

function Toggle:SetValue(value, silent)
    value = value and true or false
    if value == self.Value then
        return
    end
    self.Value = value
    self:_visual(true)
    if not silent then
        self:_commit()
    else
        publish(self)
    end
end

function Toggle:SetKey(key)
    self.Key = key
    if self._chip then
        self._chip.Set(key)
    end
end

function Toggle:Serialize()
    if self._chip then
        return { v = self.Value, k = self.Key or false }
    end
    return self.Value
end

function Toggle:Deserialize(data)
    if type(data) == "table" then
        self:SetKey(data.k or nil)
        self:SetValue(data.v)
    else
        self:SetValue(data)
    end
end

------------------------------------------------------------------------
-- Slider
------------------------------------------------------------------------
function Section:Slider(cfg)
    cfg = cfg or {}
    local window = self.Window
    local row, hit = self:_row(cfg, 38)
    local el = setmetatable({}, Slider)
    initElement(el, self, "Slider", cfg, row, hit)

    el.Min = cfg.Min or 0
    el.Max = cfg.Max or 100
    el.Increment = cfg.Increment or 1
    el.Suffix = cfg.Suffix or ""
    el._dec = decimals(el.Increment)
    el.Value = math.clamp(cfg.Default or el.Min, el.Min, el.Max)

    local right = buildRight(row, 8)
    buildLeft(el, row, cfg, "Slider", right)

    local box = new("TextBox", {
        Name = "Value", Size = UDim2.fromOffset(56, 22), Text = "", Font = FONT.Mono, TextSize = 12,
        TextXAlignment = RIGHT, LayoutOrder = 1, Theme = { TextColor3 = "Accent" }, Parent = right,
    })
    local area = new("TextButton", { Name = "TrackArea", Text = "", Size = UDim2.fromOffset(136, 28), LayoutOrder = 2, Parent = right })
    local track = new("Frame", {
        Name = "Track", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0),
        Size = UDim2.new(1, -16, 0, 6), Theme = { BackgroundColor3 = "Track" }, Parent = area,
    })
    corner(track, 3)
    local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = track })
    corner(fill, 3)
    flowGradient(fill, { shift = 0.1, periods = 0.8, scope = self.Tab.Page })
    local knob = new("Frame", {
        Name = "Knob", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1, Parent = track,
    })
    local knobGlow = glow(knob, { Layers = 4, Spread = 8, Strength = 0.55, Radius = 11, ZIndex = 1 })
    local core = new("Frame", {
        Name = "Core", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 2, Parent = knob,
    })
    corner(core, 8)
    stroke(core, "Accent", 2)

    -- floating value bubble above the knob while dragging
    local bubble = new("TextLabel", {
        Name = "SliderBubble", AnchorPoint = Vector2.new(0.5, 1), AutomaticSize = AS_X, Size = UDim2.fromOffset(0, 22),
        Text = "", Font = FONT.MonoBold, TextSize = 11, BackgroundTransparency = 1, TextTransparency = 1,
        BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 30, Theme = { TextColor3 = "OnAccent" }, Parent = window.Overlay,
    })
    corner(bubble, 8)
    pad(bubble, 9, 0, 9, 0)
    flowGradient(bubble, { rotation = 20, shift = 0.35, scope = self.Tab.Page })
    local bubbleOn = false
    local function placeBubble()
        local s = math.max(window._uiscale.Scale, 0.01)
        local p = (knob.AbsolutePosition + knob.AbsoluteSize / 2 - window.Overlay.AbsolutePosition) / s
        bubble.Position = UDim2.fromOffset(p.X, p.Y - 16)
    end
    local function showBubble(on)
        bubbleOn = on
        if on then placeBubble() end
        playOn(bubble, "fade", EASE_FAST, { BackgroundTransparency = on and 0 or 1, TextTransparency = on and 0 or 1 })
    end
    window.Maid:Give(knob:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
        if bubbleOn then placeBubble() end
    end))
    el._box, el._fill, el._knob, el._track, el._bubble = box, fill, knob, track, bubble

    local dragging, hovering = false, false
    local function knobState()
        local mode = dragging and 2 or (hovering and 1 or 0)
        local size = mode == 2 and 18 or (mode == 1 and 16 or 14)
        playOn(core, "size", EASE_POP, { Size = UDim2.fromOffset(size, size) })
        knobGlow.SetAlpha(mode == 2 and 1 or (mode == 1 and 0.55 or 0), true)
    end
    window.Maid:Give(area.MouseEnter:Connect(function() hovering = true knobState() end))
    window.Maid:Give(area.MouseLeave:Connect(function() hovering = false knobState() end))

    local moveConn, endConn
    local function fromInput(input)
        local w = track.AbsoluteSize.X
        if w <= 0 then
            return
        end
        local a = math.clamp((input.Position.X - track.AbsolutePosition.X) / w, 0, 1)
        -- fine-grained sliders follow the cursor continuously (the readout still snaps to
        -- Increment); coarse ones glide between their steps instead of teleporting
        local fine = (el.Max - el.Min) / math.max(el.Increment, 1e-9) > 60
        el:SetValue(el.Min + (el.Max - el.Min) * a, false, fine)
        if fine then
            apply(fill, { Size = UDim2.fromScale(a, 1) }, false)
            apply(knob, { Position = UDim2.fromScale(a, 0.5) }, false)
        end
    end
    local function stopDrag()
        if moveConn then
            moveConn:Disconnect()
            moveConn = nil
        end
        if endConn then
            endConn:Disconnect()
            endConn = nil
        end
        if dragging then
            dragging = false
            self.Tab:_lockScroll(false)
            knobState()
            showBubble(false)
            el:_visual(true) -- ease the fill/knob onto the snapped value
        end
    end
    window.Maid:Give(stopDrag)
    window.Maid:Give(area.InputBegan:Connect(function(input)
        if isPress(input) then
            stopDrag()
            dragging = true
            self.Tab:_lockScroll(true)
            window:_hideTip()
            knobState()
            showBubble(true)
            fromInput(input)
            -- only listen to global input while this slider is actually being dragged
            moveConn = UserInputService.InputChanged:Connect(function(moved)
                if isMove(moved) then
                    fromInput(moved)
                end
            end)
            endConn = UserInputService.InputEnded:Connect(function(ended)
                if isPress(ended) then
                    stopDrag()
                end
            end)
        end
    end))

    window.Maid:Give(box.Focused:Connect(function()
        box.Text = string.format("%." .. el._dec .. "f", el.Value)
    end))
    window.Maid:Give(box.FocusLost:Connect(function()
        local n = tonumber(box.Text:match("-?%d+%.?%d*"))
        if n then
            el:SetValue(n)
        end
        el:_visual(false)
    end))
    el._onDestroy = function()
        bubble:Destroy()
    end

    el:_visual(false)
    publish(el)
    return el
end

function Slider:_visual(animate)
    local range = self.Max - self.Min
    local a = range == 0 and 0 or (self.Value - self.Min) / range
    apply(self._fill, { Size = UDim2.fromScale(a, 1) }, animate, EASE_FAST)
    apply(self._knob, { Position = UDim2.fromScale(a, 0.5) }, animate, EASE_FAST)
    local text = string.format("%." .. self._dec .. "f", self.Value) .. self.Suffix
    if not self._box:IsFocused() then
        self._box.Text = text
    end
    self._bubble.Text = text
end

function Slider:SetValue(value, silent, instant)
    value = tonumber(value)
    if not value then
        return
    end
    value = roundTo(value - self.Min, self.Increment) + self.Min
    value = math.clamp(value, self.Min, self.Max)
    value = tonumber(string.format("%." .. self._dec .. "f", value))
    if value == self.Value then
        return
    end
    self.Value = value
    self:_visual(not instant)
    if not silent then
        self:_commit()
    else
        publish(self)
    end
end

function Slider:SetRange(min, max)
    min, max = tonumber(min), tonumber(max)
    if not min or not max then
        return false
    end
    if max < min then
        min, max = max, min
    end
    if max == min then
        max = min + 1
    end
    self.Min, self.Max = min, max
    self:SetValue(math.clamp(self.Value, min, max), true, true)
    -- A range can change the fill position even when the clamped numeric value
    -- remains the same, so refresh visuals and the published Flag explicitly.
    self:_visual(false)
    publish(self)
    return true
end

------------------------------------------------------------------------
-- Dropdown
------------------------------------------------------------------------
function Section:Dropdown(cfg)
    cfg = cfg or {}
    local window = self.Window
    local row, hit = self:_row(cfg, 38)
    local el = setmetatable({}, Dropdown)
    initElement(el, self, "Dropdown", cfg, row, hit)

    el.Multi = cfg.Multi == true
    el.Options = cfg.Options or {}
    el.Value = el.Multi and {} or nil

    local right = buildRight(row, 8)
    buildLeft(el, row, cfg, "Dropdown", right)

    local valueLabel = new("TextLabel", {
        Name = "Value", AutomaticSize = AS_X, Size = UDim2.fromOffset(0, 26), TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = RIGHT, LayoutOrder = 1,
        Theme = { TextColor3 = "SubText" }, Parent = right,
    })
    new("UISizeConstraint", { MaxSize = Vector2.new(150, 26), Parent = valueLabel })
    local chevron = Icons.Draw(right, "chevdown", 14, "Dim")
    chevron.LayoutOrder = 2
    el._valueLabel, el._chevron = valueLabel, chevron

    -- popup: fades + slides in, rounded clipping, soft shadow
    local popFrame = new("CanvasGroup", {
        Name = "DropdownPopup", Visible = false, ZIndex = 2, Size = UDim2.fromOffset(160, 0), GroupTransparency = 1,
        Theme = { BackgroundColor3 = "Panel" }, Parent = window.Overlay,
    })
    corner(popFrame, R.Card)
    strokeFade(stroke(popFrame, "Stroke"), 90, 0, 0.5)
    local searchBox
    local listFrame = new("ScrollingFrame", {
        Name = "List", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 1, -12),
        CanvasSize = UDim2.new(), AutomaticCanvasSize = AS_Y, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = popFrame,
    })
    smartScroll(listFrame, window.Maid)
    pad(listFrame, 6, 0, 6, 0)
    list(listFrame, 2)

    local popup = { Frame = popFrame, Anchor = row, Size = Vector2.new(160, 100) }
    el._popup = popup
    local buttons = {}

    local function isSelected(opt)
        if el.Multi then
            return el.Value[opt] == true
        end
        return el.Value == opt
    end

    local function styleOptions(animate)
        for opt, b in pairs(buttons) do
            local sel = isSelected(opt)
            if el.Multi then
                apply(b.Box, { BackgroundColor3 = sel and Library.Theme.Accent or Library.Theme.Track }, animate, EASE_FAST)
                b.Check.Visible = sel
                apply(b.Text, { TextColor3 = sel and Library.Theme.Text or Library.Theme.SubText }, animate, EASE_FAST)
            else
                apply(b.Frame, { BackgroundTransparency = sel and 0.86 or 1 }, animate, EASE_FAST)
                apply(b.Text, { TextColor3 = sel and Library.Theme.Accent or Library.Theme.Text }, animate, EASE_FAST)
                apply(b.Bar, { BackgroundTransparency = sel and 0 or 1, Size = UDim2.fromOffset(3, sel and 14 or 4) }, animate, EASE_POP)
            end
        end
    end
    el._styleOptions = styleOptions

    local function rebuild()
        for _, child in ipairs(listFrame:GetChildren()) do
            if child:IsA("GuiObject") then
                child:Destroy()
            end
        end
        table.clear(buttons)
        if #el.Options == 0 then
            new("TextLabel", {
                Text = "No options", Size = UDim2.new(1, 0, 0, 28), TextSize = 12,
                Theme = { TextColor3 = "SubText" }, Parent = listFrame,
            })
        end
        for i, opt in ipairs(el.Options) do
            local b = new("TextButton", {
                Name = tostring(opt), Text = "", Size = UDim2.new(1, 0, 0, 28), LayoutOrder = i,
                BackgroundTransparency = 1, Theme = { BackgroundColor3 = "Accent" }, Parent = listFrame,
            })
            corner(b, 8)
            local entry = { Frame = b }
            if el.Multi then
                entry.Box = new("Frame", {
                    Name = "Box", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 9, 0.5, 0),
                    Size = UDim2.fromOffset(16, 16), Theme = { BackgroundColor3 = "Track" }, Parent = b,
                })
                corner(entry.Box, 5)
                entry.Check = Icons.Check(entry.Box)
                entry.Check.Visible = false
            else
                entry.Bar = new("Frame", {
                    Name = "Bar", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0),
                    Size = UDim2.fromOffset(3, 4), BackgroundTransparency = 1, Theme = { BackgroundColor3 = "Accent" }, Parent = b,
                })
                corner(entry.Bar, 2)
            end
            entry.Text = new("TextLabel", {
                Name = "Text", Text = tostring(opt), Position = UDim2.fromOffset(el.Multi and 34 or 12, 0),
                Size = UDim2.new(1, el.Multi and -40 or -18, 1, 0), TextSize = 12, TextXAlignment = LEFT,
                TextTruncate = Enum.TextTruncate.AtEnd, Parent = b,
            })
            buttons[opt] = entry
            b.MouseEnter:Connect(function()
                if not isSelected(opt) or el.Multi then
                    play(b, EASE_FAST, { BackgroundTransparency = 0.92 })
                end
            end)
            b.MouseLeave:Connect(function()
                if el.Multi or not isSelected(opt) then
                    play(b, EASE_FAST, { BackgroundTransparency = 1 })
                else
                    play(b, EASE_FAST, { BackgroundTransparency = 0.86 })
                end
            end)
            b.MouseButton1Click:Connect(function()
                if el.Multi then
                    local copy = table.clone(el.Value)
                    copy[opt] = (not copy[opt]) or nil
                    el:SetValue(copy)
                else
                    el:SetValue(opt)
                    window:_closePopup()
                end
            end)
        end
        styleOptions(false)
    end
    el._rebuild = rebuild

    local function popupHeight()
        local rows = math.max(1, math.min(#el.Options, 7))
        local hasSearch = cfg.Searchable == true or cfg.Search == true or #el.Options > 7
        return 12 + rows * 30 + (hasSearch and 36 or 0)
    end

    local function ensureSearch()
        local want = cfg.Searchable == true or cfg.Search == true or #el.Options > 7
        if want and not searchBox then
            searchBox = new("TextBox", {
                Name = "Search", Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 28),
                Text = "", PlaceholderText = "Search...", TextSize = 12, TextXAlignment = LEFT,
                Theme = { BackgroundColor3 = "Row", PlaceholderColor3 = "Dim" }, BackgroundTransparency = 0,
                Parent = popFrame,
            })
            corner(searchBox, 8)
            pad(searchBox, 10, 0, 10, 0)
            listFrame.Position = UDim2.fromOffset(0, 40)
            listFrame.Size = UDim2.new(1, 0, 1, -46)
            searchBox:GetPropertyChangedSignal("Text"):Connect(function()
                local q = searchBox.Text:lower()
                for opt, b in pairs(buttons) do
                    b.Frame.Visible = q == "" or tostring(opt):lower():find(q, 1, true) ~= nil
                end
            end)
        elseif not want and searchBox then
            searchBox:Destroy()
            searchBox = nil
            listFrame.Position = UDim2.fromOffset(0, 6)
            listFrame.Size = UDim2.new(1, 0, 1, -12)
        end
    end

    popup.OnOpen = function()
        play(chevron, EASE_POP, { Rotation = 180 })
    end
    popup.OnClose = function()
        play(chevron, EASE_MED, { Rotation = 0 })
        if searchBox then
            searchBox.Text = ""
        end
    end

    window.Maid:Give(hit.MouseButton1Click:Connect(function()
        if window._popup == popup then
            window:_closePopup()
            return
        end
        ensureSearch()
        popup.Size = Vector2.new(row.AbsoluteSize.X / window.Scale, popupHeight())
        window:_openPopup(popup)
    end))
    el._onDestroy = function()
        if popup.Shadow then popup.Shadow.Destroy() end
        popFrame:Destroy()
    end

    rebuild()
    if cfg.Default ~= nil then
        el:SetValue(cfg.Default, true)
    else
        el:_visual(false)
    end
    publish(el)
    return el
end

function Dropdown:_visual()
    local text
    if self.Multi then
        local picked = {}
        for _, opt in ipairs(self.Options) do
            if self.Value[opt] then
                table.insert(picked, tostring(opt))
            end
        end
        if #picked == 0 then
            text = "None"
        elseif #picked <= 2 then
            text = table.concat(picked, ", ")
        else
            text = #picked .. " selected"
        end
    else
        text = self.Value ~= nil and tostring(self.Value) or "None"
    end
    self._valueLabel.Text = text
    self._styleOptions(false)
end

function Dropdown:SetValue(value, silent)
    if self.Multi then
        local set = {}
        if type(value) == "table" then
            for k, v in pairs(value) do
                if type(k) == "number" then
                    set[v] = true
                elseif v then
                    set[k] = true
                end
            end
        end
        self.Value = set
    else
        if value ~= nil and not table.find(self.Options, value) then
            return
        end
        self.Value = value
    end
    self:_visual()
    if not silent then
        self:_commit()
    else
        publish(self)
    end
end

function Dropdown:GetSelected()
    if not self.Multi then
        return self.Value
    end
    local out = {}
    for _, opt in ipairs(self.Options) do
        if self.Value[opt] then
            table.insert(out, opt)
        end
    end
    return out
end

function Dropdown:SetOptions(options, keepValue)
    self.Options = options or {}
    if not keepValue then
        self.Value = self.Multi and {} or nil
    elseif self.Multi then
        local set = {}
        for _, opt in ipairs(self.Options) do
            if self.Value[opt] then
                set[opt] = true
            end
        end
        self.Value = set
    elseif self.Value ~= nil and not table.find(self.Options, self.Value) then
        self.Value = nil
    end
    self._rebuild()
    self:_visual()
    publish(self)
end

function Section:SearchDropdown(cfg)
    cfg = table.clone(cfg or {})
    cfg.Searchable = true
    return self:Dropdown(cfg)
end

------------------------------------------------------------------------
-- Keybind element
------------------------------------------------------------------------
function Section:Keybind(cfg)
    cfg = cfg or {}
    local window = self.Window
    local row, hit = self:_row(cfg, 38)
    local el = setmetatable({}, Keybind)
    initElement(el, self, "Keybind", cfg, row, hit)

    el.Mode = cfg.Mode or "Press" -- Press | Toggle | Hold
    el.Value = typeof(cfg.Default) == "EnumItem" and cfg.Default or nil
    el.Active = false

    local right = buildRight(row, 8)
    buildLeft(el, row, cfg, "Keybind", right)

    el._chip = window:_keybindChip(right, el.Value, function(key)
        el:SetValue(key)
    end)
    el._kb = window:_registerKeybind({
        Get = function()
            if el.Disabled or el._destroyed then return nil end
            return el.Value
        end,
        Down = function()
            if el.Disabled or el._destroyed then return end
            if el.Mode == "Toggle" then
                el.Active = not el.Active
            else
                el.Active = true
            end
            el.Triggered:Fire(el.Active)
            safeCall(cfg.Callback, el.Active)
        end,
        Up = function()
            if el.Disabled or el._destroyed then return end
            if el.Mode == "Hold" then
                el.Active = false
                el.Triggered:Fire(false)
                safeCall(cfg.Callback, false)
            end
        end,
    })
    el._onDisabled = function()
        if el.Active then
            el.Active = false
            el.Triggered:Fire(false)
            safeCall(cfg.Callback, false)
        end
    end
    el.Triggered = Signal.new()
    el._onDestroy = function()
        window:_unregisterKeybind(el._kb)
    end

    publish(el)
    return el
end

function Keybind:SetValue(key, silent)
    self.Value = key
    if self._chip then
        self._chip.Set(key)
    end
    if not silent then
        publish(self)
        self.Changed:Fire(key)
        safeCall(self.Cfg.OnBind, key)
    else
        publish(self)
    end
end

function Keybind:Serialize()
    return self.Value or false
end

function Keybind:Deserialize(v)
    self:SetValue(v or nil)
end

function Keybind:OnTriggered(fn)
    return self.Triggered:Connect(fn)
end

------------------------------------------------------------------------
-- Textbox
------------------------------------------------------------------------
function Section:Textbox(cfg)
    cfg = cfg or {}
    local window = self.Window
    local row, hit = self:_row(cfg, 38)
    local el = setmetatable({}, Textbox)
    initElement(el, self, "Textbox", cfg, row, hit)
    el.Value = tostring(cfg.Default or "")

    local right = buildRight(row, 8)
    buildLeft(el, row, cfg, "Textbox", right)

    local holder = new("Frame", {
        Name = "Field", Size = UDim2.fromOffset(cfg.Width or 140, 26), Theme = { BackgroundColor3 = "Panel" }, Parent = right,
    })
    corner(holder, R.Chip)
    local fieldStroke = stroke(holder, "Stroke")
    strokeFade(fieldStroke, 90, 0, 0.5)
    local fieldGlow = halo(holder, {
        Parent = row, Abs = true, Scale = window._scaleFn, Layers = 5, Spread = 7, Strength = 0.4, Radius = R.Chip,
        ColorKey = "Accent", ZIndex = 0, Name = "FocusGlow",
    })
    fieldGlow.SetFade(1, false)
    local box = new("TextBox", {
        Name = "Input", Size = UDim2.fromScale(1, 1), Text = el.Value, PlaceholderText = cfg.Placeholder or "",
        TextSize = 12, TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd,
        Theme = { PlaceholderColor3 = "Dim" }, Parent = holder,
    })
    pad(box, 10, 0, 10, 0)
    el._box = box

    window.Maid:Give(box.Focused:Connect(function()
        play(fieldStroke, EASE_FAST, { Color = Library.Theme.Accent })
        fieldGlow.SetFade(0, true)
    end))
    window.Maid:Give(box.FocusLost:Connect(function()
        play(fieldStroke, EASE_FAST, { Color = Library.Theme.Stroke })
        fieldGlow.SetFade(1, true)
        el:SetValue(box.Text)
    end))
    el._onDestroy = function()
        fieldGlow.Destroy()
    end
    if cfg.Numeric then
        window.Maid:Give(box:GetPropertyChangedSignal("Text"):Connect(function()
            local cleaned = box.Text:gsub("[^%d%.%-]", "")
            if cleaned ~= box.Text then
                box.Text = cleaned
            end
        end))
    end
    if cfg.LiveUpdate then
        window.Maid:Give(box:GetPropertyChangedSignal("Text"):Connect(function()
            el:SetValue(box.Text)
        end))
    end

    publish(el)
    return el
end

function Textbox:_visual()
    if self._box.Text ~= self.Value then
        self._box.Text = self.Value
    end
end

function Textbox:SetValue(text, silent)
    text = tostring(text or "")
    if text == self.Value then
        return
    end
    self.Value = text
    self:_visual()
    if not silent then
        self:_commit()
    else
        publish(self)
    end
end

------------------------------------------------------------------------
-- Button
------------------------------------------------------------------------
local BUTTON_STYLES = {
    primary = { flow = true },
    gradient = { flow = true, shift = 0.35 },
    secondary = { bg = "Accent", text = "Accent", transparency = 0.86, stroke = "Accent" },
    danger = { bg = "Danger", text = "Danger", transparency = 0.86, stroke = "Danger" },
    success = { bg = "Success", text = "Success", transparency = 0.86, stroke = "Success" },
    warning = { bg = "Warning", text = "Warning", transparency = 0.86, stroke = "Warning" },
    ghost = { bg = "Panel", text = "SubText", transparency = 1 },
}

local function styleChip(el, variant)
    local chip = el._chip
    local style = BUTTON_STYLES[variant] or BUTTON_STYLES.secondary
    if el._chipGrad then
        Flow.items[el._chipGrad] = nil
        el._chipGrad:Destroy()
        el._chipGrad = nil
    end
    if el._chipStroke then
        el._chipStroke:Destroy()
        el._chipStroke = nil
    end
    local bound = themed[chip]
    if bound then bound.BackgroundColor3 = nil end
    if style.flow then
        chip.BackgroundColor3 = Color3.new(1, 1, 1)
        chip.BackgroundTransparency = 0
        bindTheme(chip, { TextColor3 = "OnAccent" })
        el._chipGrad = flowGradient(chip, { rotation = 15, shift = style.shift or 0, scope = el.Section.Tab.Page })
    else
        bindTheme(chip, { BackgroundColor3 = style.bg, TextColor3 = style.text })
        chip.BackgroundTransparency = style.transparency
        if style.stroke then
            el._chipStroke = stroke(chip, style.stroke, 1, 0.55)
        end
    end
    el._styleFlow = style.flow == true
    if el._glow then
        el._glow.SetFade(style.flow and 0.55 or 1, false)
    end
end

-- Button feedback is deliberately non-expanding. A previous ripple implementation
-- created temporary descendants under an AutomaticSize TextButton; depending on UI
-- measurement/layout timing those descendants could affect the measured button bounds.
-- A bounded UIScale press + glow pulse gives feedback without adding layout children.

function Section:Button(cfg)
    cfg = cfg or {}
    local window = self.Window
    local row, hit = self:_row(cfg, 38)
    local el = setmetatable({}, Button)
    initElement(el, self, "Button", cfg, row, hit)

    buildLeft(el, row, cfg, "Button", nil)
    local variant = (cfg.Variant or cfg.Style or "Secondary"):lower()
    local chip = new("TextButton", {
        Name = "Chip", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
        AutomaticSize = AS_X, Size = UDim2.fromOffset(0, cfg.ButtonHeight or 26), ClipsDescendants = true,
        Text = (cfg.Icon and (tostring(cfg.Icon) .. "  ") or "") .. (cfg.ButtonText or "Run"), TextSize = 12,
        Font = FONT.Semi, ZIndex = 2, Parent = row,
    })
    corner(chip, R.Chip)
    pad(chip, 14, 0, 14, 0)
    local press = new("UIScale", { Scale = 1, Parent = chip })
    el._chip = chip
    el.Variant = variant
    el._glow = halo(chip, {
        Parent = row, Abs = true, Scale = window._scaleFn, Layers = 5, Spread = 9, OffsetY = 2, Strength = 0.4,
        Radius = R.Chip, ColorKey = "Accent", ZIndex = 1, Name = "ButtonGlow",
    })
    styleChip(el, variant)
    el._onDestroy = function()
        el._glow.Destroy()
    end

    -- real states: hover lift + glow, press-down scale, ripple from the click point
    local base = UDim2.new(1, -14, 0.5, 0)
    window.Maid:Give(chip.MouseEnter:Connect(function()
        if el.Disabled then return end
        playOn(chip, "lift", EASE_POP, { Position = UDim2.new(1, -14, 0.5, -1) })
        if el._styleFlow then el._glow.SetFade(0, true) end
    end))
    window.Maid:Give(chip.MouseLeave:Connect(function()
        playOn(chip, "lift", EASE_MED, { Position = base })
        play(press, EASE_MED, { Scale = 1 })
        if el._glow then
            el._glow.SetFade(el._styleFlow and 0.55 or 1, true)
        end
    end))
    window.Maid:Give(chip.MouseButton1Down:Connect(function()
        if el.Disabled then return end
        play(press, EASE_FAST, { Scale = 0.96 })
        if el._glow then
            el._glow.SetFade(el._styleFlow and 0.08 or 0.72, true)
        end
    end))
    window.Maid:Give(chip.MouseButton1Up:Connect(function()
        play(press, EASE_MED, { Scale = 1 })
        if el._glow then
            el._glow.SetFade(el._styleFlow and 0.55 or 1, true)
        end
    end))

    local function fireButton()
        if el.Disabled then return end
        el:Fire()
    end
    window.Maid:Give(hit.MouseButton1Click:Connect(fireButton))
    window.Maid:Give(chip.MouseButton1Click:Connect(fireButton))
    return el
end

function Button:Fire()
    if self.Disabled or self.Loading then return end
    if self.Cfg.Confirm then
        local confirmCfg = type(self.Cfg.Confirm) == "table" and table.clone(self.Cfg.Confirm) or {}
        confirmCfg.Title = confirmCfg.Title or self.Name
        confirmCfg.Content = confirmCfg.Content or self.Cfg.ConfirmText or ("Run " .. self.Name .. "?")
        local previous = confirmCfg.OnConfirm
        confirmCfg.OnConfirm = function()
            if previous then safeCall(previous) end
            self:_fireNow()
        end
        self.Window:Confirm(confirmCfg)
    else
        self:_fireNow()
    end
end

function Button:_fireNow()
    self.Changed:Fire()
    safeCall(self.Cfg.Callback)
end

function Button:SetButtonText(text)
    self._chip.Text = tostring(text or "")
end

function Button:SetVariant(variant)
    variant = tostring(variant or "Secondary"):lower()
    self.Variant = variant
    styleChip(self, variant)
end

function Button:SetLoading(loading, text)
    self.Loading = loading and true or false
    self._chip.Active = not self.Loading
    self._chip.TextTransparency = self.Loading and 0.25 or 0
    if text then self._chip.Text = tostring(text)
    elseif self.Loading then self._chip.Text = "Working..."
    else self._chip.Text = (self.Cfg.Icon and (tostring(self.Cfg.Icon) .. "  ") or "") .. (self.Cfg.ButtonText or "Run") end
end

function Button:Serialize()
    return nil
end

function Section:LoadingButton(cfg)
    cfg = table.clone(cfg or {})
    cfg.Variant = cfg.Variant or "Primary"
    local button = self:Button(cfg)
    if cfg.Loading then button:SetLoading(true) end
    return button
end

function Section:IconButton(cfg)
    cfg = table.clone(cfg or {})
    cfg.Icon = cfg.Icon or "•"
    return self:Button(cfg)
end

function Section:ConfirmButton(cfg)
    cfg = table.clone(cfg or {})
    cfg.Variant = cfg.Variant or "Danger"
    cfg.Confirm = cfg.Confirm or true
    return self:Button(cfg)
end

------------------------------------------------------------------------
-- ColorPicker
------------------------------------------------------------------------
function Section:ColorPicker(cfg)
    cfg = cfg or {}
    local window = self.Window
    local row, hit = self:_row(cfg, 38)
    local el = setmetatable({}, ColorPicker)
    initElement(el, self, "ColorPicker", cfg, row, hit)
    el.Value = cfg.Default or Color3.fromRGB(255, 255, 255)
    el.HasAlpha = cfg.Alpha == true
    el.Alpha = math.clamp(tonumber(cfg.DefaultAlpha) or 1, 0, 1)
    local h, s, v = el.Value:ToHSV()

    local right = buildRight(row, 8)
    buildLeft(el, row, cfg, "Color", right)
    local swatch = new("Frame", {
        Name = "Swatch", Size = UDim2.fromOffset(38, 18), BackgroundColor3 = el.Value, Parent = right,
    })
    corner(swatch, 9)
    stroke(swatch, "Stroke", 1.5, 0.1)

    local popH = el.HasAlpha and 262 or 240
    local pop = new("CanvasGroup", {
        Name = "ColorPopup", Visible = false, ZIndex = 2, Size = UDim2.fromOffset(212, popH), GroupTransparency = 1,
        Theme = { BackgroundColor3 = "Panel" }, Parent = window.Overlay,
    })
    corner(pop, R.Card)
    strokeFade(stroke(pop, "Stroke"), 90, 0, 0.5)

    local sv = new("Frame", {
        Name = "SV", Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(188, 124),
        BackgroundColor3 = Color3.fromHSV(h, 1, 1), Parent = pop,
    })
    corner(sv, 10)
    local white = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = sv })
    corner(white, 10)
    new("UIGradient", { Transparency = seq({ 0, 0 }, { 1, 1 }), Parent = white })
    local black = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), Parent = sv })
    corner(black, 10)
    new("UIGradient", { Rotation = 90, Transparency = seq({ 0, 1 }, { 1, 0 }), Parent = black })
    local svCursor = new("Frame", {
        Name = "Cursor", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(14, 14),
        BackgroundTransparency = 1, ZIndex = 3, Parent = sv,
    })
    corner(svCursor, 7)
    new("UIStroke", { Thickness = 2.5, Color = Color3.new(1, 1, 1), Parent = svCursor })

    local function makeBar(y)
        local bar = new("Frame", {
            Position = UDim2.fromOffset(12, y), Size = UDim2.fromOffset(188, 12), BackgroundColor3 = Color3.new(1, 1, 1),
            ClipsDescendants = true, Parent = pop,
        })
        corner(bar, 6)
        return bar
    end
    local function makeThumb(bar)
        local thumb = new("Frame", {
            Name = "Cursor", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(16, 16),
            BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = bar,
        })
        corner(thumb, 8)
        new("UIStroke", { Thickness = 1.5, Color = Color3.fromRGB(20, 18, 30), Transparency = 0.5, Parent = thumb })
        return thumb
    end
    local hueBar = makeBar(144)
    hueBar.ClipsDescendants = false
    local keys = {}
    for i = 0, 6 do
        table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((i % 6) / 6, 0.55, 1)))
    end
    new("UIGradient", { Color = ColorSequence.new(keys), Parent = hueBar })
    local hueCursor = makeThumb(hueBar)

    local alphaBar, alphaCursor, alphaTint
    local nextY = 164
    if el.HasAlpha then
        alphaBar = makeBar(164)
        alphaBar.ClipsDescendants = true
        for r = 0, 1 do
            for c = 0, 30 do
                new("Frame", {
                    Position = UDim2.fromOffset(c * 6, r * 6), Size = UDim2.fromOffset(6, 6),
                    BackgroundColor3 = ((r + c) % 2 == 0) and Color3.fromRGB(236, 236, 242) or Color3.fromRGB(176, 176, 190),
                    Parent = alphaBar,
                })
            end
        end
        alphaTint = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = el.Value, ZIndex = 2, Parent = alphaBar })
        new("UIGradient", { Transparency = seq({ 0, 1 }, { 1, 0 }), Parent = alphaTint })
        local holderBar = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = alphaBar })
        alphaBar.Name = "Alpha"
        alphaCursor = new("Frame", {
            Name = "Cursor", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(16, 16),
            BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 4, Parent = pop,
        })
        corner(alphaCursor, 8)
        new("UIStroke", { Thickness = 1.5, Color = Color3.fromRGB(20, 18, 30), Transparency = 0.5, Parent = alphaCursor })
        holderBar.Name = "AlphaHit"
        nextY = 184
    end

    local hexHolder = new("Frame", {
        Name = "HexField", Position = UDim2.fromOffset(12, nextY + 8), Size = UDim2.fromOffset(188, 28),
        Theme = { BackgroundColor3 = "Row" }, Parent = pop,
    })
    corner(hexHolder, R.Chip)
    local hexStroke = stroke(hexHolder, "Stroke")
    local hexBox = new("TextBox", {
        Name = "Hex", Size = UDim2.fromScale(1, 1), Text = "", PlaceholderText = "#RRGGBB", TextSize = 12,
        Font = FONT.Mono, Theme = { PlaceholderColor3 = "Dim" }, Parent = hexHolder,
    })

    -- big swatches that ring when selected
    local swatchRow = new("Frame", {
        Name = "Swatches", Position = UDim2.fromOffset(12, nextY + 44), Size = UDim2.fromOffset(188, 22), BackgroundTransparency = 1, Parent = pop,
    })
    list(swatchRow, 4, HORIZ, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
    local swatches = {}
    local function swatchColor(i)
        if i <= 6 then return Library.Prism[i] or Color3.new(1, 1, 1) end
        return i == 7 and Color3.new(1, 1, 1) or Color3.fromRGB(34, 30, 52)
    end
    for i = 1, 8 do
        local sw = new("TextButton", {
            Name = "Swatch" .. i, Text = "", Size = UDim2.fromOffset(20, 20), LayoutOrder = i, BackgroundColor3 = swatchColor(i), Parent = swatchRow,
        })
        corner(sw, 10)
        local ringS = new("UIStroke", {
            Thickness = 2, Color = Color3.new(1, 1, 1), Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = sw,
        })
        local grow = new("UIScale", { Scale = 1, Parent = sw })
        swatches[i] = { Button = sw, Ring = ringS, Scale = grow }
        sw.MouseButton1Click:Connect(function()
            el:SetValue(swatchColor(i))
        end)
        sw.MouseEnter:Connect(function() play(grow, EASE_POP, { Scale = 1.12 }) end)
        sw.MouseLeave:Connect(function() play(grow, EASE_POP, { Scale = 1 }) end)
    end

    local function refresh(fromUser, animate)
        local color = Color3.fromHSV(h, s, v)
        sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        svCursor.Position = UDim2.fromScale(s, 1 - v)
        hueCursor.Position = UDim2.new(h, 0, 0.5, 0)
        swatch.BackgroundColor3 = color
        if alphaTint then
            alphaTint.BackgroundColor3 = color
            alphaCursor.Position = UDim2.fromOffset(12 + el.Alpha * 188, 164 + 6)
        end
        if not hexBox:IsFocused() then
            hexBox.Text = "#" .. color:ToHex():upper()
        end
        for i, sw in ipairs(swatches) do
            local c = swatchColor(i)
            sw.Button.BackgroundColor3 = c
            local near = math.abs(c.R - color.R) + math.abs(c.G - color.G) + math.abs(c.B - color.B) < 0.04
            apply(sw.Ring, { Transparency = near and 0 or 1 }, animate, EASE_FAST)
        end
        if fromUser then
            el.Value = color
            el:_commit()
        end
    end
    el._refresh = refresh
    el._setHSV = function(color)
        local nh, ns, nv = color:ToHSV()
        if ns > 0 and nv > 0 then
            h = nh
        end
        s, v = ns, nv
    end

    local drag = nil
    local function updateSV(input)
        s = math.clamp((input.Position.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
        v = 1 - math.clamp((input.Position.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
        refresh(true)
    end
    local function updateHue(input)
        h = math.clamp((input.Position.X - hueBar.AbsolutePosition.X) / math.max(hueBar.AbsoluteSize.X, 1), 0, 1)
        refresh(true)
    end
    local function updateAlpha(input)
        el.Alpha = math.clamp((input.Position.X - alphaBar.AbsolutePosition.X) / math.max(alphaBar.AbsoluteSize.X, 1), 0, 1)
        refresh(true)
    end
    window.Maid:Give(sv.InputBegan:Connect(function(input)
        if isPress(input) then drag = "sv" updateSV(input) end
    end))
    window.Maid:Give(hueBar.InputBegan:Connect(function(input)
        if isPress(input) then drag = "hue" updateHue(input) end
    end))
    if alphaBar then
        window.Maid:Give(alphaBar.InputBegan:Connect(function(input)
            if isPress(input) then drag = "alpha" updateAlpha(input) end
        end))
    end
    window.Maid:Give(UserInputService.InputChanged:Connect(function(input)
        if isMove(input) then
            if drag == "sv" then updateSV(input)
            elseif drag == "hue" then updateHue(input)
            elseif drag == "alpha" then updateAlpha(input) end
        end
    end))
    window.Maid:Give(UserInputService.InputEnded:Connect(function(input)
        if isPress(input) then
            drag = nil
        end
    end))
    window.Maid:Give(hexBox.Focused:Connect(function()
        play(hexStroke, EASE_FAST, { Color = Library.Theme.Accent })
    end))
    window.Maid:Give(hexBox.FocusLost:Connect(function()
        play(hexStroke, EASE_FAST, { Color = Library.Theme.Stroke })
        local ok, color = pcall(Color3.fromHex, hexBox.Text)
        if ok and color then
            el:SetValue(color)
        end
        refresh(false)
    end))

    local popup = { Frame = pop, Anchor = row, Size = Vector2.new(212, popH), AlignRight = true }
    window.Maid:Give(hit.MouseButton1Click:Connect(function()
        if window._popup == popup then
            window:_closePopup()
        else
            window:_openPopup(popup)
        end
    end))
    el._onDestroy = function()
        if popup.Shadow then popup.Shadow.Destroy() end
        pop:Destroy()
    end

    refresh(false)
    publish(el)
    return el
end

function ColorPicker:_commit()
    if self.Disabled then
        return
    end
    publish(self)
    self.Changed:Fire(self.Value, self.Alpha)
    safeCall(self.Cfg.Callback, self.Value, self.Alpha)
end

function ColorPicker:Serialize()
    if self.HasAlpha then
        return { c = self.Value, a = self.Alpha }
    end
    return self.Value
end

function ColorPicker:Deserialize(v)
    if type(v) == "table" and v.c then
        self.Alpha = tonumber(v.a) or 1
        self:SetValue(v.c)
    else
        self:SetValue(v)
    end
end

function ColorPicker:_visual()
    if self._refresh then
        self._refresh(false)
    end
end

function ColorPicker:SetValue(color, silent)
    if typeof(color) ~= "Color3" then
        return
    end
    self.Value = color
    self._setHSV(color)
    self._refresh(false)
    if not silent then
        self:_commit()
    else
        publish(self)
    end
end

------------------------------------------------------------------------
-- Extended controls and layout components
------------------------------------------------------------------------
function Section:Checkbox(cfg)
    cfg = cfg or {}
    local window = self.Window
    local row, hit = self:_row(cfg, 38)
    local el = setmetatable({}, Checkbox)
    initElement(el, self, "Checkbox", cfg, row, hit)
    el.Value = cfg.Default == true
    local right = buildRight(row, 8)
    buildLeft(el, row, cfg, "Checkbox", right)
    local box = new("Frame", { Name = "CheckBox", Size = UDim2.fromOffset(20, 20), Theme = { BackgroundColor3 = "Track" }, Parent = right })
    corner(box, 6)
    stroke(box, "Stroke", 1, 0.2)
    local fill = new("Frame", {
        Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Parent = box,
    })
    corner(fill, 6)
    el._fillGrad = flowGradient(fill, { rotation = 35, shift = 0.2, periods = 0.9, scope = self.Tab.Page })
    el._fillGrad.Enabled = false
    -- the tick is revealed left-to-right through a clipping mask, so it looks drawn in
    local mask = new("Frame", {
        Name = "Mask", Size = UDim2.new(0, 0, 1, 0), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 2, Parent = box,
    })
    local tick = Icons.Draw(mask, "check", 14, "OnAccent", 1.3)
    tick.Position = UDim2.fromOffset(3, 3)
    local pop = new("UIScale", { Scale = 1, Parent = box })
    el._box, el._fill, el._mask, el._pop = box, fill, mask, pop
    window.Maid:Give(hit.MouseButton1Click:Connect(function()
        if not el.Disabled then el:SetValue(not el.Value) end
    end))
    el:_visual(false)
    publish(el)
    return el
end

function Checkbox:_visual(animate)
    local on = self.Value
    if on then
        self._fillGrad.Enabled = true
    else
        task.delay(0.3, function()
            if not self.Value and self._fillGrad.Parent then self._fillGrad.Enabled = false end
        end)
    end
    apply(self._fill, { BackgroundTransparency = on and 0 or 1 }, animate, EASE_FAST)
    apply(self._mask, { Size = UDim2.new(0, on and 20 or 0, 1, 0) }, animate, on and EASE_MED or EASE_FAST)
    if animate then
        self._pop.Scale = on and 0.8 or 1
        if on then
            play(self._pop, EASE_POP, { Scale = 1 })
        else
            play(self._pop, EASE_POP, { Scale = 1 })
        end
    end
end

function Checkbox:SetValue(value, silent)
    value = value and true or false
    if value == self.Value then
        return
    end
    self.Value = value
    self:_visual(true)
    if not silent then self:_commit() else publish(self) end
end

function Section:ProgressBar(cfg)
    cfg = cfg or {}
    local row, hit = self:_row(cfg, cfg.Height or 52)
    hit.Visible = false
    local el = setmetatable({}, ProgressBar)
    initElement(el, self, "ProgressBar", cfg, row, nil)
    el.Min = tonumber(cfg.Min) or 0
    el.Max = tonumber(cfg.Max) or 100
    if el.Max <= el.Min then el.Max = el.Min + 1 end
    el.Value = math.clamp(tonumber(cfg.Default) or el.Min, el.Min, el.Max)
    local title = new("TextLabel", {
        Name = "Label", Text = cfg.Name or "Progress", Position = UDim2.fromOffset(14, 7),
        Size = UDim2.new(1, -92, 0, 18), TextSize = 13, TextXAlignment = LEFT, Parent = row,
    })
    local percent = new("TextLabel", {
        Name = "Percent", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 7),
        Size = UDim2.fromOffset(72, 18), TextSize = 11, Font = FONT.Mono, TextXAlignment = RIGHT,
        Theme = { TextColor3 = "Accent" }, Parent = row,
    })
    local track = new("Frame", {
        Name = "Track", Position = UDim2.new(0, 14, 1, -17), Size = UDim2.new(1, -28, 0, 6),
        Theme = { BackgroundColor3 = "Track" }, Parent = row,
    })
    corner(track, 3)
    local fill = new("Frame", {
        Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true, Parent = track,
    })
    corner(fill, 3)
    local custom = false
    if typeof(cfg.Color) == "Color3" then
        fill.BackgroundColor3 = cfg.Color
        custom = true
    elseif type(cfg.Color) == "string" and Library.Theme[cfg.Color] then
        bindTheme(fill, { BackgroundColor3 = cfg.Color })
        custom = true
    end
    if not custom then
        flowGradient(fill, { shift = 0.2, periods = 0.8, scope = self.Tab.Page })
    end
    -- animated shimmer sweeping across the fill
    local shimmer = new("Frame", {
        Name = "Shimmer", Position = UDim2.fromScale(-0.4, 0), Size = UDim2.fromScale(0.4, 1),
        BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 2, Parent = fill,
    })
    new("UIGradient", { Transparency = seq({ 0, 1 }, { 0.5, 0.55 }, { 1, 1 }), Parent = shimmer })
    local sweep = TweenService:Create(shimmer, TweenInfo.new(1.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 0.4), { Position = UDim2.fromScale(1, 0) })
    table.insert(self.Window._ambient, sweep)
    if Library.Animations ~= false then sweep:Play() end
    el._title, el._percent, el._fill = title, percent, fill
    function el:SetValue(value, silent)
        value = tonumber(value)
        if not value then return end
        value = math.clamp(value, self.Min, self.Max)
        if value == self.Value then
            return
        end
        self.Value = value
        self:_visual(true)
        if not silent then self:_commit() else publish(self) end
    end
    function el:SetRange(minimum, maximum)
        self.Min = tonumber(minimum) or self.Min
        self.Max = tonumber(maximum) or self.Max
        if self.Max <= self.Min then self.Max = self.Min + 1 end
        self:SetValue(self.Value, true)
    end
    function el:SetColor(color)
        if typeof(color) == "Color3" then self._fill.BackgroundColor3 = color end
    end
    function el:_visual(animate)
        local alpha = math.clamp((self.Value - self.Min) / (self.Max - self.Min), 0, 1)
        apply(self._fill, { Size = UDim2.fromScale(alpha, 1) }, animate, EASE_MED)
        self._percent.Text = string.format("%d%%", math.floor(alpha * 100 + 0.5))
    end
    function el:Serialize() return self.Value end
    el._onDestroy = function() pcall(function() sweep:Cancel() end) end
    el:_visual(false)
    publish(el)
    return el
end

function Section:Numberbox(cfg)
    cfg = cfg or {}
    local window = self.Window
    local row, hit = self:_row(cfg, 38)
    hit.Visible = false
    local el = setmetatable({}, Numberbox)
    initElement(el, self, "Numberbox", cfg, row, nil)
    el.Min = tonumber(cfg.Min) or -math.huge
    el.Max = tonumber(cfg.Max) or math.huge
    if el.Max < el.Min then
        el.Min, el.Max = el.Max, el.Min
    end
    el.Increment = math.max(0.000001, tonumber(cfg.Increment) or 1)
    el.Value = math.clamp(tonumber(cfg.Default) or 0, el.Min, el.Max)
    el._dec = decimals(el.Increment)
    local right = buildRight(row, 4)
    buildLeft(el, row, cfg, "Number", right)
    local minus = new("TextButton", {
        Name = "Minus", Text = "−", Size = UDim2.fromOffset(24, 24), TextSize = 16,
        Theme = { BackgroundColor3 = "Panel", TextColor3 = "SubText" }, Parent = right,
    })
    corner(minus, 8)
    local holder = new("Frame", { Name = "Value", Size = UDim2.fromOffset(cfg.Width or 64, 24), Theme = { BackgroundColor3 = "Panel" }, Parent = right })
    corner(holder, 8)
    local box = new("TextBox", {
        Name = "Input", Size = UDim2.fromScale(1, 1), Text = tostring(el.Value), TextSize = 12,
        Font = FONT.Mono, TextXAlignment = Enum.TextXAlignment.Center, Parent = holder,
    })
    local plus = new("TextButton", {
        Name = "Plus", Text = "+", Size = UDim2.fromOffset(24, 24), TextSize = 16,
        Theme = { BackgroundColor3 = "Panel", TextColor3 = "SubText" }, Parent = right,
    })
    corner(plus, 8)
    el._box = box
    window.Maid:Give(minus.MouseButton1Click:Connect(function() el:SetValue(el.Value - el.Increment) end))
    window.Maid:Give(plus.MouseButton1Click:Connect(function() el:SetValue(el.Value + el.Increment) end))
    window.Maid:Give(box.FocusLost:Connect(function()
        local value = tonumber(box.Text)
        if value then el:SetValue(value) else el:_visual(false) end
    end))
    function el:SetValue(value, silent)
        value = tonumber(value)
        if not value then return end
        -- Snap relative to Min when bounded; use zero for an unbounded lower end.
        local anchor = self.Min > -math.huge and self.Min or 0
        value = roundTo(value - anchor, self.Increment) + anchor
        value = math.clamp(value, self.Min, self.Max)
        if value == self.Value then
            self:_visual(false)
            return
        end
        self.Value = value
        self:_visual(false)
        if not silent then self:_commit() else publish(self) end
    end
    function el:_visual()
        if not self._box:IsFocused() then
            self._box.Text = string.format("%." .. self._dec .. "f", self.Value)
        end
    end
    el:_visual()
    publish(el)
    return el
end

function Section:TextArea(cfg)
    cfg = cfg or {}
    local row, hit = self:_row(cfg, cfg.Height or 112)
    hit.Visible = false
    local el = setmetatable({}, TextArea)
    initElement(el, self, "TextArea", cfg, row, nil)
    el.Value = tostring(cfg.Default or "")
    new("TextLabel", {
        Name = "Label", Text = cfg.Name or "Text", Position = UDim2.fromOffset(12, 6),
        Size = UDim2.new(1, -24, 0, 18), TextSize = 12, TextXAlignment = LEFT, Parent = row,
    })
    local box = new("TextBox", {
        Name = "Input", Position = UDim2.fromOffset(10, 29), Size = UDim2.new(1, -20, 1, -38),
        Text = el.Value, PlaceholderText = cfg.Placeholder or "Enter text...", TextSize = 12,
        TextXAlignment = LEFT, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
        MultiLine = true, ClearTextOnFocus = false, BackgroundTransparency = 0,
        Theme = { BackgroundColor3 = "Panel", PlaceholderColor3 = "Dim" }, Parent = row,
    })
    corner(box, 8); pad(box, 10, 8, 10, 8)
    local areaStroke = stroke(box, "Stroke", 1, 0.2)
    el._box = box
    self.Window.Maid:Give(box.Focused:Connect(function() play(areaStroke, EASE_FAST, { Color = Library.Theme.Accent }) end))
    self.Window.Maid:Give(box.FocusLost:Connect(function() play(areaStroke, EASE_FAST, { Color = Library.Theme.Stroke }) el:SetValue(box.Text) end))
    if cfg.LiveUpdate then
        self.Window.Maid:Give(box:GetPropertyChangedSignal("Text"):Connect(function()
            if not el.Disabled then el:SetValue(box.Text) end
        end))
    end
    function el:SetValue(value, silent)
        self.Value = tostring(value or "")
        self._box.Text = self.Value
        if not silent then self:_commit() else publish(self) end
    end
    function el:_visual() self._box.Text = self.Value end
    publish(el)
    return el
end

function Section:RangeSlider(cfg)
    cfg = cfg or {}
    local window = self.Window
    local row, hit = self:_row(cfg, cfg.Height or 52)
    hit.Visible = false
    local el = setmetatable({}, RangeSlider)
    initElement(el, self, "RangeSlider", cfg, row, nil)
    el.Min = tonumber(cfg.Min) or 0
    el.Max = tonumber(cfg.Max) or 100
    if el.Max <= el.Min then el.Max = el.Min + 1 end
    el.Increment = math.max(0.000001, tonumber(cfg.Increment) or 1)
    local def = cfg.Default or { el.Min, el.Max }
    local low = tonumber(def[1] or def.Min) or el.Min
    local high = tonumber(def[2] or def.Max) or el.Max
    if low > high then low, high = high, low end
    el.Value = { math.clamp(low, el.Min, el.Max), math.clamp(high, el.Min, el.Max) }
    local label = new("TextLabel", {
        Name = "Label", Text = cfg.Name or "Range", Position = UDim2.fromOffset(12, 5),
        Size = UDim2.new(1, -125, 0, 18), TextSize = 12, TextXAlignment = LEFT, Parent = row,
    })
    local values = new("TextLabel", {
        Name = "Values", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 5),
        Size = UDim2.fromOffset(112, 18), TextSize = 11, Font = FONT.Mono, TextXAlignment = RIGHT,
        Theme = { TextColor3 = "SubText" }, Parent = row,
    })
    local area = new("Frame", { Name = "TrackArea", Position = UDim2.new(0, 12, 1, -17), Size = UDim2.new(1, -24, 0, 8), BackgroundTransparency = 1, Active = true, Parent = row })
    local track = new("Frame", { Name = "Track", Position = UDim2.fromScale(0, 0.5), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(1, 0, 0, 6), Theme = { BackgroundColor3 = "Track" }, Parent = area })
    corner(track, 3)
    local fill = new("Frame", { Name = "Fill", BackgroundColor3 = Color3.new(1, 1, 1), Parent = track })
    corner(fill, 3)
    flowGradient(fill, { shift = 0.1, periods = 0.8, scope = self.Tab.Page })
    local function makeHandle(name)
        local handle = new("TextButton", { Name = name, Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = Color3.new(1, 1, 1), Parent = track })
        corner(handle, 8); stroke(handle, "Accent", 2)
        handle.MouseEnter:Connect(function() play(handle, EASE_POP, { Size = UDim2.fromOffset(19, 19) }) end)
        handle.MouseLeave:Connect(function() play(handle, EASE_POP, { Size = UDim2.fromOffset(16, 16) }) end)
        return handle
    end
    local lowHandle, highHandle = makeHandle("LowHandle"), makeHandle("HighHandle")
    el._track, el._fill, el._lowHandle, el._highHandle, el._values = track, fill, lowHandle, highHandle, values
    local activeHandle, dragging = nil, false
    local function alphaFor(value) return math.clamp((value - el.Min) / (el.Max - el.Min), 0, 1) end
    local function updateFromInput(input)
        local alpha = math.clamp((input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        local value = roundTo(el.Min + (el.Max - el.Min) * alpha - el.Min, el.Increment) + el.Min
        if activeHandle == "Low" then
            el:SetValue({ math.min(value, el.Value[2]), el.Value[2] })
        else
            el:SetValue({ el.Value[1], math.max(value, el.Value[1]) })
        end
    end
    local function beginDrag(input, forced)
        if el.Disabled then return end
        local a = alphaFor(el.Value[1])
        local b = alphaFor(el.Value[2])
        local x = (input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
        activeHandle = forced or (math.abs(x - a) <= math.abs(x - b) and "Low" or "High")
        dragging = true
        self.Tab:_lockScroll(true)
        updateFromInput(input)
    end
    window.Maid:Give(area.InputBegan:Connect(function(input) if isPress(input) then beginDrag(input) end end))
    window.Maid:Give(lowHandle.InputBegan:Connect(function(input) if isPress(input) then beginDrag(input, "Low") end end))
    window.Maid:Give(highHandle.InputBegan:Connect(function(input) if isPress(input) then beginDrag(input, "High") end end))
    window.Maid:Give(UserInputService.InputChanged:Connect(function(input) if dragging and isMove(input) then updateFromInput(input) end end))
    window.Maid:Give(UserInputService.InputEnded:Connect(function(input)
        if dragging and isPress(input) then dragging = false; activeHandle = nil; self.Tab:_lockScroll(false) end
    end))
    function el:SetValue(value, silent)
        if type(value) ~= "table" then return end
        local a = tonumber(value[1] or value.Min)
        local b = tonumber(value[2] or value.Max)
        if not a or not b then return end
        a = math.clamp(roundTo(a - self.Min, self.Increment) + self.Min, self.Min, self.Max)
        b = math.clamp(roundTo(b - self.Min, self.Increment) + self.Min, self.Min, self.Max)
        if a > b then a, b = b, a end
        if self.Value and a == self.Value[1] and b == self.Value[2] then
            return
        end
        self.Value = { a, b }
        self:_visual(true)
        if not silent then self:_commit() else publish(self) end
    end
    function el:_visual(animate)
        local a, b = alphaFor(self.Value[1]), alphaFor(self.Value[2])
        apply(self._fill, { Position = UDim2.fromScale(a, 0), Size = UDim2.fromScale(math.max(0, b - a), 1) }, animate, EASE_FAST)
        apply(self._lowHandle, { Position = UDim2.fromScale(a, 0.5) }, animate, EASE_FAST)
        apply(self._highHandle, { Position = UDim2.fromScale(b, 0.5) }, animate, EASE_FAST)
        self._values.Text = tostring(self.Value[1]) .. " – " .. tostring(self.Value[2])
    end
    function el:Serialize() return table.clone(self.Value) end
    el:_visual(false)
    publish(el)
    return el
end

function Section:KeyValue(cfg)
    cfg = cfg or {}
    local frame = new("Frame", { Name = cfg.Name or "KeyValue", Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Parent = self.Content })
    local key = new("TextLabel", { Name = "Key", Text = cfg.Name or cfg.Key or "Value", Size = UDim2.new(0.55, -4, 1, 0), TextSize = 12, TextXAlignment = LEFT, Parent = frame })
    local initialValue = cfg.Value ~= nil and tostring(cfg.Value) or "—"
    local value = new("TextLabel", { Name = "Value", Text = initialValue, Position = UDim2.new(0.55, 4, 0, 0), Size = UDim2.new(0.45, -4, 1, 0), TextSize = 12, TextXAlignment = RIGHT, TextTruncate = Enum.TextTruncate.AtEnd, Theme = { TextColor3 = "SubText" }, Parent = frame })
    local item = self:_entry(frame, (cfg.Name or cfg.Key or "") .. " " .. initialValue)
    local obj = { Kind = "KeyValue", Section = self, Frame = frame, KeyLabel = key, ValueLabel = value, _item = item }
    function obj:SetValue(v) self.ValueLabel.Text = tostring(v); self._item.Name = (self.KeyLabel.Text .. " " .. self.ValueLabel.Text):lower() end
    function obj:SetName(v) self.KeyLabel.Text = tostring(v); self._item.Name = (self.KeyLabel.Text .. " " .. self.ValueLabel.Text):lower() end
    function obj:SetVisible(v) self._item.Hidden = not v; self.Section.Window:_refreshItem(self._item) end
    function obj:Destroy() local i=table.find(self.Section.Entries,self._item); if i then table.remove(self.Section.Entries,i) end; self.Frame:Destroy() end
    return obj
end

function Section:Status(cfg)
    cfg = table.clone(type(cfg) == "table" and cfg or { Text = tostring(cfg or "Status") })
    cfg.Name = cfg.Name or cfg.Text
    return self:Badge(cfg)
end

function Section:Paragraph(cfg)
    if type(cfg) == "string" then cfg = { Content = cfg } end
    cfg = cfg or {}
    local frame = new("Frame", {
        Name = cfg.Name or "Paragraph", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AS_Y,
        Theme = { BackgroundColor3 = cfg.Background and "Panel" or "Row" }, Parent = self.Content,
    })
    corner(frame, R.Control)
    frame.BackgroundTransparency = cfg.Background == false and 1 or 0
    if cfg.Background ~= false then highlight(frame, 12, 0.9) end
    if cfg.Background ~= false then stroke(frame, "Stroke", 1, 0.35) end
    pad(frame, 11, 9, 11, 9)
    list(frame, 4)
    local title
    if cfg.Title or cfg.Name then
        title = new("TextLabel", { Name = "Title", Text = cfg.Title or cfg.Name, Size = UDim2.new(1, 0, 0, 17), Font = FONT.Bold, TextSize = 12, TextXAlignment = LEFT, Parent = frame })
    end
    local body = new("TextLabel", {
        Name = "Content", Text = cfg.Content or cfg.Text or "", Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = AS_Y, TextWrapped = true, TextSize = 11, Font = FONT.Regular,
        TextXAlignment = LEFT, TextYAlignment = Enum.TextYAlignment.Top,
        Theme = { TextColor3 = "SubText" }, Parent = frame,
    })
    local item = self:_entry(frame, (cfg.Name or cfg.Title or "") .. " " .. (cfg.Content or cfg.Text or ""))
    local obj = { Kind = "Paragraph", Section = self, Frame = frame, Title = title, Body = body, _item = item }
    function obj:SetText(value) self.Body.Text = tostring(value or ""); self._item.Name = ((self.Title and self.Title.Text or "") .. " " .. self.Body.Text):lower() end
    function obj:SetTitle(value) if self.Title then self.Title.Text = tostring(value or "") end end
    function obj:SetVisible(value) self._item.Hidden = not value; self.Section.Window:_refreshItem(self._item) end
    function obj:Destroy() local i=table.find(self.Section.Entries,self._item); if i then table.remove(self.Section.Entries,i) end; self.Frame:Destroy() end
    return obj
end

function Section:Badge(cfg)
    if type(cfg) == "string" then cfg = { Text = cfg } end
    cfg = cfg or {}
    local frame = new("Frame", { Name = cfg.Name or "Badge", Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Parent = self.Content })
    local badgeColor = cfg.Color
    if type(badgeColor) == "string" then badgeColor = Library.Theme[badgeColor] end
    local textColor = cfg.TextColor
    if type(textColor) == "string" then textColor = Library.Theme[textColor] end
    local chip = new("TextLabel", {
        Name = "Badge", Text = cfg.Text or cfg.Name or "Status", AutomaticSize = AS_X,
        Size = UDim2.fromOffset(0, 22), Position = UDim2.fromOffset(2, 4), TextSize = 11,
        BackgroundTransparency = cfg.Transparency or 0.82,
        BackgroundColor3 = badgeColor or Library.Theme.Accent, TextColor3 = textColor or Library.Theme.Text,
        Parent = frame,
    })
    corner(chip, R.Chip); pad(chip, 10, 0, 10, 0)
    new("UIStroke", { Color = chip.BackgroundColor3, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = chip })
    chip.FontFace = FONT.Semi
    local item = self:_entry(frame, cfg.Name or cfg.Text or "Badge")
    local obj = { Kind = "Badge", Section = self, Frame = frame, Chip = chip, _item = item }
    function obj:SetText(value) self.Chip.Text = tostring(value or ""); self._item.Name = self.Chip.Text:lower() end
    function obj:SetColor(color) if typeof(color)=="Color3" then self.Chip.BackgroundColor3=color end end
    function obj:SetVisible(value) self._item.Hidden=not value; self.Section.Window:_refreshItem(self._item) end
    function obj:Destroy() local i=table.find(self.Section.Entries,self._item); if i then table.remove(self.Section.Entries,i) end; self.Frame:Destroy() end
    return obj
end

function Section:Image(cfg)
    if type(cfg) == "string" then cfg = { Image = cfg } end
    cfg = cfg or {}
    local width = tonumber(cfg.Width) or 220
    local height = tonumber(cfg.Height) or 112
    local frame = new("Frame", { Name = cfg.Name or "Image", Size = UDim2.new(1, 0, 0, height + (cfg.Caption and 24 or 8)), BackgroundTransparency = 1, Parent = self.Content })
    local imageSource = tostring(cfg.Image or cfg.Url or "")
    if tonumber(imageSource) then imageSource = "rbxassetid://" .. imageSource end
    local imageSize = cfg.Fill == false and UDim2.new(0, width, 0, height) or UDim2.new(1, 0, 0, height)
    local scaleType = cfg.ScaleType or Enum.ScaleType.Fit
    if type(scaleType) == "string" and Enum.ScaleType[scaleType] then scaleType = Enum.ScaleType[scaleType] end
    local image = new("ImageLabel", {
        Name = "Image", Size = imageSize, Image = imageSource,
        ScaleType = scaleType, BackgroundTransparency = 1, Parent = frame,
    })
    corner(image, tonumber(cfg.Radius) or 8)
    if cfg.Caption then
        new("TextLabel", { Name = "Caption", Text = cfg.Caption, Position = UDim2.new(0, 2, 0, height + 4),
            Size = UDim2.new(1, -4, 0, 20), TextSize = 11, TextXAlignment = LEFT,
            Theme = { TextColor3 = "SubText" }, Parent = frame })
    end
    local item = self:_entry(frame, cfg.Name or cfg.Caption or "Image")
    local obj = { Kind = "Image", Section = self, Frame = frame, ImageLabel = image, _item = item }
    function obj:SetImage(value) self.ImageLabel.Image = tostring(value or "") end
    function obj:SetVisible(value) self._item.Hidden=not value; self.Section.Window:_refreshItem(self._item) end
    function obj:Destroy() local i=table.find(self.Section.Entries,self._item); if i then table.remove(self.Section.Entries,i) end; self.Frame:Destroy() end
    return obj
end

function Section:ButtonGroup(cfg)
    cfg = cfg or {}
    local frame = new("Frame", { Name = cfg.Name or "ButtonGroup", Size = UDim2.new(1, 0, 0, cfg.Height or 32), BackgroundTransparency = 1, Parent = self.Content })
    local layout = list(frame, cfg.Spacing or 6, HORIZ, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
    local item = self:_entry(frame, cfg.Name or "Button Group")
    local group = { Kind = "ButtonGroup", Section = self, Frame = frame, Layout = layout, Buttons = {}, _item = item }
    local buttonCount = tonumber(cfg.ButtonCount) or (type(cfg.Buttons) == "table" and #cfg.Buttons) or (type(cfg.Buttons) == "number" and cfg.Buttons) or 2
    function group:AddButton(buttonCfg)
        buttonCfg = buttonCfg or {}
        local variant = (buttonCfg.Variant or "Secondary"):lower()
        local colors = { primary = { "Accent", "Text" }, secondary = { "Panel", "Text" }, danger = { "Danger", "Text" }, success = { "Success", "Text" } }
        local palette = colors[variant] or colors.secondary
        local button = new("TextButton", {
            Name = buttonCfg.Name or "Button", Text = buttonCfg.ButtonText or buttonCfg.Name or "Action",
            Size = UDim2.new(buttonCfg.WidthScale or 1 / math.max(1, buttonCount), buttonCfg.WidthOffset or 0, 0, cfg.ButtonHeight or 28),
            AutomaticSize = buttonCfg.AutomaticSize and AS_X or Enum.AutomaticSize.None,
            BackgroundTransparency = buttonCfg.BackgroundTransparency or 0.08, TextSize = 11,
            Theme = { BackgroundColor3 = palette[1], TextColor3 = palette[2] }, Parent = frame,
        })
        corner(button, R.Chip); pad(button, 10, 0, 10, 0)
        button.FontFace = FONT.Semi
        local entry = { Button = button, Callback = buttonCfg.Callback }
        button.MouseButton1Click:Connect(function() if button.Active then safeCall(entry.Callback) end end)
        button.MouseEnter:Connect(function() play(button, EASE_FAST, { BackgroundTransparency = 0 }) end)
        button.MouseLeave:Connect(function() play(button, EASE_FAST, { BackgroundTransparency = buttonCfg.BackgroundTransparency or 0.08 }) end)
        function entry:SetText(value) self.Button.Text = tostring(value or "") end
        function entry:SetDisabled(value) self.Button.Active = not value; self.Button.AutoButtonColor = false; self.Button.TextTransparency = value and 0.5 or 0 end
        table.insert(group.Buttons, entry)
        return entry
    end
    group.Button = group.AddButton
    if type(cfg.Buttons) == "table" then
        for _, buttonCfg in ipairs(cfg.Buttons) do group:AddButton(buttonCfg) end
    end
    function group:SetVisible(value) self._item.Hidden=not value; self.Section.Window:_refreshItem(self._item) end
    function group:Destroy() local i=table.find(self.Section.Entries,self._item); if i then table.remove(self.Section.Entries,i) end; self.Frame:Destroy() end
    return group
end

function Section:Card(cfg)
    cfg = cfg or {}
    local frame = new("Frame", { Name = cfg.Name or "Card", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AS_Y, Theme = { BackgroundColor3 = "Panel" }, Parent = self.Content })
    if typeof(cfg.BackgroundColor) == "Color3" then frame.BackgroundColor3 = cfg.BackgroundColor end
    corner(frame, cfg.Radius or R.Card); strokeFade(stroke(frame, "Stroke", 1), 90, 0, 0.6); highlight(frame, 14, 0.88); pad(frame, 12, 10, 12, 12); list(frame, 8)
    local header = new("TextLabel", { Name = "Header", Text = cfg.Name or "Card", Size = UDim2.new(1, 0, 0, 18), TextSize = 12, Font = FONT.Bold, TextXAlignment = LEFT, Parent = frame })
    local content = new("Frame", { Name = "Content", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AS_Y, BackgroundTransparency = 1, Parent = frame })
    list(content, cfg.Spacing or 6)
    local card = setmetatable({ Window = self.Window, Tab = self.Tab, Name = cfg.Name or "Card", Frame = frame,
        Header = header, Content = content, Entries = self.Entries, ParentSection = self, _cardEntries = {}, _cardHidden = false }, Section)
    function card:_entry(childFrame, name)
        local localName = (name or ""):lower()
        local entry = self.ParentSection:_entry(childFrame, self.Name .. " " .. localName)
        entry.Card = self
        entry.CardLocalName = localName
        entry.Hidden = self._cardHidden
        table.insert(self._cardEntries, entry)
        return entry
    end
    function card:SetName(name)
        self.Name=tostring(name); self.Header.Text=self.Name
        for _, entry in ipairs(self._cardEntries) do entry.Name = (self.Name .. " " .. (entry.CardLocalName or "")):lower() end
    end
    function card:SetVisible(value)
        self._cardHidden = not value
        self.Frame.Visible = value
        for _, entry in ipairs(self._cardEntries) do entry.Hidden = not value; self.Window:_refreshItem(entry) end
    end
    function card:Destroy()
        for _, entry in ipairs(self._cardEntries) do
            local index = table.find(self.ParentSection.Entries, entry)
            if index then table.remove(self.ParentSection.Entries, index) end
            for flag, option in pairs(Library.Options) do
                if option._item == entry then
                    Library.Options[flag] = nil
                    Library.Flags[flag] = nil
                    Library._refreshers[option] = nil
                end
            end
            for option in pairs(Library._refreshers) do
                if option._item == entry then Library._refreshers[option] = nil end
            end
        end
        self.Frame:Destroy()
    end
    return card
end

------------------------------------------------------------------------
-- Label / Divider
------------------------------------------------------------------------
function Section:Label(cfg)
    if type(cfg) == "string" then
        cfg = { Text = cfg }
    end
    cfg = cfg or {}
    local text = cfg.Text or cfg.Name or "Label"
    local lbl = new("TextLabel", {
        Name = "Label", Text = text, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AS_Y, Font = FONT.Regular,
        TextSize = 12, TextWrapped = true, TextXAlignment = LEFT, Theme = { TextColor3 = "SubText" }, Parent = self.Content,
    })
    pad(lbl, 4, 2, 4, 2)
    local item = self:_entry(lbl, text)
    local obj = { Kind = "Label" }
    function obj:SetText(t)
        lbl.Text = t
        item.Name = t:lower()
    end
    function obj:SetName(v)
        lbl.Text = tostring(v or "")
        item.Name = lbl.Text:lower()
    end
    function obj:SetVisible(v)
        item.Hidden = not v
        self.Section.Window:_refreshItem(item)
    end
    function obj:Destroy()
        local i = table.find(self.Section.Entries, item)
        if i then
            table.remove(self.Section.Entries, i)
        end
        lbl:Destroy()
    end
    obj.Section = self
    return obj
end

function Section:Divider()
    local line = new("Frame", {
        Name = "Divider", Size = UDim2.new(1, 0, 0, 1), Theme = { BackgroundColor3 = "Stroke" }, Parent = self.Content,
    })
    new("UIGradient", { Transparency = seq({ 0, 1 }, { 0.5, 0.15 }, { 1, 1 }), Parent = line })
    self:_entry(line, "")
    return line
end

------------------------------------------------------------------------
-- Built-in settings page (avatar button)
------------------------------------------------------------------------
function Window:_buildSettings()
    local tab = self:_makeTab({ Name = "Settings" }, true)

    local look = tab:Section({ Name = "Appearance", Side = "Left" })
    local accent
    look:Dropdown({
        Name = "Theme", Options = Library:GetPresets(), Default = Library.PresetName,
        Tooltip = { Title = "Theme", Description = "Colours glide to the new palette. Prism is the pastel default." },
        Callback = function(name)
            Library:SetPreset(name)
            task.delay(0.65, function()
                if accent then accent:SetValue(Library.Theme.Accent, true) end
            end)
        end,
    })
    accent = look:ColorPicker({
        Name = "Accent Color", Default = Library.Theme.Accent,
        Tooltip = { Title = "Accent", Description = "Pick one colour and the whole prism re-tints around it." },
        Callback = function(color)
            Library:SetAccent(color)
        end,
    })
    look:Toggle({
        Name = "Frosted Glass", Default = self.Glass,
        Tooltip = { Title = "Frosted glass", Description = "Translucent window with a blurred scene behind it." },
        Callback = function(value) self:SetGlass(value) end,
    })
    look:Slider({
        Name = "Glass Intensity", Min = 0, Max = 100, Default = math.floor((self.GlassIntensity or 0.5) * 100), Increment = 5, Suffix = "%",
        Callback = function(value) self:SetGlass(self.Glass, value / 100) end,
    })
    look:Slider({
        Name = "Window Transparency", Min = 0, Max = 60, Default = math.floor(self.Transparency * 100), Increment = 5, Suffix = "%",
        Callback = function(value) self:SetTransparency(value / 100) end,
    })
    look:Dropdown({
        Name = "Density", Options = { "Comfortable", "Compact" }, Default = Library.Density,
        Callback = function(value) Library:SetDensity(value) end,
    })
    look:Toggle({
        Name = "Dialog Blur", Default = Library.DialogBlur,
        Callback = function(value) Library.DialogBlur = value end,
    })

    local ui = tab:Section({ Name = "Interface", Side = "Right" })
    local menuKey = ui:Keybind({
        Name = "Menu Key", Default = self.ToggleKey, Mode = "Press",
        OnBind = function(key)
            if key and typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then
                self.ToggleKey = key
            end
        end,
    })
    menuKey._kb.Down = function() end
    ui:Slider({
        Name = "UI Scale", Min = 60, Max = 130, Default = 100, Increment = 5, Suffix = "%",
        Callback = function(value)
            self:SetScale(value / 100)
        end,
    })
    ui:Slider({
        Name = "Animation Speed", Min = 50, Max = 200, Default = math.floor((Library.AnimationSpeed or 1) * 100), Increment = 10, Suffix = "%",
        Callback = function(value)
            self:SetAnimationSpeed(value / 100)
        end,
    })
    ui:Toggle({
        Name = "Animations", Default = Library.Animations ~= false,
        Callback = function(value) self:SetAnimations(value) end,
    })
    ui:Toggle({
        Name = "Snap to Edges", Default = self.SnapToEdge,
        Callback = function(value) self:SetSnapToEdge(value) end,
    })
    ui:Toggle({
        Name = "Lock Window", Default = not self.Draggable,
        Callback = function(value) self:SetDraggable(not value) end,
    })
    self._singleToggle = ui:Toggle({
        Name = "Single Column", Default = false,
        Tooltip = { Title = "Single Column", Description = "Stack every section in one column. The layout button in the top bar does the same." },
        Callback = function(value)
            if value ~= self.ForceSingle then
                self:SetSingleColumn(value)
            end
        end,
    })

    local cfgSection = tab:Section({ Name = "Configuration", Side = "Left" })
    local nameBox = cfgSection:Textbox({ Name = "Config Name", Placeholder = "default", Default = "default" })
    local picker = cfgSection:Dropdown({ Name = "Saved Configs", Options = Library:ListConfigs() })
    cfgSection:Button({
        Name = "Save Config", ButtonText = "Save", Variant = "Primary",
        Callback = function()
            local ok, err = Library:SaveConfig(nameBox.Value)
            Library:Notify({
                Title = ok and "Config saved" or "Save failed", Type = ok and "Success" or "Error",
                Content = ok and nameBox.Value or tostring(err),
            })
            picker:SetOptions(Library:ListConfigs(), true)
        end,
    })
    cfgSection:Button({
        Name = "Load Config", ButtonText = "Load",
        Callback = function()
            local target = picker.Value or nameBox.Value
            local ok, err = Library:LoadConfig(target)
            Library:Notify({
                Title = ok and "Config loaded" or "Load failed", Type = ok and "Success" or "Error",
                Content = ok and tostring(target) or tostring(err),
            })
        end,
    })
    cfgSection:Button({
        Name = "Refresh List", ButtonText = "Refresh", Variant = "Ghost",
        Callback = function()
            picker:SetOptions(Library:ListConfigs(), true)
        end,
    })
    cfgSection:Divider()
    cfgSection:Button({
        Name = "Unload Interface", ButtonText = "Unload", Variant = "Danger",
        Callback = function()
            Library:Unload()
        end,
    })
end


function Library:SetAnimations(enabled)
    local first = self.Windows[1]
    if first then first:SetAnimations(enabled) else self.Animations = enabled and true or false end
end

function Library:SetAnimationSpeed(speed)
    local first = self.Windows[1]
    if first then first:SetAnimationSpeed(speed) else self.AnimationSpeed = math.clamp(tonumber(speed) or 1, 0.1, 5) end
end

function Library:GetOption(flag)
    return self.Options[flag]
end

function Library:GetValue(flag)
    return self.Flags[flag]
end

function Library:SetValue(flag, value, silent)
    local option = self.Options[flag]
    if not option or type(option.SetValue) ~= "function" then return false end
    option:SetValue(value, silent)
    return true
end

function Library:Dialog(window, cfg)
    if type(window) == "table" and window.Dialog then
        return window:Dialog(cfg)
    end
    local target = self.Windows[1]
    return target and target:Dialog(window) or nil
end

return Library
