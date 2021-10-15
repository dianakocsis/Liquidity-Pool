// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import './SpaceLib.sol';
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SpaceCoin is ERC20, Ownable {

    bool public shouldTax;
    address public treasury;
    uint constant public EXCHANGE_RATE = 5;

    constructor(address _ico, address _treasury) ERC20("Space", "SPC") {
        uint icoAmount = 2 * ( SpaceLib.ONE_COIN * 30000 * EXCHANGE_RATE);
        _mint(_ico, icoAmount);                             // ico has 300K space coins
        _mint(_treasury, SpaceLib.MAX_COINS - icoAmount);   // treasury has 200K space coins
        treasury = _treasury;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual override {
        require(amount > 0, "Amount is zero");
        if (shouldTax) {
            uint taxAmount = amount * 2 / 100;
            amount -= taxAmount;
            super._transfer(sender, treasury, taxAmount);
        }
        super._transfer(sender, recipient, amount);
    }

    function toggleTax(bool _shouldTax) external onlyOwner {
        shouldTax = _shouldTax;
    } 
}