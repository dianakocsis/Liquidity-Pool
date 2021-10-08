// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import './SpaceLib.sol';
import './SpaceCoin.sol';
import './SpaceICO.sol';
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import '@uniswap/lib/contracts/libraries/Babylonian.sol';
import "@openzeppelin/contracts/utils/math/Math.sol";
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';


contract Pool is ERC20 {

    uint public constant MINIMUM_LIQUIDITY = 10**3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));
    address public spaceCoin;
    address public spaceICO;
    uint112 private reserve0;           
    uint112 private reserve1;

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'UniswapV2: TRANSFER_FAILED');
    }

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor() ERC20("Space LP Token", "SPCLP"){
    }

    function initialize(address _spaceCoin, address _spaceICO) external {
        require(spaceCoin == address(0x0), "WRITE_ONCE");
        spaceCoin = _spaceCoin;
        spaceICO = _spaceICO;
    }

    function _update(uint balance0, uint balance1) private {
        require(balance0 <= 2**112-1 && balance1 <= 2**112-1, 'OVERFLOW');
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        emit Sync(reserve0, reserve1);
    }

    function mint(address to) external returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1) = getReserves(); // gas savings
        uint balance0 = SpaceCoin(spaceCoin).balanceOf(address(this));
        uint balance1 = address(this).balance;
        uint amount0 = balance0 - _reserve0;
        uint amount1 = balance1 - _reserve1;
        uint totalSupply = totalSupply();
        if (totalSupply == 0) {
            liquidity = Babylonian.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
        }
        else {
            liquidity = Math.min((amount0 * totalSupply) / _reserve0,
                                 (amount1 * totalSupply) / _reserve1);
        }
        require(liquidity > 0, 'INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);
        _update(balance0, balance1);
        emit Mint(msg.sender, amount0, amount1);
    }



    function burn(address to) external returns(uint amount0, uint amount1) {
        address _spaceCoin = spaceCoin;
        uint balance0 = SpaceCoin(spaceCoin).balanceOf(address(this)); // how much this liquidity pool has of spaceCoin
        uint balance1 = address(this).balance;              // how much this liquidity pool has of ether
        uint liquidity = balanceOf(address(this));             
        uint totalSupply = totalSupply();                   // total supply of LP tokens
        amount0 = (liquidity * balance0 ) / totalSupply;     // using balances ensures pro-rata distribution
        amount1 = (liquidity * balance1) / totalSupply;     // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, 'INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(address(this), liquidity);
        _safeTransfer(_spaceCoin, to, amount0);
        (bool success, ) = to.call{ value: amount1 }("");
        require(success, "WITHDRAW_FAILED");
        balance0 = address(this).balance;
        balance1 = SpaceCoin(spaceCoin).balanceOf(address(this));
        _update(balance0, balance1);
        emit Burn(msg.sender, amount0, amount1, to);

    }

        // this low-level function should be called from a contract which performs important safety checks
    function swap(uint amountOut, address to, uint value) external {
        require(amountOut > 0, 'INSUFFICIENT_OUTPUT_AMOUNT');
        uint112 _reserve1;
        if (value > 0) {
            (_reserve1, ) = getReserves(); // gas savings
        }
        else {
            (, _reserve1 ) = getReserves(); // gas savings
        }
        require(amountOut < _reserve1, 'INSUFFICIENT_LIQUIDITY');
        uint balance0;
        uint balance1;
        { 
        address _spaceCoin = spaceCoin;
        require(to != _spaceCoin, 'INVALID_TO');
        if (value > 0) {
            if (amountOut > 0) _safeTransfer(_spaceCoin, to, amountOut); // optimistically transfer tokens
        }
        else {
            if (amountOut > 0) TransferHelper.safeTransferETH(to, amountOut); // optimistically transfer tokens
        }
        balance0 = SpaceCoin(spaceCoin).balanceOf(address(this));
        balance1 = address(this).balance;
        }
        _update(balance0, balance1);
    }
    
    receive() external payable {}


}