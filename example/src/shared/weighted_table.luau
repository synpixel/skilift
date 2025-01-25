
type WeightTable<T> = {
    [T]: {
        weight: number
    }
}

local function roll<T>(weights: WeightTable<T>): T
    local max = 0

    for _, value in weights do
        max += value.weight
    end

    local roll = math.random(max)

    for key, value in weights do
        print(roll)
        roll -= value.weight
        if roll > 0 then continue end
        print("got", key)
        return key
    end

    error("did not roll anything")
end

return {
    roll = roll
}