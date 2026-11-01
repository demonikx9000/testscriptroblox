--[[
    PRISM UI  |  v1.3.0
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
    Version = "1.3.0",
    MaxNotifications = 6,
    Animations = true,
    AnimationSpeed = 1,
    _gradients = setmetatable({}, { __mode = "k" }),
    Flags = {},
    Options = {},
    Windows = {},
    IconSet = {},
    ConfigFolder = "PrismUI",
    Theme = {
        Background = Color3.fromRGB(17, 16, 25),
        Panel      = Color3.fromRGB(24, 22, 36),
        Row        = Color3.fromRGB(29, 27, 43),
        RowHover   = Color3.fromRGB(43, 36, 62),
        Stroke     = Color3.fromRGB(57, 49, 79),
        Accent     = Color3.fromRGB(157, 111, 255),
        Accent2    = Color3.fromRGB(91, 204, 255),
        Accent3    = Color3.fromRGB(202, 105, 255),
        Text       = Color3.fromRGB(244, 240, 255),
        SubText    = Color3.fromRGB(161, 153, 184),
        Off        = Color3.fromRGB(62, 55, 82),
        Track      = Color3.fromRGB(46, 40, 65),
        Success    = Color3.fromRGB(83, 210, 163),
        Warning    = Color3.fromRGB(246, 190, 91),
        Danger     = Color3.fromRGB(245, 105, 132),
    },
    _notifCount = 0,
    _refreshers = {},
}

local FONT = {
    Regular = Enum.Font.Gotham,
    Medium = Enum.Font.GothamMedium,
    Bold = Enum.Font.GothamBold,
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
local EASE_FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local EASE_MED = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local EASE_SLOW = TweenInfo.new(0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local EASE_COLLAPSE = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, 0.06)

local activeTweens = setmetatable({}, { __mode = "k" })
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

local function play(inst, info, props)
    local prev = activeTweens[inst]
    if prev then
        prev:Cancel()
        activeTweens[inst] = nil
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
    activeTweens[inst] = tween
    tween.Completed:Once(function()
        if activeTweens[inst] == tween then
            activeTweens[inst] = nil
        end
    end)
    tween:Play()
    return tween
end

local function apply(inst, props, animate, info)
    if animate then
        return play(inst, info or EASE_MED, props)
    end
    local prev = activeTweens[inst]
    if prev then
        prev:Cancel()
        activeTweens[inst] = nil
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

function Library:_flushTheme()
    self._themePending = false
    for inst, entry in pairs(themed) do
        pcall(applyThemeEntry, inst, entry)
    end
    for gradient in pairs(self._gradients) do
        if gradient and gradient.Parent then
            gradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, self.Theme.Accent),
                ColorSequenceKeypoint.new(0.5, self.Theme.Accent3),
                ColorSequenceKeypoint.new(1, self.Theme.Accent2),
            })
        else
            self._gradients[gradient] = nil
        end
    end
    for _, refresh in pairs(self._refreshers) do
        pcall(refresh)
    end
end

-- Theme changes are applied once per frame, so dragging a colour picker or
-- slider that calls SetTheme every input event no longer re-skins the whole
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

local TEXT_CLASSES = { TextLabel = true, TextButton = true, TextBox = true }

local function new(class, props, children)
    props = props or {}
    local inst = Instance.new(class)
    local map = {}

    if inst:IsA("GuiObject") then
        inst.BorderSizePixel = 0
        if TEXT_CLASSES[class] then
            inst.BackgroundTransparency = 1
            inst.Font = FONT.Medium
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
            inst[k] = v
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

local function startGradientTween(gradient, duration)
    local previous = Library._gradientTweens and Library._gradientTweens[gradient]
    if previous then pcall(function() previous:Cancel() end) end
    if Library.Animations == false or not gradient or not gradient.Parent then return end
    local speed = math.clamp(tonumber(Library.AnimationSpeed) or 1, 0.1, 5)
    local tween = TweenService:Create(gradient,
        TweenInfo.new((duration or 12) / speed, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
        { Rotation = 360 })
    Library._gradientTweens[gradient] = tween
    tween:Play()
end

local function animatedGradient(parent, maid, duration)
    local gradient = new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Library.Theme.Accent),
            ColorSequenceKeypoint.new(0.5, Library.Theme.Accent3),
            ColorSequenceKeypoint.new(1, Library.Theme.Accent2),
        }),
        Rotation = 0,
        Parent = parent,
    })
    Library._gradients[gradient] = true
    Library._gradientDurations = Library._gradientDurations or setmetatable({}, { __mode = "k" })
    Library._gradientTweens = Library._gradientTweens or setmetatable({}, { __mode = "k" })
    Library._gradientDurations[gradient] = duration or 12
    startGradientTween(gradient, duration or 12)
    if maid then
        maid:Give(function()
            local tween = Library._gradientTweens[gradient]
            if tween then pcall(function() tween:Cancel() end) end
            Library._gradientTweens[gradient] = nil
            Library._gradientDurations[gradient] = nil
            Library._gradients[gradient] = nil
        end)
    end
    return gradient
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

function Icons.Hex(parent, diameter, outerKey, innerKey)
    local holder = new("Frame", {
        Name = "Hex", BackgroundTransparency = 1,
        Size = UDim2.fromOffset(diameter, diameter), Parent = parent,
    })
    local prismColors = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(111, 77, 255)),
        ColorSequenceKeypoint.new(0.34, Color3.fromRGB(202, 105, 255)),
        ColorSequenceKeypoint.new(0.68, Color3.fromRGB(91, 204, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(151, 112, 255)),
    })
    local function hexagon(d, key, name, usePrism)
        local half = d / 2
        local h = math.floor(half * 1.732 + 0.5)
        local w = math.floor(half + 0.5)
        local group = new("Frame", {
            Name = name, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(d, d), Parent = holder,
        })
        for _, rot in ipairs({ 30, 90, 150 }) do
            local piece = new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromOffset(w, h), Rotation = rot, Theme = { BackgroundColor3 = key },
                Parent = group,
            })
            corner(piece, 2)
            if usePrism then
                new("UIGradient", {
                    Color = prismColors, Rotation = 28, Parent = piece,
                })
            end
        end
    end
    hexagon(diameter, outerKey, "Outer", true)
    hexagon(math.floor(diameter * 0.62), innerKey, "Mid", false)
    hexagon(math.floor(diameter * 0.28), outerKey, "Core", true)
    return holder
end
function Icons.Search(parent, key)
    local holder = new("Frame", {
        Name = "SearchIcon", BackgroundTransparency = 1, Size = UDim2.fromOffset(14, 14), Parent = parent,
    })
    local ring = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(9, 9), Parent = holder })
    corner(ring, 5)
    stroke(ring, key, 1.5)
    new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(11, 11),
        Size = UDim2.fromOffset(5, 2), Rotation = 45, Theme = { BackgroundColor3 = key }, Parent = holder,
    })
    return holder
end

function Icons.Chevron(parent, key)
    local holder = new("Frame", {
        Name = "Chevron", BackgroundTransparency = 1, Size = UDim2.fromOffset(12, 8), Parent = parent,
    })
    new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(4, 4),
        Size = UDim2.fromOffset(7, 2), Rotation = 45, Theme = { BackgroundColor3 = key or "SubText" }, Parent = holder,
    })
    new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(8, 4),
        Size = UDim2.fromOffset(7, 2), Rotation = -45, Theme = { BackgroundColor3 = key or "SubText" }, Parent = holder,
    })
    return holder
end

function Icons.Close(parent, key)
    local holder = new("Frame", {
        Name = "CloseIcon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(12, 12), Parent = parent,
    })
    for _, rot in ipairs({ 45, -45 }) do
        new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(14, 2), Rotation = rot, Theme = { BackgroundColor3 = key or "SubText" },
            Parent = holder,
        })
    end
    return holder
end

function Icons.Grid(parent, key)
    local holder = new("Frame", {
        Name = "GridIcon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(14, 14), Parent = parent,
    })
    for _, p in ipairs({ { 0, 0 }, { 9, 0 }, { 0, 9 }, { 9, 9 } }) do
        local sq = new("Frame", {
            Position = UDim2.fromOffset(p[1], p[2]), Size = UDim2.fromOffset(5, 5),
            Theme = { BackgroundColor3 = key or "SubText" }, Parent = holder,
        })
        corner(sq, 1)
    end
    return holder
end

