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

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'INSUFFICIENT_LIQUIDITY');
        amountB = amountA * reserveB / reserveA;
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        uint amountSPCDesired
    ) private returns (uint amountA, uint amountB) {
        (uint reserve0, uint reserve1 ) = Pool(pool).getReserves();
        if (reserve0 == 0 && reserve1 == 0) {
            (amountA, amountB) = (amountSPCDesired, msg.value);
        }
        else {
            uint amountETHOptimal = quote(amountSPCDesired, reserve0, reserve1);
            if (amountETHOptimal <= msg.value) {
                (amountA, amountB) = (amountSPCDesired, msg.value);
            } else {
                uint amountSPCOptimal = quote(msg.value, reserve1, reserve0);
                assert(amountSPCOptimal <= amountSPCDesired);
                (amountA, amountB) = (amountSPCOptimal, msg.value);
            }
        }
    }

    function addLiquidity(
        address token,
        uint amountTokenDesired,
        address to
    ) external payable returns (uint amountSPC, uint amountETH, uint liquidity) {
        (amountSPC, amountETH) = _addLiquidity(amountTokenDesired);
        TransferHelper.safeTransferFrom(token, msg.sender, pool, amountSPC);
        (bool success, ) = pool.call{ value: amountETH }("");
        require(success, "WITHDRAW_FAILED");
        liquidity = Pool(pool).mint(to);
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
        TransferHelper.safeTransferFrom(
            token, msg.sender, pool, amountIn
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
        TransferHelper.safeTransfer(
            token, to, amount
        );
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
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn * 999; // 1% trading fee
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    receive() external payable {}
 

    
    
}