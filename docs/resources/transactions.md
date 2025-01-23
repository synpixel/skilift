# Transactions

Skilift provides built-in transactions as part of it's API. Transactions allow for editing multiple keys at the same time securely. This allows developers to easily write secure code for trading, marketplaecs, gifting etc.

## How do transactions work?

Transactions in skilift are baesd on the [two-phase commit protocol](https://en.wikipedia.org/wiki/Two-phase_commit_protocol).

## Escrowing

Escrowing is important for performing transactions safely. As transactions take time to apply, it's important to first escrow the goods before performing the transaction. In that case, when the transaction succeeds the goods have already been taken, so you only need to give the goods to the player. In the case it fails, we can return the escrowed goods.

Since skilift also supports running actions when the transaction fails, it's important that you return the escrowed goods if it fails.

```luau
-- bad, don't do this!

-- we don't escrow the money! while the transaction is processing, tom still
-- has access to their 10 coins.
local function success()
    tom:patch(reduce_money, 10)
    bob:patch(give_money, 10)
end

skilift.transaction(success)
```
```luau
-- good, do this!

local function success()
    bob:patch(give_money, 10)
end

local function failure()
    tom:patch(give_money, 10)
end

-- we escrow the money first, preventing tom from using that money and getting negative money!
tom:patch(reduce_money, 10)
skilift.transaction(success, failure)
```