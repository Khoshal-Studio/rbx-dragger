--!strict

---------------------------------------------------------------------------------------

export type dragger_info = 
{
    object : GuiObject,
    target : GuiObject?,
    rate_limit : number?,
    update : boolean?,
}

export type dragger = dragger_info & 
{
    dragging : boolean,
    drag_count : number,

    enabled : boolean,

    input_began : RBXScriptConnection,
    input_changed : RBXScriptConnection,
    input_changed_2 : RBXScriptConnection,

    drag_started : BindableEvent,
    dragged : BindableEvent,
    drag_ended : BindableEvent,

    enable : (self : any, alt : boolean?) -> (),
    disable : (self : any) -> ()
}

return nil

---------------------------------------------------------------------------------------