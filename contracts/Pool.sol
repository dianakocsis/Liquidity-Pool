// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./SpaceCoin.sol";

/// @title Pool contract
contract Pool is ERC20 {

    SpaceCoin public immutable spaceCoin;
    uint256 public ethReserve;
    uint256 public spcReserve;
    bool public locked;

    event Mint(address indexed sender, uint256  ethAmount, uint256  spcAmount);
    event Burn(address indexed sender, uint256  ethAmount, uint256  spcAmount, address indexed to);

    error NoReentrancy();
    error InsufficientLiquidity();
    error InsufficientLiquidityBurned();
    error FailedToSendEther();
    error FailedToTransferSpc();

    /// @notice Sets the SpaceCoin contract
    /// @param _name The name of the token
    /// @param _symbol The symbol of the token
    /// @param _spaceCoin The SpaceCoin contract
    constructor(string memory _name, string memory _symbol, SpaceCoin _spaceCoin) ERC20(_name, _symbol) {
        spaceCoin = _spaceCoin;
    }

    /// @dev Modifier to check if the contract is locked
    modifier nonReentrant() {
        if (locked) {
            revert NoReentrancy();
        }
        locked = true;
        _;
        locked = false;
    }

    /// @notice Gets the reserves of the pool
    function getReserves() external view returns (uint256, uint256) {
        return (ethReserve, spcReserve);
    }

    /// @notice Mints liquidity tokens
    /// @param _to The address to mint to
    /// @return liquidity The amount of liquidity tokens minted
    function mint(address _to) external nonReentrant returns (uint256 liquidity) {
        uint256 ethBalance = address(this).balance;
        uint256 spcBalance = spaceCoin.balanceOf(address(this));
        uint256 ethAmount = ethBalance - ethReserve;
        uint256 spcAmount = spcBalance - spcReserve;

        emit Mint(msg.sender, ethAmount, spcAmount);

        if (totalSupply() == 0) {
            liquidity = _sqrt(ethAmount * spcAmount);
        } else {
            liquidity = _min(
                ethAmount * totalSupply() / ethReserve,
                spcAmount * totalSupply() / spcReserve
            );
        }

        ethReserve = ethBalance;
        spcReserve = spcBalance;

        _mint(_to, liquidity);
    }

    /// @notice Burns liquidity tokens
    /// @param _to The address to send the tokens and ether to
    /// @return ethAmount The amount of ether sent
    /// @return spcAmount The amount of SpaceCoin sent
    function burn(address _to) external nonReentrant returns (uint256 ethAmount, uint256 spcAmount) {
        uint256 ethBalance = address(this).balance;
        uint256 spcBalance = spaceCoin.balanceOf(address(this));
        uint256 liquidity = balanceOf(address(this));
        uint256 totalSupply = totalSupply();

        ethAmount = liquidity * ethBalance / totalSupply;
        spcAmount = liquidity * spcBalance / totalSupply;

        if (ethAmount == 0 || spcAmount == 0) {
            revert InsufficientLiquidityBurned();
        }

        emit Burn(msg.sender, ethAmount, spcAmount, _to);

        _burn(address(this), liquidity);

        bool success = spaceCoin.transfer(_to, spcAmount);
        if (!success) {
            revert FailedToTransferSpc();
        }

        (bool sent,) = _to.call{value: ethAmount}("");
        if (!sent) {
            revert FailedToSendEther();
        }

        ethReserve = address(this).balance;
        spcReserve = spaceCoin.balanceOf(address(this));
    }

    /// @notice Swaps ether for SpaceCoin or SpaceCoin for ether
    /// @param _to The address to send the tokens or ether to
    /// @return out The amount of ether or SpaceCoin sent
    function swap(address _to) external nonReentrant returns (uint256 out) {
        uint256 ethBalance = address(this).balance;
        uint256 spcBalance = spaceCoin.balanceOf(address(this));
        uint256 ethAmount = ethBalance - ethReserve;
        uint256 spcAmount = spcBalance - spcReserve;
        if (ethAmount > 0) {
            uint256 amountEthWithFee = ethAmount * 99;
            uint256 numerator = amountEthWithFee * spcReserve;
            uint256 denominator = ethReserve * 100 + amountEthWithFee;
            out = (numerator / denominator);
            bool success = spaceCoin.transfer(_to, out);
            if (!success) {
                revert FailedToTransferSpc();
            }
        } else if (spcAmount > 0) {
            uint256 amountSpcWithFee = spcAmount * 99;
            uint256 numerator = amountSpcWithFee * ethReserve;
            uint256 denominator = spcReserve * 100 + amountSpcWithFee;
            out = (numerator / denominator);
            (bool sent,) = _to.call{value: out}("");
            if (!sent) {
                revert FailedToSendEther();
            }
        }

        ethReserve = address(this).balance;
        spcReserve = spaceCoin.balanceOf(address(this));
    }

    /// @notice Allows the contract to receive ether
    receive() external payable {}

    /// @notice Determines the minimum of two values
    /// @param a The first value
    /// @param b The second value
    /// @return The minimum of the two values
    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /// @notice Calculates the square root of a number
    /// @param y The number to calculate the square root of
    /// @return z The square root of the number
    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
