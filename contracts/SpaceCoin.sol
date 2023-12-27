// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./SpaceICO.sol";

/// @title SpaceCoin ERC20 token
contract SpaceCoin is ERC20("SpaceCoin", "SPC") {

    address public immutable treasury;
    address public immutable owner;
    address payable public immutable ico;
    bool public taxEnabled;

    event TaxToggled(bool indexed enabled);

    error OnlyOwner(address sender, address owner);
    error NoChangeInTax();

    /// @notice Mint tokens to the ICO and treasury
    /// @param _owner The owner of the contract
    /// @param _treasury The address of the treasury
    constructor(address _owner, address _treasury, address[] memory _allowList) {
        owner = _owner;
        ico = payable(address(new ICO(owner, this, _allowList)));
        treasury = _treasury;
        _mint(ico, 150_000 * 10 ** decimals());
        _mint(treasury, 350_000 * 10 ** decimals());
    }

    /// @notice Enables or disables the tax
    /// @dev Only the owner of the contract can call this function
    function toggleTax(bool _shouldTax) external {
        if (msg.sender != owner) {
            revert OnlyOwner(msg.sender, owner);
        }
        if (_shouldTax == taxEnabled) {
            revert NoChangeInTax();
        }
        taxEnabled = !taxEnabled;
        emit TaxToggled(taxEnabled);
    }

    /// @notice If the tax is enabled, 2% of the amount is sent to the treasury
    /// @param from The address to transfer from
    /// @param to The address to transfer to
    /// @param value The amount to transfer
    function _update(address from, address to, uint256 value) internal virtual override {
        if (taxEnabled) {
            uint256 taxAmount = value / 50;
            value -= taxAmount;
            super._update(from, treasury, taxAmount);
        }
        super._update(from, to, value);
    }
}
