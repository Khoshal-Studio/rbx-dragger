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
				
			end
		end