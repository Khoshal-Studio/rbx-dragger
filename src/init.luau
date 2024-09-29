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

local atan2 = math.atan2
local UDim2_new = UDim2.new
local UDim2_fromOffset = UDim2.fromOffset
local UDim2_fromScale = UDim2.fromScale
local UDim_new = UDim.new
local Vector2_new = Vector2.new
local deg = math.deg
local clamp = math.clamp

---------------------------------------------------------------------------------------------------------------

local DEFAULT_VALUES = {
	drag_mode = "plane",
	drag_axis = Vector2.one,
	bounded = false,
	bound_mode = "box",

	bound_box = {
		position = UDim2_fromScale(0.5, 0.5),
		size = UDim2_fromScale(1,1),

		size_relative_to = "screen",
		position_relative_to = "screen"
	},

	bound_circle = {
		position = UDim2_fromScale(0,0),
		radius = UDim_new(0.1,0),

		radius_relative_to = "screen",
		position_relative_to = "screen"
	},

	bound_object = nil,
	custom_bound_fn = function(position : UDim2)
		return position
	end,
	rate_limit = 1,
	update = true,
}

---------------------------------------------------------------------------------------------------------------

local function is_natural(n : number)
	return (n > 0 and n % 1 == n)
end

local function true_pos(object : GuiObject)
	return object.AbsolutePosition + object.AbsoluteSize/2
end

local function is_descendant_of(object : Instance, parent : Instance) : boolean
	local current : Instance? = object

	while current do
		if current == parent then
			return true
		end

		current = current.Parent
	end

	return false
end

local function udim2_to_absolute(udim : UDim2, screen_size : Vector2?) : Vector2
	local _screen_size = screen_size or workspace.CurrentCamera.ViewportSize
	return Vector2_new(udim.X.Scale * _screen_size.X + udim.X.Offset, udim.Y.Scale * _screen_size.Y + udim.Y.Offset)
end

local function udim_to_absolute(udim : UDim, screen_size : Vector2?) : number
	local _screen_size = screen_size or workspace.CurrentCamera.ViewportSize
	return udim.Scale * _screen_size.X + udim.Offset
end

local function vector2_to_udim2(vector : Vector2) : UDim2
	return UDim2_new(0, vector.X, 0, vector.Y)
end

local function package(value : any)
	return {
		value = value,
		cancel = false
	}
end

local function get_rotate_angle(self : dragger, input: InputObject, drag_start : Vector3, delta : Vector3)
	local start_angle = atan2(drag_start.Y, drag_start.X)
	local current_angle = atan2(delta.Y, delta.X)

	local angle = deg(current_angle + start_angle)

	return angle
end

local function box_constrain_udim(bounding_box : { position : UDim2, size : UDim2 }, position : UDim2) : UDim2
	local absolute_point : Vector2 = udim2_to_absolute(position)
	local absolute_position : Vector2 = udim2_to_absolute(bounding_box.position)
	local absolute_size : Vector2 = udim2_to_absolute(bounding_box.size)

	local e1 = absolute_position.X - absolute_size.X/2
	local e2 = absolute_position.X + absolute_size.X/2
	local e4 = absolute_position.Y - absolute_size.Y/2
	local e3 = absolute_position.Y + absolute_size.Y/2

	return UDim2_fromOffset(
		math.clamp(absolute_point.X, e1, e2),
		math.clamp(absolute_point.Y, e4, e3)
	)
end

local function constrain_vector2(bounding_box : { position : Vector2, size : Vector2 }, position : Vector2) : Vector2
	local e1 = bounding_box.position.X - bounding_box.size.X/2
	local e2 = bounding_box.position.X + bounding_box.size.X/2
	local e4 = bounding_box.position.Y - bounding_box.size.Y/2
	local e3 = bounding_box.position.Y + bounding_box.size.Y/2

	return Vector2_new(
		math.clamp(position.X, e1, e2),
		math.clamp(position.Y, e4, e3)
	)
end

local function circle_constrain_udim(radius : number, centre : UDim2, position : UDim2)
	local offset = udim2_to_absolute(position - centre)
	local distance = offset.Magnitude

	if distance > radius then
		offset = offset.Unit * radius
	end

	return centre + UDim2_fromOffset(offset.X, offset.Y)
end