function Icons.Info(parent)
    local btn = new("TextButton", {
        Name = "Info", Text = "", Size = UDim2.fromOffset(14, 14), Parent = parent,
    })
    local ring = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = btn })
    corner(ring, 7)
    stroke(ring, "SubText", 1.2)
    new("TextLabel", {
        Text = "i", Size = UDim2.fromScale(1, 1), Font = FONT.Bold, TextSize = 10,
        Theme = { TextColor3 = "SubText" }, Parent = btn,
    })
    return btn
end

function Icons.Check(parent)
    local holder = new("Frame", {
        Name = "Check", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(12, 12), Parent = parent,
    })
    new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(3, 7), Size = UDim2.fromOffset(4, 2),
        Rotation = 45, BackgroundColor3 = Color3.new(1, 1, 1), Parent = holder,
    })
    new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(7, 5), Size = UDim2.fromOffset(8, 2),
        Rotation = -50, BackgroundColor3 = Color3.new(1, 1, 1), Parent = holder,
    })
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
        Position = UDim2.new(1, -16, 1, -16), Size = UDim2.new(0, 290, 1, -32), Parent = gui,
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
    local colorKey = ({ Info = "Accent", Success = "Success", Warning = "Warning", Error = "Danger" })[cfg.Type or "Info"] or "Accent"
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
        Name = "Card", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AS_Y, Position = UDim2.fromOffset(40, 0),
        GroupTransparency = 1, Theme = { BackgroundColor3 = "Background" }, Parent = wrap,
    })
    corner(card, 10)
    stroke(card, "Stroke")
    new("Frame", { Name = "Accent", Size = UDim2.new(0, 3, 1, 0), Theme = { BackgroundColor3 = colorKey }, Parent = card })
    local inner = new("Frame", {
        Name = "Inner", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AS_Y, Parent = card,
    })
    pad(inner, 16, 11, 12, 14)
    list(inner, 3)
    if cfg.Icon then
        local iconSource = tostring(cfg.Icon)
        if tonumber(iconSource) then iconSource = "rbxassetid://" .. iconSource end
        if iconSource:find("^rbxassetid://") or iconSource:find("^rbxasset://") or iconSource:find("^https?://") then
            new("ImageLabel", {
                Name = "Icon", Size = UDim2.fromOffset(20, 20), Image = iconSource,
                BackgroundTransparency = 1, LayoutOrder = 0, Parent = inner,
            })
        else
            new("TextLabel", {
                Name = "Icon", Size = UDim2.fromOffset(22, 20), Text = iconSource,
                TextSize = 16, TextXAlignment = LEFT, LayoutOrder = 0,
                Theme = { TextColor3 = colorKey }, Parent = inner,
            })
        end
    end
    if cfg.Title then
        new("TextLabel", {
            Name = "Title", Text = cfg.Title, Size = UDim2.new(1, 0, 0, 16), Font = FONT.Bold,
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
            Name = "Action", Text = tostring(cfg.ActionText), Size = UDim2.fromOffset(0, 24),
            AutomaticSize = AS_X, TextSize = 11, BackgroundTransparency = 0.82,
            Theme = { BackgroundColor3 = colorKey, TextColor3 = colorKey }, LayoutOrder = 3, Parent = inner,
        })
        corner(actionButton, 6); pad(actionButton, 10, 0, 10, 0)
    end
    local progress = new("Frame", {
        Name = "Progress", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 2), BackgroundTransparency = 0.4, Theme = { BackgroundColor3 = colorKey },
        Parent = card,
    })

    local open = self._openNotifs
    if not open then
        open = {}
        self._openNotifs = open
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
        play(card, EASE_MED, { GroupTransparency = 1, Position = UDim2.fromOffset(40, 0) })
        -- collapse this toast's slot so the ones above glide down instead of jumping
        local height = wrap.AbsoluteSize.Y
        wrap.AutomaticSize = Enum.AutomaticSize.None
        wrap.Size = UDim2.new(1, 0, 0, height)
        wrap.ClipsDescendants = true
        local collapse = play(wrap, EASE_COLLAPSE, { Size = UDim2.new(1, 0, 0, 0) })
        if collapse then
            collapse.Completed:Once(function()
                wrap:Destroy()
            end)
        else
            wrap:Destroy()
        end
    end

    play(card, EASE_MED, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) })
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
        actionButton.MouseButton1Click:Connect(function()
            safeCall(cfg.OnAction)
            if cfg.CloseOnAction ~= false then close() end
        end)
    end
    card.InputBegan:Connect(function(input)
        if isPress(input) then
            close()
        end
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
    for flag, value in pairs(data) do
        local el = self.Options[flag]
        if el and el.Deserialize then
            pcall(el.Deserialize, el, decode(value))
        end
    end
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
    if not isfolder(self.ConfigFolder) then
        makefolder(self.ConfigFolder)
    end
    writefile(path, HttpService:JSONEncode(self:GetConfig()))
    return true
end

function Library:LoadConfig(name)
    if not canFile() then
        return false, "file functions unavailable"
    end
    local path = configPath(name)
    if not (isfile and isfile(path)) then
        return false, "config not found"
    end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)
    if not ok then
        return false, "corrupted config"
    end
    self:SetConfig(data)
    return true
end

