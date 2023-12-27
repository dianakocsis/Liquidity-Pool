// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./SpaceCoin.sol";

contract Pool is ERC20 {

    SpaceCoin public immutable spaceCoin;
    uint256 public ethReserve;
    uint256 public spcReserve;
    uint public constant MINIMUM_LIQUIDITY = 10**3;
    uint112 private reserve0;           
    uint112 private reserve1;

    bool public locked;

    uint private unlocked = 1;

    error NoReentrancy();

    modifier lock() {
        require(unlocked == 1, 'LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Sync(uint112 reserve0, uint112 reserve1);

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


    function _update(uint balance0, uint balance1) private {
        require(balance0 <= 2**256-1 && balance1 <= 2**256-1, 'OVERFLOW');
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        emit Sync(reserve0, reserve1);
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

    function burn(address to) external lock returns(uint amount0, uint amount1) {
        uint liquidity = balanceOf(address(this));          // how many LP tokens this contract has
        uint totalSupply = totalSupply();                   // total supply of LP tokens
        amount0 = (liquidity * reserve0 ) / totalSupply;     // using balances ensures pro-rata distribution
        amount1 = (liquidity * reserve1) / totalSupply;     // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, 'INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(address(this), liquidity);
        SpaceCoin(spaceCoin).transfer(to, amount0);
        (bool success, ) = to.call{ value: amount1 }("");
        require(success, "WITHDRAW_FAILED");
        uint balance0 = address(this).balance;
        uint balance1 = SpaceCoin(spaceCoin).balanceOf(address(this));
        _update(balance0, balance1);
        emit Burn(msg.sender, amount0, amount1, to);

    }

    function swap(uint amountOut, address to, uint value) external lock {
        require(amountOut > 0, 'INSUFFICIENT_OUTPUT_AMOUNT');
        uint112 _reserve;
        if (value > 0) {
            (_reserve, ) = getReserves(); 
        }
        else {
            (, _reserve ) = getReserves(); 
        }
        require(amountOut < _reserve, 'INSUFFICIENT_LIQUIDITY');
        uint balance0;
        uint balance1;
        
        require(to != address(spaceCoin), 'INVALID_TO');
        if (value > 0) {
            if (amountOut > 0) SpaceCoin(address(spaceCoin)).transfer(to, amountOut); 
        }
        else {
            if (amountOut > 0) {
                (bool sent,) = to.call{value: amountOut}("");
            }
        }
        balance0 = SpaceCoin(spaceCoin).balanceOf(address(this));
        balance1 = address(this).balance;
        
        _update(balance0, balance1);
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