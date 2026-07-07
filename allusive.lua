-- Required for this script (some services below already use cloneref)
cloneref = cloneref or function(a)
    return a
end

getgenv().GG = {
    Language = {
        CheckboxEnabled = "Enabled",
        CheckboxDisabled = "Disabled",
        SliderValue = "Value",
        DropdownSelect = "Select",
        DropdownNone = "None",
        DropdownSelected = "Selected",
        ButtonClick = "Click",
        TextboxEnter = "Enter",
        ModuleEnabled = "Enabled",
        ModuleDisabled = "Disabled",
        TabGeneral = "General",
        TabSettings = "Settings",
        Loading = "Loading...",
        Error = "Error",
        Success = "Success"
    }
}

-- Replace the SelectedLanguage with a reference to GG.Language
local SelectedLanguage = GG.Language

function convertStringToTable(inputString)
    local result = {}
    for value in string.gmatch(inputString, "([^,]+)") do
        local trimmedValue = value:match("^%s*(.-)%s*$")
        tablein(result, trimmedValue)
    end

    return result
end

function convertTableToString(inputTable)
    return table.concat(inputTable, ", ")
end

local UserInputService = cloneref(game:GetService('UserInputService'))
local ContentProvider = cloneref(game:GetService('ContentProvider'))
local TweenService = cloneref(game:GetService('TweenService'))
local HttpService = cloneref(game:GetService('HttpService'))
local TextService = cloneref(game:GetService('TextService'))
local RunService = cloneref(game:GetService('RunService'))
local Lighting = cloneref(game:GetService('Lighting'))
local Players = cloneref(game:GetService('Players'))
local CoreGui = cloneref(game:GetService('CoreGui'))
local Debris = cloneref(game:GetService('Debris'))

local mouse = Players.LocalPlayer:GetMouse()
local Silly = CoreGui:FindFirstChild('Silly')

if Silly then
    Debris:AddItem(Silly, 0)
end

if not isfolder("Silly") then
    makefolder("Silly")
end


local Connections = setmetatable({
    disconnect = function(self, connection)
        if not self[connection] then
            return
        end
    
        self[connection]:Disconnect()
        self[connection] = nil
    end,
    disconnect_all = function(self)
        for _, value in self do
            if typeof(value) == 'function' then
                continue
            end
    
            value:Disconnect()
        end
    end
}, Connections)


local Util = setmetatable({
    map = function(self: any, value: number, in_minimum: number, in_maximum: number, out_minimum: number, out_maximum: number)
        return (value - in_minimum) * (out_maximum - out_minimum) / (in_maximum - in_minimum) + out_minimum
    end,
    viewport_point_to_world = function(self: any, location: any, distance: number)
        local unit_ray = workspace.CurrentCamera:ScreenPointToRay(location.X, location.Y)

        return unit_ray.Origin + unit_ray.Direction * distance
    end,
    get_offset = function(self: any)
        local viewport_size_Y = workspace.CurrentCamera.ViewportSize.Y

        return self:map(viewport_size_Y, 0, 2560, 8, 56)
    end
}, Util)


local AcrylicBlur = {}
AcrylicBlur.__index = AcrylicBlur


function AcrylicBlur.new(object: GuiObject)
    local self = setmetatable({
        _object = object,
        _folder = nil,
        _frame = nil,
        _root = nil
    }, AcrylicBlur)

    self:setup()

    return self
end


function AcrylicBlur:create_folder()
    local old_folder = workspace.CurrentCamera:FindFirstChild('AcrylicBlur')

    if old_folder then
        Debris:AddItem(old_folder, 0)
    end

    local folder = Instance.new('Folder')
    folder.Name = 'AcrylicBlur'
    folder.Parent = workspace.CurrentCamera

    self._folder = folder
end


function AcrylicBlur:create_depth_of_fields()
    local depth_of_fields = Lighting:FindFirstChild('AcrylicBlur') or Instance.new('DepthOfFieldEffect')
    depth_of_fields.FarIntensity = 0
    depth_of_fields.FocusDistance = 0.05
    depth_of_fields.InFocusRadius = 0.1
    depth_of_fields.NearIntensity = 1
    depth_of_fields.Name = 'AcrylicBlur'
    depth_of_fields.Parent = Lighting

    for _, object in Lighting:GetChildren() do
        if not object:IsA('DepthOfFieldEffect') then
            continue
        end

        if object == depth_of_fields then
            continue
        end

        Connections[object] = object:GetPropertyChangedSignal('FarIntensity'):Connect(function()
            object.FarIntensity = 0
        end)

        object.FarIntensity = 0
    end
end


function AcrylicBlur:create_frame()
    local frame = Instance.new('Frame')
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundTransparency = 1
    frame.Parent = self._object

    self._frame = frame
end


function AcrylicBlur:create_root()
    local part = Instance.new('Part')
    part.Name = 'Root'
    part.Color = Color3.new(0, 0, 0)
    part.Material = Enum.Material.Glass
    part.Size = Vector3.new(1, 1, 0)  -- Use a thin part
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.Locked = true
    part.CastShadow = false
    part.Transparency = 0.98
    part.Parent = self._folder

    -- Create a SpecialMesh to simulate the acrylic blur effect
    local specialMesh = Instance.new('SpecialMesh')
    specialMesh.MeshType = Enum.MeshType.Brick  -- Use Brick mesh or another type suitable for the effect
    specialMesh.Offset = Vector3.new(0, 0, -0.000001)  -- Small offset to prevent z-fighting
    specialMesh.Parent = part

    self._root = part  -- Store the part as root
end


function AcrylicBlur:setup()
    self:create_depth_of_fields()
    self:create_folder()
    self:create_root()
    
    self:create_frame()
    self:render(0.001)

    self:check_quality_level()
end


function AcrylicBlur:render(distance: number)
    local positions = {
        top_left = Vector2.new(),
        top_right = Vector2.new(),
        bottom_right = Vector2.new(),
    }

    local function update_positions(size: any, position: any)
        positions.top_left = position
        positions.top_right = position + Vector2.new(size.X, 0)
        positions.bottom_right = position + size
    end

    local function update()
        local top_left = positions.top_left
        local top_right = positions.top_right
        local bottom_right = positions.bottom_right

        local top_left3D = Util:viewport_point_to_world(top_left, distance)
        local top_right3D = Util:viewport_point_to_world(top_right, distance)
        local bottom_right3D = Util:viewport_point_to_world(bottom_right, distance)

        local width = (top_right3D - top_left3D).Magnitude
        local height = (top_right3D - bottom_right3D).Magnitude

        if not self._root then
            return
        end

        self._root.CFrame = CFrame.fromMatrix((top_left3D + bottom_right3D) / 2, workspace.CurrentCamera.CFrame.XVector, workspace.CurrentCamera.CFrame.YVector, workspace.CurrentCamera.CFrame.ZVector)
        self._root.Mesh.Scale = Vector3.new(width, height, 0)
    end

    local function on_change()
        local offset = Util:get_offset()
        local size = self._frame.AbsoluteSize - Vector2.new(offset, offset)
        local position = self._frame.AbsolutePosition + Vector2.new(offset / 2, offset / 2)

        update_positions(size, position)
        task.spawn(update)
    end

    Connections['cframe_update'] = workspace.CurrentCamera:GetPropertyChangedSignal('CFrame'):Connect(update)
    Connections['viewport_size_update'] = workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(update)
    Connections['field_of_view_update'] = workspace.CurrentCamera:GetPropertyChangedSignal('FieldOfView'):Connect(update)

    Connections['frame_absolute_position'] = self._frame:GetPropertyChangedSignal('AbsolutePosition'):Connect(on_change)
    Connections['frame_absolute_size'] = self._frame:GetPropertyChangedSignal('AbsoluteSize'):Connect(on_change)
    
    task.spawn(update)
end


function AcrylicBlur:check_quality_level()
    local game_settings = UserSettings().GameSettings
    local quality_level = game_settings.SavedQualityLevel.Value

    if quality_level < 8 then
        self:change_visiblity(false)
    end

    Connections['quality_level'] = game_settings:GetPropertyChangedSignal('SavedQualityLevel'):Connect(function()
        local game_settings = UserSettings().GameSettings
        local quality_level = game_settings.SavedQualityLevel.Value

        self:change_visiblity(quality_level >= 8)
    end)
end


function AcrylicBlur:change_visiblity(state: boolean)
    self._root.Transparency = state and 0.98 or 1
end


local Config = setmetatable({
    save = function(self: any, file_name: any, config: any)
        local success_save, result = pcall(function()
            local flags = HttpService:JSONEncode(config)
            writefile('Silly/'..file_name..'.json', flags)
        end)
    
        if not success_save then
            warn('failed to save config', result)
        end
    end,
    load = function(self: any, file_name: any, config: any)
        local success_load, result = pcall(function()
            if not isfile('Silly/'..file_name..'.json') then
                self:save(file_name, config)
        
                return
            end
        
            local flags = readfile('Silly/'..file_name..'.json')
        
            if not flags then
                self:save(file_name, config)
        
                return
            end

            return HttpService:JSONDecode(flags)
        end)
    
        if not success_load then
            warn('failed to load config', result)
        end
    
        if not result then
            result = {
                _flags = {},
                _keybinds = {},
                _library = {}
            }
        end
    
        return result
    end
}, Config)


local Library = {
    _config = Config:load(game.GameId),

    _choosing_keybind = false,
    _device = nil,

    _ui_open = true,
    _ui_scale = 1,
    _ui_loaded = false,
    _ui = nil,

    _dragging = false,
    _drag_start = nil,
    _container_position = nil
}
Library.__index = Library


function Library.new()
    local self = setmetatable({
        _loaded = false,
        _tab = 0,
    }, Library)
    
    self:create_ui()

    return self
end

-- Create Notification Container
local NotificationContainer = Instance.new("Frame")
NotificationContainer.Name = "RobloxCoreGuis"
NotificationContainer.Size = UDim2.new(0, 300, 0, 0)  -- Fixed width (300px), dynamic height (Y)
NotificationContainer.Position = UDim2.new(0.8, 0, 0, 10)  -- Right side, offset by 10 from top
NotificationContainer.BackgroundTransparency = 1
NotificationContainer.ClipsDescendants = false;
NotificationContainer.Parent = game:GetService("CoreGui").RobloxGui:FindFirstChild("RobloxCoreGuis") or Instance.new("ScreenGui", game:GetService("CoreGui").RobloxGui)
NotificationContainer.AutomaticSize = Enum.AutomaticSize.Y

-- UIListLayout to arrange notifications vertically
local UIListLayout = Instance.new("UIListLayout")
UIListLayout.FillDirection = Enum.FillDirection.Vertical
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 10)
UIListLayout.Parent = NotificationContainer

-- Function to create notifications
function Library.SendNotification(settings)
    -- Create the notification frame (this will be managed by UIListLayout)
    local Notification = Instance.new("Frame")
    Notification.Size = UDim2.new(1, 0, 0, 60)  -- Width = 100% of NotificationContainer's width, dynamic height (Y)
    Notification.BackgroundTransparency = 1  -- Outer frame is transparent for layout to work
    Notification.BorderSizePixel = 0
    Notification.Name = "Notification"
    Notification.Parent = NotificationContainer  -- Parent it to your NotificationContainer (the parent of the list layout)
    Notification.AutomaticSize = Enum.AutomaticSize.Y  -- Allow this frame to resize based on child height

    -- Add rounded corners to outer frame
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 4)
    UICorner.Parent = Notification

    -- Create the inner frame for the notification's content
    local InnerFrame = Instance.new("Frame")
    InnerFrame.Size = UDim2.new(1, 0, 0, 60)  -- Start with an initial height, width will adapt
    InnerFrame.Position = UDim2.new(0, 0, 0, 0)  -- Positioned inside the outer notification frame
    InnerFrame.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
    InnerFrame.BackgroundTransparency = 0.2
    InnerFrame.BorderSizePixel = 0
    InnerFrame.Name = "InnerFrame"
    InnerFrame.Parent = Notification
    InnerFrame.AutomaticSize = Enum.AutomaticSize.Y  -- Automatically resize based on its content

    -- Add rounded corners to the inner frame
    local InnerUICorner = Instance.new("UICorner")
    InnerUICorner.CornerRadius = UDim.new(0, 4)
    InnerUICorner.Parent = InnerFrame

    -- Title Label (with automatic size support)
    local Title = Instance.new("TextLabel")
    Title.Text = settings.title or "Notification Title"
    Title.TextColor3 = Color3.fromRGB(210, 210, 210)
    Title.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
    Title.TextSize = 14
    Title.Size = UDim2.new(1, -10, 0, 20)  -- Width is 1 (100% of parent width), height is fixed initially
    Title.Position = UDim2.new(0, 5, 0, 5)
    Title.BackgroundTransparency = 1
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.TextYAlignment = Enum.TextYAlignment.Center
    Title.TextWrapped = true  -- Enable wrapping
    Title.AutomaticSize = Enum.AutomaticSize.Y  -- Allow the title to resize based on content
    Title.Parent = InnerFrame

    -- Body Text (with automatic size support)
    local Body = Instance.new("TextLabel")
    Body.Text = settings.text or "This is the body of the notification."
    Body.TextColor3 = Color3.fromRGB(255, 200, 200)
    Body.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    Body.TextSize = 12
    Body.Size = UDim2.new(1, -10, 0, 30)  -- Width is 1 (100% of parent width), height is fixed initially
    Body.Position = UDim2.new(0, 5, 0, 25)
    Body.BackgroundTransparency = 1
    Body.TextXAlignment = Enum.TextXAlignment.Left
    Body.TextYAlignment = Enum.TextYAlignment.Top
    Body.TextWrapped = true  -- Enable wrapping for long text
    Body.AutomaticSize = Enum.AutomaticSize.Y  -- Allow the body text to resize based on content
    Body.Parent = InnerFrame

    -- Force the size to adjust after the text is fully loaded and wrapped
    task.spawn(function()
        wait(0.1)  -- Allow text wrapping to finish
        -- Adjust inner frame size based on content
        local totalHeight = Title.TextBounds.Y + Body.TextBounds.Y + 10  -- Add padding
        InnerFrame.Size = UDim2.new(1, 0, 0, totalHeight)  -- Resize the inner frame
    end)

    -- Use task.spawn to ensure the notification tweening happens asynchronously
    task.spawn(function()
        -- Tween In the Notification (inner frame)
        local tweenIn = TweenService:Create(InnerFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 0, 0, 10 + NotificationContainer.Size.Y.Offset)
        })
        tweenIn:Play()

        -- Wait for the duration before tweening out
        local duration = settings.duration or 5  -- Default to 5 seconds if not provided
        wait(duration)

        -- Tween Out the Notification (inner frame) to the right side of the screen
        local tweenOut = TweenService:Create(InnerFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
            Position = UDim2.new(1, 310, 0, 10 + NotificationContainer.Size.Y.Offset)  -- Move to the right off-screen
        })
        tweenOut:Play()

        -- Remove the notification after it is done tweening out
        tweenOut.Completed:Connect(function()
            Notification:Destroy()
        end)
    end)
end

function Library:get_screen_scale()
    local viewport_size_x = workspace.CurrentCamera.ViewportSize.X

    self._ui_scale = viewport_size_x / 1400
end


function Library:get_device()
    local device = 'Unknown'

    if not UserInputService.TouchEnabled and UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then
        device = 'PC'
    elseif UserInputService.TouchEnabled then
        device = 'Mobile'
    elseif UserInputService.GamepadEnabled then
        device = 'Console'
    end

    self._device = device
end


function Library:removed(action: any)
    self._ui.AncestryChanged:Once(action)
end


function Library:flag_type(flag: any, flag_type: any)
    if not Library._config._flags[flag] then
        return
    end

    return typeof(Library._config._flags[flag]) == flag_type
end


function Library:remove_table_value(__table: any, table_value: string)
    for index, value in __table do
        if value ~= table_value then
            continue
        end

        table.remove(__table, index)
    end
end


