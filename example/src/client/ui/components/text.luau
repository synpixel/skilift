local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(ReplicatedStorage.packages.vide)

local create = vide.create

type Text = {
    text: string | () -> string,
}

return function(props: Text)
    return create "TextLabel" {
        Size = UDim2.fromScale(1, 1),
        
        TextSize = 16,
        Font = Enum.Font.BuilderSans,
        Text = props.text,
        
    }
end