local function update(input: InputObject, drag_start: Vector3, start_pos: UDim2): (UDim2?, number?)
	if currently_dragging then
		local self = currently_dragging
		local object = self.object.get() 

		local delta: Vector3 = input.Position - drag_start
		local new_position : UDim2 = object.Position
		local new_rotation : number = object.Rotation

		if self.drag_mode.get() == "plane" then
			new_position = UDim2_new(start_pos.X.Scale, start_pos.X.Offset + delta.X, start_pos.Y.Scale, start_pos.Y.Offset + delta.Y)

		elseif self.drag_mode.get() == "linear" then
			local axis: Vector2 = self.drag_axis.get().Unit  
			local projected_delta = axis.X * delta.X + axis.Y * delta.Y

			new_position = UDim2_new(
				start_pos.X.Scale, start_pos.X.Offset + axis.X * projected_delta,
				start_pos.Y.Scale, start_pos.Y.Offset + axis.Y * projected_delta
			)

		elseif self.drag_mode.get() == "rotate" then
			new_rotation = get_rotate_angle(self, input, drag_start, delta)
		end

		-- Clamping based on bounds
		local bounded : boolean = self.bounded.get()

		if bounded then
			local bound_mode = self.bound_mode.get()

			if bound_mode == "box" then
				local bound_box = self.bound_box.get()

				local position_relative_to = bound_box.position_relative_to.get()
				local size_relative_to = bound_box.size_relative_to.get()
				
				local pos = bound_box.position.get()
				
				local parent = object.Parent 
				
				if position_relative_to == "screen" and parent and parent:IsA("GuiObject") then
					-- 36 pixels because AbsolutePosition does not account for the topbar
					pos = vector2_to_udim2(udim2_to_absolute(pos)) - vector2_to_udim2(parent.AbsolutePosition + Vector2.new(0, 36)) 
				end
				
				local size = vector2_to_udim2(udim2_to_absolute(bound_box.size.get(),
					if size_relative_to == "screen" then
						workspace.CurrentCamera.ViewportSize
					elseif parent and parent:IsA("GuiObject") then
						parent.AbsoluteSize
					else
						nil
				))
				
				new_position = box_constrain_udim({position = pos, size = size}, new_position)
			elseif bound_mode == "object" then
				local bound_object : GuiObject? = self.bound_object.get()

				if not bound_object then
					warn("Bound object is nil.")
				else
					if object.Parent == bound_object then
						new_position = UDim2_new(
							0,
							clamp (new_position.X.Offset, 0, bound_object.AbsoluteSize.X),
							0,
							clamp (new_position.Y.Offset, 0, bound_object.AbsoluteSize.Y)
						)
					else
						local bound_size = bound_object.AbsoluteSize
						local bound_position = true_pos(bound_object)

						local constrained_position = constrain_vector2({
							position = bound_position,
							size = bound_size
						}, udim2_to_absolute(new_position))

						new_position = UDim2_fromOffset(constrained_position.X, constrained_position.Y)
					end
				end
            elseif bound_mode == "parent" then
                local parent = object.Parent
                if parent and parent:IsA("GuiObject") then
                    local parent_size = parent.AbsoluteSize
                    local parent_position = true_pos(parent)

                    local constrained_position = constrain_vector2({
                        position = parent_position,
                        size = parent_size
                    }, udim2_to_absolute(new_position))

                    new_position = UDim2_fromOffset(constrained_position.X, constrained_position.Y)
                end
			elseif bound_mode == "custom" then
				local transform_fn = self.custom_bound_fn.get()
				new_position = transform_fn(new_position)
			elseif bound_mode == "circle" then
				local bound_circle = self.bound_circle.get()
				
				local position_udim = bound_circle.position.get()

				local position_relative_to = bound_circle.position_relative_to.get()
				local radius_relative_to = bound_circle.radius_relative_to.get()

				local parent = object.Parent

				local pos = position_udim
				
				if position_relative_to == "screen" and parent and parent:IsA("GuiObject") then
					-- 36 pixels because AbsolutePosition does not account for the topbar
					pos = vector2_to_udim2(udim2_to_absolute(pos)) - vector2_to_udim2(parent.AbsolutePosition + Vector2.new(0, 36)) 
				end

				local radius = udim_to_absolute(bound_circle.radius.get(),
					if radius_relative_to == "screen" then
						workspace.CurrentCamera.ViewportSize
					elseif parent and parent:IsA("GuiObject") then
						parent.AbsoluteSize
					else 
						nil
				)

				new_position = circle_constrain_udim(radius, pos, new_position)
			end
		end

		if self.update.get() then
			self.target.get().Position = new_position
			self.target.get().Rotation = new_rotation
		end

		return new_position, new_rotation
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
				if input.UserInputState == Enum.UserInputState.End and (self.dragging.get() or preparing_to_drag) then
					self.dragging_internal.set(false)
					connection:Disconnect()

					if not preparing_to_drag then
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

			self.drag_start_internal:Fire()
			self.dragging_internal.set(true)

			preparing_to_drag = false
			currently_dragging = self
			drag_start = input.Position
			start_pos = self.target.get().Position
		end

		if input == drag_input and self.dragging.get() and self.rate_limit.get() then
			if key_code and not UserInputService:IsKeyDown(key_code) then
				self.dragging_internal.set(false)
				return
			end

			self.drag_count_internal.set(self.drag_count.get() + 1)
			if self.drag_count.get() % self.rate_limit.get() ~= 0 then
				return
			end

			local new_position, new_rotation = update(input, drag_start, start_pos)
			self.dragged_internal:Fire(new_position, new_rotation)
		end
	end)

	self.enabled_internal.set(true)