function Library:create_ui()
    local Silly = CoreGui:FindFirstChild('Silly')

    if Silly then
        Debris:AddItem(Silly, 0)
    end

    local Silly = Instance.new('ScreenGui')
    Silly.ResetOnSpawn = false
    Silly.Name = 'Silly'
    Silly.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    Silly.Parent = CoreGui
    
    local Container = Instance.new('Frame')
    Container.ClipsDescendants = true
    Container.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Container.AnchorPoint = Vector2.new(0.5, 0.5)
    Container.Name = 'Container'
    Container.BackgroundTransparency = 0.15
    Container.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
    Container.Position = UDim2.new(0.5, 0, 0.5, 0)
    Container.Size = UDim2.new(0, 0, 0, 0)
    Container.Active = true
    Container.BorderSizePixel = 0
    Container.Parent = Silly
    
    local UICorner = Instance.new('UICorner')
    UICorner.CornerRadius = UDim.new(0, 10)
    UICorner.Parent = Container
    
    local UIStroke = Instance.new('UIStroke')
    UIStroke.Color = Color3.fromRGB(52, 66, 89)
    UIStroke.Transparency = 0.5
    UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    UIStroke.Parent = Container
    
    local Handler = Instance.new('Frame')
    Handler.BackgroundTransparency = 1
    Handler.Name = 'Handler'
    Handler.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Handler.Size = UDim2.new(0, 698, 0, 479)
    Handler.BorderSizePixel = 0
    Handler.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Handler.Parent = Container
    
    local Tabs = Instance.new('ScrollingFrame')
    Tabs.ScrollBarImageTransparency = 1
    Tabs.ScrollBarThickness = 0
    Tabs.Name = 'Tabs'
    Tabs.Size = UDim2.new(0, 129, 0, 401)
    Tabs.Selectable = false
    Tabs.AutomaticCanvasSize = Enum.AutomaticSize.XY
    Tabs.BackgroundTransparency = 1
    Tabs.Position = UDim2.new(0.026097271591424942, 0, 0.1111111119389534, 0)
    Tabs.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Tabs.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Tabs.BorderSizePixel = 0
    Tabs.CanvasSize = UDim2.new(0, 0, 0.5, 0)
    Tabs.Parent = Handler
    
    local UIListLayout = Instance.new('UIListLayout')
    UIListLayout.Padding = UDim.new(0, 4)
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Parent = Tabs
    
    local ClientName = Instance.new('TextLabel')
    ClientName.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
    ClientName.TextColor3 = Color3.fromRGB(120, 0, 0)
    ClientName.TextTransparency = 0.20000000298023224
    ClientName.Text = 'Silly'
    ClientName.Name = 'ClientName'
    ClientName.Size = UDim2.new(0, 31, 0, 13)
    ClientName.AnchorPoint = Vector2.new(0, 0.5)
    ClientName.Position = UDim2.new(0.0560000017285347, 0, 0.054999999701976776, 0)
    ClientName.BackgroundTransparency = 1
    ClientName.TextXAlignment = Enum.TextXAlignment.Left
    ClientName.BorderSizePixel = 0
    ClientName.BorderColor3 = Color3.fromRGB(0, 0, 0)
    ClientName.TextSize = 13
    ClientName.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ClientName.Parent = Handler
    
    local UIGradient = Instance.new('UIGradient')
    UIGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(155, 155, 155)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
    }
    UIGradient.Parent = ClientName
    
    local Pin = Instance.new('Frame')
    Pin.Name = 'Pin'
    Pin.Position = UDim2.new(0.026000000536441803, 0, 0.13600000739097595, 0)
    Pin.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Pin.Size = UDim2.new(0, 2, 0, 16)
    Pin.BorderSizePixel = 0
    Pin.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
    Pin.Parent = Handler
    
    local UICorner = Instance.new('UICorner')
    UICorner.CornerRadius = UDim.new(1, 0)
    UICorner.Parent = Pin
    
    local Icon = Instance.new('ImageLabel')
    Icon.ImageColor3 = Color3.fromRGB(120, 0, 0)
    Icon.ScaleType = Enum.ScaleType.Fit
    Icon.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Icon.AnchorPoint = Vector2.new(0, 0.5)
    Icon.Image = 'rbxassetid://107819132007001'
    Icon.BackgroundTransparency = 1
    Icon.Position = UDim2.new(0.02500000037252903, 0, 0.054999999701976776, 0)
    Icon.Name = 'Icon'
    Icon.Size = UDim2.new(0, 18, 0, 18)
    Icon.BorderSizePixel = 0
    Icon.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Icon.Parent = Handler
    
    local Divider = Instance.new('Frame')
    Divider.Name = 'Divider'
    Divider.BackgroundTransparency = 0.5
    Divider.Position = UDim2.new(0.23499999940395355, 0, 0, 0)
    Divider.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Divider.Size = UDim2.new(0, 1, 0, 479)
    Divider.BorderSizePixel = 0
    Divider.BackgroundColor3 = Color3.fromRGB(52, 66, 89)
    Divider.Parent = Handler
    
    local Sections = Instance.new('Folder')
    Sections.Name = 'Sections'
    Sections.Parent = Handler
    
    local Minimize = Instance.new('TextButton')
    Minimize.FontFace = Font.new('rbxasset://fonts/families/SourceSansPro.json', Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    Minimize.TextColor3 = Color3.fromRGB(0, 0, 0)
    Minimize.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Minimize.Text = ''
    Minimize.AutoButtonColor = false
    Minimize.Name = 'Minimize'
    Minimize.BackgroundTransparency = 1
    Minimize.Position = UDim2.new(0.020057305693626404, 0, 0.02922755666077137, 0)
    Minimize.Size = UDim2.new(0, 24, 0, 24)
    Minimize.BorderSizePixel = 0
    Minimize.TextSize = 14
    Minimize.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Minimize.Parent = Handler
    
    local UIScale = Instance.new('UIScale')
    UIScale.Parent = Container    
    
    self._ui = Silly

    local function on_drag(input: InputObject, process: boolean)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then 
            self._dragging = true
            self._drag_start = input.Position
            self._container_position = Container.Position

            Connections['container_input_ended'] = input.Changed:Connect(function()
                if input.UserInputState ~= Enum.UserInputState.End then
                    return
                end

                Connections:disconnect('container_input_ended')
                self._dragging = false
            end)
        end
    end

    local function update_drag(input: any)
        local delta = input.Position - self._drag_start
        local position = UDim2.new(self._container_position.X.Scale, self._container_position.X.Offset + delta.X, self._container_position.Y.Scale, self._container_position.Y.Offset + delta.Y)

        TweenService:Create(Container, TweenInfo.new(0.2), {
            Position = position
        }):Play()
    end

    local function drag(input: InputObject, process: boolean)
        if not self._dragging then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            update_drag(input)
        end
    end

    Connections['container_input_began'] = Container.InputBegan:Connect(on_drag)
    Connections['input_changed'] = UserInputService.InputChanged:Connect(drag)

    self:removed(function()
        self._ui = nil
        Connections:disconnect_all()
    end)

    function self:Update1Run(a)
        if a == "nil" then
            Container.BackgroundTransparency = 0.15;
        else
            pcall(function()
                Container.BackgroundTransparency = tonumber(a);
            end);
        end;
    end;

    function self:UIVisiblity()
        Silly.Enabled = not Silly.Enabled;
    end;

    function self:change_visiblity(state: boolean)
        if state then
            TweenService:Create(Container, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                Size = UDim2.fromOffset(698, 479)
            }):Play()
        else
            TweenService:Create(Container, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                Size = UDim2.fromOffset(104.5, 52)
            }):Play()
        end
    end
    

    function self:load()
        local content = {}
    
        for _, object in Silly:GetDescendants() do
            if not object:IsA('ImageLabel') then
                continue
            end
    
            table.insert(content, object)
        end
    
        ContentProvider:PreloadAsync(content)
        self:get_device()

        if self._device == 'Mobile' or self._device == 'Unknown' then
            self:get_screen_scale()
            UIScale.Scale = self._ui_scale
    
            Connections['ui_scale'] = workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(function()
                self:get_screen_scale()
                UIScale.Scale = self._ui_scale
            end)
        end
    
        TweenService:Create(Container, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(698, 479)
        }):Play()

        AcrylicBlur.new(Container)
        self._ui_loaded = true
    end

    function self:update_tabs(tab: TextButton)
        for index, object in Tabs:GetChildren() do
            if object.Name ~= 'Tab' then
                continue
            end

            if object == tab then
                if object.BackgroundTransparency ~= 0.5 then
                    local offset = object.LayoutOrder * (0.113 / 1.3)

                    TweenService:Create(Pin, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        Position = UDim2.fromScale(0.026, 0.135 + offset)
                    }):Play()    

                    TweenService:Create(object, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        BackgroundTransparency = 0.5
                    }):Play()

                    TweenService:Create(object.TextLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        TextTransparency = 0.2,
                        TextColor3 = Color3.fromRGB(120, 0, 0)
                    }):Play()

                    TweenService:Create(object.TextLabel.UIGradient, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        Offset = Vector2.new(1, 0)
                    }):Play()

                    TweenService:Create(object.Icon, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        ImageTransparency = 0.2,
                        ImageColor3 = Color3.fromRGB(120, 0, 0)
                    }):Play()
                end

                continue
            end

            if object.BackgroundTransparency ~= 1 then
                TweenService:Create(object, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                    BackgroundTransparency = 1
                }):Play()
                
                TweenService:Create(object.TextLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                    TextTransparency = 0.7,
                    TextColor3 = Color3.fromRGB(255, 255, 255)
                }):Play()

                TweenService:Create(object.TextLabel.UIGradient, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                    Offset = Vector2.new(0, 0)
                }):Play()

                TweenService:Create(object.Icon, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                    ImageTransparency = 0.8,
                    ImageColor3 = Color3.fromRGB(255, 255, 255)
                }):Play()
            end
        end
    end

    function self:update_sections(left_section: ScrollingFrame, right_section: ScrollingFrame)
        for _, object in Sections:GetChildren() do
            if object == left_section or object == right_section then
                object.Visible = true

                continue
            end

            object.Visible = false
        end
    end

    function self:create_tab(title: string, icon: string)
        local TabManager = {}

        local LayoutOrder = 0;

        local font_params = Instance.new('GetTextBoundsParams')
        font_params.Text = title
        font_params.Font = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
        font_params.Size = 13
        font_params.Width = 10000

        local font_size = TextService:GetTextBoundsAsync(font_params)
        local first_tab = not Tabs:FindFirstChild('Tab')

        local Tab = Instance.new('TextButton')
        Tab.FontFace = Font.new('rbxasset://fonts/families/SourceSansPro.json', Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        Tab.TextColor3 = Color3.fromRGB(0, 0, 0)
        Tab.BorderColor3 = Color3.fromRGB(0, 0, 0)
        Tab.Text = ''
        Tab.AutoButtonColor = false
        Tab.BackgroundTransparency = 1
        Tab.Name = 'Tab'
        Tab.Size = UDim2.new(0, 129, 0, 38)
        Tab.BorderSizePixel = 0
        Tab.TextSize = 14
        Tab.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
        Tab.Parent = Tabs
        Tab.LayoutOrder = self._tab
        
        local UICorner = Instance.new('UICorner')
        UICorner.CornerRadius = UDim.new(0, 5)
        UICorner.Parent = Tab
        
        local TextLabel = Instance.new('TextLabel')
        TextLabel.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
        TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        TextLabel.TextTransparency = 0.7 -- 0.800000011920929
        TextLabel.Text = title
        TextLabel.Size = UDim2.new(0, font_size.X, 0, 16)
        TextLabel.AnchorPoint = Vector2.new(0, 0.5)
        TextLabel.Position = UDim2.new(0.2400001734495163, 0, 0.5, 0)
        TextLabel.BackgroundTransparency = 1
        TextLabel.TextXAlignment = Enum.TextXAlignment.Left
        TextLabel.BorderSizePixel = 0
        TextLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
        TextLabel.TextSize = 13
        TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        TextLabel.Parent = Tab
        
        local UIGradient = Instance.new('UIGradient')
        UIGradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(0.7, Color3.fromRGB(155, 155, 155)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(58, 58, 58))
        }
        UIGradient.Parent = TextLabel
        
        local Icon = Instance.new('ImageLabel')
        Icon.ScaleType = Enum.ScaleType.Fit
        Icon.ImageTransparency = 0.800000011920929
        Icon.BorderColor3 = Color3.fromRGB(0, 0, 0)
        Icon.AnchorPoint = Vector2.new(0, 0.5)
        Icon.BackgroundTransparency = 1
        Icon.Position = UDim2.new(0.10000000149011612, 0, 0.5, 0)
        Icon.Name = 'Icon'
        Icon.Image = icon
        Icon.Size = UDim2.new(0, 12, 0, 12)
        Icon.BorderSizePixel = 0
        Icon.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Icon.Parent = Tab

        local LeftSection = Instance.new('ScrollingFrame')
        LeftSection.Name = 'LeftSection'
        LeftSection.AutomaticCanvasSize = Enum.AutomaticSize.XY
        LeftSection.ScrollBarThickness = 0
        LeftSection.Size = UDim2.new(0, 243, 0, 445)
        LeftSection.Selectable = false
        LeftSection.AnchorPoint = Vector2.new(0, 0.5)
        LeftSection.ScrollBarImageTransparency = 1
        LeftSection.BackgroundTransparency = 1
        LeftSection.Position = UDim2.new(0.2594326436519623, 0, 0.5, 0)
        LeftSection.BorderColor3 = Color3.fromRGB(0, 0, 0)
        LeftSection.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        LeftSection.BorderSizePixel = 0
        LeftSection.CanvasSize = UDim2.new(0, 0, 0.5, 0)
        LeftSection.Visible = false
        LeftSection.Parent = Sections
        
        local UIListLayout = Instance.new('UIListLayout')
        UIListLayout.Padding = UDim.new(0, 11)
        UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
        UIListLayout.Parent = LeftSection
        
        local UIPadding = Instance.new('UIPadding')
        UIPadding.PaddingTop = UDim.new(0, 1)
        UIPadding.Parent = LeftSection

        local RightSection = Instance.new('ScrollingFrame')
        RightSection.Name = 'RightSection'
        RightSection.AutomaticCanvasSize = Enum.AutomaticSize.XY
        RightSection.ScrollBarThickness = 0
        RightSection.Size = UDim2.new(0, 243, 0, 445)
        RightSection.Selectable = false
        RightSection.AnchorPoint = Vector2.new(0, 0.5)
        RightSection.ScrollBarImageTransparency = 1
        RightSection.BackgroundTransparency = 1
        RightSection.Position = UDim2.new(0.6290000081062317, 0, 0.5, 0)
        RightSection.BorderColor3 = Color3.fromRGB(0, 0, 0)
        RightSection.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        RightSection.BorderSizePixel = 0
        RightSection.CanvasSize = UDim2.new(0, 0, 0.5, 0)
        RightSection.Visible = false
        RightSection.Parent = Sections
        
        local UIListLayout = Instance.new('UIListLayout')
        UIListLayout.Padding = UDim.new(0, 11)
        UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
        UIListLayout.Parent = RightSection
        
        local UIPadding = Instance.new('UIPadding')
        UIPadding.PaddingTop = UDim.new(0, 1)
        UIPadding.Parent = RightSection

        self._tab += 1

        if first_tab then
            self:update_tabs(Tab, LeftSection, RightSection)
            self:update_sections(LeftSection, RightSection)
        end

        Tab.MouseButton1Click:Connect(function()
            self:update_tabs(Tab, LeftSection, RightSection)
            self:update_sections(LeftSection, RightSection)
        end)

        function TabManager:create_module(settings: any)

            local LayoutOrderModule = 0;

            local ModuleManager = {
                _state = false,
                _size = 0,
                _multiplier = 0
            }

            if settings.section == 'right' then
                settings.section = RightSection
            else
                settings.section = LeftSection
            end

            local Module = Instance.new('Frame')
            Module.ClipsDescendants = true
            Module.BorderColor3 = Color3.fromRGB(0, 0, 0)
            Module.BackgroundTransparency = 0.5
            Module.Position = UDim2.new(0.004115226212888956, 0, 0, 0)
            Module.Name = 'Module'
            Module.Size = UDim2.new(0, 241, 0, 93)
            Module.BorderSizePixel = 0
            Module.BackgroundColor3 = Color3.fromRGB(230, 28, 75)
            Module.Parent = settings.section

            local UIListLayout = Instance.new('UIListLayout')
            UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
            UIListLayout.Parent = Module
            
            local UICorner = Instance.new('UICorner')
            UICorner.CornerRadius = UDim.new(0, 5)
            UICorner.Parent = Module
            
            local UIStroke = Instance.new('UIStroke')
            UIStroke.Color = Color3.fromRGB(52, 66, 89)
            UIStroke.Transparency = 0.5
            UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            UIStroke.Parent = Module
            
            local Header = Instance.new('TextButton')
            Header.FontFace = Font.new('rbxasset://fonts/families/SourceSansPro.json', Enum.FontWeight.Regular, Enum.FontStyle.Normal)
            Header.TextColor3 = Color3.fromRGB(0, 0, 0)
            Header.BorderColor3 = Color3.fromRGB(0, 0, 0)
            Header.Text = ''
            Header.AutoButtonColor = false
            Header.BackgroundTransparency = 1
            Header.Name = 'Header'
            Header.Size = UDim2.new(0, 241, 0, 93)
            Header.BorderSizePixel = 0
            Header.TextSize = 14
            Header.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            Header.Parent = Module
            
            local Icon = Instance.new('ImageLabel')
            Icon.ImageColor3 = Color3.fromRGB(120, 0, 0)
            Icon.ScaleType = Enum.ScaleType.Fit
            Icon.ImageTransparency = 0.699999988079071
            Icon.BorderColor3 = Color3.fromRGB(0, 0, 0)
            Icon.AnchorPoint = Vector2.new(0, 0.5)
            Icon.Image = 'rbxassetid://79095934438045'
            Icon.BackgroundTransparency = 1
            Icon.Position = UDim2.new(0.07100000232458115, 0, 0.8199999928474426, 0)
            Icon.Name = 'Icon'
            Icon.Size = UDim2.new(0, 15, 0, 15)
            Icon.BorderSizePixel = 0
            Icon.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            Icon.Parent = Header
            
            local ModuleName = Instance.new('TextLabel')
            ModuleName.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
            ModuleName.TextColor3 = Color3.fromRGB(230, 28, 75)
            ModuleName.TextTransparency = 0.20000000298023224
            if not settings.rich then
                ModuleName.Text = settings.title or "Skibidi"
            else
                ModuleName.RichText = true
                ModuleName.Text = settings.richtext or "<font color='rgb(255,0,0)'>Silly</font> user"
            end;
            ModuleName.Name = 'ModuleName'
            ModuleName.Size = UDim2.new(0, 205, 0, 13)
            ModuleName.AnchorPoint = Vector2.new(0, 0.5)
            ModuleName.Position = UDim2.new(0.0729999989271164, 0, 0.23999999463558197, 0)
            ModuleName.BackgroundTransparency = 1
            ModuleName.TextXAlignment = Enum.TextXAlignment.Left
            ModuleName.BorderSizePixel = 0
            ModuleName.BorderColor3 = Color3.fromRGB(0, 0, 0)
            ModuleName.TextSize = 13
            ModuleName.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            ModuleName.Parent = Header
            
            local Description = Instance.new('TextLabel')
            Description.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
            Description.TextColor3 = Color3.fromRGB(120, 0, 0)
            Description.TextTransparency = 0.699999988079071
            Description.Text = settings.description
            Description.Name = 'Description'
            Description.Size = UDim2.new(0, 205, 0, 13)
            Description.AnchorPoint = Vector2.new(0, 0.5)
            Description.Position = UDim2.new(0.0729999989271164, 0, 0.41999998688697815, 0)
            Description.BackgroundTransparency = 1
            Description.TextXAlignment = Enum.TextXAlignment.Left
            Description.BorderSizePixel = 0
            Description.BorderColor3 = Color3.fromRGB(0, 0, 0)
            Description.TextSize = 10
            Description.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            Description.Parent = Header
            
            local Toggle = Instance.new('Frame')
            Toggle.Name = 'Toggle'
            Toggle.BackgroundTransparency = 0.699999988079071
            Toggle.Position = UDim2.new(0.8199999928474426, 0, 0.7570000290870667, 0)
            Toggle.BorderColor3 = Color3.fromRGB(0, 0, 0)
            Toggle.Size = UDim2.new(0, 25, 0, 12)
            Toggle.BorderSizePixel = 0
            Toggle.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            Toggle.Parent = Header
            
            local UICorner = Instance.new('UICorner')
            UICorner.CornerRadius = UDim.new(1, 0)
            UICorner.Parent = Toggle
            
            local Circle = Instance.new('Frame')
            Circle.BorderColor3 = Color3.fromRGB(0, 0, 0)
            Circle.AnchorPoint = Vector2.new(0, 0.5)
            Circle.BackgroundTransparency = 0.20000000298023224
            Circle.Position = UDim2.new(0, 0, 0.5, 0)
            Circle.Name = 'Circle'
            Circle.Size = UDim2.new(0, 12, 0, 12)
            Circle.BorderSizePixel = 0
            Circle.BackgroundColor3 = Color3.fromRGB(66, 80, 115)
            Circle.Parent = Toggle
            
            local UICorner = Instance.new('UICorner')
            UICorner.CornerRadius = UDim.new(1, 0)
            UICorner.Parent = Circle
            
            local Keybind = Instance.new('Frame')
            Keybind.Name = 'Keybind'
            Keybind.BackgroundTransparency = 0.699999988079071
            Keybind.Position = UDim2.new(0.15000000596046448, 0, 0.7350000143051147, 0)
            Keybind.BorderColor3 = Color3.fromRGB(0, 0, 0)
            Keybind.Size = UDim2.new(0, 33, 0, 15)
            Keybind.BorderSizePixel = 0
            Keybind.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
            Keybind.Parent = Header
            
            local UICorner = Instance.new('UICorner')
            UICorner.CornerRadius = UDim.new(0, 3)
            UICorner.Parent = Keybind
            
            local TextLabel = Instance.new('TextLabel')
            TextLabel.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
            TextLabel.TextColor3 = Color3.fromRGB(209, 222, 255)
            TextLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
            TextLabel.Text = 'None'
            TextLabel.AnchorPoint = Vector2.new(0.5, 0.5)
            TextLabel.Size = UDim2.new(0, 25, 0, 13)
            TextLabel.BackgroundTransparency = 1
            TextLabel.TextXAlignment = Enum.TextXAlignment.Left
            TextLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
            TextLabel.BorderSizePixel = 0
            TextLabel.TextSize = 10
            TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            TextLabel.Parent = Keybind
            
            local Divider = Instance.new('Frame')
            Divider.BorderColor3 = Color3.fromRGB(0, 0, 0)
            Divider.AnchorPoint = Vector2.new(0.5, 0)
            Divider.BackgroundTransparency = 0.5
            Divider.Position = UDim2.new(0.5, 0, 0.6200000047683716, 0)
            Divider.Name = 'Divider'
            Divider.Size = UDim2.new(0, 241, 0, 1)
            Divider.BorderSizePixel = 0
            Divider.BackgroundColor3 = Color3.fromRGB(52, 66, 89)
            Divider.Parent = Header
            
            local Divider = Instance.new('Frame')
            Divider.BorderColor3 = Color3.fromRGB(0, 0, 0)
            Divider.AnchorPoint = Vector2.new(0.5, 0)
            Divider.BackgroundTransparency = 0.5
            Divider.Position = UDim2.new(0.5, 0, 1, 0)
            Divider.Name = 'Divider'
            Divider.Size = UDim2.new(0, 241, 0, 1)
            Divider.BorderSizePixel = 0
            Divider.BackgroundColor3 = Color3.fromRGB(52, 66, 89)
            Divider.Parent = Header
            
            local Options = Instance.new('Frame')
            Options.Name = 'Options'
            Options.BackgroundTransparency = 1
            Options.Position = UDim2.new(0, 0, 1, 0)
            Options.BorderColor3 = Color3.fromRGB(0, 0, 0)
            Options.Size = UDim2.new(0, 241, 0, 8)
            Options.BorderSizePixel = 0
            Options.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            Options.Parent = Module

            local UIPadding = Instance.new('UIPadding')
            UIPadding.PaddingTop = UDim.new(0, 8)
            UIPadding.Parent = Options

            local UIListLayout = Instance.new('UIListLayout')
            UIListLayout.Padding = UDim.new(0, 5)
            UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
            UIListLayout.Parent = Options

            function ModuleManager:change_state(state: boolean)
                self._state = state

                if self._state then
                    TweenService:Create(Module, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        Size = UDim2.fromOffset(241, 93 + self._size + self._multiplier)
                    }):Play()

                    TweenService:Create(Toggle, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        BackgroundColor3 = Color3.fromRGB(120, 0, 0)
                    }):Play()

                    TweenService:Create(Circle, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        BackgroundColor3 = Color3.fromRGB(120, 0, 0),
                        Position = UDim2.fromScale(0.53, 0.5)
                    }):Play()
                else
                    TweenService:Create(Module, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        Size = UDim2.fromOffset(241, 93)
                    }):Play()

                    TweenService:Create(Toggle, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                    }):Play()

                    TweenService:Create(Circle, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        BackgroundColor3 = Color3.fromRGB(66, 80, 115),
                        Position = UDim2.fromScale(0, 0.5)
                    }):Play()
                end

                Library._config._flags[settings.flag] = self._state
                Config:save(game.GameId, Library._config)

                settings.callback(self._state)
            end
            
            function ModuleManager:connect_keybind()
                if not Library._config._keybinds[settings.flag] then
                    return
                end

                Connections[settings.flag..'_keybind'] = UserInputService.InputBegan:Connect(function(input: InputObject, process: boolean)
                    if process then
                        return
                    end
                    
                    if tostring(input.KeyCode) ~= Library._config._keybinds[settings.flag] then
                        return
                    end
                    
                    self:change_state(not self._state)
                end)
            end

            function ModuleManager:scale_keybind(empty: boolean)
                if Library._config._keybinds[settings.flag] and not empty then
                    local keybind_string = string.gsub(tostring(Library._config._keybinds[settings.flag]), 'Enum.KeyCode.', '')

                    local font_params = Instance.new('GetTextBoundsParams')
                    font_params.Text = keybind_string
                    font_params.Font = Font.new('rbxasset://fonts/families/Montserrat.json', Enum.FontWeight.Bold)
                    font_params.Size = 10
                    font_params.Width = 10000
            
                    local font_size = TextService:GetTextBoundsAsync(font_params)
                    
                    Keybind.Size = UDim2.fromOffset(font_size.X + 6, 15)
                    TextLabel.Size = UDim2.fromOffset(font_size.X, 13)
                else
                    Keybind.Size = UDim2.fromOffset(31, 15)
                    TextLabel.Size = UDim2.fromOffset(25, 13)
                end
            end

            if Library:flag_type(settings.flag, 'boolean') then
                ModuleManager._state = true
                settings.callback(ModuleManager._state)

                Toggle.BackgroundColor3 = Color3.fromRGB(230, 28, 75)
                Circle.BackgroundColor3 = Color3.fromRGB(230, 28, 75)
                Circle.Position = UDim2.fromScale(0.53, 0.5)
            end

            if Library._config._keybinds[settings.flag] then
                local keybind_string = string.gsub(tostring(Library._config._keybinds[settings.flag]), 'Enum.KeyCode.', '')
                TextLabel.Text = keybind_string

                ModuleManager:connect_keybind()
                ModuleManager:scale_keybind()
            end

            Connections[settings.flag..'_input_began'] = Header.InputBegan:Connect(function(input: InputObject)
                if Library._choosing_keybind then
                    return
                end

                if input.UserInputType ~= Enum.UserInputType.MouseButton3 then
                    return
                end
                
                Library._choosing_keybind = true
                
                Connections['keybind_choose_start'] = UserInputService.InputBegan:Connect(function(input: InputObject, process: boolean)
                    if process then
                        return
                    end
                    
                    if input == Enum.UserInputState or input == Enum.UserInputType then
                        return
                    end

                    if input.KeyCode == Enum.KeyCode.Unknown then
                        return
                    end

                    if input.KeyCode == Enum.KeyCode.Backspace then
                        ModuleManager:scale_keybind(true)

                        Library._config._keybinds[settings.flag] = nil
                        Config:save(game.GameId, Library._config)

                        TextLabel.Text = 'None'
                        
                        if Connections[settings.flag..'_keybind'] then
                            Connections[settings.flag..'_keybind']:Disconnect()
                            Connections[settings.flag..'_keybind'] = nil
                        end

                        Connections['keybind_choose_start']:Disconnect()
                        Connections['keybind_choose_start'] = nil

                        Library._choosing_keybind = false

                        return
                    end
                    
                    Connections['keybind_choose_start']:Disconnect()
                    Connections['keybind_choose_start'] = nil
                    
                    Library._config._keybinds[settings.flag] = tostring(input.KeyCode)
                    Config:save(game.GameId, Library._config)

                    if Connections[settings.flag..'_keybind'] then
                        Connections[settings.flag..'_keybind']:Disconnect()
                        Connections[settings.flag..'_keybind'] = nil
                    end

                    ModuleManager:connect_keybind()
                    ModuleManager:scale_keybind()
                    
                    Library._choosing_keybind = false

                    local keybind_string = string.gsub(tostring(Library._config._keybinds[settings.flag]), 'Enum.KeyCode.', '')
                    TextLabel.Text = keybind_string
                end)
            end)

            Header.MouseButton1Click:Connect(function()
                ModuleManager:change_state(not ModuleManager._state)
            end)

            function ModuleManager:create_paragraph(settings: any)
                LayoutOrderModule = LayoutOrderModule + 1;

                local ParagraphManager = {}
                
                if self._size == 0 then
                    self._size = 11
                end
            
                self._size += settings.customScale or 70
            
                if ModuleManager._state then
                    Module.Size = UDim2.fromOffset(241, 93 + self._size)
                end
            
                Options.Size = UDim2.fromOffset(241, self._size)
            
                -- Container Frame
                local Paragraph = Instance.new('Frame')
                Paragraph.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
                Paragraph.BackgroundTransparency = 0.2
                Paragraph.Size = UDim2.new(0, 207, 0, 30) -- Initial size, auto-resized later
                Paragraph.BorderSizePixel = 0
                Paragraph.Name = "Paragraph"
                Paragraph.AutomaticSize = Enum.AutomaticSize.Y -- Support auto-resizing height
                Paragraph.Parent = Options
                Paragraph.LayoutOrder = LayoutOrderModule;
            
                local UICorner = Instance.new('UICorner')
                UICorner.CornerRadius = UDim.new(0, 4)
                UICorner.Parent = Paragraph
            
                -- Title Label
                local Title = Instance.new('TextLabel')
                Title.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
                Title.TextColor3 = Color3.fromRGB(210, 210, 210)
                Title.Text = settings.title or "Title"
                Title.Size = UDim2.new(1, -10, 0, 20)
                Title.Position = UDim2.new(0, 5, 0, 5)
                Title.BackgroundTransparency = 1
                Title.TextXAlignment = Enum.TextXAlignment.Left
                Title.TextYAlignment = Enum.TextYAlignment.Center
                Title.TextSize = 12
                Title.AutomaticSize = Enum.AutomaticSize.XY
                Title.Parent = Paragraph
            
                -- Body Text
                local Body = Instance.new('TextLabel')
                Body.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Regular, Enum.FontStyle.Normal)
                Body.TextColor3 = Color3.fromRGB(255, 200, 200)
                
                if not settings.rich then
                    Body.Text = settings.text or "Skibidi"
                else
                    Body.RichText = true
                    Body.Text = settings.richtext or "<font color='rgb(255,0,0)'>Silly</font> user"
                end
                
                Body.Size = UDim2.new(1, -10, 0, 20)
                Body.Position = UDim2.new(0, 5, 0, 30)
                Body.BackgroundTransparency = 1
                Body.TextXAlignment = Enum.TextXAlignment.Left
                Body.TextYAlignment = Enum.TextYAlignment.Top
                Body.TextSize = 11
                Body.TextWrapped = true
                Body.AutomaticSize = Enum.AutomaticSize.XY
                Body.Parent = Paragraph
            
                -- Hover effect for Paragraph (optional)
                Paragraph.MouseEnter:Connect(function()
                    TweenService:Create(Paragraph, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        BackgroundColor3 = Color3.fromRGB(42, 50, 66)
                    }):Play()
                end)
            
                Paragraph.MouseLeave:Connect(function()
                    TweenService:Create(Paragraph, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        BackgroundColor3 = Color3.fromRGB(120, 0, 0)
                    }):Play()
                end)

                return ParagraphManager
            end

            function ModuleManager:create_text(settings: any)
                LayoutOrderModule = LayoutOrderModule + 1
            
                local TextManager = {}
            
                if self._size == 0 then
                    self._size = 11
                end
            
                self._size += settings.customScale or 50 -- Adjust the default height for text elements
            
                if ModuleManager._state then
                    Module.Size = UDim2.fromOffset(241, 93 + self._size)
                end
            
                Options.Size = UDim2.fromOffset(241, self._size)
            
                -- Container Frame
                local TextFrame = Instance.new('Frame')
                TextFrame.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
                TextFrame.BackgroundTransparency = 0.2
                TextFrame.Size = UDim2.new(0, 207, 0, settings.CustomYSize) -- Initial size, auto-resized later
                TextFrame.BorderSizePixel = 0
                TextFrame.Name = "Text"
                TextFrame.AutomaticSize = Enum.AutomaticSize.Y -- Support auto-resizing height
                TextFrame.Parent = Options
                TextFrame.LayoutOrder = LayoutOrderModule
            
                local UICorner = Instance.new('UICorner')
                UICorner.CornerRadius = UDim.new(0, 4)
                UICorner.Parent = TextFrame
            
                -- Body Text
                local Body = Instance.new('TextLabel')
                Body.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Regular, Enum.FontStyle.Normal)
                Body.TextColor3 = Color3.fromRGB(255, 200, 200)
            
                if not settings.rich then
                    Body.Text = settings.text or "Skibidi" -- Default text
                else
                    Body.RichText = true
                    Body.Text = settings.richtext or "<font color='rgb(255,0,0)'>Silly</font> user" -- Default rich text
                end
            
                Body.Size = UDim2.new(1, -10, 1, 0)
                Body.Position = UDim2.new(0, 5, 0, 5)
                Body.BackgroundTransparency = 1
                Body.TextXAlignment = Enum.TextXAlignment.Left
                Body.TextYAlignment = Enum.TextYAlignment.Top
                Body.TextSize = 10
                Body.TextWrapped = true
                Body.AutomaticSize = Enum.AutomaticSize.XY
                Body.Parent = TextFrame
            
                -- Hover effect for TextFrame (optional)
                TextFrame.MouseEnter:Connect(function()
                    TweenService:Create(TextFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        BackgroundColor3 = Color3.fromRGB(42, 50, 66)
                    }):Play()
                end)
            
                TextFrame.MouseLeave:Connect(function()
                    TweenService:Create(TextFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        BackgroundColor3 = Color3.fromRGB(120, 0, 0)
                    }):Play()
                end)

                function TextManager:Set(new_settings)
                    if not new_settings.rich then
                        Body.Text = new_settings.text or "Skibidi" -- Default text
                    else
                        Body.RichText = true
                        Body.Text = new_settings.richtext or "<font color='rgb(255,0,0)'>Silly</font> user" -- Default rich text
                    end
                end;
            
                return TextManager
            end
            function ModuleManager:create_textbox(settings: any)
                LayoutOrderModule = LayoutOrderModule + 1
            
                local TextboxManager = {
                    _text = ""
                }
            
                if self._size == 0 then
                    self._size = 11
                end
            
                self._size += 32
            
                if ModuleManager._state then
                    Module.Size = UDim2.fromOffset(241, 93 + self._size)
                end
            
                Options.Size = UDim2.fromOffset(241, self._size)
            
                local Label = Instance.new('TextLabel')
                Label.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
                Label.TextColor3 = Color3.fromRGB(255, 255, 255)
                Label.TextTransparency = 0.2
                Label.Text = settings.title or "Enter text"
                Label.Size = UDim2.new(0, 207, 0, 13)
                Label.AnchorPoint = Vector2.new(0, 0)
                Label.Position = UDim2.new(0, 0, 0, 0)
                Label.BackgroundTransparency = 1
                Label.TextXAlignment = Enum.TextXAlignment.Left
                Label.BorderSizePixel = 0
                Label.Parent = Options
                Label.TextSize = 10;
                Label.LayoutOrder = LayoutOrderModule
            
                local Textbox = Instance.new('TextBox')
                Textbox.FontFace = Font.new('rbxasset://fonts/families/SourceSansPro.json', Enum.FontWeight.Regular, Enum.FontStyle.Normal)
                Textbox.TextColor3 = Color3.fromRGB(255, 255, 255)
                Textbox.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Textbox.PlaceholderText = settings.placeholder or "Enter text..."
                Textbox.Text = Library._config._flags[settings.flag] or ""
                Textbox.Name = 'Textbox'
                Textbox.Size = UDim2.new(0, 207, 0, 15)
                Textbox.BorderSizePixel = 0
                Textbox.TextSize = 10
                Textbox.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
                Textbox.BackgroundTransparency = 0.9
                Textbox.ClearTextOnFocus = false
                Textbox.Parent = Options
                Textbox.LayoutOrder = LayoutOrderModule
            
                local UICorner = Instance.new('UICorner')
                UICorner.CornerRadius = UDim.new(0, 4)
                UICorner.Parent = Textbox
            
                function TextboxManager:update_text(text: string)
                    self._text = text
                    Library._config._flags[settings.flag] = self._text
                    Config:save(game.GameId, Library._config)
                    settings.callback(self._text)
                end
            
                if Library:flag_type(settings.flag, 'string') then
                    TextboxManager:update_text(Library._config._flags[settings.flag])
                end
            
                Textbox.FocusLost:Connect(function()
                    TextboxManager:update_text(Textbox.Text)
                end)
            
                return TextboxManager
            end   

            function ModuleManager:create_checkbox(settings: any)
                LayoutOrderModule = LayoutOrderModule + 1
                local CheckboxManager = { _state = false }
            
                if self._size == 0 then
                    self._size = 11
                end
                self._size += 20
            
                if ModuleManager._state then
                    Module.Size = UDim2.fromOffset(241, 93 + self._size)
                end
                Options.Size = UDim2.fromOffset(241, self._size)
            
                local Checkbox = Instance.new("TextButton")
                Checkbox.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
                Checkbox.TextColor3 = Color3.fromRGB(0, 0, 0)
                Checkbox.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Checkbox.Text = ""
                Checkbox.AutoButtonColor = false
                Checkbox.BackgroundTransparency = 1
                Checkbox.Name = "Checkbox"
                Checkbox.Size = UDim2.new(0, 207, 0, 15)
                Checkbox.BorderSizePixel = 0
                Checkbox.TextSize = 14
                Checkbox.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                Checkbox.Parent = Options
                Checkbox.LayoutOrder = LayoutOrderModule
            
                local TitleLabel = Instance.new("TextLabel")
                TitleLabel.Name = "TitleLabel"
                if SelectedLanguage == "th" then
                    TitleLabel.FontFace = Font.new("rbxasset://fonts/families/NotoSansThai.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
                    TitleLabel.TextSize = 13
                else
                    TitleLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
                    TitleLabel.TextSize = 11
                end
                TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                TitleLabel.TextTransparency = 0.2
                TitleLabel.Text = settings.title or "Skibidi"
                TitleLabel.Size = UDim2.new(0, 142, 0, 13)
                TitleLabel.AnchorPoint = Vector2.new(0, 0.5)
                TitleLabel.Position = UDim2.new(0, 0, 0.5, 0)
                TitleLabel.BackgroundTransparency = 1
                TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
                TitleLabel.Parent = Checkbox

                local KeybindBox = Instance.new("Frame")
                KeybindBox.Name = "KeybindBox"
                KeybindBox.Size = UDim2.fromOffset(14, 14)
                KeybindBox.Position = UDim2.new(1, -35, 0.5, 0)
                KeybindBox.AnchorPoint = Vector2.new(0, 0.5)
                KeybindBox.BackgroundColor3 = Color3.fromRGB(230, 28, 75)
                KeybindBox.BorderSizePixel = 0
                KeybindBox.Parent = Checkbox
            
                local KeybindCorner = Instance.new("UICorner")
                KeybindCorner.CornerRadius = UDim.new(0, 4)
                KeybindCorner.Parent = KeybindBox
            
                local KeybindLabel = Instance.new("TextLabel")
                KeybindLabel.Name = "KeybindLabel"
                KeybindLabel.Size = UDim2.new(1, 0, 1, 0)
                KeybindLabel.BackgroundTransparency = 1
                KeybindLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
                KeybindLabel.TextScaled = false
                KeybindLabel.TextSize = 10
                KeybindLabel.Font = Enum.Font.SourceSans
                KeybindLabel.Text = Library._config._keybinds[settings.flag] 
                    and string.gsub(tostring(Library._config._keybinds[settings.flag]), "Enum.KeyCode.", "") 
                    or "..."
                KeybindLabel.Parent = KeybindBox
            
                local Box = Instance.new("Frame")
                Box.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Box.AnchorPoint = Vector2.new(1, 0.5)
                Box.BackgroundTransparency = 0.9
                Box.Position = UDim2.new(1, 0, 0.5, 0)
                Box.Name = "Box"
                Box.Size = UDim2.new(0, 15, 0, 15)
                Box.BorderSizePixel = 0
                Box.BackgroundColor3 = Color3.fromRGB(230, 28, 75)
                Box.Parent = Checkbox
            
                local BoxCorner = Instance.new("UICorner")
                BoxCorner.CornerRadius = UDim.new(0, 4)
                BoxCorner.Parent = Box
            
                local Fill = Instance.new("Frame")
                Fill.AnchorPoint = Vector2.new(0.5, 0.5)
                Fill.BackgroundTransparency = 0.2
                Fill.Position = UDim2.new(0.5, 0, 0.5, 0)
                Fill.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Fill.Name = "Fill"
                Fill.BorderSizePixel = 0
                Fill.BackgroundColor3 = Color3.fromRGB(230, 28, 75)
                Fill.Parent = Box
            
                local FillCorner = Instance.new("UICorner")
                FillCorner.CornerRadius = UDim.new(0, 3)
                FillCorner.Parent = Fill
            
                function CheckboxManager:change_state(state: boolean)
                    self._state = state
                    if self._state then
                        TweenService:Create(Box, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                            BackgroundTransparency = 0.7
                        }):Play()
                        TweenService:Create(Fill, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                            Size = UDim2.fromOffset(9, 9)
                        }):Play()
                    else
                        TweenService:Create(Box, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                            BackgroundTransparency = 0.9
                        }):Play()
                        TweenService:Create(Fill, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                            Size = UDim2.fromOffset(0, 0)
                        }):Play()
                    end
                    Library._config._flags[settings.flag] = self._state
                    Config:save(game.GameId, Library._config)
                    settings.callback(self._state)
                end
            
                if Library:flag_type(settings.flag, "boolean") then
                    CheckboxManager:change_state(Library._config._flags[settings.flag])
                end
            
                Checkbox.MouseButton1Click:Connect(function()
                    CheckboxManager:change_state(not CheckboxManager._state)
                end)
            
                Checkbox.InputBegan:Connect(function(input, gameProcessed)
                    if gameProcessed then return end
                    if input.UserInputType ~= Enum.UserInputType.MouseButton3 then return end
                    if Library._choosing_keybind then return end
            
                    Library._choosing_keybind = true
                    local chooseConnection
                    chooseConnection = UserInputService.InputBegan:Connect(function(keyInput, processed)
                        if processed then return end
                        if keyInput.UserInputType ~= Enum.UserInputType.Keyboard then return end
                        if keyInput.KeyCode == Enum.KeyCode.Unknown then return end
            
                        if keyInput.KeyCode == Enum.KeyCode.Backspace then
                            ModuleManager:scale_keybind(true)
                            Library._config._keybinds[settings.flag] = nil
                            Config:save(game.GameId, Library._config)
                            KeybindLabel.Text = "..."
                            if Connections[settings.flag .. "_keybind"] then
                                Connections[settings.flag .. "_keybind"]:Disconnect()
                                Connections[settings.flag .. "_keybind"] = nil
                            end
                            chooseConnection:Disconnect()
                            Library._choosing_keybind = false
                            return
                        end
            
                        chooseConnection:Disconnect()
                        Library._config._keybinds[settings.flag] = tostring(keyInput.KeyCode)
                        Config:save(game.GameId, Library._config)
                        if Connections[settings.flag .. "_keybind"] then
                            Connections[settings.flag .. "_keybind"]:Disconnect()
                            Connections[settings.flag .. "_keybind"] = nil
                        end
                        ModuleManager:connect_keybind()
                        ModuleManager:scale_keybind()
                        Library._choosing_keybind = false
            
                        local keybind_string = string.gsub(tostring(Library._config._keybinds[settings.flag]), "Enum.KeyCode.", "")
                        KeybindLabel.Text = keybind_string
                    end)
                end)
            
                local keyPressConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                    if gameProcessed then return end
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        local storedKey = Library._config._keybinds[settings.flag]
                        if storedKey and tostring(input.KeyCode) == storedKey then
                            CheckboxManager:change_state(not CheckboxManager._state)
                        end
                    end
                end)
                Connections[settings.flag .. "_keypress"] = keyPressConnection
            
                return CheckboxManager
            end

            function ModuleManager:create_divider(settings: any)
                -- Layout order management
                LayoutOrderModule = LayoutOrderModule + 1;
            
                if self._size == 0 then
                    self._size = 11
                end
            
                self._size += 27
            
                if ModuleManager._state then
                    Module.Size = UDim2.fromOffset(241, 93 + self._size)
                end

                local dividerHeight = 1
                local dividerWidth = 207 -- Adjust this to fit your UI width
            
                -- Create the outer frame to control spacing above and below
                local OuterFrame = Instance.new('Frame')
                OuterFrame.Size = UDim2.new(0, dividerWidth, 0, 20) -- Height here controls spacing above and below
                OuterFrame.BackgroundTransparency = 1 -- Fully invisible
                OuterFrame.Name = 'OuterFrame'
                OuterFrame.Parent = Options
                OuterFrame.LayoutOrder = LayoutOrderModule

                if settings and settings.showtopic then
                    local TextLabel = Instance.new('TextLabel')
                    TextLabel.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
                    TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- 154, 182, 255
                    TextLabel.TextTransparency = 0
                    TextLabel.Text = settings.title
                    TextLabel.Size = UDim2.new(0, 153, 0, 13)
                    TextLabel.Position = UDim2.new(0.5, 0, 0.501, 0)
                    TextLabel.BackgroundTransparency = 1
                    TextLabel.TextXAlignment = Enum.TextXAlignment.Center
                    TextLabel.BorderSizePixel = 0
                    TextLabel.AnchorPoint = Vector2.new(0.5,0.5)
                    TextLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
                    TextLabel.TextSize = 11
                    TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    TextLabel.ZIndex = 3;
                    TextLabel.TextStrokeTransparency = 0;
                    TextLabel.Parent = OuterFrame
                end;
                
                if not settings or settings and not settings.disableline then
                    -- Create the inner divider frame that will be placed in the middle of the OuterFrame
                    local Divider = Instance.new('Frame')
                    Divider.Size = UDim2.new(1, 0, 0, dividerHeight)
                    Divider.BackgroundColor3 = Color3.fromRGB(255, 255, 255) -- White color
                    Divider.BorderSizePixel = 0
                    Divider.Name = 'Divider'
                    Divider.Parent = OuterFrame
                    Divider.ZIndex = 2;
                    Divider.Position = UDim2.new(0, 0, 0.5, -dividerHeight / 2) -- Center the divider vertically in the OuterFrame
                
                    -- Add a UIGradient to the divider for left and right transparency
                    local Gradient = Instance.new('UIGradient')
                    Gradient.Parent = Divider
                    Gradient.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),  -- Start with white
                        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)), -- Keep it white in the middle
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255, 0))  -- Fade to transparent on the right side
                    })
                    Gradient.Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 1),   
                        NumberSequenceKeypoint.new(0.5, 0),
                        NumberSequenceKeypoint.new(1, 1)
                    })
                    Gradient.Rotation = 0 -- Horizontal gradient (fade from left to right)
                
                    -- Optionally, you can add a corner radius for rounded ends
                    local UICorner = Instance.new('UICorner')
                    UICorner.CornerRadius = UDim.new(0, 2) -- Small corner radius for smooth edges
                    UICorner.Parent = Divider

                end;
            
                return true;
            end
            
            function ModuleManager:create_slider(settings: any)

                LayoutOrderModule = LayoutOrderModule + 1

                local SliderManager = {}

                if self._size == 0 then
                    self._size = 11
                end

                self._size += 27

                if ModuleManager._state then
                    Module.Size = UDim2.fromOffset(241, 93 + self._size)
                end

                Options.Size = UDim2.fromOffset(241, self._size)

                local Slider = Instance.new('TextButton')
                Slider.FontFace = Font.new('rbxasset://fonts/families/SourceSansPro.json', Enum.FontWeight.Regular, Enum.FontStyle.Normal);
                Slider.TextSize = 14;
                Slider.TextColor3 = Color3.fromRGB(0, 0, 0)
                Slider.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Slider.Text = ''
                Slider.AutoButtonColor = false
                Slider.BackgroundTransparency = 1
                Slider.Name = 'Slider'
                Slider.Size = UDim2.new(0, 207, 0, 22)
                Slider.BorderSizePixel = 0
                Slider.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                Slider.Parent = Options
                Slider.LayoutOrder = LayoutOrderModule
                
                local TextLabel = Instance.new('TextLabel')
                if GG.SelectedLanguage == "th" then
                    TextLabel.FontFace = Font.new("rbxasset://fonts/families/NotoSansThai.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
                    TextLabel.TextSize = 13;
                else
                    TextLabel.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
                    TextLabel.TextSize = 11;
                end;
                TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                TextLabel.TextTransparency = 0.20000000298023224
                TextLabel.Text = settings.title
                TextLabel.Size = UDim2.new(0, 153, 0, 13)
                TextLabel.Position = UDim2.new(0, 0, 0.05000000074505806, 0)
                TextLabel.BackgroundTransparency = 1
                TextLabel.TextXAlignment = Enum.TextXAlignment.Left
                TextLabel.BorderSizePixel = 0
                TextLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
                TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                TextLabel.Parent = Slider
                
                local Drag = Instance.new('Frame')
                Drag.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Drag.AnchorPoint = Vector2.new(0.5, 1)
                Drag.BackgroundTransparency = 0.8999999761581421
                Drag.Position = UDim2.new(0.5, 0, 0.949999988079071, 0)
                Drag.Name = 'Drag'
                Drag.Size = UDim2.new(0, 207, 0, 4)
                Drag.BorderSizePixel = 0
                Drag.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
                Drag.Parent = Slider
                
                local UICorner = Instance.new('UICorner')
                UICorner.CornerRadius = UDim.new(1, 0)
                UICorner.Parent = Drag
                
                local Fill = Instance.new('Frame')
                Fill.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Fill.AnchorPoint = Vector2.new(0, 0.5)
                Fill.BackgroundTransparency = 0.5
                Fill.Position = UDim2.new(0, 0, 0.5, 0)
                Fill.Name = 'Fill'
                Fill.Size = UDim2.new(0, 103, 0, 4)
                Fill.BorderSizePixel = 0
                Fill.BackgroundColor3 = Color3.fromRGB(230, 28, 75)
                Fill.Parent = Drag
                
                local UICorner = Instance.new('UICorner')
                UICorner.CornerRadius = UDim.new(0, 3)
                UICorner.Parent = Fill
                
                local UIGradient = Instance.new('UIGradient')
                UIGradient.Color = ColorSequence.new{
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(79, 79, 79))
                }
                UIGradient.Parent = Fill
                
                local Circle = Instance.new('Frame')
                Circle.AnchorPoint = Vector2.new(1, 0.5)
                Circle.Name = 'Circle'
                Circle.Position = UDim2.new(1, 0, 0.5, 0)
                Circle.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Circle.Size = UDim2.new(0, 6, 0, 6)
                Circle.BorderSizePixel = 0
                Circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Circle.Parent = Fill
                
                local UICorner = Instance.new('UICorner')
                UICorner.CornerRadius = UDim.new(1, 0)
                UICorner.Parent = Circle
                
                local Value = Instance.new('TextLabel')
                Value.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
                Value.TextColor3 = Color3.fromRGB(255, 255, 255)
                Value.TextTransparency = 0.20000000298023224
                Value.Text = '50'
                Value.Name = 'Value'
                Value.Size = UDim2.new(0, 42, 0, 13)
                Value.AnchorPoint = Vector2.new(1, 0)
                Value.Position = UDim2.new(1, 0, 0, 0)
                Value.BackgroundTransparency = 1
                Value.TextXAlignment = Enum.TextXAlignment.Right
                Value.BorderSizePixel = 0
                Value.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Value.TextSize = 10
                Value.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Value.Parent = Slider

                function SliderManager:set_percentage(percentage: number)
                    local rounded_number = 0

                    if settings.round_number then
                        rounded_number = math.floor(percentage)
                    else
                        rounded_number = math.floor(percentage * 10) / 10
                    end

                    percentage = (percentage - settings.minimum_value) / (settings.maximum_value - settings.minimum_value)
                    
                    local slider_size = math.clamp(percentage, 0.02, 1) * Drag.Size.X.Offset
                    local number_threshold = math.clamp(rounded_number, settings.minimum_value, settings.maximum_value)
    
                    Library._config._flags[settings.flag] = number_threshold
                    Value.Text = number_threshold
    
                    TweenService:Create(Fill, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        Size = UDim2.fromOffset(slider_size, Drag.Size.Y.Offset)
                    }):Play()
    
                    settings.callback(number_threshold)
                end

                function SliderManager:update()
                    local mouse_position = (mouse.X - Drag.AbsolutePosition.X) / Drag.Size.X.Offset
                    local percentage = settings.minimum_value + (settings.maximum_value - settings.minimum_value) * mouse_position

                    self:set_percentage(percentage)
                end

                function SliderManager:input()
                    SliderManager:update()
    
                    Connections['slider_drag_'..settings.flag] = mouse.Move:Connect(function()
                        SliderManager:update()
                    end)
                    
                    Connections['slider_input_'..settings.flag] = UserInputService.InputEnded:Connect(function(input: InputObject, process: boolean)
                        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
                            return
                        end
    
                        Connections:disconnect('slider_drag_'..settings.flag)
                        Connections:disconnect('slider_input_'..settings.flag)

                        if not settings.ignoresaved then
                            Config:save(game.GameId, Library._config);
                        end;
                    end)
                end


                if Library:flag_type(settings.flag, 'number') then
                    if not settings.ignoresaved then
                        SliderManager:set_percentage(Library._config._flags[settings.flag]);
                    else
                        SliderManager:set_percentage(settings.value);
                    end;
                else
                    SliderManager:set_percentage(settings.value);
                end;
    
                Slider.MouseButton1Down:Connect(function()
                    SliderManager:input()
                end)

                return SliderManager
            end

            function ModuleManager:create_dropdown(settings: any)

                if not settings.Order then
                    LayoutOrderModule = LayoutOrderModule + 1;
                end;

                local DropdownManager = {
                    _state = false,
                    _size = 0
                }

                if not settings.Order then
                    if self._size == 0 then
                        self._size = 11
                    end

                    self._size += 44
                end;

                if not settings.Order then
                    if ModuleManager._state then
                        Module.Size = UDim2.fromOffset(241, 93 + self._size)
                    end
                    Options.Size = UDim2.fromOffset(241, self._size)
                end

                local Dropdown = Instance.new('TextButton')
                Dropdown.FontFace = Font.new('rbxasset://fonts/families/SourceSansPro.json', Enum.FontWeight.Regular, Enum.FontStyle.Normal)
                Dropdown.TextColor3 = Color3.fromRGB(0, 0, 0)
                Dropdown.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Dropdown.Text = ''
                Dropdown.AutoButtonColor = false
                Dropdown.BackgroundTransparency = 1
                Dropdown.Name = 'Dropdown'
                Dropdown.Size = UDim2.new(0, 207, 0, 39)
                Dropdown.BorderSizePixel = 0
                Dropdown.TextSize = 14
                Dropdown.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                Dropdown.Parent = Options

                if not settings.Order then
                    Dropdown.LayoutOrder = LayoutOrderModule;
                else
                    Dropdown.LayoutOrder = settings.OrderValue;
                end;

                if not Library._config._flags[settings.flag] then
                    Library._config._flags[settings.flag] = {};
                end;
                
                local TextLabel = Instance.new('TextLabel')
                if GG.SelectedLanguage == "th" then
                    TextLabel.FontFace = Font.new("rbxasset://fonts/families/NotoSansThai.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
                    TextLabel.TextSize = 13;
                else
                    TextLabel.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal);
                    TextLabel.TextSize = 11;
                end;
                TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                TextLabel.TextTransparency = 0.20000000298023224
                TextLabel.Text = settings.title
                TextLabel.Size = UDim2.new(0, 207, 0, 13)
                TextLabel.BackgroundTransparency = 1
                TextLabel.TextXAlignment = Enum.TextXAlignment.Left
                TextLabel.BorderSizePixel = 0
                TextLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
                TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                TextLabel.Parent = Dropdown
                
                local Box = Instance.new('Frame')
                Box.ClipsDescendants = true
                Box.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Box.AnchorPoint = Vector2.new(0.5, 0)
                Box.BackgroundTransparency = 0.8999999761581421
                Box.Position = UDim2.new(0.5, 0, 1.2000000476837158, 0)
                Box.Name = 'Box'
                Box.Size = UDim2.new(0, 207, 0, 22)
                Box.BorderSizePixel = 0
                Box.BackgroundColor3 = Color3.fromRGB(230, 28, 75)
                Box.Parent = TextLabel
                
                local UICorner = Instance.new('UICorner')
                UICorner.CornerRadius = UDim.new(0, 4)
                UICorner.Parent = Box
                
                local Header = Instance.new('Frame')
                Header.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Header.AnchorPoint = Vector2.new(0.5, 0)
                Header.BackgroundTransparency = 1
                Header.Position = UDim2.new(0.5, 0, 0, 0)
                Header.Name = 'Header'
                Header.Size = UDim2.new(0, 207, 0, 22)
                Header.BorderSizePixel = 0
                Header.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Header.Parent = Box
                
                local CurrentOption = Instance.new('TextLabel')
                CurrentOption.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
                CurrentOption.TextColor3 = Color3.fromRGB(255, 255, 255)
                CurrentOption.TextTransparency = 0.20000000298023224
                CurrentOption.Name = 'CurrentOption'
                CurrentOption.Size = UDim2.new(0, 161, 0, 13)
                CurrentOption.AnchorPoint = Vector2.new(0, 0.5)
                CurrentOption.Position = UDim2.new(0.04999988153576851, 0, 0.5, 0)
                CurrentOption.BackgroundTransparency = 1
                CurrentOption.TextXAlignment = Enum.TextXAlignment.Left
                CurrentOption.BorderSizePixel = 0
                CurrentOption.BorderColor3 = Color3.fromRGB(0, 0, 0)
                CurrentOption.TextSize = 10
                CurrentOption.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                CurrentOption.Parent = Header
                local UIGradient = Instance.new('UIGradient')
                UIGradient.Transparency = NumberSequence.new{
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(0.704, 0),
                    NumberSequenceKeypoint.new(0.872, 0.36250001192092896),
                    NumberSequenceKeypoint.new(1, 1)
                }
                UIGradient.Parent = CurrentOption
                
                local Arrow = Instance.new('ImageLabel')
                Arrow.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Arrow.AnchorPoint = Vector2.new(0, 0.5)
                Arrow.Image = 'rbxassetid://84232453189324'
                Arrow.BackgroundTransparency = 1
                Arrow.Position = UDim2.new(0.9100000262260437, 0, 0.5, 0)
                Arrow.Name = 'Arrow'
                Arrow.Size = UDim2.new(0, 8, 0, 8)
                Arrow.BorderSizePixel = 0
                Arrow.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Arrow.Parent = Header
                
                local Options = Instance.new('ScrollingFrame')
                Options.ScrollBarImageColor3 = Color3.fromRGB(0, 0, 0)
                Options.Active = true
                Options.ScrollBarImageTransparency = 1
                Options.AutomaticCanvasSize = Enum.AutomaticSize.XY
                Options.ScrollBarThickness = 0
                Options.Name = 'Options'
                Options.Size = UDim2.new(0, 207, 0, 0)
                Options.BackgroundTransparency = 1
                Options.Position = UDim2.new(0, 0, 1, 0)
                Options.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Options.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Options.BorderSizePixel = 0
                Options.CanvasSize = UDim2.new(0, 0, 0.5, 0)
                Options.Parent = Box
                
                local UIListLayout = Instance.new('UIListLayout')
                UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
                UIListLayout.Parent = Options
                
                local UIPadding = Instance.new('UIPadding')
                UIPadding.PaddingTop = UDim.new(0, -1)
                UIPadding.PaddingLeft = UDim.new(0, 10)
                UIPadding.Parent = Options
                
                local UIListLayout = Instance.new('UIListLayout')
                UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
                UIListLayout.Parent = Box

                function DropdownManager:update(option: string)
                    -- If multi-dropdown is enabled
                    if settings.multi_dropdown then
                        -- Split the CurrentOption.Text by commas into a table

                        if not Library._config._flags[settings.flag] then
                            Library._config._flags[settings.flag] = {};
                        end;

                        local CurrentTargetValue = nil;
                        
                        if #Library._config._flags[settings.flag] > 0 then

                            CurrentTargetValue = convertTableToString(Library._config._flags[settings.flag]);

                        end;

                        local selected = {}

                        if CurrentTargetValue then
                            for value in string.gmatch(CurrentTargetValue, "([^,]+)") do
                                -- Trim spaces around the option using string.match
                                local trimmedValue = value:match("^%s*(.-)%s*$")  -- Trim leading and trailing spaces
                                
                                -- Exclude any unwanted labels (e.g. "Label")
                                if trimmedValue ~= "Label" then
                                    table.insert(selected, trimmedValue)
                                end
                            end
                        else
                            for value in string.gmatch(CurrentOption.Text, "([^,]+)") do
                                -- Trim spaces around the option using string.match
                                local trimmedValue = value:match("^%s*(.-)%s*$")  -- Trim leading and trailing spaces
                                
                                -- Exclude any unwanted labels (e.g. "Label")
                                if trimmedValue ~= "Label" then
                                    table.insert(selected, trimmedValue)
                                end
                            end
                        end;
                
                        local CurrentTextGet = convertStringToTable(CurrentOption.Text);

                        optionSkibidi = "nil";
                        if typeof(option) ~= 'string' then
                            optionSkibidi = option.Name;
                        else
                            optionSkibidi = option;
                        end;

                        local found = false
                        for i, v in pairs(CurrentTextGet) do
                            if v == optionSkibidi then
                                table.remove(CurrentTextGet, i);
                                break;
                            end
                        end

                        CurrentOption.Text = table.concat(selected, ", ")
                        local OptionsChild = {}
                        -- Update the transparent effect of each option
                        for _, object in Options:GetChildren() do
                            if object.Name == "Option" then
                                table.insert(OptionsChild, object.Text)
                                if table.find(selected, object.Text) then
                                    object.TextTransparency = 0.2
                                else
                                    object.TextTransparency = 0.6
                                end
                            end
                        end

                        CurrentTargetValue = convertStringToTable(CurrentOption.Text);

                        for _, v in CurrentTargetValue do
                            if not table.find(OptionsChild, v) and table.find(selected, v) then
                                table.remove(selected, _)
                            end;
                        end;

                        CurrentOption.Text = table.concat(selected, ", ");
                
                        Library._config._flags[settings.flag] = convertStringToTable(CurrentOption.Text);
                    else
                        -- For single dropdown, just set the CurrentOption.Text to the selected option
                        CurrentOption.Text = (typeof(option) == "string" and option) or option.Name
                        for _, object in Options:GetChildren() do
                            if object.Name == "Option" then
                                -- Only update transparency for actual option text buttons
                                if object.Text == CurrentOption.Text then
                                    object.TextTransparency = 0.2
                                else
                                    object.TextTransparency = 0.6
                                end
                            end
                        end
                        Library._config._flags[settings.flag] = option
                    end
                
                    -- Save the configuration state
                    Config:save(game.GameId, Library._config)
                
                    -- Callback with the updated option(s)
                    settings.callback(option)
                end
                
                local CurrentDropSizeState = 0;

                function DropdownManager:unfold_settings()
                    self._state = not self._state

                    if self._state then
                        ModuleManager._multiplier += self._size

                        CurrentDropSizeState = self._size;

                        TweenService:Create(Module, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                            Size = UDim2.fromOffset(241, 93 + ModuleManager._size + ModuleManager._multiplier)
                        }):Play()

                        TweenService:Create(Module.Options, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                            Size = UDim2.fromOffset(241, ModuleManager._size + ModuleManager._multiplier)
                        }):Play()

                        TweenService:Create(Dropdown, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                            Size = UDim2.fromOffset(207, 39 + self._size)
                        }):Play()

                        TweenService:Create(Box, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                            Size = UDim2.fromOffset(207, 22 + self._size)
                        }):Play()

                        TweenService:Create(Arrow, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                            Rotation = 180
                        }):Play()
                    else
                        ModuleManager._multiplier -= self._size

                        CurrentDropSizeState = 0;

                        TweenService:Create(Module, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                            Size = UDim2.fromOffset(241, 93 + ModuleManager._size + ModuleManager._multiplier)
                        }):Play()

                        TweenService:Create(Module.Options, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                            Size = UDim2.fromOffset(241, ModuleManager._size + ModuleManager._multiplier)
                        }):Play()

                        TweenService:Create(Dropdown, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                            Size = UDim2.fromOffset(207, 39)
                        }):Play()

                        TweenService:Create(Box, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                            Size = UDim2.fromOffset(207, 22)
                        }):Play()

                        TweenService:Create(Arrow, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                            Rotation = 0
                        }):Play()
                    end
                end

                if #settings.options > 0 then
                    DropdownManager._size = 3

                    for index, value in settings.options do
                        local Option = Instance.new('TextButton')
                        Option.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
                        Option.Active = false
                        Option.TextTransparency = 0.6000000238418579
                        Option.AnchorPoint = Vector2.new(0, 0.5)
                        Option.TextSize = 10
                        Option.Size = UDim2.new(0, 186, 0, 16)
                        Option.TextColor3 = Color3.fromRGB(255, 255, 255)
                        Option.BorderColor3 = Color3.fromRGB(0, 0, 0)
                        Option.Text = (typeof(value) == "string" and value) or value.Name;
                        Option.AutoButtonColor = false
                        Option.Name = 'Option'
                        Option.BackgroundTransparency = 1
                        Option.TextXAlignment = Enum.TextXAlignment.Left
                        Option.Selectable = false
                        Option.Position = UDim2.new(0.04999988153576851, 0, 0.34210526943206787, 0)
                        Option.BorderSizePixel = 0
                        Option.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                        Option.Parent = Options
                        
                        local UIGradient = Instance.new('UIGradient')
                        UIGradient.Transparency = NumberSequence.new{
                            NumberSequenceKeypoint.new(0, 0),
                            NumberSequenceKeypoint.new(0.704, 0),
                            NumberSequenceKeypoint.new(0.872, 0.36250001192092896),
                            NumberSequenceKeypoint.new(1, 1)
                        }
                        UIGradient.Parent = Option

                        Option.MouseButton1Click:Connect(function()
                            if not Library._config._flags[settings.flag] then
                                Library._config._flags[settings.flag] = {};
                            end;

                            if settings.multi_dropdown then
                                if table.find(Library._config._flags[settings.flag], value) then
                                    Library:remove_table_value(Library._config._flags[settings.flag], value)
                                else
                                    table.insert(Library._config._flags[settings.flag], value)
                                end
                            end

                            DropdownManager:update(value)
                        end)
    
                        if index > settings.maximum_options then
                            continue
                        end
    
                        DropdownManager._size += 16
                        Options.Size = UDim2.fromOffset(207, DropdownManager._size)
                    end
                end

                function DropdownManager:New(value)
                    Dropdown:Destroy(true);
                    value.OrderValue = Dropdown.LayoutOrder
                    ModuleManager._multiplier -= CurrentDropSizeState
                    return ModuleManager:create_dropdown(value)
                end;

                if Library:flag_type(settings.flag, 'string') then
                    DropdownManager:update(Library._config._flags[settings.flag])
                else
                    DropdownManager:update(settings.options[1])
                end
    
                Dropdown.MouseButton1Click:Connect(function()
                    DropdownManager:unfold_settings()
                end)

                return DropdownManager
            end

            function ModuleManager:create_feature(settings)

                local checked = false;
                
                LayoutOrderModule = LayoutOrderModule + 1
            
                if self._size == 0 then
                    self._size = 11
                end
            
                self._size += 20
            
                if ModuleManager._state then
                    Module.Size = UDim2.fromOffset(241, 93 + self._size);
                end
            
                Options.Size = UDim2.fromOffset(241, self._size);
            
                local FeatureContainer = Instance.new("Frame")
                FeatureContainer.Size = UDim2.new(0, 207, 0, 16)
                FeatureContainer.BackgroundTransparency = 1
                FeatureContainer.Parent = Options
                FeatureContainer.LayoutOrder = LayoutOrderModule
            
                local UIListLayout = Instance.new("UIListLayout")
                UIListLayout.FillDirection = Enum.FillDirection.Horizontal
                UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
                UIListLayout.Parent = FeatureContainer
            
                local FeatureButton = Instance.new("TextButton")
                FeatureButton.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal);
                FeatureButton.TextSize = 11;
                FeatureButton.Size = UDim2.new(1, -35, 0, 16)
                FeatureButton.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
                FeatureButton.TextColor3 = Color3.fromRGB(210, 210, 210)
                FeatureButton.Text = "    " .. settings.title or "    " .. "Feature"
                FeatureButton.AutoButtonColor = false
                FeatureButton.TextXAlignment = Enum.TextXAlignment.Left
                FeatureButton.TextTransparency = 0.2
                FeatureButton.Parent = FeatureContainer
            
                local RightContainer = Instance.new("Frame")
                RightContainer.Size = UDim2.new(0, 45, 0, 16)
                RightContainer.BackgroundTransparency = 1
                RightContainer.Parent = FeatureContainer
            
                local RightLayout = Instance.new("UIListLayout")
                RightLayout.Padding = UDim.new(0.1, 0)
                RightLayout.FillDirection = Enum.FillDirection.Horizontal
                RightLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
                RightLayout.SortOrder = Enum.SortOrder.LayoutOrder
                RightLayout.Parent = RightContainer
            
                local KeybindBox = Instance.new("TextLabel")
                KeybindBox.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal);
                KeybindBox.Size = UDim2.new(0, 15, 0, 15)
                KeybindBox.BackgroundColor3 = Color3.fromRGB(230, 28, 75)
                KeybindBox.TextColor3 = Color3.fromRGB(255, 255, 255)
                KeybindBox.TextSize = 11
                KeybindBox.BackgroundTransparency = 1
                KeybindBox.LayoutOrder = 2;
                KeybindBox.Parent = RightContainer
            
                local KeybindButton = Instance.new("TextButton")
                KeybindButton.Size = UDim2.new(1, 0, 1, 0)
                KeybindButton.BackgroundTransparency = 1
                KeybindButton.TextTransparency = 1
                KeybindButton.Parent = KeybindBox

                local CheckboxCorner = Instance.new("UICorner", KeybindBox)
                CheckboxCorner.CornerRadius = UDim.new(0, 3)

                local UIStroke = Instance.new("UIStroke", KeybindBox)
                UIStroke.Color = Color3.fromRGB(120, 0, 0)
                UIStroke.Thickness = 1
                UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            
                if not Library._config._flags then
                    Library._config._flags = {}
                end
            
                if not Library._config._flags[settings.flag] then
                    Library._config._flags[settings.flag] = {
                        checked = false,
                        BIND = settings.default or "Unknown"
                    }
                end
            
                checked = Library._config._flags[settings.flag].checked
                KeybindBox.Text = Library._config._flags[settings.flag].BIND

                if KeybindBox.Text == "Unknown" then
                    KeybindBox.Text = "...";
                end;

                local UseF_Var = nil;
            
                if not settings.disablecheck then
                    local Checkbox = Instance.new("TextButton")
                    Checkbox.Size = UDim2.new(0, 15, 0, 15)
                    Checkbox.BackgroundColor3 = checked and Color3.fromRGB(120, 0, 0) or Color3.fromRGB(120, 0, 0)
                    Checkbox.Text = ""
                    Checkbox.Parent = RightContainer
                    Checkbox.LayoutOrder = 1;

                    local UIStroke = Instance.new("UIStroke", Checkbox)
                    UIStroke.Color = Color3.fromRGB(120, 0, 0)
                    UIStroke.Thickness = 1
                    UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                
                    local CheckboxCorner = Instance.new("UICorner")
                    CheckboxCorner.CornerRadius = UDim.new(0, 3)
                    CheckboxCorner.Parent = Checkbox
            
                    local function toggleState()
                        checked = not checked
                        Checkbox.BackgroundColor3 = checked and Color3.fromRGB(120, 0, 0) or Color3.fromRGB(120, 0, 0)
                        Library._config._flags[settings.flag].checked = checked
                        Config:save(game.GameId, Library._config)
                        if settings.callback then
                            settings.callback(checked)
                        end
                    end

                    UseF_Var = toggleState
                
                    Checkbox.MouseButton1Click:Connect(toggleState)

                else

                    UseF_Var = function()
                        settings.button_callback();
                    end;

                end;
            
                KeybindButton.MouseButton1Click:Connect(function()
                    KeybindBox.Text = "..."
                    local inputConnection
                    inputConnection = game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
                        if gameProcessed then return end
                        if input.UserInputType == Enum.UserInputType.Keyboard then
                            local newKey = input.KeyCode.Name
                            Library._config._flags[settings.flag].BIND = newKey
                            if newKey ~= "Unknown" then
                                KeybindBox.Text = newKey;
                            end;
                            Config:save(game.GameId, Library._config) -- Save new keybind
                            inputConnection:Disconnect()
                        elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
                            Library._config._flags[settings.flag].BIND = "Unknown"
                            KeybindBox.Text = "..."
                            Config:save(game.GameId, Library._config)
                            inputConnection:Disconnect()
                        end
                    end)
                    Connections["keybind_input_" .. settings.flag] = inputConnection
                end)
            
                local keyPressConnection
                keyPressConnection = game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
                    if gameProcessed then return end
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        if input.KeyCode.Name == Library._config._flags[settings.flag].BIND then
                            UseF_Var();
                        end
                    end
                end)
                Connections["keybind_press_" .. settings.flag] = keyPressConnection
            
                FeatureButton.MouseButton1Click:Connect(function()
                    if settings.button_callback then
                        settings.button_callback()
                    end
                end)

                if not settings.disablecheck then
                    settings.callback(checked);
                end;
            
                return FeatureContainer
            end                    

            return ModuleManager
        end

        return TabManager
    end

    Connections['library_visiblity'] = UserInputService.InputBegan:Connect(function(input: InputObject, process: boolean)
        if input.KeyCode ~= Enum.KeyCode.Insert then
            return
        end

        self._ui_open = not self._ui_open
        self:change_visiblity(self._ui_open)
    end)

    self._ui.Container.Handler.Minimize.MouseButton1Click:Connect(function()
        self._ui_open = not self._ui_open
        self:change_visiblity(self._ui_open)
    end)

    return self