function Library:ListConfigs()
    local out = {}
    if canFile() and typeof(listfiles) == "function" and isfolder(self.ConfigFolder) then
        for _, file in ipairs(listfiles(self.ConfigFolder)) do
            local name = file:match("([^/\\]+)%.json$")
            if name then
                table.insert(out, name)
            end
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
        Query = "",
        ForceSingle = false,
        Presets = {},
        _keybinds = {},
        _lastListenEnd = 0,
    }, Window)
    table.insert(self.Windows, window)

    -- main frame -------------------------------------------------------
    local main = new("Frame", {
        Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(size.X, size.Y), ClipsDescendants = true,
        BackgroundTransparency = window.Transparency, Theme = { BackgroundColor3 = "Background" }, Parent = gui,
    })
    corner(main, 12)
    stroke(main, "Stroke")
    window.Main = main
    window._uiscale = new("UIScale", { Parent = main })

    -- topbar -------------------------------------------------------------
    local topbar = new("Frame", { Name = "Topbar", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), Parent = main })
    local gradientLine = new("Frame", {
        Name = "GradientAccent", Position = UDim2.new(0, 12, 1, -2), Size = UDim2.new(1, -24, 0, 2),
        BackgroundColor3 = Color3.new(1, 1, 1), Parent = topbar,
    })
    if cfg.AnimatedGradient == false then
        new("UIGradient", { Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Library.Theme.Accent),
            ColorSequenceKeypoint.new(0.5, Library.Theme.Accent3),
            ColorSequenceKeypoint.new(1, Library.Theme.Accent2),
        }), Parent = gradientLine })
    else
        window._gradient = animatedGradient(gradientLine, window.Maid, cfg.GradientDuration or 12)
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
        Size = UDim2.new(0, math.max(82, #tostring(cfg.Title or "PrismUI") * 9), 0, 52), TextXAlignment = LEFT, TextYAlignment = Enum.TextYAlignment.Center,
        Font = FONT.Bold, TextSize = 15, Theme = { TextColor3 = "Text" }, Parent = topbar,
    })
    new("Frame", {
        Name = "Separator", Position = UDim2.fromOffset(136, 16), Size = UDim2.fromOffset(1, 20),
        Theme = { BackgroundColor3 = "Stroke" }, Parent = topbar,
    })

    local searchFrame = new("Frame", {
        Name = "Search", Position = UDim2.fromOffset(148, 10), Size = UDim2.new(1, -286, 0, 32),
        Theme = { BackgroundColor3 = "Panel" }, Parent = topbar,
    })
    corner(searchFrame, 8)
    local searchStroke = stroke(searchFrame, "Stroke")
    local searchIcon = Icons.Search(searchFrame, "SubText")
    searchIcon.AnchorPoint = Vector2.new(0, 0.5)
    searchIcon.Position = UDim2.new(0, 12, 0.5, 0)
    local searchInput = new("TextBox", {
        Name = "Input", Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -44, 1, 0), Text = "",
        PlaceholderText = "Search", TextXAlignment = LEFT, TextSize = 13, Font = FONT.Medium,
        Theme = { TextColor3 = "Text", PlaceholderColor3 = "SubText" }, Parent = searchFrame,
    })
    window.SearchInput = searchInput
    window.SearchFrame = searchFrame
    window.Maid:Give(searchInput.Focused:Connect(function()
        play(searchStroke, EASE_FAST, { Color = Library.Theme.Accent })
    end))
    window.Maid:Give(searchInput.FocusLost:Connect(function()
        play(searchStroke, EASE_FAST, { Color = Library.Theme.Stroke })
    end))
    local searchToken = 0
    window.Maid:Give(searchInput:GetPropertyChangedSignal("Text"):Connect(function()
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

    local function topButton(name, xFromRight)
        local btn = new("TextButton", {
            Name = name, Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -xFromRight, 0, 10),
            Size = UDim2.fromOffset(32, 32), Theme = { BackgroundColor3 = "Panel" }, Parent = topbar,
        })
        corner(btn, 8)
        stroke(btn, "Stroke")
        btn.MouseEnter:Connect(function()
            play(btn, EASE_FAST, { BackgroundColor3 = Library.Theme.RowHover })
        end)
        btn.MouseLeave:Connect(function()
            play(btn, EASE_FAST, { BackgroundColor3 = Library.Theme.Panel })
        end)
        return btn
    end
    local gridBtn = topButton("Layout", 92)
    Icons.Grid(gridBtn, "SubText")
    local minimizeBtn = topButton("Minimize", 52)
    minimizeBtn.Text = "−"
    minimizeBtn.Font = FONT.Bold
    minimizeBtn.TextSize = 19
    minimizeBtn.TextColor3 = Library.Theme.SubText
    local closeBtn = topButton("Close", 12)
    Icons.Close(closeBtn, "SubText")
    window.LayoutButton = gridBtn
    window.MinimizeButton = minimizeBtn
    window.CloseButton = closeBtn

    window.Maid:Give(gridBtn.MouseButton1Click:Connect(function()
        window:SetSingleColumn(not window.ForceSingle)
        if cfg.OnLayout then
            safeCall(cfg.OnLayout, window.ForceSingle)
        end
    end))
    window.Maid:Give(closeBtn.MouseButton1Click:Connect(function()
        window:SetVisible(false)
        if cfg.OnClose then
            safeCall(cfg.OnClose)
        end
    end))
    window.Maid:Give(minimizeBtn.MouseButton1Click:Connect(function()
        window:SetMinimized(not window.Minimized)
    end))

    -- sidebar --------------------------------------------------------------
    local sidebar = new("Frame", {
        Name = "Sidebar", Position = UDim2.fromOffset(10, 58), Size = UDim2.new(0, 46, 1, -68),
        Theme = { BackgroundColor3 = "Panel" }, Parent = main,
    })
    corner(sidebar, 10)
    stroke(sidebar, "Stroke")
    local tabList = new("ScrollingFrame", {
        Name = "Tabs", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 1, -66),
        CanvasSize = UDim2.new(), AutomaticCanvasSize = AS_Y, ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y, Parent = sidebar,
    })
    list(tabList, 6, VERT, Enum.HorizontalAlignment.Left)
    pad(tabList, 6, 0, 6, 0)
    window.TabList = tabList
    window.Sidebar = sidebar
    window.SidebarExpanded = false

    local moreChevron = Icons.Chevron(sidebar, "SubText")
    moreChevron.AnchorPoint = Vector2.new(0.5, 1)
    moreChevron.Position = UDim2.new(0.5, 0, 1, -50)
    moreChevron.Visible = false
    local function updateMore()
        moreChevron.Visible = tabList.AbsoluteCanvasSize.Y > tabList.AbsoluteSize.Y + 1
    end
    window.Maid:Give(tabList:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updateMore))
    window.Maid:Give(tabList:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateMore))

    local avatarBtn = new("TextButton", {
        Name = "Avatar", Text = "", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -7),
        Size = UDim2.fromOffset(32, 32), Theme = { BackgroundColor3 = "Row" }, Parent = sidebar,
    })
    corner(avatarBtn, 16)
    window._avatarStroke = new("UIStroke", {
        Thickness = 2, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Theme = { Color = "Accent" }, Parent = avatarBtn,
    })
    local avatarImg = new("ImageLabel", { Name = "Headshot", Size = UDim2.fromScale(1, 1), Parent = avatarBtn })
    corner(avatarImg, 16)
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
    -- The panel floats over the page instead of resizing it, so hovering the
    -- sidebar never forces every tab to re-layout mid-animation, and a short
    -- hover-intent delay on collapse stops it flickering at the edges.
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
        play(sidebar, EASE_MED, { Size = UDim2.new(0, expanded and 166 or 46, 1, -68) })
        for _, existingTab in ipairs(window.Tabs) do
            local navLabel = existingTab._navLabel
            local navButton = existingTab._navButton
            if navLabel and navButton and navButton.Parent then
                if expanded then
                    navLabel.Visible = true
                end
                play(navLabel, EASE_MED, { TextTransparency = expanded and 0 or 1 })
                play(navButton, EASE_MED, {
                    Size = expanded and UDim2.new(1, 0, 0, 34) or UDim2.fromOffset(34, 34),
                })
            end
        end
    end
    window._setSidebarExpanded = setSidebarExpanded
    window.Maid:Give(sidebar.MouseEnter:Connect(function()
        setSidebarExpanded(true)
    end))
    window.Maid:Give(sidebar.MouseLeave:Connect(function()
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
    window.Maid:Give(window._blocker.MouseButton1Click:Connect(function()
        if window._dialog then
            window:_closeDialog()
        else
            window:_closePopup()
        end
    end))
    window:_buildTooltip()

    -- resize grip ------------------------------------------------------------
    if cfg.Resizable ~= false then
        local grip = new("TextButton", {
            Name = "Grip", Text = "", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -3, 1, -3),
            Size = UDim2.fromOffset(16, 16), ZIndex = 5, Parent = main,
        })
        for i = 0, 1 do
            new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(9 - i * 3, 9 - i * 3),
                Size = UDim2.fromOffset(10 - i * 5, 2), Rotation = -45, BackgroundTransparency = 0.4,
                Theme = { BackgroundColor3 = "SubText" }, Parent = grip,
            })
        end
        window.Grip = grip
        local resizing, startMouse, startSize, startPos = false, nil, nil, nil
        window.Maid:Give(grip.InputBegan:Connect(function(input)
            if isPress(input) then
                resizing = true
                startMouse = Vector2.new(input.Position.X, input.Position.Y)
                startSize = window.Size
                startPos = main.Position
            end
        end))
        window.Maid:Give(UserInputService.InputChanged:Connect(function(input)
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
        window.Maid:Give(UserInputService.InputEnded:Connect(function(input)
            if resizing and isPress(input) then
                resizing = false
            end
        end))
    end

    -- dragging -------------------------------------------------------------
    makeDraggable(window.Maid, topbar, main, nil, nil, function()
        return window.Draggable
    end, function()
        if window.SnapToEdge then window:_snapToEdges() end
    end, true, function(pos)
        return window:_clampPosition(pos)
    end)

    -- input (keybinds, toggle key, mouse tracking) ------------------------------
    window.Maid:Give(UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            window._mouse = Vector2.new(input.Position.X, input.Position.Y)
            window:_moveTip()
        end
    end))
    window.Maid:Give(UserInputService.InputBegan:Connect(function(input)
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
    window.Maid:Give(UserInputService.InputEnded:Connect(function(input)
        for _, kb in ipairs(window._keybinds) do
            local key = kb.Get()
            if key and kb.Up and (input.KeyCode == key or input.UserInputType == key) then
                kb.Up()
            end
        end
    end))

    -- responsive scale -----------------------------------------------------------
    window.Maid:Give(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        window:_updateScale()
        window:_clamp()
    end))
    window:_updateScale()
    window._uiscale.Scale = window.Scale * 0.92
    play(window._uiscale, EASE_SLOW, { Scale = window.Scale })

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
        stroke(fab, "Stroke")
        local fabLogo = Icons.Hex(fab, 22, "Accent", "Panel")
        fabLogo.AnchorPoint = Vector2.new(0.5, 0.5)
        fabLogo.Position = UDim2.fromScale(0.5, 0.5)
        makeDraggable(window.Maid, fab, fab, nil, function()
            window:SetVisible(not window.Visible)
        end)
        window.Maid:Give(fab)
    end

    -- built-in settings page (opened by the avatar button) ----------------------------
    if cfg.Settings ~= false then
        window:_buildSettings()
    end

    window.Maid:Give(avatarBtn.MouseButton1Click:Connect(function()
        if window.SettingsTab then
            window:Select(window.SettingsTab)
        end
    end))
    window.Maid:Give(main)

    return window
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
    local tweens = Library._gradientTweens
    local tween = tweens and self._gradient and tweens[self._gradient]
    if not tween then
        return
    end
    if running then
        if Library.Animations ~= false then
            tween:Play()
        end
    else
        tween:Pause()
    end
end

function Window:SetVisible(visible)
    if visible == self.Visible then
        return
    end
    self.Visible = visible
    self:_setGradientRunning(visible)
    if visible then
        self.Main.Visible = true
        self._uiscale.Scale = self.Scale * 0.94
        play(self._uiscale, EASE_MED, { Scale = self.Scale })
    else
        self:_closePopup()
        self:_hideTip()
        if self._setSidebarExpanded then
            self._setSidebarExpanded(false)
        end
        play(self._uiscale, EASE_FAST, { Scale = self.Scale * 0.94 })
        task.delay(0.13, function()
            if not self.Visible then
                self.Main.Visible = false
                self._uiscale.Scale = self.Scale
            end
        end)
    end
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
        if self.MinimizeButton then self.MinimizeButton.Text = "+" end
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
        if self.MinimizeButton then self.MinimizeButton.Text = "−" end
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
    if self.Main then self.Main.BackgroundTransparency = self.Transparency end
end

function Window:SetAnimationSpeed(speed)
    Library.AnimationSpeed = math.clamp(tonumber(speed) or 1, 0.1, 5)
    for gradient, duration in pairs(Library._gradientDurations or {}) do
        startGradientTween(gradient, duration)
    end
end

function Window:SetAnimations(enabled)
    Library.Animations = enabled and true or false
    for gradient, duration in pairs(Library._gradientDurations or {}) do
        if Library.Animations then
            startGradientTween(gradient, duration)
        else
            local tween = Library._gradientTweens and Library._gradientTweens[gradient]
            if tween then pcall(function() tween:Cancel() end) end
            if Library._gradientTweens then Library._gradientTweens[gradient] = nil end
        end
    end
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
    local shade = new("Frame", {
        Name = "DialogShade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1, ZIndex = 55, Parent = overlay,
    })
    local card = new("CanvasGroup", {
        Name = "Dialog", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(cfg.Width or 340, cfg.Height or 176), ZIndex = 60, GroupTransparency = 1,
        Theme = { BackgroundColor3 = "Background" }, Parent = overlay,
    })
    local cardScale = new("UIScale", { Scale = 0.92, Parent = card })
    corner(card, 12); stroke(card, "Stroke"); pad(card, 16, 14, 16, 14)
    local title = new("TextLabel", {
        Name = "Title", Text = cfg.Title or "Confirm action", Size = UDim2.new(1, 0, 0, 22),
        TextSize = 15, Font = FONT.Bold, TextXAlignment = LEFT, ZIndex = 61, Parent = card,
    })
    local content = new("TextLabel", {
        Name = "Content", Text = cfg.Content or cfg.Description or "Are you sure?",
        Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 1, -78),
        TextSize = 12, Font = FONT.Regular, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
        TextXAlignment = LEFT, ZIndex = 61, Theme = { TextColor3 = "SubText" }, Parent = card,
    })
    local actions = new("Frame", {
        Name = "Actions", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, ZIndex = 61, Parent = card,
    })
    list(actions, 8, HORIZ, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
    local dialog = { Frame = card, Shade = shade, Closed = false }
    local function close(confirmed)
        if dialog.Closed then return end
        dialog.Closed = true
        self._dialog = nil
        self._blocker.Visible = false
        play(card, EASE_FAST, { GroupTransparency = 1 })
        play(cardScale, EASE_FAST, { Scale = 0.94 })
        play(shade, EASE_FAST, { BackgroundTransparency = 1 })
        task.delay(0.15, function()
            if card.Parent then card:Destroy() end
            if shade.Parent then shade:Destroy() end
        end)
        if confirmed then safeCall(cfg.OnConfirm) else safeCall(cfg.OnCancel) end
    end
    local cancel = new("TextButton", {
        Name = "Cancel", Text = cfg.CancelText or "Cancel", Size = UDim2.fromOffset(82, 28),
        BackgroundTransparency = 0.2, ZIndex = 62, Theme = { BackgroundColor3 = "Panel", TextColor3 = "SubText" }, Parent = actions,
    })
    corner(cancel, 6)
    local confirm = new("TextButton", {
        Name = "Confirm", Text = cfg.ConfirmText or "Confirm", Size = UDim2.fromOffset(92, 28),
        BackgroundTransparency = 0.05, ZIndex = 62, Theme = { BackgroundColor3 = cfg.Danger and "Danger" or "Accent", TextColor3 = "Text" }, Parent = actions,
    })
    corner(confirm, 6)
    cancel.MouseButton1Click:Connect(function() close(false) end)
    confirm.MouseButton1Click:Connect(function() close(true) end)
    self._dialog = dialog
    dialog.Close = function() close(false) end
    dialog.Confirm = function() close(true) end
    play(card, EASE_MED, { GroupTransparency = 0 })
    play(cardScale, EASE_MED, { Scale = 1 })
    play(shade, EASE_MED, { BackgroundTransparency = 0.45 })
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
    local i = table.find(self.Library.Windows, self)
    if i then
        table.remove(self.Library.Windows, i)
    end
    for _, tab in ipairs(self.Tabs) do
        Library._refreshers[tab] = nil
    end
    self.Maid:Clean()
end

-- tooltip -----------------------------------------------------------------------
function Window:_buildTooltip()
    local frame = new("Frame", {
        Name = "Tooltip", Visible = false, ZIndex = 20, AutomaticSize = AS_XY, Size = UDim2.fromOffset(0, 0),
        Theme = { BackgroundColor3 = "Background" }, Parent = self.Overlay,
    })
    corner(frame, 8)
    stroke(frame, "Stroke")
    pad(frame, 10, 8, 10, 8)
    list(frame, 3)
    local title = new("TextLabel", {
        Name = "Title", Font = FONT.Bold, TextSize = 13, TextXAlignment = LEFT, LayoutOrder = 1, Parent = frame,
    })
    local desc = new("TextLabel", {
        Name = "Description", Font = FONT.Regular, TextSize = 12, TextXAlignment = LEFT, TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2, Theme = { TextColor3 = "SubText" }, Parent = frame,
    })
    self._tip = { Frame = frame, Title = title, Desc = desc }
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
    t.Title.Visible = titleText ~= ""
    t.Desc.Visible = descText ~= ""
    if titleText ~= "" then
        local b = TextService:GetTextSize(titleText, 13, FONT.Bold, Vector2.new(260, 1000))
        t.Title.Text = titleText
        t.Title.Size = UDim2.fromOffset(b.X + 2, b.Y)
    end
    if descText ~= "" then
        local b = TextService:GetTextSize(descText, 12, FONT.Regular, Vector2.new(220, 1000))
        t.Desc.Text = descText
        t.Desc.Size = UDim2.fromOffset(math.min(b.X + 3, 220), b.Y)
    end
    t.Frame.Visible = true
    self:_moveTip()
end

function Window:_hideTip()
    if self._tip then
        self._tip.Frame.Visible = false
    end
end

function Window:_moveTip()
    local f = self._tip and self._tip.Frame
    if not f or not f.Visible or not self._mouse then
        return
    end
    local s = self.Scale
    local o = self.Overlay.AbsolutePosition
    local ov = self.Overlay.AbsoluteSize / s
    local size = f.AbsoluteSize / s
    local mx = (self._mouse.X - o.X) / s
    local my = (self._mouse.Y - o.Y) / s
    local x = math.clamp(mx + 14, 4, math.max(4, ov.X - size.X - 4))
    local y = my + 18
    if y + size.Y > ov.Y - 4 then
        y = my - size.Y - 10
    end
    f.Position = UDim2.fromOffset(x, math.max(4, y))
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
    local y = ay + ah + 4
    if y + p.Size.Y > ov.Y - 4 then
        y = math.max(4, ay - p.Size.Y - 4)
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
    p.Frame.Visible = true
    self:_placePopup(p)
    p.Frame.Size = UDim2.fromOffset(p.Size.X, 0)
    play(p.Frame, EASE_MED, { Size = UDim2.fromOffset(p.Size.X, p.Size.Y) })
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
    play(p.Frame, EASE_FAST, { Size = UDim2.fromOffset(p.Size.X, 0) })
    task.delay(0.13, function()
        if self._popup ~= p and p.Frame.Parent then
            p.Frame.Visible = false
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
    local btn = new("TextButton", {
        Name = "KeyChip", AutomaticSize = AS_X, Size = UDim2.fromOffset(0, 22), Text = "",
        Theme = { BackgroundColor3 = "Panel" }, Parent = parent,
    })
    corner(btn, 6)
    stroke(btn, "Stroke")
    new("UISizeConstraint", { MinSize = Vector2.new(34, 22), Parent = btn })
    pad(btn, 8, 0, 8, 0)
    list(btn, 0, HORIZ, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
    local lbl = new("TextLabel", {
        Name = "Key", AutomaticSize = AS_X, Size = UDim2.fromOffset(0, 22), Text = keyName(initial),
        TextSize = 11, Theme = { TextColor3 = "SubText" }, Parent = btn,
    })
    chip.Frame = btn

    local function render()
        lbl.Text = keyName(chip.Key)
        play(lbl, EASE_FAST, { TextColor3 = chip.Key and Library.Theme.Text or Library.Theme.SubText })
    end
    function chip.Set(key)
        chip.Key = key
        render()
    end
    self.Maid:Give(btn.MouseButton1Click:Connect(function()
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
local function buildIcon(parent, icon, tabName)
    local img = icon and (Library.IconSet[icon] or icon)
    if type(img) == "string" and (img:find("^rbxassetid://") or img:find("^rbxasset://") or img:find("^https?://") or tonumber(img)) then
        if tonumber(img) then
            img = "rbxassetid://" .. img
        end
        local i = new("ImageLabel", {
            Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(18, 18), Image = img, Theme = { ImageColor3 = "SubText" }, Parent = parent,
        })
        return i, "ImageColor3"
    end
    local text
    if type(icon) == "string" and icon ~= "" and #icon <= 2 then
        text = icon
    else
        text = (tabName or "?"):sub(1, 1):upper()
    end
    local l = new("TextLabel", {
        Name = "Icon", Size = UDim2.fromScale(1, 1), Text = text, Font = FONT.Bold, TextSize = 14,
        Theme = { TextColor3 = "SubText" }, Parent = parent,
    })
    return l, "TextColor3"
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
        _matches = 0,
        _sideCount = 0,
    }, Tab)

    local page = new("ScrollingFrame", {
        Name = tab.Name, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(),
        AutomaticCanvasSize = AS_Y, ScrollBarThickness = 3, ScrollingDirection = Enum.ScrollingDirection.Y,
        Visible = false, Theme = { ScrollBarImageColor3 = "Stroke" }, Parent = self.Content,
    })
    pad(page, 0, 0, 10, 8)
    local cols = new("Frame", {
        Name = "Columns", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AS_Y, Parent = page,
    })
    tab.Layout = list(cols, 12, HORIZ)
    local function makeCol(name, order)
        local f = new("Frame", {
            Name = name, BackgroundTransparency = 1, Size = UDim2.new(0.5, -6, 0, 0), AutomaticSize = AS_Y,
            LayoutOrder = order, Parent = cols,
        })
        list(f, 14)
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
            apply(self._avatarStroke, { Transparency = active and 0 or 1 }, animate ~= false, EASE_MED)
        end
    else
        btn = new("TextButton", {
            Name = tab.Name, Text = "",
            Size = self.SidebarExpanded and UDim2.new(1, 0, 0, 34) or UDim2.fromOffset(34, 34),
            LayoutOrder = #self.Tabs + 1,
            Theme = { BackgroundColor3 = "Accent" }, Parent = self.TabList,
        })
        corner(btn, 9)
        local btnStroke = new("UIStroke", {
            Thickness = 1, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Theme = { Color = "Accent" }, Parent = btn,
        })
        local icon, iconProp = buildIcon(btn, cfg.Icon, tab.Name)
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.Position = UDim2.fromOffset(17, 17)
        icon.Size = UDim2.fromOffset(18, 18)
        local navLabel = new("TextLabel", {
            Name = "Label", Text = tab.Name, Position = UDim2.fromOffset(42, 0),
            Size = UDim2.new(1, -48, 1, 0), Visible = self.SidebarExpanded == true,
            TextTransparency = self.SidebarExpanded and 0 or 1, TextXAlignment = LEFT,
            TextTruncate = Enum.TextTruncate.AtEnd, TextSize = 12, Font = FONT.Medium,
            Theme = { TextColor3 = "SubText" }, Parent = btn,
        })
        tab._navButton = btn
        tab._navLabel = navLabel
        tab._dot = new("Frame", {
            Name = "MatchDot", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -3, 0, 3),
            Size = UDim2.fromOffset(6, 6), Visible = false, Theme = { BackgroundColor3 = "Accent" }, Parent = btn,
        })
        corner(tab._dot, 3)
        tab._setActive = function(active, animate)
            local go = animate ~= false
            apply(btn, { BackgroundTransparency = active and 0.86 or 1 }, go, EASE_MED)
            apply(btnStroke, { Transparency = active and 0.55 or 1 }, go, EASE_MED)
            local color = active and Library.Theme.Accent or Library.Theme.SubText
            apply(icon, { [iconProp] = color }, go, EASE_MED)
            apply(navLabel, { TextColor3 = active and Library.Theme.Text or Library.Theme.SubText }, go, EASE_MED)
        end
        self.Maid:Give(btn.MouseEnter:Connect(function()
            if self.ActiveTab ~= tab then
                play(icon, EASE_FAST, { [iconProp] = Library.Theme.Text })
            end
        end))
        self.Maid:Give(btn.MouseLeave:Connect(function()
            if self.ActiveTab ~= tab then
                play(icon, EASE_FAST, { [iconProp] = Library.Theme.SubText })
            end
        end))
    end
    tab.Button = btn
    self.Maid:Give(btn.MouseButton1Click:Connect(function()
        self:Select(tab)
    end))
    self:_tooltip(btn, function()
        return { Title = tab.Name }
    end, 0.5)

    Library._refreshers[tab] = function()
        tab._setActive(self.ActiveTab == tab, false)
    end

    table.insert(self.Tabs, tab)
    if isSettings then
        self.SettingsTab = tab
    elseif not self.ActiveTab then
        self:Select(tab)
    end
    tab:_layout()
    return tab
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
    self:_closePopup()
    local prev = self.ActiveTab
    if prev then
        prev.Page.Visible = false
        prev._setActive(false)
    end
    self.ActiveTab = tab
    tab.Page.Visible = true
    tab.Page.Position = UDim2.fromOffset(0, 10)
    play(tab.Page, EASE_MED, { Position = UDim2.fromOffset(0, 0) })
    tab._setActive(true)
    tab:_layout()
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
    list(frame, cfg.SectionSpacing or 6)
    local header = new(cfg.Collapsible and "TextButton" or "TextLabel", {
        Name = "Header", Text = cfg.Name or "Section", Size = UDim2.new(1, 0, 0, 20), TextSize = 12,
        TextXAlignment = LEFT, LayoutOrder = 0, BackgroundTransparency = 1,
        Theme = { TextColor3 = "SubText" }, Parent = frame,
    })
    if cfg.Collapsible then
        header.AutoButtonColor = false
    end
    pad(header, 3, 0, 24, 0)
    local description
    if cfg.Description and cfg.Description ~= "" then
        description = new("TextLabel", {
            Name = "Description", Text = cfg.Description, Size = UDim2.new(1, -6, 0, 0),
            AutomaticSize = AS_Y, TextWrapped = true, TextSize = 11, TextXAlignment = LEFT,
            Font = FONT.Regular, LayoutOrder = 1, Theme = { TextColor3 = "SubText" }, Parent = frame,
        })
        pad(description, 3, 0, 3, 2)
    end
    local items = new("Frame", {
        Name = "Items", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AS_Y,
        LayoutOrder = description and 2 or 1, Parent = frame,
    })
    list(items, cfg.Spacing or 6)
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
        section._chevron = new("TextLabel", {
            Name = "Chevron", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -5, 0.5, 0),
            Size = UDim2.fromOffset(16, 16), Text = section.Collapsed and "+" or "−", TextSize = 16,
            BackgroundTransparency = 1, Theme = { TextColor3 = "SubText" }, Parent = header,
        })
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
    self.Header.Text = name
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
        self._chevron.Text = state and "+" or "−"
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
    local row = new("Frame", {
        Name = cfg.Name or "Row", Size = UDim2.new(1, 0, 0, height or 38),
        Theme = { BackgroundColor3 = "Row" }, Parent = self.Content,
    })
    corner(row, 8)
    stroke(row, "Stroke")
    local hit = new("TextButton", { Name = "Hit", Text = "", Size = UDim2.fromScale(1, 1), Parent = row })
    local maid = self.Window.Maid
    maid:Give(hit.MouseEnter:Connect(function()
        play(row, EASE_FAST, { BackgroundColor3 = Library.Theme.RowHover })
    end))
    maid:Give(hit.MouseLeave:Connect(function()
        play(row, EASE_FAST, { BackgroundColor3 = Library.Theme.Row })
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
    if el.Flag then
        Library.Flags[el.Flag] = el.Value
    end
end

local function buildLeft(el, row, cfg, fallback, rightFrame)
    local left = new("Frame", {
        Name = "Left", BackgroundTransparency = 1, AutomaticSize = AS_X, Size = UDim2.new(0, 0, 1, 0),
        Position = UDim2.fromOffset(12, 0), Parent = row,
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
        local avail = row.AbsoluteSize.X / scale - rightW - 40 - (info.Visible and 21 or 0)
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
        Position = UDim2.new(1, -12, 0.5, 0), AutomaticSize = AS_X, Size = UDim2.fromOffset(0, 24), Parent = row,
    })
    list(right, spacing or 8, HORIZ, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
    return right
end

------------------------------------------------------------------------
-- Element base
------------------------------------------------------------------------
function Element:_commit()
    if self.Disabled then
        return
    end
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
    self.Name = name
    self._item.Name = name:lower()
    if self._label then
        self._label.Text = name
    end
end

function Element:Destroy()
    Library._refreshers[self] = nil
    local i = table.find(self.Section.Entries, self._item)
    if i then
        table.remove(self.Section.Entries, i)
    end
    if self.Flag then
        Library.Flags[self.Flag] = nil
        Library.Options[self.Flag] = nil
    end
    if self._onDestroy then
        self._onDestroy()
    end
    self.Row:Destroy()
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
                return el.Key
            end,
            Down = function()
                el:SetValue(not el.Value)
            end,
        })
    end

    local switch = new("Frame", {
        Name = "Switch", Size = UDim2.fromOffset(34, 18), LayoutOrder = 2, Theme = { BackgroundColor3 = "Off" }, Parent = right,
    })
    corner(switch, 9)
    local knob = new("Frame", {
        Name = "Knob", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Color3.new(1, 1, 1), Parent = switch,
    })
    corner(knob, 6)
    el._switch, el._knob = switch, knob

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
    apply(self._switch, { BackgroundColor3 = on and Library.Theme.Accent or Library.Theme.Off }, animate, EASE_MED)
    apply(self._knob, { Position = on and UDim2.new(1, -15, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }, animate, EASE_MED)
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

    local right = buildRight(row, 10)
    buildLeft(el, row, cfg, "Slider", right)

    local box = new("TextBox", {
        Name = "Value", Size = UDim2.fromOffset(46, 20), Text = "", Font = FONT.Bold, TextSize = 12,
        TextXAlignment = RIGHT, LayoutOrder = 1, Parent = right,
    })
    local area = new("TextButton", {
        Name = "TrackArea", Text = "", Size = UDim2.fromOffset(132, 24), LayoutOrder = 2, Parent = right,
    })
    local track = new("Frame", {
        Name = "Track", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0),
        Size = UDim2.new(1, -12, 0, 4), Theme = { BackgroundColor3 = "Track" }, Parent = area,
    })
    corner(track, 2)
    local fill = new("Frame", {
        Name = "Fill", Size = UDim2.fromScale(0, 1), Theme = { BackgroundColor3 = "Accent" }, Parent = track,
    })
    corner(fill, 2)
    local knob = new("Frame", {
        Name = "Knob", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Color3.new(1, 1, 1), Parent = track,
    })
    corner(knob, 6)
    el._box, el._fill, el._knob, el._track = box, fill, knob, track

    local dragging = false
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
            play(knob, EASE_FAST, { Size = UDim2.fromOffset(12, 12) })
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
            play(knob, EASE_FAST, { Size = UDim2.fromOffset(15, 15) })
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

    el:_visual(false)
    publish(el)
    return el
end

function Slider:_visual(animate)
    local range = self.Max - self.Min
    local a = range == 0 and 0 or (self.Value - self.Min) / range
    apply(self._fill, { Size = UDim2.fromScale(a, 1) }, animate, EASE_FAST)
    apply(self._knob, { Position = UDim2.fromScale(a, 0.5) }, animate, EASE_FAST)
    if not self._box:IsFocused() then
        self._box.Text = string.format("%." .. self._dec .. "f", self.Value) .. self.Suffix
    end
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
    self.Min, self.Max = min, max
    self.Value = math.clamp(self.Value, min, max)
    self:_visual(true)
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
        Name = "Value", AutomaticSize = AS_X, Size = UDim2.fromOffset(0, 24), TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = RIGHT, LayoutOrder = 1,
        Theme = { TextColor3 = "SubText" }, Parent = right,
    })
    new("UISizeConstraint", { MaxSize = Vector2.new(150, 24), Parent = valueLabel })
    local chevron = Icons.Chevron(right, "SubText")
    chevron.LayoutOrder = 2
    el._valueLabel, el._chevron = valueLabel, chevron

    -- popup
    local popFrame = new("Frame", {
        Name = "DropdownPopup", Visible = false, ZIndex = 2, ClipsDescendants = true, Size = UDim2.fromOffset(160, 0),
        Theme = { BackgroundColor3 = "Background" }, Parent = window.Overlay,
    })
    corner(popFrame, 8)
    stroke(popFrame, "Stroke")
    local searchBox
    local listFrame = new("ScrollingFrame", {
        Name = "List", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 1, -12),
        CanvasSize = UDim2.new(), AutomaticCanvasSize = AS_Y, ScrollBarThickness = 3,
        ScrollingDirection = Enum.ScrollingDirection.Y, Theme = { ScrollBarImageColor3 = "Stroke" }, Parent = popFrame,
    })
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
                Text = "No options", Size = UDim2.new(1, 0, 0, 26), TextSize = 12,
                Theme = { TextColor3 = "SubText" }, Parent = listFrame,
            })
        end
        for i, opt in ipairs(el.Options) do
            local b = new("TextButton", {
                Name = tostring(opt), Text = "", Size = UDim2.new(1, 0, 0, 26), LayoutOrder = i,
                BackgroundTransparency = 1, Theme = { BackgroundColor3 = "Accent" }, Parent = listFrame,
            })
            corner(b, 6)
            local entry = { Frame = b }
            if el.Multi then
                entry.Box = new("Frame", {
                    Name = "Box", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0),
                    Size = UDim2.fromOffset(14, 14), Theme = { BackgroundColor3 = "Track" }, Parent = b,
                })
                corner(entry.Box, 4)
                entry.Check = Icons.Check(entry.Box)
                entry.Check.Visible = false
            end
            entry.Text = new("TextLabel", {
                Name = "Text", Text = tostring(opt), Position = UDim2.fromOffset(el.Multi and 30 or 10, 0),
                Size = UDim2.new(1, el.Multi and -36 or -16, 1, 0), TextSize = 12, TextXAlignment = LEFT,
                TextTruncate = Enum.TextTruncate.AtEnd, Parent = b,
            })
            buttons[opt] = entry
            b.MouseEnter:Connect(function()
                if not isSelected(opt) or el.Multi then
                    play(b, EASE_FAST, { BackgroundTransparency = 0.93 })
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
        return 12 + rows * 28 + (hasSearch and 34 or 0)
    end

    local function ensureSearch()
        if (cfg.Searchable == true or cfg.Search == true or #el.Options > 7) and not searchBox then
            searchBox = new("TextBox", {
                Name = "Search", Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 26),
                Text = "", PlaceholderText = "Search...", TextSize = 12, TextXAlignment = LEFT,
                Theme = { BackgroundColor3 = "Panel", PlaceholderColor3 = "SubText" }, BackgroundTransparency = 0,
                Parent = popFrame,
            })
            corner(searchBox, 6)
            pad(searchBox, 8, 0, 8, 0)
            listFrame.Position = UDim2.fromOffset(0, 38)
            listFrame.Size = UDim2.new(1, 0, 1, -44)
            searchBox:GetPropertyChangedSignal("Text"):Connect(function()
                local q = searchBox.Text:lower()
                for opt, b in pairs(buttons) do
                    b.Frame.Visible = q == "" or tostring(opt):lower():find(q, 1, true) ~= nil
                end
            end)
        elseif not (cfg.Searchable == true or cfg.Search == true or #el.Options > 7) and searchBox then
            searchBox:Destroy()
            searchBox = nil
            listFrame.Position = UDim2.fromOffset(0, 6)
            listFrame.Size = UDim2.new(1, 0, 1, -12)
        end
    end

    popup.OnOpen = function()
        play(chevron, EASE_MED, { Rotation = 180 })
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
            return el.Value
        end,
        Down = function()
            if el.Mode == "Toggle" then
                el.Active = not el.Active
            else
                el.Active = true
            end
            el.Triggered:Fire(el.Active)
            safeCall(cfg.Callback, el.Active)
        end,
        Up = function()
            if el.Mode == "Hold" then
                el.Active = false
                el.Triggered:Fire(false)
                safeCall(cfg.Callback, false)
            end
        end,
    })
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
        Name = "Field", Size = UDim2.fromOffset(cfg.Width or 130, 24), Theme = { BackgroundColor3 = "Panel" }, Parent = right,
    })
    corner(holder, 6)
    local fieldStroke = stroke(holder, "Stroke")
    local box = new("TextBox", {
        Name = "Input", Size = UDim2.fromScale(1, 1), Text = el.Value, PlaceholderText = cfg.Placeholder or "",
        TextSize = 12, TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd,
        Theme = { PlaceholderColor3 = "SubText" }, Parent = holder,
    })
    pad(box, 8, 0, 8, 0)
    el._box = box

    window.Maid:Give(box.Focused:Connect(function()
        play(fieldStroke, EASE_FAST, { Color = Library.Theme.Accent })
    end))
    window.Maid:Give(box.FocusLost:Connect(function()
        play(fieldStroke, EASE_FAST, { Color = Library.Theme.Stroke })
        el:SetValue(box.Text)
    end))
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
function Section:Button(cfg)
    cfg = cfg or {}
    local window = self.Window
    local row, hit = self:_row(cfg, 38)
    local el = setmetatable({}, Button)
    initElement(el, self, "Button", cfg, row, hit)

    buildLeft(el, row, cfg, "Button", nil)
    local variant = (cfg.Variant or cfg.Style or "Secondary"):lower()
    local palette = {
        primary = { bg = "Accent", text = "Text", transparency = 0.08 },
        secondary = { bg = "Accent", text = "Accent", transparency = 0.82 },
        gradient = { bg = "Accent", text = "Text", transparency = 0.08 },
        danger = { bg = "Danger", text = "Danger", transparency = 0.82 },
        success = { bg = "Success", text = "Success", transparency = 0.82 },
        warning = { bg = "Warning", text = "Warning", transparency = 0.82 },
        ghost = { bg = "Panel", text = "SubText", transparency = 1 },
    }
    local style = palette[variant] or palette.secondary
    local chip = new("TextButton", {
        Name = "Chip", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
        AutomaticSize = AS_X, Size = UDim2.fromOffset(0, cfg.ButtonHeight or 24), Text = (cfg.Icon and (tostring(cfg.Icon) .. "  ") or "") .. (cfg.ButtonText or "Run"), TextSize = 11,
        BackgroundTransparency = style.transparency, Theme = { TextColor3 = style.text, BackgroundColor3 = style.bg }, Parent = row,
    })
    corner(chip, 6)
    pad(chip, 10, 0, 10, 0)
    if variant == "gradient" then animatedGradient(chip, window.Maid, cfg.GradientDuration or 9) end
    el._chip = chip
    el.Variant = variant

    local function fireButton()
        if el.Disabled then return end
        play(chip, EASE_FAST, { Size = UDim2.fromOffset(math.max(42, chip.AbsoluteSize.X - 4), math.max(20, (cfg.ButtonHeight or 24) - 2)) })
        task.delay(0.08, function()
            if chip.Parent then
                play(chip, EASE_FAST, { Size = UDim2.fromOffset(0, cfg.ButtonHeight or 24) })
            end
        end)
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
    local palette = {
        primary = { bg = "Accent", text = "Text", transparency = 0.08 },
        secondary = { bg = "Accent", text = "Accent", transparency = 0.82 },
        gradient = { bg = "Accent", text = "Text", transparency = 0.08 },
        danger = { bg = "Danger", text = "Danger", transparency = 0.82 },
        success = { bg = "Success", text = "Success", transparency = 0.82 },
        warning = { bg = "Warning", text = "Warning", transparency = 0.82 },
        ghost = { bg = "Panel", text = "SubText", transparency = 1 },
    }
    local style = palette[variant] or palette.secondary
    self.Variant = variant
    self._chip.BackgroundColor3 = Library.Theme[style.bg]
    self._chip.TextColor3 = Library.Theme[style.text]
    self._chip.BackgroundTransparency = style.transparency
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
    local h, s, v = el.Value:ToHSV()

    local right = buildRight(row, 8)
    buildLeft(el, row, cfg, "Color", right)
    local swatch = new("Frame", {
        Name = "Swatch", Size = UDim2.fromOffset(30, 16), BackgroundColor3 = el.Value, Parent = right,
    })
    corner(swatch, 5)
    stroke(swatch, "Stroke")

    -- popup
    local pop = new("Frame", {
        Name = "ColorPopup", Visible = false, ZIndex = 2, ClipsDescendants = true, Size = UDim2.fromOffset(200, 0),
        Theme = { BackgroundColor3 = "Background" }, Parent = window.Overlay,
    })
    corner(pop, 8)
    stroke(pop, "Stroke")

    local sv = new("Frame", {
        Name = "SV", Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(180, 120),
        BackgroundColor3 = Color3.fromHSV(h, 1, 1), Parent = pop,
    })
    corner(sv, 6)
    local white = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = sv })
    corner(white, 6)
    new("UIGradient", {
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
        Parent = white,
    })
    local black = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), Parent = sv })
    corner(black, 6)
    new("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }),
        Parent = black,
    })
    local svCursor = new("Frame", {
        Name = "Cursor", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10),
        BackgroundTransparency = 1, Parent = sv,
    })
    corner(svCursor, 5)
    new("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1), Parent = svCursor })

    local hueBar = new("Frame", {
        Name = "Hue", Position = UDim2.fromOffset(10, 140), Size = UDim2.fromOffset(180, 12),
        BackgroundColor3 = Color3.new(1, 1, 1), Parent = pop,
    })
    corner(hueBar, 6)
    local keys = {}
    for i = 0, 6 do
        table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((i % 6) / 6, 1, 1)))
    end
    new("UIGradient", { Color = ColorSequence.new(keys), Parent = hueBar })
    local hueCursor = new("Frame", {
        Name = "Cursor", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(4, 18),
        BackgroundColor3 = Color3.new(1, 1, 1), Parent = hueBar,
    })
    corner(hueCursor, 2)
    new("UIStroke", { Thickness = 1, Color = Color3.fromRGB(20, 20, 26), Transparency = 0.3, Parent = hueCursor })

    local hexHolder = new("Frame", {
        Name = "HexField", Position = UDim2.fromOffset(10, 162), Size = UDim2.fromOffset(180, 26),
        Theme = { BackgroundColor3 = "Panel" }, Parent = pop,
    })
    corner(hexHolder, 6)
    local hexStroke = stroke(hexHolder, "Stroke")
    local hexBox = new("TextBox", {
        Name = "Hex", Size = UDim2.fromScale(1, 1), Text = "", PlaceholderText = "#RRGGBB", TextSize = 12,
        Font = FONT.Medium, Theme = { PlaceholderColor3 = "SubText" }, Parent = hexHolder,
    })

    local function refresh(fromUser)
        local color = Color3.fromHSV(h, s, v)
        sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        svCursor.Position = UDim2.fromScale(s, 1 - v)
        hueCursor.Position = UDim2.fromScale(h, 0.5)
        swatch.BackgroundColor3 = color
        if not hexBox:IsFocused() then
            hexBox.Text = "#" .. color:ToHex():upper()
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

    local dragSV, dragHue = false, false
    local function updateSV(input)
        s = math.clamp((input.Position.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
        v = 1 - math.clamp((input.Position.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
        refresh(true)
    end
    local function updateHue(input)
        h = math.clamp((input.Position.X - hueBar.AbsolutePosition.X) / math.max(hueBar.AbsoluteSize.X, 1), 0, 1)
        refresh(true)
    end
    window.Maid:Give(sv.InputBegan:Connect(function(input)
        if isPress(input) then
            dragSV = true
            updateSV(input)
        end
    end))
    window.Maid:Give(hueBar.InputBegan:Connect(function(input)
        if isPress(input) then
            dragHue = true
            updateHue(input)
        end
    end))
    window.Maid:Give(UserInputService.InputChanged:Connect(function(input)
        if isMove(input) then
            if dragSV then
                updateSV(input)
            elseif dragHue then
                updateHue(input)
            end
        end
    end))
    window.Maid:Give(UserInputService.InputEnded:Connect(function(input)
        if isPress(input) then
            dragSV, dragHue = false, false
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

    local popup = { Frame = pop, Anchor = row, Size = Vector2.new(200, 198), AlignRight = true }
    window.Maid:Give(hit.MouseButton1Click:Connect(function()
        if window._popup == popup then
            window:_closePopup()
        else
            window:_openPopup(popup)
        end
    end))
    el._onDestroy = function()
        pop:Destroy()
    end

    refresh(false)
    publish(el)
    return el
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
    local box = new("Frame", {
        Name = "CheckBox", Size = UDim2.fromOffset(18, 18),
        Theme = { BackgroundColor3 = el.Value and "Accent" or "Track" }, Parent = right,
    })
    corner(box, 5); stroke(box, "Stroke", 1, 0.25)
    local check = Icons.Check(box)
    check.Visible = el.Value
    el._box, el._check = box, check
    window.Maid:Give(hit.MouseButton1Click:Connect(function()
        if not el.Disabled then el:SetValue(not el.Value) end
    end))
    el:_visual(false)
    publish(el)
    return el
end

function Checkbox:_visual(animate)
    apply(self._box, { BackgroundColor3 = self.Value and Library.Theme.Accent or Library.Theme.Track }, animate, EASE_FAST)
    self._check.Visible = self.Value
end

function Checkbox:SetValue(value, silent)
    self.Value = value and true or false
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
        Name = "Label", Text = cfg.Name or "Progress", Position = UDim2.fromOffset(12, 6),
        Size = UDim2.new(1, -92, 0, 18), TextSize = 12, TextXAlignment = LEFT, Parent = row,
    })
    local percent = new("TextLabel", {
        Name = "Percent", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 6),
        Size = UDim2.fromOffset(72, 18), TextSize = 11, TextXAlignment = RIGHT,
        Theme = { TextColor3 = "SubText" }, Parent = row,
    })
    local track = new("Frame", {
        Name = "Track", Position = UDim2.new(0, 12, 1, -15), Size = UDim2.new(1, -24, 0, 5),
        Theme = { BackgroundColor3 = "Track" }, Parent = row,
    })
    corner(track, 3)
    local fill = new("Frame", {
        Name = "Fill", Size = UDim2.fromScale(0, 1), Theme = { BackgroundColor3 = "Accent" }, Parent = track,
    })
    if typeof(cfg.Color) == "Color3" then
        fill.BackgroundColor3 = cfg.Color
    elseif type(cfg.Color) == "string" and Library.Theme[cfg.Color] then
        fill.BackgroundColor3 = Library.Theme[cfg.Color]
    end
    corner(fill, 3)
    if cfg.Gradient then animatedGradient(fill, self.Window.Maid, cfg.GradientDuration or 10) end
    el._title, el._percent, el._fill = title, percent, fill
    function el:SetValue(value, silent)
        value = tonumber(value)
        if not value then return end
        self.Value = math.clamp(value, self.Min, self.Max)
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
    el.Increment = math.max(0.000001, tonumber(cfg.Increment) or 1)
    el.Value = math.clamp(tonumber(cfg.Default) or 0, el.Min, el.Max)
    el._dec = decimals(el.Increment)
    local right = buildRight(row, 4)
    buildLeft(el, row, cfg, "Number", right)
    local minus = new("TextButton", {
        Name = "Minus", Text = "−", Size = UDim2.fromOffset(24, 24), TextSize = 16,
        Theme = { BackgroundColor3 = "Panel", TextColor3 = "SubText" }, Parent = right,
    })
    corner(minus, 5)
    local holder = new("Frame", { Name = "Value", Size = UDim2.fromOffset(cfg.Width or 64, 24), Theme = { BackgroundColor3 = "Panel" }, Parent = right })
    corner(holder, 5)
    local box = new("TextBox", {
        Name = "Input", Size = UDim2.fromScale(1, 1), Text = tostring(el.Value), TextSize = 12,
        Font = FONT.Medium, TextXAlignment = Enum.TextXAlignment.Center, Parent = holder,
    })
    local plus = new("TextButton", {
        Name = "Plus", Text = "+", Size = UDim2.fromOffset(24, 24), TextSize = 16,
        Theme = { BackgroundColor3 = "Panel", TextColor3 = "SubText" }, Parent = right,
    })
    corner(plus, 5)
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
        value = roundTo(value, self.Increment)
        self.Value = math.clamp(value, self.Min, self.Max)
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
        Theme = { BackgroundColor3 = "Panel", PlaceholderColor3 = "SubText" }, Parent = row,
    })
    corner(box, 6); pad(box, 8, 6, 8, 6)
    el._box = box
    self.Window.Maid:Give(box.FocusLost:Connect(function() el:SetValue(box.Text) end))
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
        Size = UDim2.fromOffset(112, 18), TextSize = 11, TextXAlignment = RIGHT,
        Theme = { TextColor3 = "SubText" }, Parent = row,
    })
    local area = new("Frame", { Name = "TrackArea", Position = UDim2.new(0, 12, 1, -17), Size = UDim2.new(1, -24, 0, 8), BackgroundTransparency = 1, Active = true, Parent = row })
    local track = new("Frame", { Name = "Track", Position = UDim2.fromScale(0, 0.5), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(1, 0, 0, 4), Theme = { BackgroundColor3 = "Track" }, Parent = area })
    corner(track, 3)
    local fill = new("Frame", { Name = "Fill", Theme = { BackgroundColor3 = "Accent" }, Parent = track })
    corner(fill, 3)
    local function makeHandle(name)
        local handle = new("TextButton", { Name = name, Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Color3.new(1, 1, 1), Parent = track })
        corner(handle, 6); stroke(handle, "Accent", 2)
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
    local value = new("TextLabel", { Name = "Value", Text = tostring(cfg.Value or "—"), Position = UDim2.new(0.55, 4, 0, 0), Size = UDim2.new(0.45, -4, 1, 0), TextSize = 12, TextXAlignment = RIGHT, TextTruncate = Enum.TextTruncate.AtEnd, Theme = { TextColor3 = "SubText" }, Parent = frame })
    local item = self:_entry(frame, (cfg.Name or cfg.Key or "") .. " " .. tostring(cfg.Value or ""))
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
    corner(frame, 8)
    frame.BackgroundTransparency = cfg.Background == false and 1 or 0
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
    corner(chip, 6); pad(chip, 9, 0, 9, 0)
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
        corner(button, 6); pad(button, 9, 0, 9, 0)
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
    corner(frame, cfg.Radius or 9); stroke(frame, "Stroke", 1, 0.25); pad(frame, 10, 9, 10, 9); list(frame, 6)
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
    self:_entry(line, "")
    return line
