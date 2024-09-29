--!strict

---------------------------------------------------------------------------------------

local dependencies = script.Parent:WaitForChild("dependencies")

local props = require(dependencies:WaitForChild("props"):WaitForChild("props_types"))
local signal = require(dependencies:WaitForChild("signal"))

---------------------------------------------------------------------------------------

export type get<T> = props.get<T>
export type set<T> = props.set<T>
export type immutable_prop<T> = props.immutable_prop<T>
export type prop<T> = props.prop<T>
export type public_prop<T> = props.public_prop<T>

export type signal = signal.signal
export type restricted_signal = signal.restricted_signal
export type fire<T> = signal.fire<T>

---------------------------------------------------------------------------------------

export type unit_vector = Vector2

export type drag_mode = "plane" | "linear" | "rotate"

export type bound_mode = "box" | "object" | "custom"| "circle"

export type relative_to = "screen" | "parent"

export type dragger_info = 
	{
		object : GuiObject,
		target : GuiObject?,                     -- default : object
		rate_limit : number?,                    -- default : 1
		drag_mode : drag_mode?,                  -- default : "plane"
		update : boolean?,                       -- default : true
		drag_axis : Vector2?,                    -- default : Vector2.one

		bounded : boolean?,                      -- default : false
		bound_mode : bound_mode?,                -- default : "box"

		bound_box : {
			position : UDim2,                    -- default : UDim2.fromScale(0, 0)
			size : UDim2,				         -- default : UDim2.fromScale(1, 1)

			size_relative_to :  relative_to?,    -- default : "screen" 
			position_relative_to : relative_to?, -- default : "screen"                   
		}?,

		bound_circle : {
			position : UDim2, 				     -- default : UDim2.fromScale(0, 0)
			radius : UDim,			  	         -- default : UDim

			radius_relative_to :  relative_to?,    -- default : "screen" 
			position_relative_to : relative_to?, -- default : "screen"   
		}?,                    

		bound_object : GuiObject?,               -- default : nil

		custom_bound_fn : ((position : UDim2) -> UDim2)? --[[
		default : function(position)
			return position
		end
	]]
	}

export type dragger = 
	{
		object : public_prop<GuiObject>,
		target : public_prop<GuiObject>,

		drag_mode : public_prop<drag_mode>,
		drag_axis : public_prop<unit_vector>,

		bounded : public_prop<boolean>,
		bound_mode : public_prop<bound_mode>,

		bound_box : immutable_prop<{
			position : public_prop<UDim2>,
			size : public_prop<UDim2>,

			size_relative_to : public_prop<relative_to>,
			position_relative_to : public_prop<relative_to>
		}>,

		bound_circle : immutable_prop<{
			position : public_prop<UDim2>,
			radius : public_prop<UDim>,

			radius_relative_to : public_prop<relative_to>,
			position_relative_to : public_prop<relative_to>
		}>,

		bound_object : public_prop<GuiObject?>,
		custom_bound_fn : public_prop<((position : UDim2) -> UDim2)>,

		rate_limit : public_prop<number>,
		update : public_prop<boolean?>,

		dragging : immutable_prop<boolean>,
		drag_count : immutable_prop<number>,

		enabled : immutable_prop<boolean>,

		drag_started : restricted_signal,
		dragged : restricted_signal,
		drag_ended : restricted_signal,

		enable : (self : any, key_code : Enum.KeyCode?) -> (),
		disable : (self : any) -> ()
	}

export type internal_dragger = dragger & 
{
	input_began : RBXScriptConnection?,
	input_changed : RBXScriptConnection?,
	input_changed_2 : RBXScriptConnection?,

	drag_start_internal : signal,
	drag_end_internal : signal,
	dragged_internal : signal,

	enabled_internal : prop<boolean>,
	dragging_internal : prop<boolean>,
	drag_count_internal : prop<number>,
}

return nil

---------------------------------------------------------------------------------------