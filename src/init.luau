--!strict

---------------------------------------------------------------------------------------------------------------

local module = {}

---------------------------------------------------------------------------------------------------------------

local UserInputService = game:GetService("UserInputService")

---------------------------------------------------------------------------------------------------------------

local dependencies = script:WaitForChild("dependencies")

local dragger_types = require(script:WaitForChild("dragger_types"))

local props = require(dependencies:WaitForChild("props"))
local signal = require(dependencies:WaitForChild("signal"))

---------------------------------------------------------------------------------------------------------------

local currently_dragging : dragger? = nil

---------------------------------------------------------------------------------------------------------------

export type dragger_info = dragger_types.dragger_info
export type dragger = dragger_types.dragger
export type internal_dragger = dragger_types.internal_dragger

export type get<T> = props.get<T>
export type set<T> = props.set<T>
export type immutable_prop<T> = props.immutable_prop<T>
export type prop<T> = props.prop<T>

export type signal = signal.signal
export type restricted_signal = signal.restricted_signal
export type fire<T> = signal.fire<T>
---------------------------------------------------------------------------------------------------------------

local function update(input : InputObject, drag_start : Vector3, start_pos : UDim2) : UDim2?
    if currently_dragging then
        local self = currently_dragging

        local delta : Vector3 = input.Position - drag_start
        local new_position : UDim2 = UDim2.new(start_pos.X.Scale, start_pos.X.Offset + delta.X, start_pos.Y.Scale, start_pos.Y.Offset + delta.Y)

        if self.update.get() and self.target.get() then
            self.target.get().Position = new_position
        end

        return new_position
    end
    return nil
end

--[=[
    Enables the dragger to start dragging the target object.
]=]--
local function dragger_enable(self : internal_dragger, key_code : Enum.KeyCode?) : ()
    local object : GuiObject = self.object.get()

    local preparing_to_drag : boolean = false
    local drag_input : InputObject = nil
    local drag_start : Vector3 = nil
    local start_pos : UDim2 = nil

    self.input_began = object.InputBegan:Connect(function(input : InputObject)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if key_code and not UserInputService:IsKeyDown(key_code) then
                return
            end
            preparing_to_drag = true

            local connection : RBXScriptConnection = nil
            connection = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End and (self.dragging or preparing_to_drag) then
                    self.dragging_internal.set(false)
                    connection:Disconnect()

                    if self.drag_ended and not preparing_to_drag then
                        self.drag_end_internal:Fire()
                    end

                    preparing_to_drag = false
                end
            end)
        end
    end)

    self.input_changed = object.InputChanged:Connect(function(input : InputObject) : ()
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            drag_input = input
        end
    end)

    self.input_changed_2 = UserInputService.InputChanged:Connect(function(input : InputObject) : ()
        if object.Parent == nil then
            self:disable()
            return
        end

        if preparing_to_drag then
            if key_code and not UserInputService:IsKeyDown(key_code) then
                preparing_to_drag = false
                return
            end

            preparing_to_drag = false

            if self.drag_started then
                self.drag_started_fire()
            end

            self.dragging_set(true)

            currently_dragging = self
            drag_start = input.Position
            start_pos = self.target.get().Position
        end

        if input == drag_input and self.dragging and self.rate_limit.get() > 1 then
            if key_code and not UserInputService:IsKeyDown(key_code) then
                self.dragging_set(false)
                return
            end

            self.drag_count_set(self.drag_count.get() + 1)
            if self.drag_count.get() % self.rate_limit.get() ~= 0 then
                return
            end

            local new_position : UDim2? = update(input, drag_start, start_pos)

            if self.dragged then
                self.dragged_fire(new_position)
            end
        end
    end)

    self.enabled_set(true)
end


--[=[
    Disables the dragger from dragging the target object.
]=]--
local function disable_dragger(self : internal_dragger) : ()
    self.input_began:Disconnect()
    self.input_changed:Disconnect()
    self.input_changed_2:Disconnect()

    if self.dragging.get() then
        self.dragging_set(false)
        currently_dragging = nil

        self.drag_ended_fire()
    end

    self.enabled_set(false)
end

local function valid_dragger_info(info : dragger_info) : boolean
    if info.rate_limit then
        if info.rate_limit < 1 then
            warn("Rate limit must be greater than or equal to 1.")
            return false
        end
        if info.rate_limit % 1 ~= 0 then
            warn("Rate limit must be an integer.")
            return false
        end
    end

    return true
end

--[=[
    Creates a new dragger object.

    @param info : `dragger_info` — The information to create the dragger object.
    @return `dragger` : `dragger` — The dragger object.
]=]
module.new = function(info : dragger_info) : (boolean, dragger?)
    if not valid_dragger_info(info) then
        return false
    end

    --[[----------------------------------------------------------------------]]--

    local self : dragger

    local rate_limit_set = function(new_value : number) : ()
        local current_value : number = self.rate_limit.get()

        if new_value < 1 then
            warn("Rate limit must be greater than or equal to 1.")
            return current_value
        end

        if new_value % 1 ~= 0 then
            warn("Rate limit must be an integer.")
            return current_value
        end

        return new_value
    end

    local dragging_attr, dragging_fire, dragging_set = immutable(false)
    local drag_count_attr, drag_count_fire, drag_count_set = immutable(0)


    local function target_changed(new : GuiObject, previous : GuiObject?)
        self.
        if self.enabled.get() then
            
        end
    end

    --[[----------------------------------------------------------------------]]--

    self = {
        object = info.object,
        target = info.target or info.object,

        drag_started = Instance.new('BindableEvent'),
        dragged = Instance.new("BindableEvent"),
        drag_ended = Instance.new("BindableEvent"),

        rate_limit = mutable(info.rate_limit or 1, nil, rate_limit_set),
        update = mutable(info.update or true),

        dragging = mutable(false),
        drag_count = ,
        enabled = false,

        input_began = nil :: any,
        input_changed = nil :: any,
        input_changed_2 = nil :: any,

        enable = function(self : any, key_code : Enum.KeyCode?) : ()
            dragger_enable(self)
        end,

        disable = function(self : any) : ()
            disable_dragger(self)
        end
    } :: dragger

    return self
end

-------------------------------------------------------------------------------------

return table.freeze(module)

-------------------------------------------------------------------------------------