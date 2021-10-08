# Liquidity-Pool

Project: SpaceCoin Pool

In this project you're going to extend your previous project by writing a liquidity pool contract. In doing so you will:

Learn how liquidity pools work
Write a Uniswap v2 style liquidity pool contract
Deploy to a testnet
Update your Space ICO contract to move its funds to your pool contract
Extend your frontend for yield farmers to manage their ETH-SPC LP tokens
Context

Read the context document.

Then read the uniswap document.

The SpaceCoin Liquidity Pool

Previously, you wrote an ERC-20 contract for SPC and an ICO contract to get the token off the ground.

Now, it's time to finish bootstrapping your token's ecosystem by writing a liquidity pool contract so your users can buy and sell SPC at will.

ERC-20 & ICO Updates

You may have noticed that your ICO contract spec had nothing to say about its invested ETH funds. With a liquidity contract now in the picture, that's going to change.

Update your contracts to:

Add a withdraw function to your ICO contract that allows you to moves the invested funds to your liquidity contract. How exactly you do this is up to you; just make sure it's possible to deposit an even worth of each asset.
Liquidity Pool Contract

Implement a liquidity pool for ETH-SPC. You will need to:

Write an ERC-20 contract for your pool's LP tokens.
Write a liquidity pool contract that:
Mints LP tokens for liquidity deposits (ETH + SPC tokens)
Burns LP tokens to return liquidity to holder
Accepts trades with a 1% fee
Note that platforms usually require you to deposit your LP tokens after you've minted them. In this project there's no need for that step.
SpaceRouter

Transferring tokens to an LP pool requires two transactions:

Trader grants allowance to contract X for Y tokens
Trader invokes contract X to make the transfer
Write a router contract to handles these transactions. Be sure it can:

Add / remove liquidity
Swap tokens, rejecting if the slippage is above a given amount
Frontend

Extend your frontend to add two additional sections (or tabs if you like):

LP Management
Allow users to deposit ETH and SPC for LP tokens (and vice-versa)
Example, but take note you only need to support one trade pair: https://pancakeswap.finance/liquidity
Trading
Allow users to trade ETH for SPC (and vice-versa)
Be sure to show the estimated trade value they will be receiving
Example, but take note you only need to support one trade pair: https://pancakeswap.finance/swap
Project Extensions

If you finish early, you can:

Allow the user to configure their slippage tolerance
Add a feature that rewards additional SPC tokens over time for LP holders to further incentivize yield farmers to participate in your pool.
Add a 3% withdraw fee if an LP holder withdraws within 72h of depositing.
Research how you would implement a pool that integrates with Uniswap's ecosystem.