--!strict

-------------------------------------------------------------------------------------------

local signal = require(script.Parent.Parent:WaitForChild("signal"))

-------------------------------------------------------------------------------------------

type signal = signal.signal
type restricted_signal = signal.restricted_signal

-------------------------------------------------------------------------------------------

export type get<T> = (...any?) -> T
export type set<T> = (new_value : T, ...any?) -> ()

export type user_get<T> = (current_value : T, ...any?) -> T
export type user_set<T> = (new_value : T, ...any?) -> T

export type immutable_prop<T> = 
{
    get : get<T>,

    changed : restricted_signal,
}

export type public_prop<T> = 
{
    get : get<T>,
    set : set<T>,
    
    changed : restricted_signal,
}

export type middleware<T> = (value : T, ...any?) -> {
    value : T,
    cancel : boolean
}

export type middleware_obj<T> = 
{
    list : {
        [number] : middleware<T>
    },

    add : (middleware : middleware<T>, index : number?) -> (),
    remove : (index : number) -> (),

    clear : () -> (),

    apply : (value : T, ...any?) -> T,
}

export type prop<T> = 
{
    get : get<T>,
    set : set<T>,

    middleware : {
        get : middleware_obj<T>,
        set : middleware_obj<T>,
    },

    changed : signal,

    immutable : immutable_prop<T>,
    public : public_prop<T>,
}

export type object_base<T> = 
{
    __type : T
}

-------------------------------------------------------------------------------------------

return nil

-------------------------------------------------------------------------------------------