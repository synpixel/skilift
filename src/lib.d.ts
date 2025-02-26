import {
    StoreOptions,
    Store,
    Session,
    View,
    Action,
    Migrations,
    Migration
} from './types';

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

export = Skilift
