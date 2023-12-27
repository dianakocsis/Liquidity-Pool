# The SpaceCoin Liquidity Pool Project

## Project Spec

### ERC20 & ICO Updates

- Add a withdraw function to your ICO contract that allows you to moves the invested funds out of the ICO contract and into the treasury address.

### Liquidity Pool Contract

Implement a liquidity pool for ETH-SPC. You will need to:

- Write an ERC-20 contract for your pool's LP tokens.
- Write a liquidity pool contract that
  - Mints LP tokens for liquidity deposits (ETH + SPC tokens)
  - Burns LP tokens to return liquidity to holder
  - Accepts trades with a 1% fee

### SpaceRouter

Transferring tokens to an LP pool requires two transactions:

1. Trader grants allowance on the Router contract for Y tokens.
2. Trader executes a function on the Router which pulls the funds from the Trader and transfers them to the LP Pool.

Write a router contract to handles these transactions. Be sure it can:

- Add / remove liquidity, without wasting or donating user funds.
- Swap tokens, allowing traders to specify a minimum amount out for the output token.

&nbsp;

## Code Coverage Report

------------------|----------|----------|----------|----------|----------------|
File | % Stmts | % Branch | % Funcs | % Lines |Uncovered Lines |
------------------|----------|----------|----------|----------|----------------|
contracts/ | 99.07 | 77.5 | 100 | 91.76 | |
Pool.sol | 97.56 | 56.25 | 100 | 90.77 |... 123,132,163 |
SpaceCoin.sol | 100 | 100 | 100 | 100 | |
SpaceICO.sol | 100 | 91.3 | 100 | 94.23 | 97,131,135 |
SpaceRouter.sol | 100 | 75 | 100 | 87.76 |... ,86,115,146 |
------------------|----------|----------|----------|----------|----------------|
All files | 99.07 | 77.5 | 100 | 91.76 | |
------------------|----------|----------|----------|----------|----------------|

&nbsp;

## Testnet Deploy Information
