# Migrations

More often than not, as a developer you have to start changing the data format that you use for player data. Skilift requires this as part of it's API.

## Setting up migrations

Migrations are simple functions that transform data. They are only ran at most once on old data. They receive the old data and are expected to spit out data that either matches the current schema or can be fed into the next migration.

> [!WARNING]
> Migrations are permanent functions left to be in your codebase. They should never be removed, as removing a migration may result in corrupted data.

The names provided with a migration are used to track if a migration happened.

Here is an example migration to demonstrate adding fields.

```luau

type OldPlayerData = {
    money: number
}

type NewPlayerData = {
    money: number,
    gems: number
}

local function add_gems_migrate(data: OldPlayerdata): NewPlayerData
    data.gems = 0
    return data
end

local player_data = skilift.store {
    name = "player-data",
    migrations = {
        { step = "add-gems-field", migrate = add_gems_migrate }
    },
    default_data = function()
        return {
            money = 0,
            gems = 0
        }
    end
}
```

When a session is loaded that does not have all migrations applied to it, it will apply any migration that hasn't been applied yet. Migrations are performed in the order they are provided.
