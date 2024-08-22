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

export type middleware<T> = props_types.middleware<T>
export type middleware_obj<T> = props_types.middleware_obj<T>
export type middleware_init<T> = {
    get : {
        [number] : middleware<T>
    },
    set : {
        [number] : middleware<T>
    }
}

----------------------------------------------------------------------------------------------------------------

local function new_middleware_obj<T>(list : {[number] : middleware<T>}?) : middleware_obj<T>
    local local_list = list or {}

    local local_add = function<T>(middleware : middleware<T>, index : number?)
        if index then
            table.insert(local_list, index, middleware)
        else
            table.insert(local_list, middleware)
        end
    end

    local local_remove = function<T>(index : number)
        table.remove(local_list, index)
    end
    
    local local_clear = function()
        local_list = {}
    end

    local local_apply = function<T>(value : T, ... : any?): T
        local current_value = value
        
        for _, middleware in ipairs(local_list) do
            local result = middleware(current_value, ...)

            if result.cancel then
                break
            end

            current_value = result.value
        end

        return current_value
    end

    return {
        list = local_list,
        add = local_add,
        remove = local_remove,
        clear = local_clear,
        apply = local_apply
    }
end

----------------------------------------------------------------------------------------------------------------

local function new_prop<T>(init_value : T, middleware : middleware_init<T>?) : prop<T>
    local current_value = init_value

    local get = function() : T
        return current_value
    end

    local set = function(new_value : T, ... : any?)
        current_value = new_value
    end

    local get_middleware_obj = new_middleware_obj(if middleware then middleware.get else nil)
    local set_middleware_obj = new_middleware_obj(if middleware then middleware.set else nil)

    local changed = signal()

    local immutable = {
        get = get,
        
        changed = changed.Restricted
    }

    local public = {
        get = get,
        set = set,

        changed = changed.Restricted
    }

    return {
        get = get,
        set = set,

        middleware = {
            get = get_middleware_obj,
            set = set_middleware_obj
        },

        changed = changed,
        
        immutable = immutable,
        public = public
    }
end

----------------------------------------------------------------------------------------------------------------

return new_prop

----------------------------------------------------------------------------------------------------------------