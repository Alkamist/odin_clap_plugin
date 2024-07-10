package main

Plugin_Gui_Resize_Hints :: struct {
    can_resize_horizontally: bool,
    can_resize_vertically: bool,
    preserve_aspect_ratio: bool,
    aspect_ratio_width: int,
    aspect_ratio_height: int,
}

Parameter_Flag :: enum {
    Is_Stepped,
    Is_Periodic,
    Is_Hidden,
    Is_Read_Only,
    Is_Bypass,
    Is_Automatable,
    Is_Automatable_Per_Note_Id,
    Is_Automatable_Per_Key,
    Is_Automatable_Per_Channel,
    Is_Automatable_Per_Port,
    Is_Modulatable,
    Is_Modulatable_Per_Note_Id,
    Is_Modulatable_Per_Key,
    Is_Modulatable_Per_Channel,
    Is_Modulatable_Per_Port,
    Requires_Process,
}

Parameter_Info :: struct {
    id: Parameter_Id,
    name: string,
    min_value: f64,
    max_value: f64,
    default_value: f64,
    flags: bit_set[Parameter_Flag],
    module: string,
}