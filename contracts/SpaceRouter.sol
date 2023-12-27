// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./Pool.sol";
import "./SpaceCoin.sol";

contract SpaceRouter {

    Pool public immutable pool;
    SpaceCoin public immutable spaceCoin;

    error FailedToSendEther();
    error InsufficientAmount();
    error InsufficientLiquidity();
    error InsufficientOutputAmount(uint256 out, uint256 min);

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

    function removeLiquidity(
        uint256 _liquidity,
        address _to
    )
        external
        returns (uint256 ethAmount, uint256 spcAmount)
    {
        bool success = pool.transferFrom(msg.sender, address(pool), _liquidity);
        if (!success) {
            revert();
        }
        (ethAmount, spcAmount) = pool.burn(_to);
    }

    function swapSpcForEth(
        uint256 _amountSpcIn,
        uint256 _minEthOut,
        address _to
    )
        external
        returns (uint256 amountEthOut)
    {
        if (_amountSpcIn == 0) {
            revert InsufficientAmount();
        }

        (uint256 ethReserve, uint256 spcReserve) = pool.getReserves();
        if (ethReserve == 0 || spcReserve == 0) {
            revert InsufficientLiquidity();
        }

        bool success = spaceCoin.transferFrom(msg.sender, address(pool), _amountSpcIn);
        if (!success) {
            revert();
        }
        amountEthOut = pool.swap(_to);

        if (amountEthOut < _minEthOut) {
            revert InsufficientOutputAmount(amountEthOut, _minEthOut);
        }
    }

    function swapEthForSpc(
        uint256 _minSpcOut,
        address _to
    )
        external payable
        returns (uint256 amountSpcOut)
    {
        if (msg.value == 0) {
            revert InsufficientAmount();
        }

        (uint256 ethReserve, uint256 spcReserve) = pool.getReserves();
        if (ethReserve == 0 || spcReserve == 0) {
            revert InsufficientLiquidity();
        }

        (bool sent,) = address(pool).call{value: msg.value}("");
        if (!sent) {
            revert FailedToSendEther();
        }
        amountSpcOut = pool.swap(_to);
        if (amountSpcOut < _minSpcOut) {
            revert InsufficientOutputAmount(amountSpcOut, _minSpcOut);
        }
    }
}