end

local main = Library.new()

local rage = main:create_tab('Blatant', 'rbxassetid://76499042599127')
local player = main:create_tab('Player', 'rbxassetid://126017907477623')
local world = main:create_tab('World', 'rbxassetid://85168909131990')
local farm = main:create_tab('Farm', 'rbxassetid://132243429647479')
local misc = main:create_tab('Misc', 'rbxassetid://132243429647479')

main:load()



repeat task.wait() until game:IsLoaded()


local Players = game:GetService('Players')
local Player = Players.LocalPlayer
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Tornado_Time = tick()
local UserInputService = game:GetService('UserInputService')
local Last_Input = UserInputService:GetLastInputType()
local Debris = game:GetService('Debris')
local RunService = game:GetService('RunService')
local Vector2_Mouse_Location = nil
local Grab_Parry = nil
local Remotes = {}
local Parry_Key = nil
local Speed_Divisor_Multiplier = 1.1
local LobbyAP_Speed_Divisor_Multiplier = 1.1
local firstParryFired = false
local ParryThreshold = 2.5
local firstParryType = 'F_Key'
local Previous_Positions = {}
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualInputService = game:GetService("VirtualInputManager")


local GuiService = game:GetService('GuiService')

local function updateNavigation(guiObject: GuiObject | nil)
    GuiService.SelectedObject = guiObject
