-- NOTES TO OTHER DEVS:
-- Always use SingleSync, no matter what.
-- Events should only ever be listened to from one place inside a queue.
opt casing = "snake_case"
opt server_output = "src/shared/net/server.luau"
opt client_output = "src/shared/net/client.luau"
opt write_checks = false

-- * Client

event roll_item = {
	from: Client,
	type: Reliable,
	call: SingleSync,
}

event request_trade = {
	from: Client,
	type: Reliable,
	call: SingleSync,
	data: Instance
}

event reject_trade = {
	from: Client,
	type: Reliable,
	call: SingleSync
}

event set_item = {
	from: Client,
	type: Reliable,
	call: SingleSync,
	data: struct {
		item: string,
		amount: u32
	}
}

event trade_ready = {
	from: Client,
	type: Reliable,
	call: SingleSync,
}

-- * Server

event start_trade = {
	from: Server,
	type: Reliable,
	call: SingleSync,
	data: struct {
		who: Instance
	}
}

event obtain_item = {
	from: Server,
	type: Reliable,
	call: SingleSync,
	data: struct {
		obtained: string
	}
}

event trade_rejected = {
	from: Server,
	type: Reliable,
	call: SingleSync
}

event update_inventory = {
	from: Server,
	type: Reliable,
	call: SingleSync,
	data: map { [string]: u8 }
}

event set_item_offer = {
	from: Server,
	type: Reliable,
	call: SingleSync,
	data: struct {
		item: string,
		amount: u32
	}
}