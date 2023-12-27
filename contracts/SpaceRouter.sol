// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./Pool.sol";
import "./SpaceCoin.sol";

contract SpaceRouter {

    Pool public immutable pool;
    SpaceCoin public immutable spaceCoin;

    error FailedToSendEther();

    constructor(Pool _lp, SpaceCoin _spaceCoin) {
        pool = _lp;
        spaceCoin = _spaceCoin;
    }

    function addLiquidity(
        address _to,
        uint256 _amountSpc
    )
        external
        payable
        returns (uint256 amountEth, uint256 amountSpc, uint256 liquidity)
    {
        (uint256 ethReserve, uint256 spcReserve) = pool.getReserves();
        if (ethReserve == 0 && spcReserve == 0) {
            (amountEth, amountSpc) = (msg.value, _amountSpc);
        } else {
            amountSpc = msg.value * spcReserve / ethReserve;
            if (_amountSpc <= _amountSpc) {
                amountEth = _amountSpc * ethReserve / spcReserve;
            }

            if (spaceCoin.taxEnabled()) {
                uint256 spaceCoinDepositedAfterTax = (_amountSpc * 98) / 100;
                amountEth = spaceCoinDepositedAfterTax * ethReserve / spcReserve;
            }
         }
        bool success = spaceCoin.transferFrom(msg.sender, address(pool), amountSpc);
        if (!success) {
            revert();
        }
        (bool sent,) = address(pool).call{value: amountEth}("");
        if (!sent) {
            revert FailedToSendEther();
        }
        liquidity = pool.mint(_to);
        if (msg.value > amountEth) {
            (success,) = msg.sender.call{value: msg.value - amountEth}("");
            if (!success) {
                revert FailedToSendEther();
            }
        }
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        uint liquidity,
        address to
    ) public returns (uint amount0, uint amount1) {
        Pool(pool).transferFrom(msg.sender, address(pool), liquidity); // send liquidity to pool
        (amount0, amount1) = Pool(pool).burn(to);
    }

    function swapExactTokensForETH(
        address token,
        uint amountIn,
        address to
    ) external returns (uint amount) {
        amount = _getOut(amountIn);
        SpaceCoin(token).transferFrom(
            msg.sender, address(pool), amountIn
        );
        Pool(pool).swap(amount, address(this), 0);
    }

    function swapExactETHForTokens(
        address token,
        address to
    ) external payable returns (uint amount) {
        amount = _getOut(msg.value);
        (bool sent,) = address(pool).call{value: msg.value}("");
        if (!sent) {
            revert FailedToSendEther();
        }
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