end

local function performFirstPress(parryType)
    if parryType == 'F_Key' then
        VirtualInputService:SendKeyEvent(true, Enum.KeyCode.F, false, nil)
    elseif parryType == 'Left_Click' then
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
    elseif parryType == 'Navigation' then
        local button = Players.LocalPlayer.PlayerGui.Hotbar.Block
        updateNavigation(button)
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
        task.wait(0.01)
        updateNavigation(nil)
    end
end

if not LPH_OBFUSCATED then
    function LPH_JIT(Function) return Function end
    function LPH_JIT_MAX(Function) return Function end
    function LPH_NO_VIRTUALIZE(Function) return Function end
end

local PrivateKey = nil

local PropertyChangeOrder = {}

local HashOne
local HashTwo
local HashThree


LPH_NO_VIRTUALIZE(function()
    for _, Value in pairs(getgc(true)) do
        if type(Value) == "function" and islclosure(Value) then
            local Protos = debug.getprotos(Value)
            local Upvalues = debug.getupvalues(Value)
            local Constants = debug.getconstants(Value)
            if Protos and Upvalues and Constants and (#Protos == 4) and (#Upvalues == 24) and (#Constants == 104) then
                Remotes[debug.getupvalue(Value, 16)] = debug.getconstant(Value, 62)
                Parry_Key = debug.getupvalue(Value, 17)
                Remotes[debug.getupvalue(Value, 18)] = debug.getconstant(Value, 64)
                Remotes[debug.getupvalue(Value, 19)] = debug.getconstant(Value, 65)
                break
            end
        end
    end
end)()

LPH_NO_VIRTUALIZE(function()
    for Index, Object in next, game:GetDescendants() do
        if Object:IsA("RemoteEvent") and string.find(Object.Name, "\n") then
            Object.Changed:Once(function()
                table.insert(PropertyChangeOrder, Object)
            end)
        end
    end
end)()


repeat
    task.wait()
until #PropertyChangeOrder == 3


local ShouldPlayerJump = PropertyChangeOrder[1]
local MainRemote = PropertyChangeOrder[2]
local GetOpponentPosition = PropertyChangeOrder[3]

    local __namecall
    __namecall = hookmetamethod(game, "__namecall", function(self, ...)
        local Args = {...}
        local Method = getnamecallmethod()

        if not checkcaller() and (Method == "FireServer") and string.find(self.Name, "\n") then
            if Args[2] then
                PrivateKey = Args[2]
            end
        end

        return __namecall(self, ...)
    end)


local Parry_Key

for Index, Value in pairs(getconnections(game:GetService("Players").LocalPlayer.PlayerGui.Hotbar.Block.Activated)) do
    if Value and Value.Function and not iscclosure(Value.Function)  then
        for Index2,Value2 in pairs(getupvalues(Value.Function)) do
            if type(Value2) == "function" then
                Parry_Key = getupvalue(getupvalue(Value2, 2), 17);
                print("Parry_Key:", Parry_Key)
            end;
        end;
    end;
end;

-- ...vers la ligne 2792...
local function Parry(...)
    ShouldPlayerJump:FireServer(HashOne, PrivateKey, ...)
    MainRemote:FireServer(HashTwo, PrivateKey, ...)
    GetOpponentPosition:FireServer(HashThree, PrivateKey, ...)
end

local canHookRemote = type(hookmetamethod) == "function" and type(getrawmetatable) == "function" and type(setreadonly) == "function"
local revertedRemotes = {}
local originalMetatables = {}

local function isValidParryArgs(args)
    return #args == 7
       and type(args[2]) == "string"
       and type(args[3]) == "number"
       and typeof(args[4]) == "CFrame"
       and type(args[5]) == "table"
       and type(args[6]) == "table"
       and type(args[7]) == "boolean"
end

local function hookRemote(remote)
    if not remote or revertedRemotes[remote] then
        return
    end

    local meta = getrawmetatable(remote)
    if not meta or not meta.__index then
        return
    end

    if not originalMetatables[meta] then
        originalMetatables[meta] = true
        setreadonly(meta, false)
        local oldIndex = meta.__index
        meta.__index = function(self, key)
            if key == "FireServer" and self:IsA("RemoteEvent") then
                return function(_, ...)
                    local args = { ... }
                    if isValidParryArgs(args) and not revertedRemotes[self] then
                        revertedRemotes[self] = args
                    end
                    return oldIndex(self, "FireServer")(_, table.unpack(args))
                end
            elseif key == "InvokeServer" and self:IsA("RemoteFunction") then
                return function(_, ...)
                    local args = { ... }
                    if isValidParryArgs(args) and not revertedRemotes[self] then
                        revertedRemotes[self] = args
                    end
                    return oldIndex(self, "InvokeServer")(_, table.unpack(args))
                end
            end

            return oldIndex(self, key)
        end
        setreadonly(meta, true)
    end
end

if canHookRemote then
    for _, remote in ipairs(ReplicatedStorage:GetChildren()) do
        if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
            hookRemote(remote)
        end
    end

    ReplicatedStorage.ChildAdded:Connect(function(child)
        if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
            hookRemote(child)
        end
    end)
end

local function applyParryData(args, parryData)
    if not parryData or typeof(parryData) ~= "table" then
        return
    end

    if typeof(parryData[2]) == "CFrame" then
        args[4] = parryData[2]
    end

    if type(parryData[3]) == "table" then
        args[5] = parryData[3]
    end

    if type(parryData[4]) == "table" then
        args[6] = parryData[4]
    end
end

local function SendParry(parryData)
    if canHookRemote and next(revertedRemotes) then
        for remote, args in pairs(revertedRemotes) do
            if typeof(remote) ~= "Instance" or not remote:IsDescendantOf(game) then
                revertedRemotes[remote] = nil
            else
                applyParryData(args, parryData)

                if remote:IsA("RemoteEvent") then
                    remote:FireServer(table.unpack(args))
                elseif remote:IsA("RemoteFunction") then
                    remote:InvokeServer(table.unpack(args))
                end
            end
        end
    else
        if type(parryData) == "table" then
            Parry(table.unpack(parryData))
        end
    end
end

--[[

local function Parry(...)
    ShouldPlayerJump:FireServer(HashOne, PrivateKey, ...)
    MainRemote:FireServer(HashTwo, PrivateKey, ...)
    GetOpponentPosition:FireServer(HashThree, PrivateKey, ...)
end

]]

type functionInfo = {
    scriptName: string,
    name: string,
    line: number,
    upvalueCount: number,
    constantCount: number
}

local function getFunction(t:functionInfo)
    t = t or {}
    local functions = {}
    local function findMatches()
        setthreadidentity(6)
        for i,v in getgc() do
            if type(v) == "function" and islclosure(v) then
                local match = true
                local info = getinfo(v)
                if t.scriptName and (not tostring(getfenv(v).script):find(t.scriptName)) then
                    match = false
                end
                if t.name and info.name ~= t.name then
                    match = false
                end
                if t.line and info.currentline ~= t.line then
                    match = false
                end
                if t.upvalueCount and #getupvalues(v) ~= t.upvalueCount then
                    match = false
                end
                if t.constantCount and #getconstants(v) ~= t.constantsCount then
                    match = false
                end
                if match then
                    table.insert(functions,v)
                end
            end
        end
        setthreadidentity(8)
    end

    findMatches()

    if #functions == 0 then
        while task.wait(1) and #functions == 0 do
            findMatches()
        end
    end
    
    if #functions == 1 then
        return functions[1]
    end
end

type tableInfo = {
    highEntropyTableIndex: string,
}

getgenv().skinChanger = false
getgenv().swordModel = ""
getgenv().swordAnimations = ""
getgenv().swordFX = ""


local print = function() end

if getgenv().updateSword and getgenv().skinChanger then
    getgenv().updateSword()
    return
end

local function getTable(t:tableInfo)
    t = t or {}
    local tables = {}
    
    local function findMatches()
        for i,v in getgc(true) do
            if type(v) == "table" then
                local match = true
                if t.highEntropyTableIndex and (not rawget(v,t.highEntropyTableIndex)) then
                    match = false
                end
                if match then
                    table.insert(tables,v)
                end
            end
        end
    end

    findMatches()

    if #tables == 0 then
        while task.wait(1) and #tables == 0 do
            findMatches()
        end
    end

    if #tables == 1 then
        return tables[1]
    end
end

local plrs = game:GetService("Players")
local plr = plrs.LocalPlayer
local rs = game:GetService("ReplicatedStorage")
local swordInstancesInstance = rs:WaitForChild("Shared",9e9):WaitForChild("ReplicatedInstances",9e9):WaitForChild("Swords",9e9)
local swordInstances = require(swordInstancesInstance)

local swordsController

while task.wait() and (not swordsController) do
    for i,v in getconnections(rs.Remotes.FireSwordInfo.OnClientEvent) do
        if v.Function and islclosure(v.Function) then
            local upvalues = getupvalues(v.Function)
            if #upvalues == 1 and type(upvalues[1]) == "table" then
                swordsController = upvalues[1]
                break
            end
        end
    end
end

function getSlashName(swordName)
    local slashName = swordInstances:GetSword(swordName)
    return (slashName and slashName.SlashName) or "SlashEffect"
end

function setSword()
    if not getgenv().skinChanger then return end
    
    setupvalue(rawget(swordInstances,"EquipSwordTo"),2,false)
    
    swordInstances:EquipSwordTo(plr.Character, getgenv().swordModel)
    swordsController:SetSword(getgenv().swordAnimations)
end

local playParryFunc
local parrySuccessAllConnection

while task.wait() and not parrySuccessAllConnection do
    for i,v in getconnections(rs.Remotes.ParrySuccessAll.OnClientEvent) do
        if v.Function and getinfo(v.Function).name == "parrySuccessAll" then
            parrySuccessAllConnection = v
            playParryFunc = v.Function
            v:Disable()
        end
    end
end

local parrySuccessClientConnection
while task.wait() and not parrySuccessClientConnection do
    for i,v in getconnections(rs.Remotes.ParrySuccessClient.Event) do
        if v.Function and getinfo(v.Function).name == "parrySuccessAll" then
            parrySuccessClientConnection = v
            v:Disable()
        end
    end
end

getgenv().slashName = getSlashName(getgenv().swordFX)

local lastOtherParryTimestamp = 0
local clashConnections = {}

rs.Remotes.ParrySuccessAll.OnClientEvent:Connect(function(...)
    setthreadidentity(2)
    local args = {...}
    if tostring(args[4]) ~= plr.Name then
        lastOtherParryTimestamp = tick()
    elseif getgenv().skinChanger then
        args[1] = getgenv().slashName
        args[3] = getgenv().swordFX
    end
    return playParryFunc(unpack(args))
end)

table.insert(clashConnections, getconnections(rs.Remotes.ParrySuccessAll.OnClientEvent)[1])

getgenv().updateSword = function()
    getgenv().slashName = getSlashName(getgenv().swordFX)
    setSword()
end

task.spawn(function()
    while task.wait(1) do
        if getgenv().skinChanger then
            local char = plr.Character or plr.CharacterAdded:Wait()
            if plr:GetAttribute("CurrentlyEquippedSword") ~= getgenv().swordModel then
                setSword()
            end
            if char and (not char:FindFirstChild(getgenv().swordModel)) then
                setSword()
            end
            for _,v in (char and char:GetChildren()) or {} do
                if v:IsA("Model") and v.Name ~= getgenv().swordModel then
                    v:Destroy()
                end
                task.wait()
            end
        end
    end
end)

local Parries = 0

function create_animation(object, info, value)
    local animation = game:GetService('TweenService'):Create(object, info, value)

    animation:Play()
    task.wait(info.Time)

    Debris:AddItem(animation, 0)

    animation:Destroy()
    animation = nil
end

local Animation = {}
Animation.storage = {}

Animation.current = nil
Animation.track = nil

for _, v in pairs(game:GetService("ReplicatedStorage").Misc.Emotes:GetChildren()) do
    if v:IsA("Animation") and v:GetAttribute("EmoteName") then
        local Emote_Name = v:GetAttribute("EmoteName")
        Animation.storage[Emote_Name] = v
    end
end

local Emotes_Data = {}

for Object in pairs(Animation.storage) do
    table.insert(Emotes_Data, Object)
end

table.sort(Emotes_Data)

local Auto_Parry = {}

function Auto_Parry.Parry_Animation()
    local Parry_Animation = game:GetService("ReplicatedStorage").Shared.SwordAPI.Collection.Default:FindFirstChild('GrabParry')
    local Current_Sword = Player.Character:GetAttribute('CurrentlyEquippedSword')

    if not Current_Sword then
        return
    end

    if not Parry_Animation then
        return
    end

    local Sword_Data = game:GetService("ReplicatedStorage").Shared.ReplicatedInstances.Swords.GetSword:Invoke(Current_Sword)

    if not Sword_Data or not Sword_Data['AnimationType'] then
        return
    end

    for _, object in pairs(game:GetService('ReplicatedStorage').Shared.SwordAPI.Collection:GetChildren()) do
        if object.Name == Sword_Data['AnimationType'] then
            if object:FindFirstChild('GrabParry') or object:FindFirstChild('Grab') then
                local sword_animation_type = 'GrabParry'

                if object:FindFirstChild('Grab') then
                    sword_animation_type = 'Grab'
                end

                Parry_Animation = object[sword_animation_type]
            end
        end
    end

    Grab_Parry = Player.Character.Humanoid.Animator:LoadAnimation(Parry_Animation)
    Grab_Parry:Play()
end

function Auto_Parry.Play_Animation(v)
    local Animations = Animation.storage[v]

    if not Animations then
        return false
    end

    local Animator = Player.Character.Humanoid.Animator

    if Animation.track then
        Animation.track:Stop()
    end

    Animation.track = Animator:LoadAnimation(Animations)
    Animation.track:Play()

    Animation.current = v
end

function Auto_Parry.Get_Balls()
    local Balls = {}

    for _, Instance in pairs(workspace.Balls:GetChildren()) do
        if Instance:GetAttribute('realBall') then
            Instance.CanCollide = false
            table.insert(Balls, Instance)
        end
    end
    return Balls
end

function Auto_Parry.Get_Ball()
    for _, Instance in pairs(workspace.Balls:GetChildren()) do
        if Instance:GetAttribute('realBall') then
            Instance.CanCollide = false
            return Instance
        end
    end
end

function Auto_Parry.Lobby_Balls()
    for _, Instance in pairs(workspace.TrainingBalls:GetChildren()) do
        if Instance:GetAttribute("realBall") then
            return Instance
        end
    end
end


local Closest_Entity = nil

function Auto_Parry.Closest_Player()
    local Max_Distance = math.huge
    local Found_Entity = nil
    
    for _, Entity in pairs(workspace.Alive:GetChildren()) do
        if tostring(Entity) ~= tostring(Player) then
            if Entity.PrimaryPart then  -- Check if PrimaryPart exists
                local Distance = Player:DistanceFromCharacter(Entity.PrimaryPart.Position)
                if Distance < Max_Distance then
                    Max_Distance = Distance
                    Found_Entity = Entity
                end
            end
        end
    end
    
    Closest_Entity = Found_Entity
    return Found_Entity
end

function Auto_Parry:Get_Entity_Properties()
    Auto_Parry.Closest_Player()

    if not Closest_Entity then
        return false
    end

    local Entity_Velocity = Closest_Entity.PrimaryPart.Velocity
    local Entity_Direction = (Player.Character.PrimaryPart.Position - Closest_Entity.PrimaryPart.Position).Unit
    local Entity_Distance = (Player.Character.PrimaryPart.Position - Closest_Entity.PrimaryPart.Position).Magnitude

    return {
        Velocity = Entity_Velocity,
        Direction = Entity_Direction,
        Distance = Entity_Distance
    }
end

local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled


function Auto_Parry.Parry_Data(Parry_Type)
    Auto_Parry.Closest_Player()
    
    local Events = {}
    local Camera = workspace.CurrentCamera
    local Vector2_Mouse_Location
    
    if Last_Input == Enum.UserInputType.MouseButton1 or (Enum.UserInputType.MouseButton2 or Last_Input == Enum.UserInputType.Keyboard) then
        local Mouse_Location = UserInputService:GetMouseLocation()
        Vector2_Mouse_Location = {Mouse_Location.X, Mouse_Location.Y}
    else
        Vector2_Mouse_Location = {Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2}
    end
    
    if isMobile then
        Vector2_Mouse_Location = {Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2}
    end
    
    local Players_Screen_Positions = {}
    for _, v in pairs(workspace.Alive:GetChildren()) do
        if v ~= Player.Character then
            local worldPos = v.PrimaryPart.Position
            local screenPos, isOnScreen = Camera:WorldToScreenPoint(worldPos)
            
            if isOnScreen then
                Players_Screen_Positions[v] = Vector2.new(screenPos.X, screenPos.Y)
            end
            
            Events[tostring(v)] = screenPos
        end
    end
    
    if Parry_Type == 'Camera' then
        return {0, Camera.CFrame, Events, Vector2_Mouse_Location}
    end
    
    if Parry_Type == 'Backwards' then
        local Backwards_Direction = Camera.CFrame.LookVector * -10000
        Backwards_Direction = Vector3.new(Backwards_Direction.X, 0, Backwards_Direction.Z)
        return {0, CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + Backwards_Direction), Events, Vector2_Mouse_Location}
    end

    if Parry_Type == 'Straight' then
        local Aimed_Player = nil
        local Closest_Distance = math.huge
        local Mouse_Vector = Vector2.new(Vector2_Mouse_Location[1], Vector2_Mouse_Location[2])
        
        for _, v in pairs(workspace.Alive:GetChildren()) do
            if v ~= Player.Character then
                local worldPos = v.PrimaryPart.Position
                local screenPos, isOnScreen = Camera:WorldToScreenPoint(worldPos)
                
                if isOnScreen then
                    local playerScreenPos = Vector2.new(screenPos.X, screenPos.Y)
                    local distance = (Mouse_Vector - playerScreenPos).Magnitude
                    
                    if distance < Closest_Distance then
                        Closest_Distance = distance
                        Aimed_Player = v
                    end
                end
            end
        end
        
        if Aimed_Player then
            return {0, CFrame.new(Player.Character.PrimaryPart.Position, Aimed_Player.PrimaryPart.Position), Events, Vector2_Mouse_Location}
        else
            return {0, CFrame.new(Player.Character.PrimaryPart.Position, Closest_Entity.PrimaryPart.Position), Events, Vector2_Mouse_Location}
        end
    end
    
    if Parry_Type == 'Random' then
        return {0, CFrame.new(Camera.CFrame.Position, Vector3.new(math.random(-4000, 4000), math.random(-4000, 4000), math.random(-4000, 4000))), Events, Vector2_Mouse_Location}
    end
    
    if Parry_Type == 'High' then
        local High_Direction = Camera.CFrame.UpVector * 10000
        return {0, CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + High_Direction), Events, Vector2_Mouse_Location}
    end
    
    if Parry_Type == 'Left' then
        local Left_Direction = Camera.CFrame.RightVector * 10000
        return {0, CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position - Left_Direction), Events, Vector2_Mouse_Location}
    end
    
    if Parry_Type == 'Right' then
        local Right_Direction = Camera.CFrame.RightVector * 10000
        return {0, CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + Right_Direction), Events, Vector2_Mouse_Location}
    end

    if Parry_Type == 'RandomTarget' then
        local candidates = {}
        for _, v in pairs(workspace.Alive:GetChildren()) do
            if v ~= Player.Character and v.PrimaryPart then
                local screenPos, isOnScreen = Camera:WorldToScreenPoint(v.PrimaryPart.Position)
                if isOnScreen then
                    table.insert(candidates, {
                        character = v,
                        screenXY  = { screenPos.X, screenPos.Y }
                    })
                end
            end
        end
        if #candidates > 0 then
            local pick = candidates[ math.random(1, #candidates) ]
            local lookCFrame = CFrame.new(Player.Character.PrimaryPart.Position, pick.character.PrimaryPart.Position)
            return {0, lookCFrame, Events, pick.screenXY}
        else
            return {0, Camera.CFrame, Events, { Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2 }}
        end
    end
    
    return Parry_Type
end

function Auto_Parry.Parry(Parry_Type)
    local Parry_Data = Auto_Parry.Parry_Data(Parry_Type)

    if not firstParryFired then
        performFirstPress(firstParryType)
        firstParryFired = true
    else
        SendParry(Parry_Data)
    end

    if Parries > 7 then
        return false
    end

    Parries += 1

    task.delay(0.5, function()
        if Parries > 0 then
            Parries -= 1
        end
    end)
end

local Lerp_Radians = 0
local Last_Warping = tick()

function Auto_Parry.Linear_Interpolation(a, b, time_volume)
    return a + (b - a) * time_volume
end

local Previous_Velocity = {}
local Curving = tick()

local Runtime = workspace.Runtime

function Auto_Parry.Is_Curved()
    local Ball = Auto_Parry.Get_Ball()

    if not Ball then
        return false
    end

    local Zoomies = Ball:FindFirstChild('zoomies')
    if not Zoomies then
        return false
    end

    local Ping = game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue()
    local Velocity = Zoomies.VectorVelocity
    local Ball_Direction = Velocity.Unit

    local playerPos = Player.Character.PrimaryPart.Position
    local ballPos = Ball.Position
    local Direction = (playerPos - ballPos).Unit
    local Dot = Direction:Dot(Ball_Direction)
    local Speed = Velocity.Magnitude

    local Speed_Threshold = math.min(Speed/100, 40)
    local Angle_Threshold = 40 * math.max(Dot, 0)
    local Distance = (playerPos - ballPos).Magnitude
    local Reach_Time = Distance / Speed - (Ping / 1000)
    
    local Ball_Distance_Threshold = 15 - math.min(Distance/1000, 15) + Speed_Threshold

    table.insert(Previous_Velocity, Velocity)
    if #Previous_Velocity > 4 then
        table.remove(Previous_Velocity, 1)
    end

    if Ball:FindFirstChild('AeroDynamicSlashVFX') then
        Debris:AddItem(Ball.AeroDynamicSlashVFX, 0)
        Tornado_Time = tick()
    end

    if Runtime:FindFirstChild('Tornado') then
        if (tick() - Tornado_Time) < ((Runtime.Tornado:GetAttribute("TornadoTime") or 1) + 0.314159) then
            return true
        end
    end

    local Enough_Speed = Speed > 160
    if Enough_Speed and Reach_Time > Ping / 10 then
        if Speed < 300 then
            Ball_Distance_Threshold = math.max(Ball_Distance_Threshold - 15, 15)
        elseif Speed > 300 and Speed < 600 then
            Ball_Distance_Threshold = math.max(Ball_Distance_Threshold - 16, 16)
        elseif Speed > 600 and Speed < 1000 then
            Ball_Distance_Threshold = math.max(Ball_Distance_Threshold - 17, 17)
        elseif Speed > 1000 and Speed < 1500 then
            Ball_Distance_Threshold = math.max(Ball_Distance_Threshold - 19, 19)
        elseif Speed > 1500 then
            Ball_Distance_Threshold = math.max(Ball_Distance_Threshold - 20, 20)
        end
    end

    if Distance < Ball_Distance_Threshold then
        return false
    end

    if Speed < 300 then
        if (tick() - Curving) < (Reach_Time / 1.2) then
            return true
        end
    elseif Speed >= 300 and Speed < 450 then
        if (tick() - Curving) < (Reach_Time / 1.21) then
            return true
        end
    elseif Speed > 450 and Speed < 600 then
        if (tick() - Curving) < (Reach_Time / 1.335) then
            return true
        end
    elseif Speed > 600 then
        if (tick() - Curving) < (Reach_Time / 1.5) then
            return true
        end
    end
    
    local Dot_Threshold = (0.5 - Ping / 1000)
    local Direction_Difference = (Ball_Direction - Velocity.Unit)
    local Direction_Similarity = Direction:Dot(Direction_Difference.Unit)
    local Dot_Difference = Dot - Direction_Similarity

    if Dot_Difference < Dot_Threshold then
        return true
    end

    local Clamped_Dot = math.clamp(Dot, -1, 1)
    local Radians = math.deg(math.asin(Clamped_Dot))

    Lerp_Radians = Auto_Parry.Linear_Interpolation(Lerp_Radians, Radians, 0.8)
    if Speed < 300 then
        if Lerp_Radians < 0.02 then
            Last_Warping = tick()
        end
        if (tick() - Last_Warping) < (Reach_Time / 1.19) then
            return true
        end
    else
        if Lerp_Radians < 0.018 then
            Last_Warping = tick()
        end
        if (tick() - Last_Warping) < (Reach_Time / 1.5) then
            return true
        end
    end

    if #Previous_Velocity == 4 then
        local Intended_Direction_Difference = (Ball_Direction - Previous_Velocity[1].Unit).Unit
        local Intended_Dot = Direction:Dot(Intended_Direction_Difference)
        local Intended_Dot_Difference = Dot - Intended_Dot

        local Intended_Direction_Difference2 = (Ball_Direction - Previous_Velocity[2].Unit).Unit
        local Intended_Dot2 = Direction:Dot(Intended_Direction_Difference2)
        local Intended_Dot_Difference2 = Dot - Intended_Dot2

        if Intended_Dot_Difference < Dot_Threshold or Intended_Dot_Difference2 < Dot_Threshold then
            return true
        end
    end

    local backwardsCurveDetected = false
    local backwardsAngleThreshold = 85

    local horizDirection = Vector3.new(playerPos.X - ballPos.X, 0, playerPos.Z - ballPos.Z)
    if horizDirection.Magnitude > 0 then
        horizDirection = horizDirection.Unit
    end

    local awayFromPlayer = -horizDirection

    local horizBallDir = Vector3.new(Ball_Direction.X, 0, Ball_Direction.Z)
    if horizBallDir.Magnitude > 0 then
        horizBallDir = horizBallDir.Unit
        local backwardsAngle = math.deg(math.acos(math.clamp(awayFromPlayer:Dot(horizBallDir), -1, 1)))
        if backwardsAngle < backwardsAngleThreshold then
            backwardsCurveDetected = true
        end
    end

    return (Dot < Dot_Threshold) or backwardsCurveDetected
end

function Auto_Parry:Get_Ball_Properties()
    local Ball = Auto_Parry.Get_Ball()

    if not Ball or not Ball.PrimaryPart then
        return {
            Velocity = Vector3.zero,
            Direction = Vector3.new(0, 0, -1),
            Distance = math.huge,
            Dot = -1
        }
    end

    local Ball_Velocity = Vector3.zero
    local Ball_Origin = Ball

    local Ball_Direction = (Player.Character.PrimaryPart.Position - Ball_Origin.Position).Unit
    local Ball_Distance = (Player.Character.PrimaryPart.Position - Ball.Position).Magnitude
    local Ball_Dot = Ball_Direction:Dot(Ball_Velocity.Unit)

    return {
        Velocity = Ball_Velocity,
        Direction = Ball_Direction,
        Distance = Ball_Distance,
        Dot = Ball_Dot
    }
end

function Auto_Parry.Spam_Service(self)
    local Ball = Auto_Parry.Get_Ball()

    local Entity = Auto_Parry.Closest_Player()

    if not Ball then
        return false
    end

    if not Entity or not Entity.PrimaryPart then
        return false
    end

    local Spam_Accuracy = 0

    local Velocity = Ball.AssemblyLinearVelocity
    local Speed = Velocity.Magnitude

    local Direction = (Player.Character.PrimaryPart.Position - Ball.Position).Unit
    local Dot = Direction:Dot(Velocity.Unit)

    local Target_Position = Entity.PrimaryPart.Position
    local Target_Distance = Player:DistanceFromCharacter(Target_Position)

    local Maximum_Spam_Distance = self.Ping + math.min(Speed / 6, 95)

    if self.Entity_Properties.Distance > Maximum_Spam_Distance then
        return Spam_Accuracy
    end

    if self.Ball_Properties.Distance > Maximum_Spam_Distance then
        return Spam_Accuracy
    end

    if Target_Distance > Maximum_Spam_Distance then
        return Spam_Accuracy
    end

    local Maximum_Speed = 5 - math.min(Speed / 5, 5)
    local Maximum_Dot = math.clamp(Dot, -1, 0) * Maximum_Speed

    Spam_Accuracy = Maximum_Spam_Distance - Maximum_Dot

    return Spam_Accuracy
end

local Connections_Manager = {}
local Selected_Parry_Type = nil

local Parried = false
local Last_Parry = 0


local deathshit = false

ReplicatedStorage.Remotes.DeathBall.OnClientEvent:Connect(function(c, d)
    if d then
        deathshit = true
    else
        deathshit = false
    end
end)

local Infinity = false

ReplicatedStorage.Remotes.InfinityBall.OnClientEvent:Connect(function(a, b)
    if b then
        Infinity = true
    else
        Infinity = false
    end
end)


local timehole = false

ReplicatedStorage.Remotes.TimeHoleHoldBall.OnClientEvent:Connect(function(e, f)
    if f then
        timehole = true
    else
        timehole = false
    end
end)


local AutoParry = true

local Balls = workspace:WaitForChild('Balls')
local CurrentBall = nil
local InputTask = nil
local Cooldown = 0.02
local RunTime = workspace:FindFirstChild("Runtime")



local function GetBall()
    for _, Ball in ipairs(Balls:GetChildren()) do
        if Ball:FindFirstChild("ff") then
            return Ball
        end
    end
    return nil
end

local function SpamInput(Label)
    if InputTask then return end
    InputTask = task.spawn(function()
        while AutoParry do
            Auto_Parry.Parry(Selected_Parry_Type)
            task.wait(Cooldown)
        end
        InputTask = nil
    end)
end

Balls.ChildAdded:Connect(function(Value)
    Value.ChildAdded:Connect(function(Child)
        if getgenv().SlashOfFuryDetection and Child.Name == 'ComboCounter' then
            local Sof_Label = Child:FindFirstChildOfClass('TextLabel')

            if Sof_Label then
                repeat
                    local Slashes_Counter = tonumber(Sof_Label.Text)

                    if Slashes_Counter and Slashes_Counter < 32 then
                        Auto_Parry.Parry(Selected_Parry_Type)
                    end

                    task.wait()

                until not Sof_Label.Parent or not Sof_Label
            end
        end
    end)
end)


local Players = game:GetService("Players")
local player10239123 = Players.LocalPlayer
local RunService = game:GetService("RunService")

if not player10239123 then return end

RunTime.ChildAdded:Connect(function(Object)
    local Name = Object.Name
    if getgenv().PhantomV2Detection then
        if Name == "maxTransmission" or Name == "transmissionpart" then
            local Weld = Object:FindFirstChildWhichIsA("WeldConstraint")
            if Weld then
                local Character = player10239123.Character or player10239123.CharacterAdded:Wait()
                if Character and Weld.Part1 == Character.HumanoidRootPart then
                    CurrentBall = GetBall()
                    Weld:Destroy()
    
                    if CurrentBall then
                        local FocusConnection
                        FocusConnection = RunService.RenderStepped:Connect(function()
                            local Highlighted = CurrentBall:GetAttribute("highlighted")
    
                            if Highlighted == true then
                                game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 36
    
                                local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
                                if HumanoidRootPart then
                                    local PlayerPosition = HumanoidRootPart.Position
                                    local BallPosition = CurrentBall.Position
                                    local PlayerToBall = (BallPosition - PlayerPosition).Unit
    
                                    game.Players.LocalPlayer.Character.Humanoid:Move(PlayerToBall, false)
                                end
    
                            elseif Highlighted == false then
                                FocusConnection:Disconnect()
    
                                game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 10
                                game.Players.LocalPlayer.Character.Humanoid:Move(Vector3.new(0, 0, 0), false)
    
                                task.delay(3, function()
                                    game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 36
                                end)
    
                                CurrentBall = nil
                            end
                        end)
    
                        task.delay(3, function()
                            if FocusConnection and FocusConnection.Connected then
                                FocusConnection:Disconnect()
    
                                game.Players.LocalPlayer.Character.Humanoid:Move(Vector3.new(0, 0, 0), false)
                                game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 36
                                CurrentBall = nil
                            end
                        end)
                    end
                end
            end
        end
    end
end)

local player11 = game.Players.LocalPlayer
local PlayerGui = player11:WaitForChild("PlayerGui")
local playerGui = player11:WaitForChild("PlayerGui")
local Hotbar = PlayerGui:WaitForChild("Hotbar")


local ParryCD = playerGui.Hotbar.Block.UIGradient
local AbilityCD = playerGui.Hotbar.Ability.UIGradient

local function isCooldownInEffect1(uigradient)
    return uigradient.Offset.Y < 0.4
end

local function isCooldownInEffect2(uigradient)
    return uigradient.Offset.Y == 0.5
end

local function cooldownProtection()
    if isCooldownInEffect1(ParryCD) then
        game:GetService("ReplicatedStorage").Remotes.AbilityButtonPress:Fire()
        return true
    end
    return false
end

local function AutoAbility()
    if isCooldownInEffect2(AbilityCD) then
        if Player.Character.Abilities["Raging Deflection"].Enabled or Player.Character.Abilities["Rapture"].Enabled or Player.Character.Abilities["Calming Deflection"].Enabled or Player.Character.Abilities["Aerodynamic Slash"].Enabled or Player.Character.Abilities["Fracture"].Enabled or Player.Character.Abilities["Death Slash"].Enabled then
            Parried = true
            game:GetService("ReplicatedStorage").Remotes.AbilityButtonPress:Fire()
            task.wait(2.432)
            game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("DeathSlashShootActivation"):FireServer(true)
            return true
        end
    end
    return false
end

do
    local module = rage:create_module({
        title = 'Auto Parry',
        flag = 'Auto_Parry',
        description = 'Automatically parries ball',
        section = 'left',
        callback = function(value: boolean)
            if getgenv().AutoParryNotify then
                if value then
                    Library.SendNotification({
                        title = "Module Notification",
                        text = "Auto Parry has been turned ON",
                        duration = 3
                    })
                else
                    Library.SendNotification({
                        title = "Module Notification",
                        text = "Auto Parry has been turned OFF",
                        duration = 3
                    })
                end
            end
            if value then
                Connections_Manager['Auto Parry'] = RunService.PreSimulation:Connect(function()
                    local One_Ball = Auto_Parry.Get_Ball()
                    local Balls = Auto_Parry.Get_Balls()

                    for _, Ball in pairs(Balls) do

                        if not Ball then
                            return
                        end

                        local Zoomies = Ball:FindFirstChild('zoomies')
                        if not Zoomies then
                            return
                        end

                        Ball:GetAttributeChangedSignal('target'):Once(function()
                            Parried = false
                        end)

                        if Parried then
                            return
                        end

                        local Ball_Target = Ball:GetAttribute('target')
                        local One_Target = One_Ball:GetAttribute('target')

                        local Velocity = Zoomies.VectorVelocity

                        local Distance = (Player.Character.PrimaryPart.Position - Ball.Position).Magnitude

                        local Ping = game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue() / 10

                        local Ping_Threshold = math.clamp(Ping / 10, 5, 17)

                        local Speed = Velocity.Magnitude

                        local cappedSpeedDiff = math.min(math.max(Speed - 9.5, 0), 650)
                        local speed_divisor_base = 2.4 + cappedSpeedDiff * 0.002

                        local effectiveMultiplier = Speed_Divisor_Multiplier
                        if getgenv().RandomParryAccuracyEnabled then
                            if Speed < 200 then
                                effectiveMultiplier = 0.7 + (math.random(40, 100) - 1) * (0.35 / 99)
                            else
                                effectiveMultiplier = 0.7 + (math.random(1, 100) - 1) * (0.35 / 99)
                            end
                        end

                        local speed_divisor = speed_divisor_base * effectiveMultiplier
                        local Parry_Accuracy = Ping_Threshold + math.max(Speed / speed_divisor, 9.5)

                        local Curved = Auto_Parry.Is_Curved()

                        if Ball:FindFirstChild('AeroDynamicSlashVFX') then
                            Debris:AddItem(Ball.AeroDynamicSlashVFX, 0)
                            Tornado_Time = tick()
                        end

                        if Runtime:FindFirstChild('Tornado') then
                            if (tick() - Tornado_Time) < (Runtime.Tornado:GetAttribute("TornadoTime") or 1) + 0.314159 then
                            return
                            end
                        end

                        if One_Target == tostring(Player) and Curved then
                            return
                        end

                        if Ball:FindFirstChild("ComboCounter") then
                            return
                        end

                        local Singularity_Cape = Player.Character.PrimaryPart:FindFirstChild('SingularityCape')
                        if Singularity_Cape then
                            return
                        end 

                        if getgenv().InfinityDetection and Infinity then
                            return
                        end

                        if getgenv().DeathSlashDetection and deathshit then
                            return
                        end

                        if getgenv().TimeHoleDetection and timehole then
                            return
                        end

                        if Ball_Target == tostring(Player) and Distance <= Parry_Accuracy then
                            if getgenv().AutoAbility and AutoAbility() then
                                return
                            end
                        end

                        if Ball_Target == tostring(Player) and Distance <= Parry_Accuracy then
                            if getgenv().CooldownProtection and cooldownProtection() then
                                return
                            end

                            local Parry_Time = os.clock()
                            local Time_View = Parry_Time - (Last_Parry)
                            if Time_View > 0.5 then
                                Auto_Parry.Parry_Animation()
                            end

                            if getgenv().AutoParryKeypress then
                                VirtualInputService:SendKeyEvent(true, Enum.KeyCode.F, false, nil)
                            else
                                Auto_Parry.Parry(Selected_Parry_Type)
                            end

                            Last_Parry = Parry_Time
                            Parried = true
                        end
                        local Last_Parrys = tick()
                        repeat
                            RunService.PreSimulation:Wait()
                        until (tick() - Last_Parrys) >= 1 or not Parried
                        Parried = false
                    end
                end)
            else
                if Connections_Manager['Auto Parry'] then
                    Connections_Manager['Auto Parry']:Disconnect()
                    Connections_Manager['Auto Parry'] = nil
                end
            end
        end
    })

    local dropdown3 = module:create_dropdown({
        title = 'First Parry Type',
        flag = 'First_Parry_Type',

        options = {
            'F_Key',
            'Left_Click',
            'Navigation'
        },

        multi_dropdown = false,
        maximum_options = 3,
        callback = function(value)
            firstParryType = value
        end
    })

    local parryTypeMap = {
        ["Camera"] = "Camera",
        ["Random"] = "Random",
        ["Backwards"] = "Backwards",
        ["Straight"] = "Straight",
        ["High"] = "High",
        ["Left"] = "Left",
        ["Right"] = "Right",
        ["Random Target"] = "RandomTarget"
    }

    local dropdown = module:create_dropdown({
        title = 'Parry Type',
        flag = 'Parry_Type',

        options = {
            'Camera',
            'Random',
            'Backwards',
            'Straight',
            'High',
            'Left',
            'Right',
            'Random Target'
        },

        multi_dropdown = false,
        maximum_options = 8,

        callback = function(value: string)
            Selected_Parry_Type = parryTypeMap[value] or value
        end
    })



   

    module:create_slider({
        title = 'Parry Accuracy',
        flag = 'Parry_Accuracy',

        maximum_value = 100,
        minimum_value = 1,
        value = 100,

        round_number = true,

        callback = function(value: boolean)
            Speed_Divisor_Multiplier = 0.7 + (value - 1) * (0.35 / 99)
        end
    })

    module:create_divider({
    })

    

    module:create_checkbox({
        title = "Infinity Detection",
        flag = "Infinity_Detection",
        callback = function(value: boolean)
            if value then
                getgenv().InfinityDetection = value
            end
        end
    })

 

   

    

    module:create_checkbox({
        title = "Anti Phantom",
        flag = "Anti_Phantom",
        callback = function(value: boolean)
            getgenv().PhantomV2Detection = value
        end
    })

   



    module:create_checkbox({
        title = "Keypress",
        flag = "Auto_Parry_Keypress",
        callback = function(value: boolean)
            getgenv().AutoParryKeypress = value
        end
    })


   

    local SpamParry = rage:create_module({
        title = 'Auto Spam Parry',
        flag = 'Auto_Spam_Parry',
        description = 'Automatically spam parries ball',
        section = 'right',
        callback = function(value: boolean)
            if getgenv().AutoSpamNotify then
                if value then
                    Library.SendNotification({
                        title = "Module Notification",
                        text = "Auto Spam Parry turned ON",
                        duration = 3
                    })
                else
                    Library.SendNotification({
                        
                        text = "Auto Spam Parry turned OFF",
                        duration = 3
                    })
                end
            end

            if value then
                Connections_Manager['Auto Spam'] = RunService.PreSimulation:Connect(function()
                    local Ball = Auto_Parry.Get_Ball()

                    if not Ball then
                        return
                    end

                    local Zoomies = Ball:FindFirstChild('zoomies')

                    if not Zoomies then
                        return
                    end

                    Auto_Parry.Closest_Player()

                    local Ping = game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue()

                    local Ping_Threshold = math.clamp(Ping / 10, 1, 16)

                    local Ball_Target = Ball:GetAttribute('target')

                    local Ball_Properties = Auto_Parry:Get_Ball_Properties()
                    local Entity_Properties = Auto_Parry:Get_Entity_Properties()

                    local Spam_Accuracy = Auto_Parry.Spam_Service({
                        Ball_Properties = Ball_Properties,
                        Entity_Properties = Entity_Properties,
                        Ping = Ping_Threshold
                    })

                    local Target_Position = Closest_Entity.PrimaryPart.Position
                    local Target_Distance = Player:DistanceFromCharacter(Target_Position)

                    local Direction = (Player.Character.PrimaryPart.Position - Ball.Position).Unit
                    local Ball_Direction = Zoomies.VectorVelocity.Unit

                    local Dot = Direction:Dot(Ball_Direction)

                    local Distance = Player:DistanceFromCharacter(Ball.Position)

                    if not Ball_Target then
                        return
                    end

                    if Target_Distance > Spam_Accuracy or Distance > Spam_Accuracy then
                        return
                    end
                    
                    local Pulsed = Player.Character:GetAttribute('Pulsed')

                    if Pulsed then
                        return
                    end

                    if Ball_Target == tostring(Player) and Target_Distance > 30 and Distance > 30 then
                        return
                    end

                    local threshold = ParryThreshold

                    if Distance <= Spam_Accuracy and Parries > threshold then
                        if getgenv().SpamParryKeypress then
                            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game) 
                        else
                            Auto_Parry.Parry(Selected_Parry_Type)
                        end
                    end
                end)
            else
                if Connections_Manager['Auto Spam'] then
                    Connections_Manager['Auto Spam']:Disconnect()
                    Connections_Manager['Auto Spam'] = nil
                end
            end
        end
    })

    local dropdown2 = SpamParry:create_dropdown({
        title = 'Parry Type',
        flag = 'Spam_Parry_Type',

        options = {
            'Legit',
            'Blatant'
        },

        multi_dropdown = false,
        maximum_options = 2,

        callback = function(value: string)
        end
    })

    SpamParry:create_slider({
        title = "Parry Threshold",
        flag = "Parry_Threshold",
        maximum_value = 3,
        minimum_value = 1,
        value = 2.5,
        round_number = false,
        callback = function(value: number)
            ParryThreshold = value
        end
    })

    SpamParry:create_divider({
    })

    if not isMobile then
        local AnimationFix = SpamParry:create_checkbox({
            title = "Animation Fix",
            flag = "AnimationFix",
            callback = function(value: boolean)
                if value then
                    Connections_Manager['Animation Fix'] = RunService.PreSimulation:Connect(function()
                        local Ball = Auto_Parry.Get_Ball()
    
                        if not Ball then
                            return
                        end
    
                        local Zoomies = Ball:FindFirstChild('zoomies')
    
                        if not Zoomies then
                            return
                        end
    
                        Auto_Parry.Closest_Player()
    
                        local Ping = game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue()
    
                        local Ping_Threshold = math.clamp(Ping / 10, 10, 16)
    
                        local Ball_Target = Ball:GetAttribute('target')
    
                        local Ball_Properties = Auto_Parry:Get_Ball_Properties()
                        local Entity_Properties = Auto_Parry:Get_Entity_Properties()
    
                        local Spam_Accuracy = Auto_Parry.Spam_Service({
                            Ball_Properties = Ball_Properties,
                            Entity_Properties = Entity_Properties,
                            Ping = Ping_Threshold
                        })
    
                        local Target_Position = Closest_Entity.PrimaryPart.Position
                        local Target_Distance = Player:DistanceFromCharacter(Target_Position)
    
                        local Direction = (Player.Character.PrimaryPart.Position - Ball.Position).Unit
                        local Ball_Direction = Zoomies.VectorVelocity.Unit
    
                        local Dot = Direction:Dot(Ball_Direction)
    
                        local Distance = Player:DistanceFromCharacter(Ball.Position)
    
                        if not Ball_Target then
                            return
                        end
    
                        if Target_Distance > Spam_Accuracy or Distance > Spam_Accuracy then
                            return
                        end
                        
                        local Pulsed = Player.Character:GetAttribute('Pulsed')
    
                        if Pulsed then
                            return
                        end
    
                        if Ball_Target == tostring(Player) and Target_Distance > 30 and Distance > 30 then
                            return
                        end
    
                        local threshold = ParryThreshold
    
                        if Distance <= Spam_Accuracy and Parries > threshold then
                            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game) 
                        end
                    end)
                else
                    if Connections_Manager['Animation Fix'] then
                        Connections_Manager['Animation Fix']:Disconnect()
                        Connections_Manager['Animation Fix'] = nil
                    end
                end
            end
        })

        AnimationFix:change_state(true)
    end

    SpamParry:create_checkbox({
        title = "Keypress",
        flag = "Auto_Spam_Parry_Keypress",
        callback = function(value: boolean)
            getgenv().SpamParryKeypress = value
        end
    })

    SpamParry:create_checkbox({
        title = "Notify",
        flag = "Auto_Spam_Parry_Notify",
        callback = function(value: boolean)
            getgenv().AutoSpamNotify = value
        end
    })

    local ManualSpam = rage:create_module({
        title = 'Manual Spam Parry',
        flag = 'Manual_Spam_Parry',
        description = 'Manually Spams Parry',
        section = 'right',
        callback = function(value: boolean)
            if getgenv().ManualSpamNotify then
                if value then
                    Library.SendNotification({
                        title = "Module Notification",
                        text = "Manual Spam Parry turned ON",
                        duration = 3
                    })
                else
                    Library.SendNotification({
                        title = "Module Notification",
                        text = "Manual Spam Parry turned OFF",
                        duration = 3
                    })
                end
            end
            if value then
                Connections_Manager['Manual Spam'] = RunService.PreSimulation:Connect(function()
                    if getgenv().spamui then
                        return
                    end

                    if getgenv().ManualSpamKeypress then
                        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game) 
                    else
                        Auto_Parry.Parry(Selected_Parry_Type)
                    end

                end)
            else
                if Connections_Manager['Manual Spam'] then
                    Connections_Manager['Manual Spam']:Disconnect()
                    Connections_Manager['Manual Spam'] = nil
                end
            end
        end
    })
    
    ManualSpam:change_state(false)

    if isMobile then
        ManualSpam:create_checkbox({
            title = "UI",
            flag = "Manual_Spam_UI",
            callback = function(value: boolean)
                getgenv().spamui = value
        
                if value then
                    local gui = Instance.new("ScreenGui")
                    gui.Name = "ManualSpamUI"
                    gui.ResetOnSpawn = false
                    gui.Parent = game.CoreGui
        
                    local frame = Instance.new("Frame")
                    frame.Name = "MainFrame"
                    frame.Position = UDim2.new(0, 20, 0, 20)
                    frame.Size = UDim2.new(0, 200, 0, 100)
                    frame.BackgroundColor3 = Color3.fromRGB(10, 10, 50)
                    frame.BackgroundTransparency = 0.3
                    frame.BorderSizePixel = 0
                    frame.Active = true
                    frame.Draggable = true
                    frame.Parent = gui
        
                    local uiCorner = Instance.new("UICorner")
                    uiCorner.CornerRadius = UDim.new(0, 12)
                    uiCorner.Parent = frame
        
                    local uiStroke = Instance.new("UIStroke")
                    uiStroke.Thickness = 2
                    uiStroke.Color = Color3.new(0, 0, 0)
                    uiStroke.Parent = frame
        
                    local button = Instance.new("TextButton")
                    button.Name = "ClashModeButton"
                    button.Text = "Clash Mode"
                    button.Size = UDim2.new(0, 160, 0, 40)
                    button.Position = UDim2.new(0.5, -80, 0.5, -20)
                    button.BackgroundTransparency = 1
                    button.BorderSizePixel = 0
                    button.Font = Enum.Font.GothamSemibold
                    button.TextColor3 = Color3.new(1, 1, 1)
                    button.TextSize = 22
                    button.Parent = frame
        
                    local activated = false
        
                    local function toggle()
                        activated = not activated
                        button.Text = activated and "Stop" or "Clash Mode"
                        if activated then
                            Connections_Manager['Manual Spam UI'] = game:GetService("RunService").Heartbeat:Connect(function()
                                Auto_Parry.Parry(Selected_Parry_Type)
                            end)
                        else
                            if Connections_Manager['Manual Spam UI'] then
                                Connections_Manager['Manual Spam UI']:Disconnect()
                                Connections_Manager['Manual Spam UI'] = nil
                            end
                        end
                    end
        
                    button.MouseButton1Click:Connect(toggle)
                else
                    if game.CoreGui:FindFirstChild("ManualSpamUI") then
                        game.CoreGui:FindFirstChild("ManualSpamUI"):Destroy()
                    end
        
                    if Connections_Manager['Manual Spam UI'] then
                        Connections_Manager['Manual Spam UI']:Disconnect()
                        Connections_Manager['Manual Spam UI'] = nil
                    end
                end
            end
        })
    end
    
    ManualSpam:create_checkbox({
        title = "Keypress",
        flag = "Manual_Spam_Keypress",
        callback = function(value: boolean)
            getgenv().ManualSpamKeypress = value
        end
    })
    
    ManualSpam:create_checkbox({
        title = "Notify",
        flag = "Manual_Spam_Parry_Notify",
        callback = function(value: boolean)
            getgenv().ManualSpamNotify = value
        end
    })

   
     
    
    
    local plr = game.Players.LocalPlayer
    local cam = workspace.CurrentCamera
    local hit = game.ReplicatedStorage.Remotes.ParryAttempt
    
    getgenv().originalCameraSubject = nil
    
    function getspeed(ball)
        if ball then
            if ball:FindFirstChild("zoomies") and ball.zoomies.VectorVelocity then
                return ball.zoomies.VectorVelocity
            end
        else
            for _, b in pairs(workspace.Balls:GetChildren()) do
                if b:FindFirstChild("zoomies") and b.zoomies.VectorVelocity then
                    return b.zoomies.VectorVelocity
                end
            end
        end
        return Vector3.new(0,0,0)
    end
    
    function restoreCamera()
        local character = plr.Character
        if character and character:FindFirstChild("Humanoid") then
            cam.CameraSubject = character.Humanoid
        end
    end
    
    
    

    
                
                
    
    function handleBallTargetChange(ball)
        local target = ball:GetAttribute("target")
        local c = plr.Character
        if not c then return end
        local hrp = c:FindFirstChild("HumanoidRootPart")
        local hum = c:FindFirstChild("Humanoid")
        if not hrp or not hum then return end
        
        if target == plr.Name then
            if not getgenv().originalCFrame then
                getgenv().originalCFrame = hrp.CFrame
            end
            
            local speed = getspeed(ball)
            if speed.Magnitude > 100 then
                task.wait(0.2)
            end
            
            -- Teleport to ball
            local offset = Vector3.new(5, 5, 5)
            hum.PlatformStand = true
            hrp:PivotTo(ball.CFrame + offset)
            task.wait(0.1)
            hum.PlatformStand = false
            
            cam.CameraSubject = ball
        else
            if getgenv().originalCFrame then
                hum.PlatformStand = true
                hrp:PivotTo(getgenv().originalCFrame)
                task.wait(0.1)
                hum.PlatformStand = false
                getgenv().originalCFrame = nil
                
                restoreCamera()
            end
        end
    end

   
    
    


    
    

    local CameraToggle = player:create_module({
        title = 'Fov',
        flag = 'Fov',
    
        description = 'Changes Camera POV',
        section = 'left',
    
        callback = function(value)
            getgenv().CameraEnabled = value
            local Camera = game:GetService("Workspace").CurrentCamera
    
            if value then
                getgenv().CameraFOV = getgenv().CameraFOV or 70
                Camera.FieldOfView = getgenv().CameraFOV
                
                if not getgenv().FOVLoop then
                    getgenv().FOVLoop = game:GetService("RunService").RenderStepped:Connect(function()
                        if getgenv().CameraEnabled then
                            Camera.FieldOfView = getgenv().CameraFOV
                        end
                    end)
                end
            else
                Camera.FieldOfView = 70
                
                if getgenv().FOVLoop then
                    getgenv().FOVLoop:Disconnect()
                    getgenv().FOVLoop = nil
                end
            end
        end
    })
    
    CameraToggle:create_slider({
        title = 'Camera FOV',
        flag = 'Camera_FOV',
    
        maximum_value = 120,
        minimum_value = 50,
        value = 70,
    
        round_number = true,
    
        callback = function(value)
            getgenv().CameraFOV = value
            if getgenv().CameraEnabled then
                game:GetService("Workspace").CurrentCamera.FieldOfView = value
            end
        end
    })
    
    local Animations = player:create_module({
        title = 'Emotes',
        flag = 'Emotes',
    
        description = 'Custom Emotes',
        section = 'right',
    
        callback = function(value)
            getgenv().Animations = value
    
            if value then
                Connections_Manager['Animations'] = RunService.Heartbeat:Connect(function()
                    if not Player.Character or not Player.Character.PrimaryPart then
                        return
                    end
    
                    local Speed = Player.Character.PrimaryPart.AssemblyLinearVelocity.Magnitude
    
                    if Speed > 30 then
                        if Animation.track then
                            Animation.track:Stop()
                            Animation.track:Destroy()
                            Animation.track = nil
                        end
                    else
                        if not Animation.track and Animation.current then
                            Auto_Parry.Play_Animation(Animation.current)
                        end
                    end
                end)
            else
                if Animation.track then
                    Animation.track:Stop()
                    Animation.track:Destroy()
                    Animation.track = nil
                end
    
                if Connections_Manager['Animations'] then
                    Connections_Manager['Animations']:Disconnect()
                    Connections_Manager['Animations'] = nil
                end
            end
        end
    })
   
    local selected_animation = Emotes_Data[1]
    
    local AnimationChoice = Animations:create_dropdown({
        title = 'Animation Type',
        flag = 'Selected_Animation',
    
        options = Emotes_Data,
    
        multi_dropdown = false,
        maximum_options = #Emotes_Data,
    
        callback = function(value)
            selected_animation = value
    
            if getgenv().Animations then
                Auto_Parry.Play_Animation(value)
            end
        end
    })
    
    AnimationChoice:update(selected_animation)

    _G.PlayerCosmeticsCleanup = {}
    
    local PlayerCosmetics = player:create_module({
        title = "Player Cosmetics",
        flag = "Player_Cosmetics",
        description = "Apply headless and korblox",
        section = "left",
        callback = function(value: boolean)
            local players = game:GetService("Players")
            local lp = players.LocalPlayer
    
            local function applyKorblox(character)
                local rightLeg = character:FindFirstChild("RightLeg") or character:FindFirstChild("Right Leg")
                if not rightLeg then
                    warn("Right leg not found on character")
                    return
                end
                
                for _, child in pairs(rightLeg:GetChildren()) do
                    if child:IsA("SpecialMesh") then
                        child:Destroy()
                    end
                end
                local specialMesh = Instance.new("SpecialMesh")
                specialMesh.MeshId = "rbxassetid://101851696"
                specialMesh.TextureId = "rbxassetid://115727863"
                specialMesh.Scale = Vector3.new(1, 1, 1)
                specialMesh.Parent = rightLeg
            end
    
            local function saveRightLegProperties(char)
                if char then
                    local rightLeg = char:FindFirstChild("RightLeg") or char:FindFirstChild("Right Leg")
                    if rightLeg then
                        local originalMesh = rightLeg:FindFirstChildOfClass("SpecialMesh")
                        if originalMesh then
                            _G.PlayerCosmeticsCleanup.originalMeshId = originalMesh.MeshId
                            _G.PlayerCosmeticsCleanup.originalTextureId = originalMesh.TextureId
                            _G.PlayerCosmeticsCleanup.originalScale = originalMesh.Scale
                        else
                            _G.PlayerCosmeticsCleanup.hadNoMesh = true
                        end
                        
                        _G.PlayerCosmeticsCleanup.rightLegChildren = {}
                        for _, child in pairs(rightLeg:GetChildren()) do
                            if child:IsA("SpecialMesh") then
                                table.insert(_G.PlayerCosmeticsCleanup.rightLegChildren, {
                                    ClassName = child.ClassName,
                                    Properties = {
                                        MeshId = child.MeshId,
                                        TextureId = child.TextureId,
                                        Scale = child.Scale
                                    }
                                })
                            end
                        end
                    end
                end
            end
            
            local function restoreRightLeg(char)
                if char then
                    local rightLeg = char:FindFirstChild("RightLeg") or char:FindFirstChild("Right Leg")
                    if rightLeg and _G.PlayerCosmeticsCleanup.rightLegChildren then
                        for _, child in pairs(rightLeg:GetChildren()) do
                            if child:IsA("SpecialMesh") then
                                child:Destroy()
                            end
                        end
                        
                        if _G.PlayerCosmeticsCleanup.hadNoMesh then
                            return
                        end
                        
                        for _, childData in ipairs(_G.PlayerCosmeticsCleanup.rightLegChildren) do
                            if childData.ClassName == "SpecialMesh" then
                                local newMesh = Instance.new("SpecialMesh")
                                newMesh.MeshId = childData.Properties.MeshId
                                newMesh.TextureId = childData.Properties.TextureId
                                newMesh.Scale = childData.Properties.Scale
                                newMesh.Parent = rightLeg
                            end
                        end
                    end
                end
            end
    
            if value then
                CosmeticsActive = true
    
                getgenv().Config = {
                    Headless = true
                }
                
                if lp.Character then
                    local head = lp.Character:FindFirstChild("Head")
                    if head and getgenv().Config.Headless then
                        _G.PlayerCosmeticsCleanup.headTransparency = head.Transparency
                        
                        local decal = head:FindFirstChildOfClass("Decal")
                        if decal then
                            _G.PlayerCosmeticsCleanup.faceDecalId = decal.Texture
                            _G.PlayerCosmeticsCleanup.faceDecalName = decal.Name
                        end
                    end
                    
                    saveRightLegProperties(lp.Character)
                    applyKorblox(lp.Character)
                end
                
                _G.PlayerCosmeticsCleanup.characterAddedConn = lp.CharacterAdded:Connect(function(char)
                    local head = char:FindFirstChild("Head")
                    if head and getgenv().Config.Headless then
                        _G.PlayerCosmeticsCleanup.headTransparency = head.Transparency
                        
                        local decal = head:FindFirstChildOfClass("Decal")
                        if decal then
                            _G.PlayerCosmeticsCleanup.faceDecalId = decal.Texture
                            _G.PlayerCosmeticsCleanup.faceDecalName = decal.Name
                        end
                    end
                    
                    saveRightLegProperties(char)
                    applyKorblox(char)
                end)
                
                if getgenv().Config.Headless then
                    headLoop = task.spawn(function()
                        while CosmeticsActive do
                            local char = lp.Character
                            if char then
                                local head = char:FindFirstChild("Head")
                                if head then
                                    head.Transparency = 1
                                    local decal = head:FindFirstChildOfClass("Decal")
                                    if decal then
                                        decal:Destroy()
                                    end
                                end
                            end
                            task.wait(0.1)
                        end
                    end)
                end
    
            else
                CosmeticsActive = false
    
                if _G.PlayerCosmeticsCleanup.characterAddedConn then
                    _G.PlayerCosmeticsCleanup.characterAddedConn:Disconnect()
                    _G.PlayerCosmeticsCleanup.characterAddedConn = nil
                end
    
                if headLoop then
                    task.cancel(headLoop)
                    headLoop = nil
                end
    
                local char = lp.Character
                if char then
                    local head = char:FindFirstChild("Head")
                    if head and _G.PlayerCosmeticsCleanup.headTransparency ~= nil then
                        head.Transparency = _G.PlayerCosmeticsCleanup.headTransparency
                        
                        if _G.PlayerCosmeticsCleanup.faceDecalId then
                            local newDecal = head:FindFirstChildOfClass("Decal") or Instance.new("Decal", head)
                            newDecal.Name = _G.PlayerCosmeticsCleanup.faceDecalName or "face"
                            newDecal.Texture = _G.PlayerCosmeticsCleanup.faceDecalId
                            newDecal.Face = Enum.NormalId.Front
                        end
                    end
                    
                    restoreRightLeg(char)
                end
    
                _G.PlayerCosmeticsCleanup = {}
            end
        end
    })

    local fly = player:create_module({
        title = "Fly",
        flag = "Fly",
        description = "Allows the player to fly",
        section = "right",
        callback = function(value: boolean)
            if value then
                getgenv().FlyEnabled = true
                local char = Player.Character or Player.CharacterAdded:Wait()
                local hrp = char:WaitForChild("HumanoidRootPart")
                local humanoid = char:WaitForChild("Humanoid")
                
                getgenv().OriginalStateType = humanoid:GetState()
                
                getgenv().RagdollHandler = humanoid.StateChanged:Connect(function(oldState, newState)
                    if getgenv().FlyEnabled then
                        if newState == Enum.HumanoidStateType.Physics or newState == Enum.HumanoidStateType.Ragdoll then
                            task.defer(function()
                                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                                humanoid:ChangeState(Enum.HumanoidStateType.Running)
                            end)
                        end
                    end
                end)
                
                local bodyGyro = Instance.new("BodyGyro")
                bodyGyro.P = 90000
                bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
                bodyGyro.Parent = hrp
                
                local bodyVelocity = Instance.new("BodyVelocity")
                bodyVelocity.Velocity = Vector3.new(0, 0, 0)
                bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                bodyVelocity.Parent = hrp
                
                humanoid.PlatformStand = true
                
                getgenv().ResetterConnection = RunService.Heartbeat:Connect(function()
                    if not getgenv().FlyEnabled then return end
                    
                    if bodyGyro and bodyGyro.Parent then
                        bodyGyro.P = 90000
                        bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
                    end
                    
                    if bodyVelocity and bodyVelocity.Parent then
                        bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                    end
                    
                    humanoid.PlatformStand = true
                    
                    if not bodyGyro.Parent or not bodyVelocity.Parent then
                        if bodyGyro then bodyGyro:Destroy() end
                        if bodyVelocity then bodyVelocity:Destroy() end
                        
                        bodyGyro = Instance.new("BodyGyro")
                        bodyGyro.P = 90000
                        bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
                        bodyGyro.Parent = hrp
                        
                        bodyVelocity = Instance.new("BodyVelocity")
                        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
                        bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                        bodyVelocity.Parent = hrp
                    end
                end)
                
                getgenv().FlyConnection = RunService.RenderStepped:Connect(function()
                    if not getgenv().FlyEnabled then return end
                    local camCF = workspace.CurrentCamera.CFrame
                    local moveDir = Vector3.new(0, 0, 0)
                    
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                        moveDir = moveDir + camCF.LookVector
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                        moveDir = moveDir - camCF.LookVector
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                        moveDir = moveDir - camCF.RightVector
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                        moveDir = moveDir + camCF.RightVector
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.E) then
                        moveDir = moveDir + Vector3.new(0, 1, 0)
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.Q) then
                        moveDir = moveDir - Vector3.new(0, 1, 0)
                    end
                    
                    if moveDir.Magnitude > 0 then
                        moveDir = moveDir.Unit
                    end
                    bodyVelocity.Velocity = moveDir * (getgenv().FlySpeed or 50)
                    bodyGyro.CFrame = camCF
                end)
            else
                getgenv().FlyEnabled = false
                
                if getgenv().FlyConnection then
                    getgenv().FlyConnection:Disconnect()
                    getgenv().FlyConnection = nil
                end
                
                if getgenv().RagdollHandler then
                    getgenv().RagdollHandler:Disconnect()
                    getgenv().RagdollHandler = nil
                end
                
                if getgenv().ResetterConnection then
                    getgenv().ResetterConnection:Disconnect()
                    getgenv().ResetterConnection = nil
                end
                
                local char = Player.Character
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    local humanoid = char:FindFirstChild("Humanoid")
                    
                    if humanoid then
                        humanoid.PlatformStand = false
                        if getgenv().OriginalStateType then
                            humanoid:ChangeState(getgenv().OriginalStateType)
                        end
                    end
                    
                    if hrp then
                        for _, v in ipairs(hrp:GetChildren()) do
                            if v:IsA("BodyGyro") or v:IsA("BodyVelocity") then
                                v:Destroy()
                            end
                        end
                    end
                end
            end
        end
    })
    
    

    local localPlayer = Players.LocalPlayer
                
    local SelectedPlayerFollow = nil
    local followDropdown
    
    local function getPlayerNames()
        local names = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= localPlayer then
                table.insert(names, player.Name)
            end
        end
        return names
    end
    
    local function updateFollowTarget()
        local availablePlayers = getPlayerNames()
        if #availablePlayers > 0 then
            SelectedPlayerFollow = availablePlayers[1]
            if followDropdown then
                followDropdown:update(SelectedPlayerFollow)
            end
        else
            SelectedPlayerFollow = nil
        end
    end
    
    local PlayerFollow = player:create_module({
        title = "Player Follow",
        flag = "Player_Follow",
        description = "Follows the selected player",
        section = "left",
        callback = function(value)
            if value then
                getgenv().PlayerFollowEnabled = true
                getgenv().PlayerFollowConnection = RunService.Heartbeat:Connect(function()
                    if not SelectedPlayerFollow then return end -- Prevents nil indexing
                    local targetPlayer = Players:FindFirstChild(SelectedPlayerFollow)
                    if targetPlayer and targetPlayer.Character and targetPlayer.Character.PrimaryPart then
                        local char = localPlayer.Character
                        if char then
                            local humanoid = char:FindFirstChild("Humanoid")
                            if humanoid then
                                humanoid:MoveTo(targetPlayer.Character.PrimaryPart.Position)
                            end
                        end
                    end
                end)
            else
                getgenv().PlayerFollowEnabled = false
                if getgenv().PlayerFollowConnection then
                    getgenv().PlayerFollowConnection:Disconnect()
                    getgenv().PlayerFollowConnection = nil
                end
            end
        end
    })

    local initialOptions = getPlayerNames()
    if #initialOptions > 0 then
        followDropdown = PlayerFollow:create_dropdown({
            title = "Follow Target",
            flag = "Follow_Target",
            options = initialOptions,
            multi_dropdown = false,
            maximum_options = #initialOptions,
            callback = function(value)
                if value then
                    SelectedPlayerFollow = value
                    if getgenv().FollowNotifyEnabled then
                        Library.SendNotification({
                            title = "Module Notification",
                            text = "Now following: " .. value,
                            duration = 3
                        })
                    end
                end
            end
        })
        SelectedPlayerFollow = initialOptions[1]
        followDropdown:update(SelectedPlayerFollow)
        getgenv().FollowDropdown = followDropdown
    else
        SelectedPlayerFollow = nil
    end
    
    local lastOptionsString = table.concat(initialOptions, ",")
    local updateTimer = 0
    
    RunService.Heartbeat:Connect(function(dt)
        updateTimer = updateTimer + dt
        if updateTimer >= 10 then
            local newOptions = getPlayerNames()
            table.sort(newOptions)
            local newOptionsString = table.concat(newOptions, ",")
            
            if newOptionsString ~= lastOptionsString then
                if followDropdown then
                    if #newOptions > 0 then
                        if followDropdown.set_options then
                            followDropdown:set_options(newOptions)
                        else
                            followDropdown.maximum_options = #newOptions
                        end
                        if not table.find(newOptions, SelectedPlayerFollow) then
                            SelectedPlayerFollow = newOptions[1]
                            followDropdown:update(SelectedPlayerFollow)
                        end
                    else
                        SelectedPlayerFollow = nil
                    end
                end
                lastOptionsString = newOptionsString
            end
            updateTimer = 0
        end
    end)
    
    PlayerFollow:create_checkbox({
        title = "Notify",
        flag = "Follow_Notify",
        default = false,
        callback = function(value)
            getgenv().FollowNotifyEnabled = value
        end
    })

    local HitSounds = player:create_module({
        title = 'Hit Sounds',
        flag = 'Hit_Sounds',
        description = 'Toggles hit sounds',
        section = 'right',
        callback = function(value)
            hit_Sound_Enabled = value
        end
    })
    
    local Folder = Instance.new("Folder")
    Folder.Name = "Useful Utility"
    Folder.Parent = workspace
    
    local hit_Sound = Instance.new('Sound', Folder)
    hit_Sound.Volume = 6
    
    local hitSoundOptions = { 
        "Medal", 
        "Fatality", 
        "Skeet",
        "Switches",
        "Rust Headshot", 
        "Neverlose Sound", 
        "Bubble", 
        "Laser", 
        "Steve", 
        "Call of Duty", 
        "Bat", 
        "TF2 Critical", 
        "Saber", 
        "Bameware"
    }
    
    local hitSoundIds = {
        Medal = "rbxassetid://6607336718",
        Fatality = "rbxassetid://6607113255",
        Skeet = "rbxassetid://6607204501",
        Switches = "rbxassetid://6607173363",
        ["Rust Headshot"] = "rbxassetid://138750331387064",
        ["Neverlose Sound"] = "rbxassetid://110168723447153",
        Bubble = "rbxassetid://6534947588",
        Laser = "rbxassetid://7837461331",
        Steve = "rbxassetid://4965083997",
        ["Call of Duty"] = "rbxassetid://5952120301",
        Bat = "rbxassetid://3333907347",
        ["TF2 Critical"] = "rbxassetid://296102734",
        Saber = "rbxassetid://8415678813",
        Bameware = "rbxassetid://3124331820"
    }

    HitSounds:create_slider({
        title = 'Volume',
        flag = 'HitSoundVolume',
        minimum_value = 1,
        maximum_value = 10,
        value = 5,
        callback = function(value)
            hit_Sound.Volume = value
        end
    })

    
    
    ReplicatedStorage.Remotes.ParrySuccess.OnClientEvent:Connect(function()
        if hit_Sound_Enabled then
            hit_Sound:Play()
        end
    end)

    local soundOptions = {
        ["Eeyuh"] = "rbxassetid://16190782181",
        ["Sweep"] = "rbxassetid://103508936658553",
        ["Bounce"] = "rbxassetid://134818882821660",
        ["Everybody Wants To Rule The World"] = "rbxassetid://87209527034670",
        ["Missing Money"] = "rbxassetid://134668194128037",
        ["Sour Grapes"] = "rbxassetid://117820392172291",
        ["Erwachen"] = "rbxassetid://124853612881772",
        ["Grasp the Light"] = "rbxassetid://89549155689397",
        ["Beyond the Shadows"] = "rbxassetid://120729792529978",
        ["Rise to the Horizon"] = "rbxassetid://72573266268313",
        ["Echoes of the Candy Kingdom"] = "rbxassetid://103040477333590",
        ["Speed"] = "rbxassetid://125550253895893",
        ["Lo-fi Chill A"] = "rbxassetid://9043887091",
        ["Lo-fi Ambient"] = "rbxassetid://129775776987523",
        ["Tears in the Rain"] = "rbxassetid://129710845038263"
    }
    
    local currentSound = Instance.new("Sound")
    currentSound.Volume = 3
    currentSound.Looped = false
    currentSound.Parent = game:GetService("SoundService")   
    
    local soundModule
    
    local function playSoundById(soundId)
        currentSound:Stop()
        currentSound.SoundId = soundId
        currentSound:Play()
    end
    
    local selectedSound = "Eeyuh"
    
    local soundModule = world:create_module({
        title = 'Sound Controller',
        flag = 'sound_controller',
        description = 'Control background music and sounds',
        section = 'left',
        callback = function(value)
            getgenv().soundmodule = value
            if value then
                playSoundById(soundOptions[selectedSound])
            else
                currentSound:Stop()
            end
        end
    })

    soundModule:create_checkbox({
        title = "Loop Song",
        flag = "LoopSong",
        callback = function(value)
            currentSound.Looped = value
        end
    })

   

    soundModule:create_divider({
    })
    
    soundModule:create_dropdown({
        title = 'Select Sound',
        flag = 'sound_selection',
        options = {
            "Eeyuh",
            "Sweep", 
            "Bounce",
            "Everybody Wants To Rule The World",
            "Missing Money",
            "Sour Grapes",
            "Erwachen",
            "Grasp the Light",
            "Beyond the Shadows",
            "Rise to the Horizon",
            "Echoes of the Candy Kingdom",
            "Speed",
            "Lo-fi Chill A",
            "Lo-fi Ambient",
            "Tears in the Rain"
        },
        multi_dropdown = false,
        maximum_options = 15,
        callback = function(value)
            selectedSound = value
            if getgenv().soundmodule then
                playSoundById(soundOptions[value])
            end
        end
    })

    local WorldFilter = world:create_module({
        title = 'Filter',
        flag = 'Filter',
    
        description = 'Toggles custom world filter effects',
        section = 'right',
    
        callback = function(value)
            getgenv().WorldFilterEnabled = value
    
            if not value then

                if game.Lighting:FindFirstChild("CustomAtmosphere") then
                    game.Lighting.CustomAtmosphere:Destroy()
                end
                game.Lighting.FogEnd = 100000
                game.Lighting.ColorCorrection.TintColor = Color3.new(1, 1, 1)
                game.Lighting.ColorCorrection.Saturation = 0
            end
        end
    })
    
    WorldFilter:create_checkbox({
        title = 'Enable Atmosphere',
        flag = 'World_Filter_Atmosphere',
    
        callback = function(value)
            getgenv().AtmosphereEnabled = value
    
            if value then
                if not game.Lighting:FindFirstChild("CustomAtmosphere") then
                    local atmosphere = Instance.new("Atmosphere")
                    atmosphere.Name = "CustomAtmosphere"
                    atmosphere.Parent = game.Lighting
                end
            else
                if game.Lighting:FindFirstChild("CustomAtmosphere") then
                    game.Lighting.CustomAtmosphere:Destroy()
                end
            end
        end
    })

    WorldFilter:create_slider({
        title = 'Atmosphere Density',
        flag = 'World_Filter_Atmosphere_Slider',
    
        minimum_value = 0,
        maximum_value = 1,
        value = 0.5,
    
        callback = function(value)
            if getgenv().AtmosphereEnabled and game.Lighting:FindFirstChild("CustomAtmosphere") then
                game.Lighting.CustomAtmosphere.Density = value
            end
        end
    })

    WorldFilter:create_checkbox({
        title = 'Enable Fog',
        flag = 'World_Filter_Fog',
    
        callback = function(value)
            getgenv().FogEnabled = value
    
            if not value then
                game.Lighting.FogEnd = 100000
            end
        end
    })

    WorldFilter:create_slider({
        title = 'Fog Distance',
        flag = 'World_Filter_Fog_Slider',
    
        minimum_value = 50,
        maximum_value = 10000,
        value = 1000,
    
        callback = function(value)
            if getgenv().FogEnabled then
                game.Lighting.FogEnd = value
            end
        end
    })

    WorldFilter:create_checkbox({
        title = 'Enable Saturation',
        flag = 'World_Filter_Saturation',
    
        callback = function(value)
            getgenv().SaturationEnabled = value
    
            if not value then
                game.Lighting.ColorCorrection.Saturation = 0
            end
        end
    })

    WorldFilter:create_slider({
        title = 'Saturation Level',
        flag = 'World_Filter_Saturation_Slider',
    
        minimum_value = -1,
        maximum_value = 1,
        value = 0,
    
        callback = function(value)
            if getgenv().SaturationEnabled then
                game.Lighting.ColorCorrection.Saturation = value
            end
        end
    })

    WorldFilter:create_checkbox({
        title = 'Enable Hue',
        flag = 'World_Filter_Hue',
    
        callback = function(value)
            getgenv().HueEnabled = value
    
            if not value then
                game.Lighting.ColorCorrection.TintColor = Color3.new(1, 1, 1)
            end
        end
    })
    
    WorldFilter:create_slider({
        title = 'Hue Shift',
        flag = 'World_Filter_Hue_Slider',
    
        minimum_value = -1,
        maximum_value = 1,
        value = 0,
    
        callback = function(value)
            if getgenv().HueEnabled then
                game.Lighting.ColorCorrection.TintColor = Color3.fromHSV(value, 1, 1)
            end
        end
    })

    local BallTrail = world:create_module({
        title = "Ball Trail",
        flag = "Ball_Trail",
        description = "Toggles ball trail effects",
        section = "left",
        callback = function(value)
            getgenv().BallTrailEnabled = value
            if value then
                for _, ball in pairs(Auto_Parry.Get_Balls()) do
                    if not ball:FindFirstChild("Trail") then
                        local trail = Instance.new("Trail")
                        trail.Name = "Trail"
                        
                        local att0 = Instance.new("Attachment")
                        att0.Name = "Attachment0"
                        att0.Parent = ball
                        
                        local att1 = Instance.new("Attachment")
                        att1.Name = "Attachment1"
                        att1.Parent = ball
                        
                        att0.Position = Vector3.new(0, ball.Size.Y/2, 0)
                        att1.Position = Vector3.new(0, -ball.Size.Y/2, 0)
                        
                        trail.Attachment0 = att0
                        trail.Attachment1 = att1
                        
                        trail.Lifetime = 0.4
                        trail.WidthScale = NumberSequence.new({
                            NumberSequenceKeypoint.new(0, 0.5),
                            NumberSequenceKeypoint.new(1, 0.5)
                        })
                        trail.Transparency = NumberSequence.new({
                            NumberSequenceKeypoint.new(0, 0),
                            NumberSequenceKeypoint.new(1, 1)
                        })
                        
                        trail.Color = ColorSequence.new(getgenv().BallTrailColor or Color3.new(1, 1, 1))
                        
                        trail.Parent = ball
                    else
                        local trail = ball:FindFirstChild("Trail")
                        trail.Color = ColorSequence.new(getgenv().BallTrailColor or Color3.new(1, 1, 1))
                        trail.Lifetime = 0.4
                        trail.WidthScale = NumberSequence.new({
                            NumberSequenceKeypoint.new(0, 0.5),
                            NumberSequenceKeypoint.new(1, 0.5)
                        })
                        trail.Transparency = NumberSequence.new({
                            NumberSequenceKeypoint.new(0, 0),
                            NumberSequenceKeypoint.new(1, 1)
                        })
                    end
                end
            else
                for _, ball in pairs(Auto_Parry.Get_Balls()) do
                    local trail = ball:FindFirstChild("Trail")
                    if trail then
                        trail:Destroy()
                    end
                end
            end
        end
    })

    BallTrail:create_slider({
        title = "Ball Trail Hue",
        flag = "Ball_Trail_Hue",
        minimum_value = 0,
        maximum_value = 360,
        value = 0,
        round_number = true,
        callback = function(value)
            if not getgenv().BallTrailRainbowEnabled then
                local newColor = Color3.fromHSV(value / 360, 1, 1)
                getgenv().BallTrailColor = newColor
                if getgenv().BallTrailEnabled then
                    for _, ball in pairs(Auto_Parry.Get_Balls()) do
                        local trail = ball:FindFirstChild("Trail")
                        if trail then
                            trail.Color = ColorSequence.new(newColor)
                        end
                    end
                end
            end
        end
    })  

    BallTrail:create_checkbox({
        title = "Rainbow Trail",
        flag = "Ball_Trail_Rainbow",
        callback = function(value)
            getgenv().BallTrailRainbowEnabled = value
        end
    })

    BallTrail:create_checkbox({
        title = "Particle Emitter",
        flag = "Ball_Trail_Particle",
        callback = function(value)
            getgenv().BallTrailParticleEnabled = value
            for _, ball in pairs(Auto_Parry.Get_Balls()) do
                if value then
                    if not ball:FindFirstChild("ParticleEmitter") then
                        local emitter = Instance.new("ParticleEmitter")
                        emitter.Name = "ParticleEmitter"
                        emitter.Rate = 100
                        emitter.Lifetime = NumberRange.new(0.5, 1)
                        emitter.Speed = NumberRange.new(0, 1)
                        emitter.Size = NumberSequence.new({
                            NumberSequenceKeypoint.new(0, 0.5),
                            NumberSequenceKeypoint.new(1, 0)
                        })
                        emitter.Transparency = NumberSequence.new({
                            NumberSequenceKeypoint.new(0, 0),
                            NumberSequenceKeypoint.new(1, 1)
                        })
                        emitter.Parent = ball
                    end
                else
                    local emitter = ball:FindFirstChild("ParticleEmitter")
                    if emitter then
                        emitter:Destroy()
                    end
                end
            end
        end
    })

    BallTrail:create_checkbox({
        title = "Glow Effect",
        flag = "Ball_Trail_Glow",
        callback = function(value)
            getgenv().BallTrailGlowEnabled = value
            for _, ball in pairs(Auto_Parry.Get_Balls()) do
                if value then
                    if not ball:FindFirstChild("BallGlow") then
                        local glow = Instance.new("PointLight")
                        glow.Name = "BallGlow"
                        glow.Range = 15
                        glow.Brightness = 2
                        glow.Parent = ball
                    end
                else
                    local glow = ball:FindFirstChild("BallGlow")
                    if glow then
                        glow:Destroy()
                    end
                end
            end
        end
    })

    local hue = 0
    game:GetService("RunService").Heartbeat:Connect(function()
        if getgenv().BallTrailEnabled then
            for _, ball in pairs(Auto_Parry.Get_Balls()) do
                local trail = ball:FindFirstChild("Trail")
                if trail then
                    if getgenv().BallTrailRainbowEnabled then
                        hue = (hue + 1) % 360
                        local newColor = Color3.fromHSV(hue / 360, 1, 1)
                        trail.Color = ColorSequence.new(newColor)
                        getgenv().BallTrailColor = newColor
                    else
                        trail.Color = ColorSequence.new(getgenv().BallTrailColor or Color3.new(1, 1, 1))
                    end
                end
            end
        end
    end)

    local billboardLabels = {}

    function qolPlayerNameVisibility()
        local function createBillboardGui(p)
            local character = p.Character
    
            while (not character) or (not character.Parent) do
                task.wait()
                character = p.Character
            end
    
            local head = character:WaitForChild("Head")
    
            local billboardGui = Instance.new("BillboardGui")
            billboardGui.Adornee = head
            billboardGui.Size = UDim2.new(0, 200, 0, 50)
            billboardGui.StudsOffset = Vector3.new(0, 3, 0)
            billboardGui.AlwaysOnTop = true
            billboardGui.Parent = head
    
            local textLabel = Instance.new("TextLabel")
            textLabel.Size = UDim2.new(1, 0, 1, 0)
            textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            textLabel.TextSize = 8
            textLabel.TextWrapped = false
            textLabel.BackgroundTransparency = 1
            textLabel.TextXAlignment = Enum.TextXAlignment.Center
            textLabel.TextYAlignment = Enum.TextYAlignment.Center
            textLabel.Parent = billboardGui
    
            billboardLabels[p] = textLabel
    
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid then
                humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
            end
    
            local heartbeatConnection
            heartbeatConnection = RunService.Heartbeat:Connect(function()
                if not (character and character.Parent) then
                    heartbeatConnection:Disconnect()
                    billboardGui:Destroy()
                    billboardLabels[p] = nil
                    return
                end
    
                if getgenv().AbilityESP then
                    textLabel.Visible = true
                    local abilityName = p:GetAttribute("EquippedAbility")
                    if abilityName then
                        textLabel.Text = p.DisplayName .. " [" .. abilityName .. "]"
                    else
                        textLabel.Text = p.DisplayName
                    end
                else
                    textLabel.Visible = false
                end
            end)
        end
    
        for _, p in Players:GetPlayers() do
            if p ~= plr then
                p.CharacterAdded:Connect(function()
                    createBillboardGui(p)
                end)
                createBillboardGui(p)
            end
        end
    
        Players.PlayerAdded:Connect(function(newPlayer)
            newPlayer.CharacterAdded:Connect(function()
                createBillboardGui(newPlayer)
            end)
        end)
    end
    
    qolPlayerNameVisibility()
    
    local AbilityESP = world:create_module({
        title = 'Ability ESP',
        flag = 'AbilityESP',
        description = 'Displays Player Abilities',
        section = 'right',
        callback = function(value: boolean)
            getgenv().AbilityESP = value
            for _, label in pairs(billboardLabels) do
                label.Visible = value
            end
        end
    })

    local CustomSky = world:create_module({
        title = 'Custom Sky',
        flag = 'Custom_Sky',
        description = 'Toggles a custom skybox',
        section = 'left',
        callback = function(value)
            local Lighting = game.Lighting
            local Sky = Lighting:FindFirstChildOfClass("Sky")
            if value then
                if not Sky then
                    Sky = Instance.new("Sky", Lighting)
                end
            else
                if Sky then
                    local defaultSkyboxIds = {"591058823", "591059876", "591058104", "591057861", "591057625", "591059642"}
                    local skyFaces = {"SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp"}
                    
                    for index, face in ipairs(skyFaces) do
                        Sky[face] = "rbxassetid://" .. defaultSkyboxIds[index]
                    end
                    Lighting.GlobalShadows = true
                    
                end
            end
        end
    })
    
    CustomSky:create_dropdown({
        title = 'Select Sky',
        flag = 'custom_sky_selector',
        options = {
            "Default",
            "Vaporwave",
            "Redshift",
            "Desert",
            "DaBaby",
            "Minecraft",
            "SpongeBob",
            "Skibidi",
            "Blaze",
            "Pussy Cat",
            "Among Us",
            "Space Wave",
            "Space Wave2",
            "Turquoise Wave",
            "Dark Night",
            "Bright Pink",
            "White Galaxy",
            "Blue Galaxy"
        },
        multi_dropdown = false,
        maximum_options = 18,
        callback = function(selectedOption)
            local skyboxData = nil
            if selectedOption == "Default" then
                skyboxData = {"591058823", "591059876", "591058104", "591057861", "591057625", "591059642"}
            elseif selectedOption == "Vaporwave" then
                skyboxData = {"1417494030", "1417494146", "1417494253", "1417494402", "1417494499", "1417494643"}
            elseif selectedOption == "Redshift" then
                skyboxData = {"401664839", "401664862", "401664960", "401664881", "401664901", "401664936"}
            elseif selectedOption == "Desert" then
                skyboxData = {"1013852", "1013853", "1013850", "1013851", "1013849", "1013854"}
            elseif selectedOption == "DaBaby" then
                skyboxData = {"7245418472", "7245418472", "7245418472", "7245418472", "7245418472", "7245418472"}
            elseif selectedOption == "Minecraft" then
                skyboxData = {"1876545003", "1876544331", "1876542941", "1876543392", "1876543764", "1876544642"}
            elseif selectedOption == "SpongeBob" then
                skyboxData = {"7633178166", "7633178166", "7633178166", "7633178166", "7633178166", "7633178166"}
            elseif selectedOption == "Skibidi" then
                skyboxData = {"14952256113", "14952256113", "14952256113", "14952256113", "14952256113", "14952256113"}
            elseif selectedOption == "Blaze" then
                skyboxData = {"150939022", "150939038", "150939047", "150939056", "150939063", "150939082"}
            elseif selectedOption == "Pussy Cat" then
                skyboxData = {"11154422902", "11154422902", "11154422902", "11154422902", "11154422902", "11154422902"}
            elseif selectedOption == "Among Us" then
                skyboxData = {"5752463190", "5752463190", "5752463190", "5752463190", "5752463190", "5752463190"}
            elseif selectedOption == "Space Wave" then
                skyboxData = {"16262356578", "16262358026", "16262360469", "16262362003", "16262363873", "16262366016"}
            elseif selectedOption == "Space Wave2" then
                skyboxData = {"1233158420", "1233158838", "1233157105", "1233157640", "1233157995", "1233159158"}
            elseif selectedOption == "Turquoise Wave" then
                skyboxData = {"47974894", "47974690", "47974821", "47974776", "47974859", "47974909"}
            elseif selectedOption == "Dark Night" then
                skyboxData = {"6285719338", "6285721078", "6285722964", "6285724682", "6285726335", "6285730635"}
            elseif selectedOption == "Bright Pink" then
                skyboxData = {"271042516", "271077243", "271042556", "271042310", "271042467", "271077958"}
            elseif selectedOption == "White Galaxy" then
                skyboxData = {"5540798456", "5540799894", "5540801779", "5540801192", "5540799108", "5540800635"}
            elseif selectedOption == "Blue Galaxy" then
                skyboxData = {"14961495673", "14961494492", "14961492844", "14961491298", "14961490439", "14961489508"}
            end
    
            if not skyboxData then
                warn("Sky option not found: " .. tostring(selectedOption))
                return
            end
    
            local Lighting = game.Lighting
            local Sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky", Lighting)
    
            local skyFaces = {"SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp"}
            for index, face in ipairs(skyFaces) do
                Sky[face] = "rbxassetid://" .. skyboxData[index]
            end

            Lighting.GlobalShadows = false
        end
    })

    local AbilityExploit = world:create_module({
        title = 'Ability Exploit',
        flag = 'AbilityExploit',
        description = 'Ability Exploit(Blatant)',    
        section = 'right',
    
        callback = function(value)
            getgenv().AbilityExploit = value
        end
    })

    AbilityExploit:create_checkbox({
        title = 'Thunder Dash No Cooldown',
        flag = 'ThunderDashNoCooldown',
        callback = function(value)
            getgenv().ThunderDashNoCooldown = value
            if getgenv().AbilityExploit and getgenv().ThunderDashNoCooldown then
                local thunderModule = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Abilities"):WaitForChild("Thunder Dash")
                local mod = require(thunderModule)
                mod.cooldown = 0
                mod.cooldownReductionPerUpgrade = 0
            end
        end
    })

    AbilityExploit:create_checkbox({
        title = 'Continuity Zero Exploit',
        flag  = 'ContinuityZeroExploit',
        callback = function(value)
            getgenv().ContinuityZeroExploit = value
    
            if getgenv().AbilityExploit and getgenv().ContinuityZeroExploit then
                local ContinuityZeroRemote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("UseContinuityPortal")
                local oldNamecall
                oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                    local method = getnamecallmethod()
    
                    if self == ContinuityZeroRemote and method == "FireServer" then
                        return oldNamecall(self,
                            CFrame.new(9e17, 9e16, 9e15, 9e14, 9e13, 9e12, 9e11, 9e10, 9e9, 9e8, 9e7, 9e6),
                            player.Name
                        )
                    end
    
                    return oldNamecall(self, ...)
                end)
            end
        end
    })

    local autoDuelsRequeueEnabled = false

    local AutoDuelsRequeue = farm:create_module({
        title = 'Auto Duels Requeue',
        flag = 'AutoDuelsRequeue',
    
        description = 'Automatically requeues duels',
        section = 'left',
    
        callback = function(value)
            autoDuelsRequeueEnabled = value

            if autoDuelsRequeueEnabled then
                task.spawn(function()
                    while autoDuelsRequeueEnabled do
                        game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.1.0"):WaitForChild("net"):WaitForChild("RE/PlayerWantsRematch"):FireServer()
                        task.wait(5)
                    end
                end)
            end
        end
    })

    local validRankedPlaceIds = {
        13772394625,
        14915220621,
    }

    local selectedQueue = "FFA"
    local autoRequeueEnabled = false

    local AutoRankedRequeue = farm:create_module({
        title = 'Auto Ranked Requeue',
        flag = 'AutoRankedRequeue',
    
        description = 'Automatically requeues Ranked',
        section = 'right',
    
        callback = function(value)
            autoRequeueEnabled = value

            if autoRequeueEnabled then
                if not table.find(validRankedPlaceIds, game.PlaceId) then
                    autoRequeueEnabled = false
                    return
                end

                task.spawn(function()
                    while autoRequeueEnabled do
                        game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("JoinQueue"):FireServer("Ranked", selectedQueue, "Normal")
                        task.wait(5)
                    end
                end)
            end
        end
    })

    AutoRankedRequeue:create_dropdown({
        title = 'Select Queue Type',
        flag = 'QueueType',
        options = { 
            "FFA",
            "Duo" 
        },
        multi_dropdown = false,
        maximum_options = 2,
        callback = function(selectedOption)
            selectedQueue = selectedOption
        end
    })

    local autoLTMRequeueEnabled = false
    local validLTMPlaceId = 13772394625

    local AutoLTMRequeue = farm:create_module({
        title = 'Auto LTM Requeue',
        flag = 'AutoLTMRequeue',
    
        description = 'Automatically requeues LTM',
        section = 'left',
    
        callback = function(value)
            autoLTMRequeueEnabled = value

            if autoLTMRequeueEnabled then
                if game.PlaceId ~= validLTMPlaceId then
                    autoLTMRequeueEnabled = false
                    return
                end

                task.spawn(function()
                    while autoLTMRequeueEnabled do
                        game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.1.0"):WaitForChild("net"):WaitForChild("RF/JoinTournamentEventQueue"):InvokeServer({})
                        task.wait(5)
                    end
                end)
            end
        end
    })

    local SkinChanger = misc:create_module({
        title = 'Skin Changer',
        flag = 'SkinChanger',
        description = 'Skin Changer',
        section = 'left',
        callback = function(value: boolean)
            getgenv().skinChanger = value
            if value then
                getgenv().updateSword()
            end
        end
    })

    SkinChanger:change_state(false)

    SkinChanger:create_paragraph({
        title = "⚠️EVERYONE CAN SEE ANIMATIONS",
        text = "IF YOU USE SKIN CHANGER BACKSWORD YOU MUST EQUIP AN ACTUAL BACKSWORD"
    })

    local skinchangertextbox = SkinChanger:create_textbox({
        title = "￬ Skin Name (Case Sensitive) ￬",
        placeholder = "Enter Sword Skin Name... ",
        flag = "SkinChangerTextbox",
        callback = function(text)
            getgenv().swordModel = text
            getgenv().swordAnimations = text
            getgenv().swordFX = text
            if getgenv().skinChanger then
                getgenv().updateSword()
            end
        end
    })
    
    local AutoPlayModule = {}
    AutoPlayModule.CONFIG = {
        DEFAULT_DISTANCE = 30,
        MULTIPLIER_THRESHOLD = 70,
        TRAVERSING = 25,
        DIRECTION = 1,
        JUMP_PERCENTAGE = 50,
        DOUBLE_JUMP_PERCENTAGE = 50,
        JUMPING_ENABLED = false,
        MOVEMENT_DURATION = 0.8,
        OFFSET_FACTOR = 0.7,
        GENERATION_THRESHOLD = 0.25
    }
    
    AutoPlayModule.ball = nil
    AutoPlayModule.lobbyChoice = nil
    AutoPlayModule.animationCache = nil
    AutoPlayModule.doubleJumped = false
    AutoPlayModule.ELAPSED = 0
    AutoPlayModule.CONTROL_POINT = nil
    AutoPlayModule.LAST_GENERATION = 0
    AutoPlayModule.signals = {}
    
    do
        local getServiceFunction = game.GetService
        
        local function getClonerefPermission()
            local permission = cloneref(getServiceFunction(game, "ReplicatedFirst"))
            return permission
        end
        
        AutoPlayModule.clonerefPermission = getClonerefPermission()
        
        if not AutoPlayModule.clonerefPermission then
            warn("cloneref is not available on your executor! There is a risk of getting detected.")
        end
        
        function AutoPlayModule.findCachedService(self, name)
            for index, value in self do
                if value.Name == name then
                    return value
                end
            end
            return
        end
        
        function AutoPlayModule.getService(self, name)
            local cachedService = AutoPlayModule.findCachedService(self, name)
        
            if cachedService then
                return cachedService
            end
        
            local service = getServiceFunction(game, name)
        
            if AutoPlayModule.clonerefPermission then
                service = cloneref(service)
            end
        
            table.insert(self, service)
            return service
        end
        
        AutoPlayModule.customService = setmetatable({}, {
            __index = AutoPlayModule.getService
        })
    end
    
    AutoPlayModule.playerHelper = {
        isAlive = function(player)
            local character = nil
        
            if player and player:IsA("Player") then
                character = player.Character
            end
        
            if not character then
                return false
            end
        
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            local humanoid = character:FindFirstChild("Humanoid")
        
            if not rootPart or not humanoid then
                return false
            end
        
            return humanoid.Health > 0
        end,
        
        inLobby = function(character)
            if not character then
                return false
            end
        
            return character.Parent == AutoPlayModule.customService.Workspace.Dead
        end,
        
        onGround = function(character)
            if not character then
                return false
            end
        
            return character.Humanoid.FloorMaterial ~= Enum.Material.Air
        end
    }
    
    function AutoPlayModule.isLimited()
        local passedTime = tick() - AutoPlayModule.LAST_GENERATION
        return passedTime < AutoPlayModule.CONFIG.GENERATION_THRESHOLD
    end
    
    function AutoPlayModule.percentageCheck(limit)
        if AutoPlayModule.isLimited() then
            return false
        end
    
        local percentage = math.random(100)
        AutoPlayModule.LAST_GENERATION = tick()
    
        return limit >= percentage
    end

    AutoPlayModule.ballUtils = {
        getBall = function()
            for _, object in AutoPlayModule.customService.Workspace.Balls:GetChildren() do
                if object:GetAttribute("realBall") then
                    AutoPlayModule.ball = object
                    return
                end
            end
        
            AutoPlayModule.ball = nil
        end,
        
        getDirection = function()
            if not AutoPlayModule.ball then
                return
            end
        
            local direction = (AutoPlayModule.customService.Players.LocalPlayer.Character.HumanoidRootPart.Position - AutoPlayModule.ball.Position).Unit
            return direction
        end,
        
        getVelocity = function()
            if not AutoPlayModule.ball then
                return
            end
        
            local zoomies = AutoPlayModule.ball:FindFirstChild("zoomies")
        
            if not zoomies then
                return
            end
        
            return zoomies.VectorVelocity
        end,
        
        getSpeed = function()
            local velocity = AutoPlayModule.ballUtils.getVelocity()
        
            if not velocity then
                return
            end
        
            return velocity.Magnitude
        end,
        
        isExisting = function()
            return AutoPlayModule.ball ~= nil
        end
    }
    
    AutoPlayModule.lerp = function(start, finish, alpha)
        return start + (finish - start) * alpha
    end
    
    AutoPlayModule.quadratic = function(start, middle, finish, alpha)
        local firstLerp = AutoPlayModule.lerp(start, middle, alpha)
        local secondLerp = AutoPlayModule.lerp(middle, finish, alpha)
    
        return AutoPlayModule.lerp(firstLerp, secondLerp, alpha)
    end
    
    AutoPlayModule.getCandidates = function(middle, theta, offsetLength)
        local firstCanditateX = math.cos(theta + math.pi / 2)
        local firstCanditateZ = math.sin(theta + math.pi / 2)
        local firstCandidate = middle + Vector3.new(firstCanditateX, 0, firstCanditateZ) * offsetLength
    
        local secondCanditateX = math.cos(theta - math.pi / 2)
        local secondCanditateZ = math.sin(theta - math.pi / 2)
        local secondCandidate = middle + Vector3.new(secondCanditateX, 0, secondCanditateZ) * offsetLength
    
        return firstCandidate, secondCandidate
    end
    
    AutoPlayModule.getControlPoint = function(start, finish)
        local middle = (start + finish) * 0.5
        local difference = start - finish
    
        if difference.Magnitude < 5 then
            return finish
        end
    
        local theta = math.atan2(difference.Z, difference.X)
        local offsetLength = difference.Magnitude * AutoPlayModule.CONFIG.OFFSET_FACTOR
    
        local firstCandidate, secondCandidate = AutoPlayModule.getCandidates(middle, theta, offsetLength)
        local dotValue = start - middle
    
        if (firstCandidate - middle):Dot(dotValue) < 0 then
            return firstCandidate
        else
            return secondCandidate
        end
    end
    
    AutoPlayModule.getCurve = function(start, finish, delta)
        AutoPlayModule.ELAPSED = AutoPlayModule.ELAPSED + delta
        local timeElapsed = math.clamp(AutoPlayModule.ELAPSED / AutoPlayModule.CONFIG.MOVEMENT_DURATION, 0, 1)
    
        if timeElapsed >= 1 then
            local distance = (start - finish).Magnitude
    
            if distance >= 10 then
                AutoPlayModule.ELAPSED = 0
            end
    
            AutoPlayModule.CONTROL_POINT = nil
            return finish
        end
    
        if not AutoPlayModule.CONTROL_POINT then
            AutoPlayModule.CONTROL_POINT = AutoPlayModule.getControlPoint(start, finish)
        end
    
        assert(AutoPlayModule.CONTROL_POINT, "CONTROL_POINT: Vector3 expected, got nil")
        return AutoPlayModule.quadratic(start, AutoPlayModule.CONTROL_POINT, finish, timeElapsed)
    end
    
    AutoPlayModule.map = {
        getFloor = function()
            local floor = AutoPlayModule.customService.Workspace:FindFirstChild("FLOOR")
            
            if not floor then
                for _, part in pairs(AutoPlayModule.customService.Workspace:GetDescendants()) do
                    if part:IsA("MeshPart") or part:IsA("BasePart") then
                        local size = part.Size
                        if size.X > 50 and size.Z > 50 and part.Position.Y < 5 then
                            return part
                        end
                    end
                end
            end
            
            return floor
        end
    }
    
    AutoPlayModule.getRandomPosition = function()
        local floor = AutoPlayModule.map.getFloor()
    
        if not floor or not AutoPlayModule.ballUtils.isExisting() then
            return
        end
    
        local ballDirection = AutoPlayModule.ballUtils.getDirection() * AutoPlayModule.CONFIG.DIRECTION
        local ballSpeed = AutoPlayModule.ballUtils.getSpeed()
    
        local speedThreshold = math.min(ballSpeed / 10, AutoPlayModule.CONFIG.MULTIPLIER_THRESHOLD)
        local speedMultiplier = AutoPlayModule.CONFIG.DEFAULT_DISTANCE + speedThreshold
        local negativeDirection = ballDirection * speedMultiplier
    
        local currentTime = os.time() / 1.2
        local sine = math.sin(currentTime) * AutoPlayModule.CONFIG.TRAVERSING
        local cosine = math.cos(currentTime) * AutoPlayModule.CONFIG.TRAVERSING
    
        local traversing = Vector3.new(sine, 0, cosine)
        local finalPosition = floor.Position + negativeDirection + traversing
    
        return finalPosition
    end
    
    
    AutoPlayModule.lobby = {
        isChooserAvailable = function()
            return AutoPlayModule.customService.Workspace.Spawn.NewPlayerCounter.GUI.SurfaceGui.Top.Options.Visible
        end,
        
        updateChoice = function(choice)
            AutoPlayModule.lobbyChoice = choice
        end,
        
        getMapChoice = function()
            local choice = AutoPlayModule.lobbyChoice or math.random(1, 3)
            local collider = AutoPlayModule.customService.Workspace.Spawn.NewPlayerCounter.Colliders:FindFirstChild(choice)
        
            return collider
        end,
        
        getPadPosition = function()
            if not AutoPlayModule.lobby.isChooserAvailable() then
                AutoPlayModule.lobbyChoice = nil
                return
            end
        
            local choice = AutoPlayModule.lobby.getMapChoice()
        
            if not choice then
                return
            end
        
            return choice.Position, choice.Name
        end
    }
    
    AutoPlayModule.movement = {
        removeCache = function()
            if AutoPlayModule.animationCache then
                AutoPlayModule.animationCache = nil
            end
        end,
        
        createJumpVelocity = function(player)
            local maxForce = math.huge
            local velocity = Instance.new("BodyVelocity")
            velocity.MaxForce = Vector3.new(maxForce, maxForce, maxForce)
            velocity.Velocity = Vector3.new(0, 80, 0)
            velocity.Parent = player.Character.HumanoidRootPart
        
            AutoPlayModule.customService.Debris:AddItem(velocity, 0.001)
            AutoPlayModule.customService.ReplicatedStorage.Remotes.DoubleJump:FireServer()
        end,
        
        playJumpAnimation = function(player)
            if not AutoPlayModule.animationCache then
                local doubleJumpAnimation = AutoPlayModule.customService.ReplicatedStorage.Assets.Tutorial.Animations.DoubleJump
                AutoPlayModule.animationCache = player.Character.Humanoid.Animator:LoadAnimation(doubleJumpAnimation)
            end
        
            if AutoPlayModule.animationCache then
                AutoPlayModule.animationCache:Play()
            end
        end,
        
        doubleJump = function(player)
            if AutoPlayModule.doubleJumped then
                return
            end
        
            if not AutoPlayModule.percentageCheck(AutoPlayModule.CONFIG.DOUBLE_JUMP_PERCENTAGE) then
                return
            end
        
            AutoPlayModule.doubleJumped = true
            AutoPlayModule.movement.createJumpVelocity(player)
            AutoPlayModule.movement.playJumpAnimation(player)
        end,
        
        jump = function(player)
            if not AutoPlayModule.CONFIG.JUMPING_ENABLED then
                return
            end
            
            if not AutoPlayModule.playerHelper.onGround(player.Character) then
                AutoPlayModule.movement.doubleJump(player)
                return
            end
        
            if not AutoPlayModule.percentageCheck(AutoPlayModule.CONFIG.JUMP_PERCENTAGE) then
                return
            end
        
            AutoPlayModule.doubleJumped = false
            player.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end,
        
        move = function(player, playerPosition)
            player.Character.Humanoid:MoveTo(playerPosition)
        end,
        
        stop = function(player)
            local playerPosition = player.Character.HumanoidRootPart.Position
            player.Character.Humanoid:MoveTo(playerPosition)
        end
    }
    
    AutoPlayModule.signal = {
        connect = function(name, connection, callback)
            if not name then
                name = AutoPlayModule.customService.HttpService:GenerateGUID()
            end
        
            AutoPlayModule.signals[name] = connection:Connect(callback)
            return AutoPlayModule.signals[name]
        end,
        
        disconnect = function(name)
            if not name or not AutoPlayModule.signals[name] then
                return
            end
        
            AutoPlayModule.signals[name]:Disconnect()
            AutoPlayModule.signals[name] = nil
        end,
        
        stop = function()
            for name, connection in pairs(AutoPlayModule.signals) do
                if typeof(connection) ~= "RBXScriptConnection" then
                    continue
                end
        
                connection:Disconnect()
                AutoPlayModule.signals[name] = nil
            end
        end
    }
    
    AutoPlayModule.findPath = function(inLobby, delta)
        local rootPosition = AutoPlayModule.customService.Players.LocalPlayer.Character.HumanoidRootPart.Position
    
        if inLobby then
            local padPosition, padNumber = AutoPlayModule.lobby.getPadPosition()
            local choice = tonumber(padNumber)
            if choice then
                AutoPlayModule.lobby.updateChoice(choice)
                if getgenv().AutoVote then
                    game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.1.0"):WaitForChild("net"):WaitForChild("RE/UpdateVotes"):FireServer("FFA")
                end
            end
    
            if not padPosition then
                return
            end
    
            return AutoPlayModule.getCurve(rootPosition, padPosition, delta)
        end
    
        local randomPosition = AutoPlayModule.getRandomPosition()
    
        if not randomPosition then
            return
        end
    
        return AutoPlayModule.getCurve(rootPosition, randomPosition, delta)
    end
    
    
    AutoPlayModule.followPath = function(delta)
        if not AutoPlayModule.playerHelper.isAlive(AutoPlayModule.customService.Players.LocalPlayer) then
            AutoPlayModule.movement.removeCache()
            return
        end
    
        local inLobby = AutoPlayModule.customService.Players.LocalPlayer.Character.Parent == AutoPlayModule.customService.Workspace.Dead
        local path = AutoPlayModule.findPath(inLobby, delta)
    
        if not path then
            AutoPlayModule.movement.stop(AutoPlayModule.customService.Players.LocalPlayer)
            return
        end
    
        AutoPlayModule.movement.move(AutoPlayModule.customService.Players.LocalPlayer, path)
        AutoPlayModule.movement.jump(AutoPlayModule.customService.Players.LocalPlayer)
    end
    
    AutoPlayModule.finishThread = function()
        AutoPlayModule.signal.disconnect("auto-play")
        AutoPlayModule.signal.disconnect("synchronize")
        
        if not AutoPlayModule.playerHelper.isAlive(AutoPlayModule.customService.Players.LocalPlayer) then
            return
        end
        
        AutoPlayModule.movement.stop(AutoPlayModule.customService.Players.LocalPlayer)
    end
    
    AutoPlayModule.runThread = function()
        AutoPlayModule.signal.connect("auto-play", AutoPlayModule.customService.RunService.PostSimulation, AutoPlayModule.followPath)
        AutoPlayModule.signal.connect("synchronize", AutoPlayModule.customService.RunService.PostSimulation, AutoPlayModule.ballUtils.getBall)
    end
    
    --[[
        TeleportService = cloneref(game:GetService("TeleportService"))
        PlaceId, JobId = game.PlaceId, game.JobId
        if #Players:GetPlayers() < 5 then
            if getgenv().AutoServerHop then
                Players.LocalPlayer:Kick("\nRejoining")
                wait()
                TeleportService:Teleport(PlaceId, Players.LocalPlayer)
            else
                TeleportService:TeleportToPlaceInstance(PlaceId, JobId, Players.LocalPlayer)
            end
        end
    ]]

    local AutoPlay = misc:create_module({
        title = 'Auto Play',
        flag = 'AutoPlay',
        description = 'Automatically Plays Game',
        section = 'right',
        callback = function(value)
            if value then
                AutoPlayModule.runThread()
            else
                AutoPlayModule.finishThread()
            end
        end
    })
    
    local AntiAFK = AutoPlay:create_checkbox({
        title = "Anti AFK",
        flag = "AutoPlayAntiAFK",
        callback = function(value: boolean)
            if value then
                local GC = getconnections or get_signal_cons
                if GC then
                    for i, v in pairs(GC(Players.LocalPlayer.Idled)) do
                        if v["Disable"] then
                            v["Disable"](v)
                        elseif v["Disconnect"] then
                            v["Disconnect"](v)
                        end
                    end
                else
                    local VirtualUser = cloneref(game:GetService("VirtualUser"))
                    Players.LocalPlayer.Idled:Connect(function()
                        VirtualUser:CaptureController()
                        VirtualUser:ClickButton2(Vector2.new())
                    end)
                end
            end
        end
    })

    AntiAFK:change_state(true)

    AutoPlay:create_checkbox({
        title = "Enable Jumping",
        flag = "jumping_enabled",
        callback = function(value)
            AutoPlayModule.CONFIG.JUMPING_ENABLED = value
        end
    })

    AutoPlay:create_checkbox({
        title = "Auto Vote",
        flag = "AutoVote",
        callback = function(value)
            getgenv().AutoVote = value
        end
    })

    --[[
        local AutoServerHop = AutoPlay:create_checkbox({
            title = "Auto Server Hop",
            flag = "AutoServerHop",
            callback = function(value)
                getgenv().AutoServerHop = value
            end
        })

        AutoServerHop:change_state(false)
    ]]
    AutoPlay:create_divider({
    })
    
    AutoPlay:create_slider({
        title = 'Distance From Ball',
        flag = 'default_distance',
        maximum_value = 100,
        minimum_value = 5,
        value = AutoPlayModule.CONFIG.DEFAULT_DISTANCE,
        round_number = true,
        callback = function(value)
            AutoPlayModule.CONFIG.DEFAULT_DISTANCE = value
        end
    })
    
    AutoPlay:create_slider({
        title = 'Speed Multiplier',
        flag = 'multiplier_threshold',
        maximum_value = 200,
        minimum_value = 10,
        value = AutoPlayModule.CONFIG.MULTIPLIER_THRESHOLD,
        round_number = true,
        callback = function(value)
            AutoPlayModule.CONFIG.MULTIPLIER_THRESHOLD = value
        end
    })
    
    AutoPlay:create_slider({
        title = 'Transversing',
        flag = 'traversing',
        maximum_value = 100,
        minimum_value = 0,
        value = AutoPlayModule.CONFIG.TRAVERSING,
        round_number = true,
        callback = function(value)
            AutoPlayModule.CONFIG.TRAVERSING = value
        end
    })

    AutoPlay:create_slider({
        title = 'Direction',
        flag = 'Direction',
        maximum_value = 1,
        minimum_value = -1,
        value = AutoPlayModule.CONFIG.DIRECTION,
        round_number = false,
        callback = function(value)
            AutoPlayModule.CONFIG.DIRECTION = value
        end
    })

    AutoPlay:create_slider({
        title = 'Offset Factor',
        flag = 'OffsetFactor',
        maximum_value = 1,
        minimum_value = 0.1,
        value = AutoPlayModule.CONFIG.OFFSET_FACTOR,
        round_number = false,
        callback = function(value)
            AutoPlayModule.CONFIG.OFFSET_FACTOR = value
        end
    })

    AutoPlay:create_slider({
        title = 'Movement Duration',
        flag = 'MovementDuration',
        maximum_value = 1,
        minimum_value = 0.1,
        value = AutoPlayModule.CONFIG.MOVEMENT_DURATION,
        round_number = false,
        callback = function(value)
            AutoPlayModule.CONFIG.MOVEMENT_DURATION = value
        end
    })

    AutoPlay:create_slider({
        title = 'Generation Threshold',
        flag = 'GenerationThreshold',
        maximum_value = 0.5,
        minimum_value = 0.1,
        value = AutoPlayModule.CONFIG.GENERATION_THRESHOLD,
        round_number = false,
        callback = function(value)
            AutoPlayModule.CONFIG.GENERATION_THRESHOLD = value
        end
    })

    AutoPlay:create_slider({
        title = 'Jump Chance',
        flag = 'jump_percentage',
        maximum_value = 100,
        minimum_value = 0,
        value = AutoPlayModule.CONFIG.JUMP_PERCENTAGE,
        round_number = true,
        callback = function(value)
            AutoPlayModule.CONFIG.JUMP_PERCENTAGE = value
        end
    })
    
    AutoPlay:create_slider({
        title = 'Double Jump Chance',
        flag = 'double_jump_percentage',
        maximum_value = 100,
        minimum_value = 0,
        value = AutoPlayModule.CONFIG.DOUBLE_JUMP_PERCENTAGE,
        round_number = true,
        callback = function(value)
            AutoPlayModule.CONFIG.DOUBLE_JUMP_PERCENTAGE = value
        end
    })

    local ballStatsUI
    local heartbeatConn
    local peakVelocity = 0
    
    local BallStats = misc:create_module({
        title = 'Ball Stats', 
        flag = 'ballStats', 
        description = 'Toggle ball speed stats display', 
        section = 'left',
        callback = function(value)
            if value then
                local ballPeaks = {}

                if not ballStatsUI then
                    local player = game.Players.LocalPlayer
                    ballStatsUI = Instance.new("ScreenGui")
                    ballStatsUI.ResetOnSpawn = false
                    ballStatsUI.Parent = player:WaitForChild("PlayerGui")
                
                    textLabel = Instance.new("TextLabel")
                    textLabel.Name = "BallStatsLabel"
                    textLabel.Size = UDim2.new(0.2, 0, 0.05, 0)
                    textLabel.Position = UDim2.new(0, 0, 0.1, 0)
                    textLabel.TextScaled = false
                    textLabel.TextSize = 26
                    textLabel.BackgroundTransparency = 1
                    textLabel.TextColor3 = Color3.new(1, 1, 1)
                    textLabel.Font = Enum.Font.Gotham
                    textLabel.ZIndex = 2
                    textLabel.Parent = ballStatsUI
                
                    shadowLabel = Instance.new("TextLabel")
                    shadowLabel.Name = "BallStatsShadow"
                    shadowLabel.Size = textLabel.Size
                    shadowLabel.Position = textLabel.Position + UDim2.new(0, 2, 0, 2)
                    shadowLabel.TextScaled = textLabel.TextScaled
                    shadowLabel.TextSize = textLabel.TextSize
                    shadowLabel.BackgroundTransparency = 1
                    shadowLabel.TextColor3 = Color3.new(0, 0, 0)
                    shadowLabel.Font = textLabel.Font
                    shadowLabel.ZIndex = 1
                    shadowLabel.Parent = ballStatsUI
                
                    peakLabel = Instance.new("TextLabel")
                    peakLabel.Name = "PeakStatsLabel"
                    peakLabel.Size = UDim2.new(0.2, 0, 0.05, 0)
                    peakLabel.Position = UDim2.new(0, 0, 0.135, 0)
                    peakLabel.TextScaled = false
                    peakLabel.TextSize = 26
                    peakLabel.BackgroundTransparency = 1
                    peakLabel.TextColor3 = Color3.new(1, 1, 1)
                    peakLabel.Font = Enum.Font.Gotham
                    peakLabel.ZIndex = 2
                    peakLabel.Parent = ballStatsUI
                
                    peakShadow = Instance.new("TextLabel")
                    peakShadow.Name = "PeakStatsShadow"
                    peakShadow.Size = peakLabel.Size
                    peakShadow.Position = peakLabel.Position + UDim2.new(0, 2, 0, 2)
                    peakShadow.TextScaled = peakLabel.TextScaled
                    peakShadow.TextSize = peakLabel.TextSize
                    peakShadow.BackgroundTransparency = 1
                    peakShadow.TextColor3 = Color3.new(0, 0, 0)
                    peakShadow.Font = peakLabel.Font
                    peakShadow.ZIndex = 1
                    peakShadow.Parent = ballStatsUI
                
                    peakVelocity = 0
                    
                    local RunService = game:GetService("RunService")
                    heartbeatConn = RunService.Heartbeat:Connect(function()
                    local Balls = Auto_Parry.Get_Balls() or {}

                    for oldBall,_ in pairs(ballPeaks) do
                        local stillAlive = false
                        for _, b in ipairs(Balls) do
                            if b == oldBall then
                                stillAlive = true
                                break
                            end
                        end
                        if not stillAlive then
                            ballPeaks[oldBall] = nil
                        end
                    end

                    for _, Ball in ipairs(Balls) do
                        local zoomies = Ball:FindFirstChild("zoomies")
                        if zoomies then
                            local speed = zoomies.VectorVelocity.Magnitude

                            ballPeaks[Ball] = ballPeaks[Ball] or 0
                            
                            if speed > ballPeaks[Ball] then
                                ballPeaks[Ball] = speed
                            end

                            local curText = ("Velocity: %.2f"):format(speed)
                            textLabel.Text      = curText
                            shadowLabel.Text    = curText

                            local peakText = ("Peak: %.2f"):format(ballPeaks[Ball])
                            peakLabel.Text      = peakText
                            peakShadow.Text     = peakText

                            break
                        end
                    end
                end)
                end
            else
                if heartbeatConn then
                    heartbeatConn:Disconnect()
                    heartbeatConn = nil
                end
                if ballStatsUI then
                    ballStatsUI:Destroy()
                    ballStatsUI = nil
                end
                peakVelocity = 0
            end
        end
    })

    local visualPart

    local Visualiser = misc:create_module({
        title = 'Visualiser',
        flag = 'Visualiser',
        description = 'Parry Range Visualiser',
        section = 'right',
        callback = function(value: boolean)
            if value then
                if not visualPart then
                    visualPart = Instance.new("Part")
                    visualPart.Name = "VisualiserPart"
                    visualPart.Shape = Enum.PartType.Ball
                    visualPart.Material = Enum.Material.ForceField
                    -- Initial color; will be overridden by slider/checkbox callbacks
                    visualPart.Color = Color3.fromRGB(255, 255, 255)
                    visualPart.Transparency = 0  
                    visualPart.CastShadow = false 
                    visualPart.Anchored = true
                    visualPart.CanCollide = false
                    visualPart.Parent = workspace
                end
    
                Connections_Manager['Visualiser'] = game:GetService("RunService").RenderStepped:Connect(function()
                    local character = Player.Character
                    local HumanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
                    if HumanoidRootPart and visualPart then
                        visualPart.CFrame = HumanoidRootPart.CFrame  
                    end
    
                    if getgenv().VisualiserRainbow then
                        local hue = (tick() % 5) / 5
                        visualPart.Color = Color3.fromHSV(hue, 1, 1)
                    else
                        local hueVal = getgenv().VisualiserHue or 0
                        visualPart.Color = Color3.fromHSV(hueVal / 360, 1, 1)
                    end
    
                    local speed = 0
                    local maxSpeed = 350 
                    local Balls = Auto_Parry.Get_Balls()
    
                    for _, Ball in pairs(Balls) do
                        if Ball and Ball:FindFirstChild("zoomies") then
                            local Velocity = Ball.AssemblyLinearVelocity
                            speed = math.min(Velocity.Magnitude, maxSpeed) / 6.5  
                            break
                        end
                    end
    
                    local size = math.max(speed, 6.5)
                    if visualPart then
                        visualPart.Size = Vector3.new(size, size, size)
                    end
                end)
            else
                if Connections_Manager['Visualiser'] then
                    Connections_Manager['Visualiser']:Disconnect()
                    Connections_Manager['Visualiser'] = nil
                end
    
                if visualPart then
                    visualPart:Destroy()
                    visualPart = nil
                end
            end
        end
    })


    Visualiser:create_checkbox({
        title = 'Rainbow',
        flag = 'VisualiserRainbow',
        callback = function(value)
            getgenv().VisualiserRainbow = value
        end
    })

    Visualiser:create_slider({
        title = 'Color Hue',
        flag = 'VisualiserHue',
        minimum_value = 0,
        maximum_value = 360,
        value = 0,
        callback = function(value)
            getgenv().VisualiserHue = value
        end
    })
    

    local AutoClaimRewards = misc:create_module({
        title = 'Auto Claim Rewards',
        flag = 'AutoClaimRewards',
        description = 'Automatically claims rewards.',
        section = 'left',
        callback = function(value: boolean)
            getgenv().AutoClaimRewards = value
            if value then
                local rs = game:GetService("ReplicatedStorage")
                local net = rs:WaitForChild("Packages")
                    :WaitForChild("_Index")
                    :WaitForChild("sleitnick_net@0.1.0")
                    :WaitForChild("net")
                    
                task.spawn(function()
                    net["RF/RedeemQuestsType"]:InvokeServer("Battlepass", "Weekly")
                    net["RF/RedeemQuestsType"]:InvokeServer("Battlepass", "Daily")
                    net["RF/ClaimAllDailyMissions"]:InvokeServer("Daily")
                    net["RF/ClaimAllDailyMissions"]:InvokeServer("Weekly")
                    net["RF/ClaimAllClanBPQuests"]:InvokeServer()
        
                    local joinTimestamp = tonumber(plr:GetAttribute("JoinedTimestamp")) + 10
                    for i = 1, 6 do
                        while workspace:GetServerTimeNow() < joinTimestamp + (i * 300) + 1 do
                            task.wait(1)
                            if not getgenv().AutoClaimRewards then 
                                return 
                            end
                        end
                        net["RF/ClaimPlaytimeReward"]:InvokeServer(i)
                    end
                end)
            end
        end
    })

    local DisableQuantumEffects = misc:create_module({
        title = 'Disable Quantum Arena Effects',
        flag = 'NoQuantumEffects',
        description = 'Disables Quantum Arena effects.',
        section = 'right',
        callback = function(value: boolean)
            getgenv().NoQuantumEffects = value
            if value then
                task.spawn(function()
                    local quantumfx
                    while task.wait() and getgenv().NoQuantumEffects and not quantumfx do
                        for _, v in getconnections(ReplicatedStorage.Remotes.QuantumArena.OnClientEvent) do
                            quantumfx = v
                            v:Disable()
                        end
                    end
                end)
            end
        end
    })

    local No_Render = misc:create_module({
        title = 'No Render',
        flag = 'No_Render',
        description = 'Disables rendering of effects',
        section = 'left',
        
        callback = function(state)
            Player.PlayerScripts.EffectScripts.ClientFX.Disabled = state
    
            if state then
                Connections_Manager['No Render'] = workspace.Runtime.ChildAdded:Connect(function(Value)
                    Debris:AddItem(Value, 0)
                end)
            else
                if Connections_Manager['No Render'] then
                    Connections_Manager['No Render']:Disconnect()
                    Connections_Manager['No Render'] = nil
                end
            end
        end
    })

    local CustomAnnouncer = misc:create_module({
        title = 'Custom Announcer',
        flag = 'Custom_Announcer',
        description = 'Customize the game announcements',
        section = 'right',
        callback = function(value: boolean)
            if value then
                local Announcer = Player.PlayerGui:WaitForChild("announcer")
                local Winner = Announcer:FindFirstChild("Winner")
                if Winner then
                    Winner.Text = Library._config._flags["announcer_text"] or "discord.gg/Silly"
                end
                Announcer.ChildAdded:Connect(function(Value)
                    if Value.Name == "Winner" then
                        Value.Changed:Connect(function(Property)
                            if Property == "Text" and Library._config._flags["Custom_Announcer"] then
                                Value.Text = Library._config._flags["announcer_text"] or "discord.gg/Silly"
                            end
                        end)
                        if Library._config._flags["Custom_Announcer"] then
                            Value.Text = Library._config._flags["announcer_text"] or "discord.gg/Silly"
                        end
                    end
                end)
            end
        end
    })

    CustomAnnouncer:create_textbox({
        title = "Custom Announcement Text",
        placeholder = "Enter custom announcer text... ",
        flag = "announcer_text",
        callback = function(text)
            Library._config._flags["announcer_text"] = text
            
            if Library._config._flags["Custom_Announcer"] then
                local Announcer = Player.PlayerGui:WaitForChild("announcer")
                local Winner = Announcer:FindFirstChild("Winner")
                if Winner then
                    Winner.Text = text
                end
            end
        end
    })
