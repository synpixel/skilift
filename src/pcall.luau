
type Result<T, U> = {
    ok: true,
    result: T
} | {
    ok: false,
    err: U
}

local function pcall<T, U>()

end