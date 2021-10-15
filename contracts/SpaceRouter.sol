// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import './Pool.sol';
import './SpaceCoin.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

contract SpaceRouter {

    address payable pool;

    constructor(address _pool) {
        pool = payable(_pool);
    }

    function addLiquidity(
        address token,
        uint amountToken,
        address to
    ) external payable returns (uint liquidity) {
        SpaceCoin(token).transferFrom(msg.sender, pool, amountToken);       // transfer amountSpc tokens from msg.sender to the pool
        (bool success, ) = pool.call{ value: msg.value }("");                        // transfer eth (msg.value) to the pool
        require(success, "WITHDRAW_FAILED");
        liquidity = Pool(pool).mint(to);                                             // mint LP tokens for the liquidity provider
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        uint liquidity,
        address to
    ) public returns (uint amount0, uint amount1) {
        Pool(pool).transferFrom(msg.sender, pool, liquidity); // send liquidity to pool
        (amount0, amount1) = Pool(pool).burn(to);
    }

    function swapExactTokensForETH(
        address token,
        uint amountIn,
        address to
    ) external returns (uint amount) {
        amount = _getOut(amountIn);
        SpaceCoin(token).transferFrom(
            msg.sender, pool, amountIn
        );
        Pool(pool).swap(amount, address(this), 0);
        TransferHelper.safeTransferETH(to, amount);
    }

    function swapExactETHForTokens(
        address token,
        address to
    ) external payable returns (uint amount) {
        amount = _getOut(msg.value);
        TransferHelper.safeTransferETH(pool, msg.value);
        Pool(pool).swap(amount, address(this), msg.value);
        SpaceCoin(token).transfer(to, amount);
    }

    function _getOut(uint amountIn) internal returns (uint amountOut) {
        require(amountIn > 0, 'INSUFFICIENT_INPUT_AMOUNT');
        uint reserveOut;
        uint reserveIn;
        if (msg.value > 0) {
            (reserveOut, reserveIn ) = Pool(pool).getReserves();
        }
        else {
            (reserveIn, reserveOut ) = Pool(pool).getReserves();
        }
        require(reserveIn > 0 && reserveOut > 0, 'INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn * 999; // 1% trading fee
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    receive() external payable {}
 
}