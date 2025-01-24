type Array<T> = { T }
type Map<K, V> = { [K]: V }

type Request = {
    id: string,
}

type MockStoreService = {
    datastores: Map<string, MockStore>,

    Parent: { PlaceId: number, JobId: string },

    GetDataStore: (MockStoreService, string) -> MockStore,
}

type DataInstance = {
    data: unknown,
    metadata: Map<string, unknown>,
    userids: Array<number>,
    version: string,
    time: number,
    deleted: boolean
}
type MockStore = {
    service: MockStoreService,
    name: string,
    data: Map<string, {
        current: DataInstance?,
        versions: Array<DataInstance>,
        writeCount: number,
        createdTime: number
    }?>,

    queues: Map<string, Array<thread>>,

    SetAsync: (self: MockStore, id: string, value: unknown, userids: Array<number>, options: MockStoreSetOptions) -> (),
    GetAsync: (self: MockStore, id: string) -> (unknown, MockStoreKeyInfo?),
    GetVersionAsync: (self: MockStore, id: string, version: string) -> (unknown, MockStoreKeyInfo?),
    RemoveAsync: (self: MockStore, id: string) -> (unknown, MockStoreKeyInfo?),
    UpdateAsync: (self: MockStore, id: string, fn: (unknown, MockStoreKeyInfo?) -> (any?, Array<number>?, Map<string, any>?)) -> (unknown, MockStoreKeyInfo?),
    ListVersionsAsync: (self: MockStore, id: string, dir: Enum.SortDirection?, min: number?, max: number?, size: number?) -> MockStoreVersionPages
}

type MockStoreKeyInfo = {
    metadata: Map<string, unknown>,
    userids: Array<number>,

    CreatedTime: number,
    UpdatedTime: number,
    Version: string,

    GetMetadata: (MockStoreKeyInfo) -> Map<string, unknown>,
    GetUserIds: (MockStoreKeyInfo) -> Array<number>
}

type MockStoreVersionPages = {
    store: MockStore,
    id: string,
    ascending: boolean,
    min: number, max: number,
    size: number,
    current: number,
    initialized: boolean,
    list: Array<MockStoreObjectVersionInfo>,

    IsFinished: boolean,

    GetCurrentPage: (MockStoreVersionPages) -> Array<MockStoreObjectVersionInfo>,
    AdvanceToNextPageAsync: (MockStoreVersionPages) -> ()
}

type MockStoreObjectVersionInfo = {
    CreatedTime: number,
    IsDeleted: boolean,
    Version: string   
}

type MockStoreSetOptions = {
    metadata: Map<string, unknown>,

    SetMetadata: (self: MockStoreSetOptions, metadata: Map<string, unknown>) -> ()
}

local SETTINGS = {
    current_time = os.time(),
    requests_frozen = false,
    simulate_outage = false
}

local datamodel = {
    JobId = "",
    PlaceId = 0
}

local services = {} :: Array<MockStoreService>

local time = table.freeze {
    wait = function(t: number)
        SETTINGS.current_time += t
    end,

    get = function(): number
        return SETTINGS.current_time
    end
}

local function toid(v: string|number): string
    return
        if type(v) == "string" then v
        elseif type(v) == "number" then tostring(v)
        else error("invalid id, must be string or number", 2)
end

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

local function pop<T>(t: Array<T>): T?
    return table.remove(t, 1)
end

local function push<T>(t: Array<T>, v: T)
    table.insert(t, v)
end

local function resume(thread: thread)
    local ok, err = coroutine.resume(thread)
    if not ok then error(err, 2) end    
end

local function ycall<T..., U...>(fn: (T...) -> U..., ...: T...): U...
    local thread = coroutine.create(pcall)
    local resume_ok, run_ok, a, b, c, d = coroutine.resume(thread, fn, ...)

    assert(resume_ok)
        
    if coroutine.status(thread) ~= "dead" then
        error("yielding is none allowed", 2)
    end

    if not run_ok then
        error(a, 2)
    end

    return a, b, c, d
end

