local function clone<T>(x: T): T
    if type(x) == "table" then
        local t = table.create(#x)
        for i, v in next, x do
            t[clone(i)] = clone(v)
        end 
        return t :: T & {}
    else
        return x
    end    
end

return clone