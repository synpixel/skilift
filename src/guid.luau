local function generate_guid()
    local b = buffer.create(16)

    buffer.writeu32(b, 0, math.random(-2147483647, 2147483647))
    buffer.writeu32(b, 4, math.random(-2147483647, 2147483647))
    buffer.writeu32(b, 8, math.random(-2147483647, 2147483647))
    buffer.writeu32(b, 12, math.random(-2147483647, 2147483647))

    return buffer.tostring(b)
end

return generate_guid