end

ReplicatedStorage.Remotes.ParrySuccessAll.OnClientEvent:Connect(function(_, root)
    if root.Parent and root.Parent ~= Player.Character then
        if root.Parent.Parent ~= workspace.Alive then
            return
        end
    end

    Auto_Parry.Closest_Player()

    local Ball = Auto_Parry.Get_Ball()

    if not Ball then
        return
    end

    local Target_Distance = (Player.Character.PrimaryPart.Position - Closest_Entity.PrimaryPart.Position).Magnitude
    local Distance = (Player.Character.PrimaryPart.Position - Ball.Position).Magnitude
    local Direction = (Player.Character.PrimaryPart.Position - Ball.Position).Unit
    local Dot = Direction:Dot(Ball.AssemblyLinearVelocity.Unit)

    local Curve_Detected = Auto_Parry.Is_Curved()

    if Target_Distance < 15 and Distance < 15 and Dot > -0.25 then -- wtf ?? maybe the big issue
        if Curve_Detected then
            Auto_Parry.Parry(Selected_Parry_Type)
        end
    end

    if not Grab_Parry then
        return
    end

    Grab_Parry:Stop()
end)

ReplicatedStorage.Remotes.ParrySuccess.OnClientEvent:Connect(function()
    if Player.Character.Parent ~= workspace.Alive then
        return
    end

    if not Grab_Parry then
        return
    end

    Grab_Parry:Stop()
end)

workspace.Balls.ChildAdded:Connect(function()
    Parried = false
end)

workspace.Balls.ChildRemoved:Connect(function(Value)
    Parries = 0
    Parried = false

    if Connections_Manager['Target Change'] then
        Connections_Manager['Target Change']:Disconnect()
        Connections_Manager['Target Change'] = nil
    end
end)

