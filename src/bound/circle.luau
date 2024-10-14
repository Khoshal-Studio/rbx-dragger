--!strict

------------------------------------------------------------------------------------------------------------------------

local util = require(script.Parent.Parent:WaitForChild("util"))
local types = require(script.Parent.Parent:WaitForChild("types"))


------------------------------------------------------------------------------------------------------------------------

local function constrain(radius : number, centre : UDim2, position : UDim2)
	local offset = udim2_to_absolute(position - centre)
	local distance = offset.Magnitude

	if distance > radius then
		offset = offset.Unit * radius
	end

	return centre + UDim2_fromOffset(offset.X, offset.Y)
end

------------------------------------------------------------------------------------------------------------------------

local function bound(self : types.internal_dragger, position : UDim2) : UDim2
    local object = self.object.get()
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

	return constrain(radius, pos, position)
end

------------------------------------------------------------------------------------------------------------------------

return bound