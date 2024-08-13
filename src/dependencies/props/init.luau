--!strict

----------------------------------------------------------------------------------------------------------------

local props_types : nil = require(script:WaitForChild("props_types"))
local signal = require(script.Parent:WaitForChild("signal"))

type signal = signal.signal
type restricted_signal = signal.restricted_signal

----------------------------------------------------------------------------------------------------------------

export type get<T> = props_types.get<T>
export type set<T> = props_types.set<T>

export type user_get<T> = props_types.user_get<T>
export type user_set<T> = props_types.user_set<T>

export type immutable_prop<T> = props_types.immutable_prop<T>
export type prop<T> = props_types.prop<T>

export type object_base<T> = props_types.object_base<T>

----------------------------------------------------------------------------------------------------------------

local default_proxy = function<T>(current_value : T, ... : any?): T
    return current_value
end

----------------------------------------------------------------------------------------------------------------

local function new_prop<T>(init_value : T, get_handler : user_get<T>?, set_handler : user_set<T>?) : prop<T>
    local get = get_handler or default_proxy :: any
    local set = set_handler or default_proxy :: any

    local prop : prop<T> = nil
    local current_value : T = init_value

    local prop_signal = signal()
    local restricted_signal = prop_signal.Restricted

    local function get_proxy(...: any): T
        return get(current_value, ...)
    end

    local function set_proxy(new_value : T, ...: any): ()
        local value = set(new_value, ...)
        if value == current_value then
            return
        end
        
        local previous_value = current_value
        current_value = set(new_value, ...)
        
        prop.changed:Fire(current_value, previous_value)
    end

    prop = {
        get = get_proxy,
        set = set_proxy,
        changed = prop_signal,

        immutable = {
            get = get_proxy,
            changed = restricted_signal
        }
    }

    return prop
end

----------------------------------------------------------------------------------------------------------------

return new_prop

----------------------------------------------------------------------------------------------------------------