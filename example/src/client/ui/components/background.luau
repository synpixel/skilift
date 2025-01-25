local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(ReplicatedStorage.packages.vide)

local create = vide.create

type Background = {
    name: string?,
    automatic_size: Enum.AutomaticSize?,
    
    size: (UDim2 | () -> UDim2)?,
    position: (UDim2 | () -> UDim2)?,
    anchor_point: (Vector2 | () -> Vector2)?,
    layout_order: (number | () -> number)?,
    zindex: (number | () -> number)?,

    [number]: any
}

return function(props: Background)
    return create "Frame" {
        Name = props.name,
        AutomaticSize = props.automatic_size,
        Size = props.size,
        Position = props.position,
        AnchorPoint = props.anchor_point,
        LayoutOrder = props.layout_order,
        ZIndex = props.zindex,

        unpack(props)
    }
end