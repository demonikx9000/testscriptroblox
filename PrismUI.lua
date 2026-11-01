--[[
    PRISM UI  |  v1.1.0
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
    Section:Button({ Name = "Button", ButtonText = "Run", Callback = function() end })
    Section:Label("Plain label text")
    Section:Divider()

    Library:Notify({ Title = "Title", Content = "Content", Type = "Info", Duration = 4 }) -- Info | Success | Warning | Error

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

local LocalPlayer = Players.LocalPlayer

------------------------------------------------------------------------
-- Library root
------------------------------------------------------------------------
local Library = {
    Version = "1.1.0",
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

local activeTweens = setmetatable({}, { __mode = "k" })

local function play(inst, info, props)
    local prev = activeTweens[inst]
    if prev then
        prev:Cancel()
    end
    local tween = TweenService:Create(inst, info, props)
    activeTweens[inst] = tween
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

function Library:SetTheme(overrides)
    for key, value in pairs(overrides) do
        self.Theme[key] = value
    end
    for inst, entry in pairs(themed) do
        for prop, key in pairs(entry) do
            pcall(function()
                inst[prop] = self.Theme[key]
            end)
        end
    end
    for _, refresh in pairs(self._refreshers) do
        pcall(refresh)
    end
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
    local duration = cfg.Duration or 4

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
    local progress = new("Frame", {
        Name = "Progress", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 2), BackgroundTransparency = 0.4, Theme = { BackgroundColor3 = colorKey },
        Parent = card,
    })

    local closed = false
    local function close()
        if closed then
            return
        end
        closed = true
        play(card, EASE_MED, { GroupTransparency = 1, Position = UDim2.fromOffset(40, 0) })
        task.delay(0.26, function()
            wrap:Destroy()
        end)
    end

    play(card, EASE_MED, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) })
    TweenService:Create(progress, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) }):Play()
    task.delay(duration, close)
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
end

------------------------------------------------------------------------
-- Shared drag helper
------------------------------------------------------------------------
local function makeDraggable(maid, handle, target, afterMove, onClick)
    local dragging, moved = false, false
    local startMouse, startPos
    maid:Give(handle.InputBegan:Connect(function(input)
        if isPress(input) then
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
                target.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + d.X,
                    startPos.Y.Scale, startPos.Y.Offset + d.Y
                )
                if afterMove then
                    afterMove()
                end
            end
        end
    end))
    maid:Give(UserInputService.InputEnded:Connect(function(input)
        if dragging and isPress(input) then
            dragging = false
            if not moved and onClick then
                onClick()
            end
        end
    end))
end