end

------------------------------------------------------------------------
-- Built-in settings page (avatar button)
------------------------------------------------------------------------
function Window:_buildSettings()
    local tab = self:_makeTab({ Name = "Settings" }, true)

    local ui = tab:Section({ Name = "Interface", Side = "Left" })
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
    ui:Slider({
        Name = "Window Transparency", Min = 0, Max = 60, Default = math.floor(self.Transparency * 100), Increment = 5, Suffix = "%",
        Callback = function(value) self:SetTransparency(value / 100) end,
    })
    ui:Toggle({
        Name = "Snap to Edges", Default = self.SnapToEdge,
        Callback = function(value) self:SetSnapToEdge(value) end,
    })
    ui:Toggle({
        Name = "Lock Window", Default = not self.Draggable,
        Callback = function(value) self:SetDraggable(not value) end,
    })
    ui:ColorPicker({
        Name = "Accent Color", Default = Library.Theme.Accent,
        Callback = function(color)
            Library:SetTheme({ Accent = color })
        end,
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

    local cfgSection = tab:Section({ Name = "Configuration", Side = "Right" })
    local nameBox = cfgSection:Textbox({ Name = "Config Name", Placeholder = "default", Default = "default" })
    local picker = cfgSection:Dropdown({ Name = "Saved Configs", Options = Library:ListConfigs() })
    cfgSection:Button({
        Name = "Save Config", ButtonText = "Save",
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
        Name = "Refresh List", ButtonText = "Refresh",
        Callback = function()
            picker:SetOptions(Library:ListConfigs(), true)
        end,
    })
    cfgSection:Divider()
    cfgSection:Button({
        Name = "Unload Interface", ButtonText = "Unload",
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