end


--[=[
    Disables the dragger from dragging the target object.
]=]--
local function disable_dragger(self : internal_dragger) : ()
	if self.enabled.get() and self.input_began and self.input_changed and self.input_changed_2 then
		self.input_began:Disconnect()
		self.input_changed:Disconnect()
		self.input_changed_2:Disconnect()
	end

	if self.dragging.get() then
		self.dragging_internal.set(false)
		currently_dragging = nil

		self.drag_end_internal:Fire()
	end

	self.enabled_internal.set(false)
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

---------------------------------------------------------------------------------------------------------------

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

	local dragger : internal_dragger

	--[[----------------------------------------------------------------------]]--

	local dragging_internal = props(false)
	local drag_count_internal = props(0)
	local enabled_internal = props(false)
	local drag_start_internal = signal()
	local drag_end_internal = signal()
	local dragged_internal = signal()

	--[[----------------------------------------------------------------------]]--

	local function cancel(key : string)
		return {
			value = (dragger :: any)[key].get(),
			cancel = true
		}
	end

	--[[----------------------------------------------------------------------]]--

	local rate_limit_info = {
		set = {
			function(new_value : number)
				if not is_natural(new_value) then
					return cancel("rate_limit")
				end

				return package(new_value)
			end
		}
	}

	local object_info = {
		set = {
			function(new_value : GuiObject)
				if not new_value:IsA("GuiObject") then
					warn("Object must be a GuiObject.")
					return cancel("object")
				end

				return package(new_value)
			end
		}
	}

	local target_info = {
		set = {
			function(new_value : GuiObject)
				if not new_value:IsA("GuiObject") then
					warn("Target must be a GuiObject.")
					return cancel("target")
				end

				return package(new_value)
			end
		}
	}

	local bound_object_info = {
		set = {
			function(new_value : GuiObject?)
				if new_value and not new_value:IsA("GuiObject") then
					warn("Bound object must be a GuiObject.")
					return cancel("bound_object")
				end

				return package(new_value)
			end,

			function(new_value : GuiObject?)
				if new_value and (new_value == dragger.object.get().Parent or is_descendant_of(new_value, dragger.object.get())) then
					warn("Bound object cannot be the same as the object or a descendant of the object.")
					return cancel("bound_object")
				end

				return package(new_value)
			end
		}
	}

	--[[----------------------------------------------------------------------]]--

	local function object_changed(new_value : GuiObject)
		dragger:disable()  

		if dragger.enabled.get() then
			dragger:enable()
		end
	end

	--[[----------------------------------------------------------------------]]--

	local function def(key : string) : any
		return if info[key] == nil then DEFAULT_VALUES[key] else info[key]
	end

	dragger = {
		enable = function(self : any, key_code : Enum.KeyCode?) : ()
			dragger_enable(self)
		end,

		disable = function(self : any) : ()
			disable_dragger(self)
		end,

		input_began = nil,
		input_changed = nil,
		input_changed_2 = nil,

		drag_mode = props(def("drag_mode")).public,
		drag_axis = props(def("drag_axis")).public,

		bounded = props(def("bounded")).public,
		bound_mode = props(def("bound_mode")).public,

		bound_box = props({
			position = props(def("bound_box").position).public,
			size = props(def("bound_box").size).public,

			size_relative_to = props(def("bound_box").size_relative_to).public,
			position_relative_to = props(def("bound_box").position_relative_to).public
		}).immutable,

		bound_circle = props({
			position = props(def("bound_circle").position).public,
			radius = props(def("bound_circle").radius).public,

			radius_relative_to = props(def("bound_circle").radius_relative_to).public,
			position_relative_to = props(def("bound_circle").position_relative_to).public
		}).immutable,

		bound_object = props(def("bound_object"), bound_object_info).public,
		custom_bound_fn = props(def("custom_bound_fn")).public,

		object = props(info.object, object_info).public,
		target = props(info.target or info.object, target_info).public,

		drag_started = drag_start_internal.Restricted,
		dragged = dragged_internal.Restricted,
		drag_ended = drag_end_internal.Restricted,
          
		rate_limit = props(def("rate_limit"), rate_limit_info).public,
		update = props(def("update")).public,

		dragging = dragging_internal.immutable,
		drag_count = drag_count_internal.immutable,
		enabled = enabled_internal.immutable,

		drag_start_internal = drag_start_internal,
		drag_end_internal = drag_end_internal,
		dragged_internal = dragged_internal,

		enabled_internal = enabled_internal,
		dragging_internal = dragging_internal,
		drag_count_internal = drag_count_internal,
	}

	--[[----------------------------------------------------------------------]]--

	dragger.object.changed:Connect(object_changed)

	--[[----------------------------------------------------------------------]]--

	return true, dragger
end

-------------------------------------------------------------------------------------

return table.freeze(module)

-------------------------------------------------------------------------------------