// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./SpaceCoin.sol";

contract Pool is ERC20 {

    SpaceCoin public immutable spaceCoin;
    uint public constant MINIMUM_LIQUIDITY = 10**3;
    uint112 private reserve0;           
    uint112 private reserve1;

    uint private unlocked = 1;
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

    function _update(uint balance0, uint balance1) private {
        require(balance0 <= 2**256-1 && balance1 <= 2**256-1, 'OVERFLOW');
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        emit Sync(reserve0, reserve1);
    }

    function mint(address to) external lock returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1) = getReserves(); 
        uint balance0 = SpaceCoin(spaceCoin).balanceOf(address(this));
        uint balance1 = address(this).balance;
        uint amount0 = balance0 - _reserve0;
        uint amount1 = balance1 - _reserve1;
        uint totalSupply = totalSupply();
        // first time total supply is 0
        if (totalSupply == 0) {
            liquidity = _sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
        }
        else {
            liquidity = _min((amount0 * totalSupply) / _reserve0,
                                 (amount1 * totalSupply) / _reserve1);
        }
        require(liquidity > 0, 'INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);                                       // mint these LP tokens to the address
        _update(balance0, balance1);                                // update reserves
        emit Mint(msg.sender, amount0, amount1);
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