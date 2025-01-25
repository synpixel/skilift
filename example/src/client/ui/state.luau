local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(ReplicatedStorage.packages.vide)

local source = vide.source

return {
    inventory = source ({} :: { [string]: number }),
    obtained = source(false) :: vide.source<false | string>,

    players = source({} :: {Player}),

    trading_with = source(false) :: vide.source<false | Player>,

    trading_finalized = source(false),
    trading_they_finalized = source(false),
    trading_ready = source(false),
    trading_they_ready = source(false),
    trading_cooldown = source(false) :: vide.source<false | number>,
    
    trading_my_offer = source ({} :: { [string]: number }),
    trading_their_offer = source ({} :: { [string]: number })
}