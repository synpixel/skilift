local DataStoreService = game:GetService("DataStoreService")

local MINIMUM = 5

type BudgetUsage = 
    | "get"
    | "get_version"
    | "update"

local function has_budget_and_delta(key: BudgetUsage, amount: number)
    local budget = DataStoreService:GetRequestBudgetForRequestType(
        if key == "get" then Enum.DataStoreRequestType.GetAsync
        elseif key == "get_version" then Enum.DataStoreRequestType.GetVersionAsync
        elseif key == "update" then Enum.DataStoreRequestType.UpdateAsync
        else error(`{key} is not valid`)
    )

    return budget - MINIMUM > amount
end

local function delay_until_meets_budget(key: BudgetUsage, minimum: number)
    while has_budget_and_delta(key, minimum) == false do
        task.wait()
    end
end

return {
    has_budget_and_delta = has_budget_and_delta,
    delay_until_meets_budget = delay_until_meets_budget
}