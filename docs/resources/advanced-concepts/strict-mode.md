# Strict Mode

Strict mode is intended to catch errors and bad code that would generally be considered too expensive to check for. It's enabled by default in Roblox Studio and automatically disables itself outside of studio. This can be toggled through `skilift.strict`.

Currently, strict mode is limited to the following errors:

## Bad JSON

Every single (currently only normal) action in skilift is checked to make sure it does not return invalid JSON. It errors whenever it encounters a datatype that cannot be serialized into JSON.

This errors in cases where you have:

- Non real numbers (nan, inf, -inf)
- Bad Datatype (anything that isn't a buffer, bool, string, number, table)
- Recursive table (a table that refers to itself somewhere down)
- Non-string key dictionary (not all keys of a dictionary are a string)

```luau
local function bad_action(data)
    data.money = 0/0 -- non-real number
    data.table = data -- recursive table
    data.bad_datatype = vector.create() -- bad datatype
    data.test = { [vector.create(0, 0, 0)] = "test" } -- non-string-key dictionary
    return data
end
```

## Impure actions

Actions are ran twice and evaluated to determine if they yield the same result. It fails when it does not yield the same result. It's easiest to avoid by only using the values you pass into the action.

```luau
local function impure_action(data)
    data.money = math.random() -- math.random is not deterministic, therefore making it impure! this will cause an error in strict mode
    return data
end
```