local MockStore = {} do
    local MockStoreKeyInfo = {} do
        function GetMetadata(self: MockStoreKeyInfo)
            return clone(self.metadata)
        end

        function GetUserIds(self: MockStoreKeyInfo)
            return clone(self.userids)
        end

        function MockStoreKeyInfo.new(createdTime: number, data: DataInstance): MockStoreKeyInfo
            return table.freeze {
                metadata = clone(data.metadata),
                userids = clone(data.userids),

                CreatedTime = createdTime,
                UpdatedTime = data.time,
                Version = data.version,

                GetMetadata = GetMetadata,
                GetUserIds = GetUserIds
            }
        end
    end

    local DIRECTION_ASCENDING = 0
    local DIRECTION_DESCENDING = 1

    local MockStoreVersionPages = {} do
        function GetCurrentPage(self: MockStoreVersionPages): Array<MockStoreObjectVersionInfo>
            if not self.initialized then error("must advance to next page first", 2) end
            return clone(self.list)
        end

        function AdvanceToNextPageAsync(self: MockStoreVersionPages)
            if SETTINGS.requests_frozen then
                push(self.store.queues[self.id], coroutine.running())
                coroutine.yield()
            end
            
            if SETTINGS.simulate_outage then error("could not advance to next page", 2) end
            -- todo what if new entries are added after finished is reached
            if self.IsFinished then error("no more pages left", 2) end

            local versions = assert(self.store.data[self.id]).versions

            if not self.initialized then -- when called for the first time
                self.initialized = true
                self.current = self.ascending and 1 or #versions
            end

            local list = {} :: Array<MockStoreObjectVersionInfo>

            local diff = self.ascending and self.size or -self.size

            for i =
                self.current,
                self.ascending and self.current + diff - 1 or self.current + diff + 1,
                self.ascending and 1 or -1
            do
                local instance = versions[i]

                if instance == nil then
                    break
                end

                if self.ascending then
                    if instance.time < self.min then
                        continue
                    elseif instance.time > self.max then
                        break
                    end
                else
                    if instance.time > self.max then
                        continue
                    elseif instance.time < self.min then
                        break
                    end
                end
                
                table.insert(list, table.freeze {
                    CreatedTime = instance.time,
                    IsDeleted = instance.deleted,
                    Version = instance.version
                })
            end
            self.current += diff

            self.IsFinished = #list == 0

            self.list = list
        end

        function MockStoreVersionPages.new(store: MockStore, id: string, dir: number, min: number, max: number, size: number): MockStoreVersionPages
            id = toid(id)
            
            local self = {
                store = store,
                id = id,
                ascending =  if dir == DIRECTION_ASCENDING then true elseif dir == DIRECTION_DESCENDING then false else error("invalid direction", 3),
                min = min,
                max = max,
                size = size,
                current = -1,
                initialized = false,
                list = {},

                IsFinished = false,

                GetCurrentPage = GetCurrentPage,
                AdvanceToNextPageAsync = AdvanceToNextPageAsync
            }

            self:AdvanceToNextPageAsync()

            return self
        end
    end

    --[[
    function SetAsync(self: MockStore, id: string, value: unknown, userids: Array<number>, options: DataStoreSetOptions): string -- new version
        if self.SimulateOutage then error("could not set data", 2) end
        local versions = self.data[id]
        local latest = versions[#versions]
        local newVersion = tostring(tonumber(latest.version) :: number + 1)
        table.insert(versions, {

        })
        return newVersion
    end
    ]]

    function Set(
        self: MockStore,
        id: string,
        data: unknown,
        userids: Array<number>?,
        metadata: {}?): string
        id = toid(id)
        if data == nil then error("cannot set data to nil", 2) end

        if SETTINGS.simulate_outage then error("could not set data", 2) end

        local key = self.data[id]

        if key == nil then
            key = {
                current = nil :: any,
                versions = {},
                writeCount = 0,
                createdTime = time.get()
            }
            self.data[id] = key
        end

        assert(key)

        key.writeCount += 1
        local version = tostring(key.writeCount)

        local instance: DataInstance = {
            data = clone(data),
            metadata = clone(metadata) or {},
            userids = clone(userids) or {},
            version = version,
            time = time.get(),
            deleted = false
        }

       table.insert(key.versions, instance)
       key.current = instance

       return version
    end

    function SetAsync(
        self: MockStore,
        id: string,
        data: unknown,
        userids: Array<number>?,
        options: MockStoreSetOptions?
    ): string
        id = toid(id)
        if SETTINGS.requests_frozen then
            push(self.queues[id], coroutine.running())
            coroutine.yield()
        end 

        return Set(self, id, data, userids, options and options.metadata)
    end

    function GetAsync(self: MockStore, id: string): (unknown, MockStoreKeyInfo?)
        id = toid(id)
        if SETTINGS.requests_frozen then
            push(self.queues[id], coroutine.running())
            coroutine.yield()
        end

        if SETTINGS.simulate_outage then error("could not retrieve data", 2) end

        local key = self.data[id]

        if key == nil or key.current == nil then return nil, nil end; assert(key and key.current)

        return clone(key.current.data), MockStoreKeyInfo.new(key.createdTime, key.current)
    end

    function GetVersionAsync(self: MockStore, id: string, version: string): (unknown, MockStoreKeyInfo?)
        id = toid(id)
        if SETTINGS.requests_frozen then
            push(self.queues[id], coroutine.running())
            coroutine.yield()
        end

        if SETTINGS.simulate_outage then error("could not retrieve data", 2) end

        local key = self.data[id]

        if key == nil then return nil, nil end; assert(key)

        for _, instance in next, key.versions do
            if instance.version == version then
                if instance.deleted then error("version was deleted", 2) end -- todo: update when roblox fixes
                return clone(instance.data), MockStoreKeyInfo.new(key.createdTime, instance)
            end
        end

        return nil, nil
    end

    function UpdateAsync(
        self: MockStore,
        id: string,
        fn: (unknown, MockStoreKeyInfo?) -> (unknown, Array<number>?, Map<string, unknown>?),
        tag: string?
    ): (unknown, MockStoreKeyInfo?)
        id = toid(id)

        local newdata, newuserids, newmetadata; repeat
            local writes1 do
                local key = self.data[id]
                writes1 = key and key.writeCount or 0
            end

            local data, info = GetAsync(self, id)

            newdata, newuserids, newmetadata = ycall(fn, data, info)
            if newdata == nil then return end
            newdata = clone(newdata)

            if SETTINGS.requests_frozen then
                push(self.queues[id], coroutine.running())
                coroutine.yield()
            end

            local writes2 do
                local key = self.data[id]
                writes2 = key and key.writeCount or 0
            end
        until writes1 == writes2

        Set(self, id, newdata, newuserids, newmetadata)

        local key = self.data[id]; assert(key and key.current)
        return clone(newdata), MockStoreKeyInfo.new(key.createdTime, key.current)
    end

    local function RemoveAsync(self: MockStore, id: string): (unknown, MockStoreKeyInfo?)
        id = toid(id)

        if SETTINGS.requests_frozen then
            push(self.queues[id], coroutine.running())
            coroutine.yield()
        end

        if SETTINGS.simulate_outage then error("could not remove data", 2) end

        local key = self.data[id]

        if key == nil or key.current == nil then return nil, nil end; assert(key and key.current)

        key.writeCount += 1

        key.current.deleted = true -- todo: verify behavior
        local data, info = key.current.data, MockStoreKeyInfo.new(key.createdTime, key.current)
        key.current = nil

        return clone(data), info
    end

    function ListVersionsAsync(self: MockStore, id: string, dir: Enum.SortDirection?, min: number?, max: number?, size: number?): MockStoreVersionPages
        id = toid(id)
        if SETTINGS.simulate_outage then error("could not update data", 2) end

        local ndir = dir or DIRECTION_ASCENDING :: any
        local nmin = min or 0
        local nmax = max or 0
        local nsize = size or 0

        if nmax == 0 then nmax = 2^50 end
        if nsize == 0 then nsize = 2^50 end

        return MockStoreVersionPages.new(self, id, ndir, nmin, nmax, nsize)
    end

    function MockStore.new(service: MockStoreService, name: string): MockStore
        local queues = {} :: Map<string, Array<thread>>

        setmetatable(queues :: any, { __index = function(_, index)
            queues[index] = {}
            return queues[index]
        end })

        return {
            service = service,
            name = name,
            data = {},

            queues = queues,

            Name = name,

            SetAsync = SetAsync,
            GetAsync = GetAsync,
            GetVersionAsync = GetVersionAsync,
            RemoveAsync = RemoveAsync,
            UpdateAsync = UpdateAsync,
            ListVersionsAsync = ListVersionsAsync,
        }
    end
end

local MockStoreService = {} do
    function GetDataStore(self: MockStoreService, name: string): MockStore
        return self.datastores[name]
    end

    function MockStoreService.new(): MockStoreService
        local datastores = {} :: Map<string, MockStore>

        local self = {
            datastores = datastores,

            SimulateOutage = false,

            Parent = datamodel,

            GetDataStore = GetDataStore
        }

        table.insert(services, self)

        setmetatable(datastores :: any, { __index = function(_, index)
            datastores[index] = MockStore.new(self, index)
            return datastores[index]
        end })

        return self
    end
end

local MockStoreSetOptions = {} do
    function SetMetadata(self: MockStoreSetOptions, metadata: Map<string, unknown>)
        self.metadata = metadata
    end

    function MockStoreSetOptions.new()
        return {
            metadata = {},

            SetMetadata = SetMetadata
        }
    end
end

local function requests_pop()
    local processed = false -- true if at least one queue was processed

    for _, service in services do
        for _, store in service.datastores do
            for _, queue in store.queues do
                local thread = pop(queue)
                if thread then
                    resume(thread)
                    processed = true
                end
            end
        end
    end

    return processed
end

local requests = table.freeze {
    freeze = function()
        SETTINGS.requests_frozen = true
    end,

    unfreeze = function()
        repeat until not requests_pop()
        SETTINGS.requests_frozen = false
    end,

    pop = requests_pop
}

return {
    DataStoreService = MockStoreService.new(),
    DataStoreSetOptions = MockStoreSetOptions,

    requests = requests,
    time = time,

    set_jobid = function(id: string)
        datamodel.JobId = id
    end,

    simulate_outage = function(f: boolean)
        SETTINGS.simulate_outage = f
    end
}
