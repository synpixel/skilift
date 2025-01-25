local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local background = require(script.Parent.background)
local effects = require(ReplicatedStorage.client.ui.effects)
local state = require(ReplicatedStorage.client.ui.state)
local vide = require(ReplicatedStorage.packages.vide)
local button = require(script.Parent.button)
local screengui = require(script.Parent.screengui)
local text = require(script.Parent.text)

local create = vide.create
local indexes = vide.indexes
local values = vide.values

local function hud()

    return screengui {
        name = "HUD",
        enabled = true,

        screengui {
            name = "Inventory",
            enabled = true,

            background {
                size = UDim2.fromOffset(0, 0),
                position = UDim2.fromScale(1, 1),
                anchor_point = Vector2.new(1, 1),
                automatic_size = Enum.AutomaticSize.XY,

                create "UIListLayout" {
                    VerticalAlignment = Enum.VerticalAlignment.Bottom,
                    HorizontalAlignment = Enum.HorizontalAlignment.Right,
                },

                indexes(state.inventory, function(value, key)
                    return background {
                        size = UDim2.fromOffset(100, 30),

                        text {
                            text = function()
                                return `{key}: {value()}x`
                            end
                        }
                    }
                end)
            }
        },

        screengui {
            name = "Unlock",
            enabled = function()
                return state.obtained() ~= false
            end,

            background {
                size = UDim2.fromOffset(300, 300),
                position = UDim2.fromScale(0.5, 0.5),
                anchor_point = Vector2.new(0.5, 0.5),

                create "UIListLayout" {
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    HorizontalAlignment = Enum.HorizontalAlignment.Center,
                },

                text {
                    text = function()
                        return `You obtained a {state.obtained()}`
                    end
                },

                button {
                    size = UDim2.fromOffset(100, 50),

                    activated = function()
                        state.obtained(false)
                    end,

                    text { text = "Close" }
                }

            }
        },

        screengui {
            name = "player list",
            enabled = function() return not state.trading_with() end,

            background {
                automatic_size = Enum.AutomaticSize.Y,
                position = UDim2.fromScale(0, 0.5),

                values(state.players, function(player, index)
                    if player == Players.LocalPlayer then return nil end
                    return button {
                        size = UDim2.fromOffset(200, 50),
                        layout_order = index,
                        text {
                            text = `trade {player.Name}`
                        },

                        activated = function()
                            effects.start_trade(player)
                        end
                    }
                end)
            }
        },

        screengui {
            name = "Trading",
            enabled = function()
                return state.trading_with() ~= false
            end,

            background {
                size = UDim2.fromOffset(500, 300),

                create "UIListLayout" {
                    HorizontalAlignment = Enum.HorizontalAlignment.Center,
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    VerticalFlex = Enum.UIFlexAlignment.SpaceEvenly,
                },

                background {
                    size = UDim2.new(1, 0, 0, 30),

                    text {
                        text = function()
                            return `Trading with {(state.trading_with() or {}).Name}`
                        end
                    }
                },

                background {
                    size = UDim2.new(1, 0, 0, 0),

                    create "UIFlexItem" { FlexMode = Enum.UIFlexMode.Fill },

                    create "UIListLayout" {
                        FillDirection = Enum.FillDirection.Horizontal,
                        HorizontalAlignment = Enum.HorizontalAlignment.Center,
                        VerticalAlignment = Enum.VerticalAlignment.Center,
                        HorizontalFlex = Enum.UIFlexAlignment.SpaceEvenly,
                        Padding = UDim.new(0, 16),
                    },

                    background {
                        size = UDim2.fromScale(0.5, 1),
                        
                        create "UIListLayout" {},

                        indexes(state.inventory, function(value, name)
                            local function get_trading()
                                local offer = state.trading_my_offer()
                                return offer[name] or 0
                            end

                            return background {
                                size = UDim2.new(1, 0, 0, 20),

                                create "UIListLayout" {
                                    FillDirection = Enum.FillDirection.Horizontal,
                                    HorizontalFlex = Enum.UIFlexAlignment.Fill
                                },

                                text {text = function() return `{name}: {get_trading()}/{value()}` end},

                                button {
                                    size = UDim2.fromOffset(100, 20),
                                    text { text = "+" },
                                    activated = function()
                                        print("add", name)
                                        effects.add(name)
                                    end
                                },

                                button {
                                    size = UDim2.fromOffset(100, 20),
                                    text { text = "-" },
                                    activated = function()
                                        print("remove", name)
                                        effects.remove(name)
                                    end
                                },

                            }
                        end)

                    },

                    background {
                        size = UDim2.fromScale(0.5, 1),

                        create "UIListLayout" {},

                        indexes(state.trading_their_offer, function(value, index)
                            return background {
                                size = UDim2.new(1, 0, 0, 20),

                                text {text = function() return `{index}: {value()}x` end}
                            }
                        end)
                    }

                },

                background {
                    size = UDim2.new(1, 0, 0, 50),

                    create "UIListLayout" {
                        FillDirection = Enum.FillDirection.Horizontal,
                        HorizontalAlignment = Enum.HorizontalAlignment.Center,
                        VerticalAlignment = Enum.VerticalAlignment.Center,
                    },

                    button {
                        text { text = "Finalize" },

                        activated = function()
                            state.trading_finalized(true)
                            effects.ready()
                        end
                    },

                    button {
                        text { text = "Reject" },

                        activated = effects.reject_trade
                    },
                    
                }

            }
        },

        button {
            position = UDim2.fromScale(0.5, 1),
            anchor_point = Vector2.new(0, 1),
            
            activated = effects.roll_item,

            text {text = "roll"}
        }

    }

end

return hud