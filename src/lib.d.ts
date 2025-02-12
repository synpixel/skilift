


export default Skilift
export as namespace Skilift

// declare class DataStoreKeyInfo {
//     CreatedTime: number
//     UpdatedTime: number
//     Version: string

//     GetMetadata(this: DataStoreKeyInfo): Map<string, unknown>
//     GetUserIds(this: DataStoreKeyInfo): Array<number>
// }

// declare class DataStore {
//     GetVersionAsync(key: string, version: string): LuaTuple<[unknown, DataStoreKeyInfo, ]>
// }

// declare interface DataStoreService {
//     GetDataStore(this: DataStoreService, name: string, scope?: string): DataStore
// }

declare type Migration = { step: string, migrate: (old: unknown) => unknown }
export declare type Migrations = Migration[]

export declare type Action<T, U extends unknown[]> = (old: T, params: LuaTuple<U>) => T

export declare interface StoreOptions<DefaultData> {
    /**
     * The name of the Data Store to retrieve.
     */
    name: string,
    /**
     * The scope of the Data Store to retrieve. Default "global"
     */
    scope?: string,
    /**
     * Called whenever a session is loaded without data - this should represent
     * the latest format currently available.
     * @returns DefaultData
     */
    default_data: () => DefaultData,
    /**
     * A list of migrations and the associated steps needed to get to them.
     * They are performed in the order specified.
     */
    migrations: Migrations,
    /**
     * Called whenever skilift receives data. This checks if the data matches a
     * specific schema.
     * @param unknown 
     * @returns 
     */
    schema?: (value: unknown) => boolean,
    /**
     * A custom specified delay on when data is auto-saved.
     */
    pull_delay?: number

}

export declare class Session<T> {
    /**
     * Patches the currently stored data with a given patcher function.
     * Patches will apply immediately outside of a transaction.
     * @param this
     * @param fn 
     * @param params 
     */
    patch<U extends unknown[]>(this: Session<T>, fn: Action<T, U>, ...params: U[]): void
    /**
     * Binds a callback to whenever a session is updated. Sessions should serve
     * as a source of truth for your game, so inside the callback you should
     * reconcile all your data into your game state.
     * 
     * @param this 
     * @param fn 
     */
    updated(this: Session<T>, fn: (value: T) => void): void
    /**
     * Stops the session and saves the last data stored.
     * @param this
     */
    stop(this: Session<T>): void
    /**
     * Waits until the next request has completed. Use this alongside `:stop()`
     * to listen when the store has succesfully saved, or when loading to determine
     * when the data finished loading exactly.
     * @param this 
     */
    await(this: Session<T>): void
    /**
     * Returns a reason why data is considered bad if there is one. It's recommended
     * to check this frequently. When skilift encounters bad data, it will automatically
     * stop that session to prevent the developer from saving said data. It's
     * recommended to kick the player when they have bad data.
     */
    bad(this: Session<T>): "unrecognized_transaction" | "unknown_migration" | undefined
}

export declare class View<T> {
    latest(this: View<T>): T
    version(this: View<T>, version: string): T
    timestamp(this: View<T>, unix: number): T

}

export declare class Store<T> {
    /**
     * Loads a key and returns a new session actively pulling that key.
     * @param this 
     * @param key 
     */
    public load(this: Store<T>, key: string): Session<T>
    /**
     * Views a key and returns an object to read the latest version of that key
     * or the value of the key in the past.
     * @param this 
     * @param key 
     */
    public view(this: Store<T>, key: string): View<T>

}

declare namespace Skilift {

    const action: {
        normal: <T, U extends unknown[]>(this: void, action: Action<T, U>) => void
        transaction: <T, U extends unknown[]>(this: void, action: Action<T, U>, name: string) => void
    }

    /**
     * Creates a new store.
     * @param options 
     */
    function store<DefaultData>(options: StoreOptions<DefaultData>): Store<DefaultData>

    /**
     * Enables strict mode. This is enabled by default in Roblox Studio. This
     * enables purity checks and json checks.
     * @param value 
     */
    function strict(value?: boolean): boolean

    /**
     * Initiates a transaction. It's recommended to escrow items first before
     * actually performing a transaction.
     * @param success 
     * @param failure 
     */
    function transaction(success: () => void, failure?: () => void): boolean
    
    /**
     * Replaces all calls to DataStoreService with a provided mock interface of DataStoreService.
     * @param datastoreservice 
     */
    function mock(datastoreservice: DataStoreService): void
}
