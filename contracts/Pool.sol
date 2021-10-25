// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import './SpaceLib.sol';
import './SpaceCoin.sol';
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import '@uniswap/lib/contracts/libraries/Babylonian.sol';
import "@openzeppelin/contracts/utils/math/Math.sol";
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';


contract Pool is ERC20 {

    uint public constant MINIMUM_LIQUIDITY = 10**3;
    address public spaceCoin;
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

    constructor() ERC20("Space LP Token", "SPCLP"){
    }

    function initialize(address _spaceCoin) external {
        require(spaceCoin == address(0x0), "WRITE_ONCE");
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
            liquidity = Babylonian.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
        }
        else {
            liquidity = Math.min((amount0 * totalSupply) / _reserve0,
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
        
        address _spaceCoin = spaceCoin;
        require(to != _spaceCoin, 'INVALID_TO');
        if (value > 0) {
            if (amountOut > 0) SpaceCoin(_spaceCoin).transfer(to, amountOut); 
        }
        else {
            if (amountOut > 0) TransferHelper.safeTransferETH(to, amountOut); 
        }
        balance0 = SpaceCoin(spaceCoin).balanceOf(address(this));
        balance1 = address(this).balance;
        
        _update(balance0, balance1);
    }
    
    receive() external payable {}


}