------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------
function Library:CreateWindow(cfg)
    cfg = cfg or {}
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
        Query = "",
        ForceSingle = false,
        _keybinds = {},
        _lastListenEnd = 0,
    }, Window)
    table.insert(self.Windows, window)

    -- main frame -------------------------------------------------------
    local main = new("Frame", {
        Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(size.X, size.Y), Theme = { BackgroundColor3 = "Background" }, Parent = gui,
    })
    corner(main, 12)
    stroke(main, "Stroke")
    window.Main = main
    window._uiscale = new("UIScale", { Parent = main })

    -- topbar -------------------------------------------------------------
    local topbar = new("Frame", { Name = "Topbar", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), Parent = main })
    local logo = Icons.Hex(topbar, 24, "Accent", "Background")
    logo.Position = UDim2.fromOffset(14, 14)
    new("TextLabel", {
        Name = "Brand", Text = "PrismUI", Position = UDim2.fromOffset(47, 0),
        Size = UDim2.fromOffset(82, 52), TextXAlignment = LEFT, TextYAlignment = Enum.TextYAlignment.Center,
        Font = FONT.Bold, TextSize = 15, Theme = { TextColor3 = "Text" }, Parent = topbar,
    })
    new("Frame", {
        Name = "Separator", Position = UDim2.fromOffset(136, 16), Size = UDim2.fromOffset(1, 20),
        Theme = { BackgroundColor3 = "Stroke" }, Parent = topbar,
    })

    local searchFrame = new("Frame", {
        Name = "Search", Position = UDim2.fromOffset(148, 10), Size = UDim2.new(1, -246, 0, 32),
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
    window.Maid:Give(searchInput.Focused:Connect(function()
        play(searchStroke, EASE_FAST, { Color = Library.Theme.Accent })
    end))
    window.Maid:Give(searchInput.FocusLost:Connect(function()
        play(searchStroke, EASE_FAST, { Color = Library.Theme.Stroke })
    end))
    window.Maid:Give(searchInput:GetPropertyChangedSignal("Text"):Connect(function()
        window:_applySearch(searchInput.Text)
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
    local gridBtn = topButton("Layout", 52)
    Icons.Grid(gridBtn, "SubText")
    local closeBtn = topButton("Close", 12)
    Icons.Close(closeBtn, "SubText")

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
    local tabListLayout = list(tabList, 6, VERT, Enum.HorizontalAlignment.Center)
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
    local function setSidebarExpanded(expanded)
        expanded = expanded and true or false
        if window.SidebarExpanded == expanded then
            return
        end
        window.SidebarExpanded = expanded
        local width = expanded and 166 or 46
        local contentX = expanded and 186 or 66
        local contentRight = expanded and 196 or 76
        play(sidebar, EASE_MED, { Size = UDim2.new(0, width, 1, -68) })
        play(window.Content, EASE_MED, {
            Position = UDim2.fromOffset(contentX, 58),
            Size = UDim2.new(1, -contentRight, 1, -68),
        })
        tabListLayout.HorizontalAlignment = expanded and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Center
        for _, existingTab in ipairs(window.Tabs) do
            local navLabel = existingTab._navLabel
            local navButton = existingTab._navButton
            if navLabel and navButton and navButton.Parent then
                navLabel.Visible = expanded
                navLabel.TextTransparency = expanded and 0 or 1
                play(navButton, EASE_MED, {
                    Size = expanded and UDim2.new(1, -12, 0, 34) or UDim2.fromOffset(34, 34),
                })
            end
        end
    end
    window._setSidebarExpanded = setSidebarExpanded
    window.Maid:Give(sidebar.MouseEnter:Connect(function()
        setSidebarExpanded(true)
    end))
    window.Maid:Give(sidebar.MouseLeave:Connect(function()
        setSidebarExpanded(false)
    end))

    window.Overlay = new("Frame", {
        Name = "Overlay", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = main,
    })
    window._blocker = new("TextButton", {
        Name = "Blocker", Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 1, Visible = false, Parent = window.Overlay,
    })
    window.Maid:Give(window._blocker.MouseButton1Click:Connect(function()
        window:_closePopup()
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
    makeDraggable(window.Maid, topbar, main, function()
        window:_clamp()
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

function Window:_clamp()
    local main = self.Main
    local vp = self.Gui.AbsoluteSize
    local half = main.AbsoluteSize / 2
    local pos = main.Position
    local maxX = vp.X / 2 + half.X - 80
    local minY = -vp.Y / 2 + half.Y
    local maxY = vp.Y / 2 + half.Y - 56
    local cx = pos.X.Offset
    local cy = pos.Y.Offset
    local nx = math.clamp(cx, -maxX, maxX)
    local ny = math.clamp(cy, minY, math.max(minY, maxY))
    if nx ~= cx or ny ~= cy then
        main.Position = UDim2.new(pos.X.Scale, nx, pos.Y.Scale, ny)
    end
end

function Window:SetVisible(visible)
    if visible == self.Visible then
        return
    end
    self.Visible = visible
    if visible then
        self.Main.Visible = true
        self._uiscale.Scale = self.Scale * 0.94
        play(self._uiscale, EASE_MED, { Scale = self.Scale })
    else
        self:_closePopup()
        self:_hideTip()
        play(self._uiscale, EASE_FAST, { Scale = self.Scale * 0.94 })
        task.delay(0.13, function()
            if not self.Visible then
                self.Main.Visible = false
                self._uiscale.Scale = self.Scale
            end
        end)
    end
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
            Size = self.SidebarExpanded and UDim2.new(1, -12, 0, 34) or UDim2.fromOffset(34, 34),
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
    list(frame, 6)
    local header = new("TextLabel", {
        Name = "Header", Text = cfg.Name or "Section", Size = UDim2.new(1, 0, 0, 18), TextSize = 12,
        TextXAlignment = LEFT, LayoutOrder = 0, Theme = { TextColor3 = "SubText" }, Parent = frame,
    })
    pad(header, 3, 0, 0, 0)
    local items = new("Frame", {
        Name = "Items", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AS_Y,
        LayoutOrder = 1, Parent = frame,
    })
    list(items, 6)

    local section = setmetatable({
        Window = self.Window, Tab = self, Name = cfg.Name or "Section",
        Frame = frame, Header = header, Content = items, Entries = {},
    }, Section)
    table.insert(self.Sections, section)
    return section
end

function Section:SetName(name)
    self.Name = name
    self.Header.Text = name
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
    el._tip = cfg.Tooltip
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
    local function fromInput(input)
        local w = track.AbsoluteSize.X
        if w <= 0 then
            return
        end
        local a = math.clamp((input.Position.X - track.AbsolutePosition.X) / w, 0, 1)
        el:SetValue(el.Min + (el.Max - el.Min) * a, false, true)
    end
    window.Maid:Give(area.InputBegan:Connect(function(input)
        if isPress(input) then
            dragging = true
            self.Tab:_lockScroll(true)
            window:_hideTip()
            play(knob, EASE_FAST, { Size = UDim2.fromOffset(15, 15) })
            fromInput(input)
        end
    end))
    window.Maid:Give(UserInputService.InputChanged:Connect(function(input)
        if dragging and isMove(input) then
            fromInput(input)
        end
    end))
    window.Maid:Give(UserInputService.InputEnded:Connect(function(input)
        if dragging and isPress(input) then
            dragging = false
            self.Tab:_lockScroll(false)
            play(knob, EASE_FAST, { Size = UDim2.fromOffset(12, 12) })
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
        return 12 + rows * 28 + ((#el.Options > 7) and 34 or 0)
    end

    local function ensureSearch()
        if #el.Options > 7 and not searchBox then
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
        elseif #el.Options <= 7 and searchBox then
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
    local chip = new("TextLabel", {
        Name = "Chip", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
        AutomaticSize = AS_X, Size = UDim2.fromOffset(0, 22), Text = cfg.ButtonText or "Run", TextSize = 11,
        BackgroundTransparency = 0.85, Theme = { TextColor3 = "Accent", BackgroundColor3 = "Accent" }, Parent = row,
    })
    corner(chip, 6)
    pad(chip, 10, 0, 10, 0)
    el._chip = chip

    window.Maid:Give(hit.MouseButton1Click:Connect(function()
        chip.BackgroundTransparency = 0.45
        play(chip, EASE_MED, { BackgroundTransparency = 0.85 })
        el:Fire()
    end))
    return el
end

function Button:Fire()
    self.Changed:Fire()
    safeCall(self.Cfg.Callback)
end

function Button:SetButtonText(text)
    self._chip.Text = text
end

function Button:Serialize()
    return nil
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
    function obj:SetVisible(v)
        item.Hidden = not v
        item.Frame.Visible = v
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

return Library
