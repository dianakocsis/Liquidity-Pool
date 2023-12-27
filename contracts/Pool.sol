// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./SpaceCoin.sol";

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

    constructor(string memory _name, string memory _symbol, SpaceCoin _spaceCoin) ERC20(_name, _symbol) {
        spaceCoin = _spaceCoin;
    }

    modifier nonReentrant() {
        if (locked) {
            revert NoReentrancy();
        }
        locked = true;
        _;
        locked = false;
    }

    function getReserves() external view returns (uint256, uint256) {
        return (ethReserve, spcReserve);
    }

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
            revert();
        }

        (bool sent,) = _to.call{value: ethAmount}("");
        if (!sent) {
            revert FailedToSendEther();
        }

        ethReserve = address(this).balance;
        spcReserve = spaceCoin.balanceOf(address(this));
    }

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
                revert();
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

    receive() external payable {}

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

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
