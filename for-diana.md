https://github.com/dlk61/Liquidity-Pool

The following is a micro audit of git commit fa32d77470e054124f4971545ea1c0c206233a07 by Theo.

## General comments

- Impressive work!

- SpaceRouter should not have special permission to transfer SPC tokens. The router contract should only be a helper; in theory, anyone should be able to write a contract like your router contract and successfully interact with your pool contract.

## issue-1

**[Medium]** `Pool.burn` ignores return value from `SpaceCoin.transfer`

Use SafeERC20, or ensure that the transfer return value is checked.
This is also true in `Pool.swap`

## nitpicks
- you could set `unlocked` to be a bool instead of a uint in `Pool.sol`