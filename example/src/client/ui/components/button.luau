local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(ReplicatedStorage.packages.vide)

local create = vide.create

type Background = {
    automatic_size: Enum.AutomaticSize?,
    
    size: (UDim2 | () -> UDim2)?,
    position: (UDim2 | () -> UDim2)?,
    anchor_point: (Vector2 | () -> Vector2)?,
    layout_order: (number | () -> number)?,
    zindex: (number | () -> number)?,

    activated: () -> (),

    [number]: any
}

return function(props: Background)
    return create "ImageButton" {
        AutomaticSize = props.automatic_size,
        Size = props.size or UDim2.fromOffset(100, 50),
        Position = props.position,
        AnchorPoint = props.anchor_point,
        LayoutOrder = props.layout_order,
        ZIndex = props.zindex,
        AutoButtonColor = true,
        BorderSizePixel = 1,

        Activated = props.activated,

        unpack(props)
    }
end