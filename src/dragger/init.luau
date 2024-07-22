--!strict

---------------------------------------------------------------------------------------------------------------

local module = {}

---------------------------------------------------------------------------------------------------------------

local UserInputService = game:GetService("UserInputService")

---------------------------------------------------------------------------------------------------------------

local types = require(script:WaitForChild("dragger_types"))

export type dragger_info = types.dragger_info
export type dragger = types.dragger

---------------------------------------------------------------------------------------------------------------

local currently_dragging : dragger? = nil

---------------------------------------------------------------------------------------------------------------

local function update(input : InputObject, drag_start : Vector3, start_pos : UDim2) : UDim2?
    if currently_dragging then
        local self = currently_dragging

        local delta = input.Position - drag_start
        local new_position = UDim2.new(start_pos.X.Scale, start_pos.X.Offset + delta.X, start_pos.Y.Scale, start_pos.Y.Offset + delta.Y)
        if self.update and self.target then
            self.target.Position = new_position
        end

        return new_position
    end
    return nil
end

local dragger = {
    __newindex = function(_t, _k, _v)
        error("Cannot add properties to a dragger.")
    end
}
dragger.__index = dragger

--[=[
    Enables the dragger to start dragging the target object.
]=]--
dragger.enable = function(self : dragger, ctrl : boolean?)
    local object : GuiObject = self.object
    local drag_input : InputObject = nil
    local drag_start : Vector3 = nil
    local start_pos : UDim2 = nil
    local preparing_to_drag : boolean = false

    rawset(self, "input_began", object.InputBegan:Connect(function(input : InputObject)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if ctrl and not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                return
            end
            preparing_to_drag = true

            local connection 
            connection = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End and (self.dragging or preparing_to_drag) then
                    self.dragging = false
                    connection:Disconnect()

                    if self.drag_ended and not preparing_to_drag then
                        self.drag_ended:Fire()
                    end

                    preparing_to_drag = false
                end
            end)
        end
    end))

    rawset(self, "input_changed", object.InputChanged:Connect(function(input : InputObject)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            drag_input = input
        end
    end))

    rawset(self, "input_changed_2", UserInputService.InputChanged:Connect(function(input : InputObject)
        if object.Parent == nil then
            self:disable()
            return
        end

        if preparing_to_drag and self.target then
            if ctrl and not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                preparing_to_drag = false
                return
            end

            preparing_to_drag = false

            if self.drag_started then
                self.drag_started:Fire()
            end

            self.dragging = true
            currently_dragging = self
            drag_start = input.Position
            start_pos = self.target.Position

        end

        if input == drag_input and self.dragging and self.rate_limit then
            if ctrl and not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                self.dragging = false
                return
            end

            self.drag_count += 1
            if self.drag_count % self.rate_limit ~= 0 then return end

            local new_position = update(input, drag_start, start_pos)

            if self.dragged then
                self.dragged:Fire(new_position)
            end
        end
    end))

    self.enabled = true
end


--[=[
    Disables the dragger from dragging the target object.
]=]--
dragger.disable = function(self : dragger)
    self.input_began:Disconnect()
    self.input_changed:Disconnect()
    self.input_changed_2:Disconnect()

    if self.dragging then
        self.dragging = false
        currently_dragging = nil
        if self.drag_ended then
            self.drag_ended:Fire()
        end
    end

    self.enabled = false
end

--[=[
    Creates a new dragger object.

    @param info : `dragger_info` — The information to create the dragger object.
    @return `dragger` : `dragger` — The dragger object.
]=]
module.new = function(info : dragger_info) : dragger
    local self = {
        object = info.object,
        target = info.target or info.object,

        drag_started = Instance.new('BindableEvent'),
        dragged = Instance.new("BindableEvent"),
        drag_ended = Instance.new("BindableEvent"),

        rate_limit = info.rate_limit or 1,
        update = info.update or true,

        dragging = false,
        drag_count = 0,
        enabled = false,
    }

    setmetatable(self, dragger)
    local _dragger = self :: any
    return _dragger :: dragger
end

-------------------------------------------------------------------------------------

return table.freeze(module)

-------------------------------------------------------------------------------------