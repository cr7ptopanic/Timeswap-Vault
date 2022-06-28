# Timeswap Vault

A fund manager style protocol holds the funds of users and have a privilege manager invest the funds into Timeswap pools based on a specific strategy.

The Timevault with single pair weekly lend strategy is a vault where the funds can only be lent to pools of a specific pair. It can only do so onto pools that matures weekly. The goal is to maximize weekly returns while minimizing probability of loss.

## Rules

### Users
- Users can deposit underlying tokens to the vault.
- Near the end of the week, users can request to withdraw their investmemt. It is not must. If users don't request, their investment are roll overed next week. Reward will be accumulated automatically. Once users request to withdraw their investment, the withdraw amount of users can not take part in next vault lending.
- Users can cancel their investment before maturity and cancelled amount can take part in lednding from the next round.
- Users can get their investment after maturity if they requested.

### Vault manager
- Vault manager can lend any amount of underlying tokens in the vault to any of the pools in any time.
- After getting rewards from the timeswap pools after maturity, manager swaps collateral tokens to underlying tokens which users deposited by using DEX(UniswapV2Router). As a result, users can get the rewards according their deposit amount.
```shell
For example: 
    Say we have user A and B and manager.
    A deposits 1000, and B deposits 1500 for a total of 2500 in the vault. 
    Now A has 40% of the vault and B has 60%.

    Manager invests 500(20 %of the vault) to the X1.2 reward pool. After maturity 600 => reward 100
    Manager invests 1000(40 % of the vault) to the X1.4 reward pool. After maturity 1400 => reward 400
    1000(40% of the vault) is left in the vault.

    So after maturity, 600 + 1400 + 1000 = 3000 in the vault

    A(1000 deposited) should be able to withdraw 1200.
    Reward of A = 100 * 1000 / 2500 + 400 * 1000 / 2500 = 200

    B(1500 deposited) should be able to withdraw 1800.
    Reward of B = 100 * 1500 / 2500 + 400 * 1500 / 2500 = 300
```
- As above example, we can calculate user's reward after close lend position.

### Rewards formula

- User's rewards after nth lend position are sum of each rewards from lend round when user withdraw the last time to n.

    **URn = Σn (Rn * Dn / Tn)**

- URn = User's rewards when after nth lend position is closed.
- Rn = Total rewards when after nth lend position is closed.
- Dn = User's deposit amount which take part in nth lending.
- Tn = Total deposit amount which take participate in nth lending.
- n > Lend round when user withdraw the last time.
    
