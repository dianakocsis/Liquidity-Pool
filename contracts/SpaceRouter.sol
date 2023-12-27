// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./Pool.sol";
import "./SpaceCoin.sol";

/// @title Router contract
contract SpaceRouter {

    Pool public immutable pool;
    SpaceCoin public immutable spaceCoin;

    error FailedToSendEther();
    error InsufficientAmount();
    error InsufficientLiquidity();
    error InsufficientOutputAmount(uint256 out, uint256 min);

    /// @notice Sets the Pool and SpaceCoin contracts
    constructor(Pool _lp, SpaceCoin _spaceCoin) {
        pool = _lp;
        spaceCoin = _spaceCoin;
    }

    /// @notice Adds spaceCoin and Ether liquidity to the pool
    /// @param _to The address to mint the liquidity tokens to
    /// @param _amountSpc The amount of SpaceCoin to add
    /// @return amountEth The amount of Ether added
    /// @return amountSpc The amount of SpaceCoin added
    /// @return liquidity The amount of liquidity tokens minted
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

    /// @notice Removes spaceCoin and Ether liquidity from the pool
    /// @param _liquidity The amount of liquidity tokens to burn
    /// @param _to The address to send the Ether and SpaceCoin to
    /// @return ethAmount The amount of Ether returned
    /// @return spcAmount The amount of SpaceCoin returned
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

    /// @notice Swaps SpaceCoin for Ether
    /// @param _amountSpcIn The amount of SpaceCoin to swap
    /// @param _minEthOut The minimum amount of Ether to receive
    /// @param _to The address to send the Ether to
    /// @return amountEthOut The amount of Ether received
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

    /// @notice Swaps Ether for SpaceCoin
    /// @param _minSpcOut The minimum amount of SpaceCoin to receive
    /// @param _to The address to send the SpaceCoin to
    /// @return amountSpcOut The amount of SpaceCoin received
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
