local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(ReplicatedStorage.packages.vide)

local create = vide.create

type ScreenGui = {
    name: string,
    enabled: boolean | () -> boolean,

    [number]: any
}

return function(props: ScreenGui)
    return create "ScreenGui" {
        Name = props.name,
        Enabled = props.enabled,

        unpack(props)
    }
end