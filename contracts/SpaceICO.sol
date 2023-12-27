// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./SpaceCoin.sol";

/// @title ICO contract
contract ICO {

    enum Phase {
        SEED,
        GENERAL,
        OPEN
    }

    uint256 public constant EXCHANGE_RATE = 5;
    uint256 public constant MAX_INDIVIDUAL_SEED_LIMIT = 1500 ether;
    uint256 public constant MAX_TOTAL_SEED_LIMIT = 15000 ether;
    uint256 public constant MAX_INDIVIDUAL_GENERAL_LIMIT = 1000 ether;
    uint256 public constant MAX_CONTRIBUTION = 30000 ether;
    SpaceCoin public immutable spaceCoin;
    address public immutable owner;
    Phase public phase;
    uint256 public totalContribution;
    mapping(address => uint256) public contributions;
    mapping(address => bool) public allowList;
    bool public paused;

    event Contributed(address indexed contributor, uint256 indexed amount);
    event Redeemed(address indexed redeemer, uint256 indexed amount);
    event PhaseAdvanced(Phase indexed newPhase);
    event Paused();
    event Unpaused();

    error OnlyOwner(address sender, address owner);
    error CannotContribute(uint256 amount, uint256 limit);
    error AlreadyUnpaused();
    error AlreadyPaused();
    error CannotRedeem(Phase currentPhase, Phase expectedPhase);
    error CannotAdvance();
    error NoContributions();
    error CannotWithdraw(uint256 amount, uint256 max);
    error FailedToWithdrawEth();
    error FailedToTransferSpc();

    /// @param _owner The owner of the contract
    /// @param _allowList The list of addresses allowed to contribute
    constructor(address _owner, SpaceCoin _spaceCoin, address[] memory _allowList) {
        owner = _owner;
        spaceCoin = _spaceCoin;
        for (uint i = 0; i < _allowList.length; i++) {
            allowList[_allowList[i]] = true;
        }
    }

    /// @dev Modifier to check if the sender is the owner
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert OnlyOwner(msg.sender, owner);
        }
        _;
    }

    /// @dev Modifier to check if the contract is paused
    modifier notPaused() {
        if (paused) {
            revert AlreadyPaused();
        }
        _;
    }

    /// @notice Contributes to the ICO
    /// @dev The contribution is only allowed if the contract is not paused
    function contribute() external payable notPaused {
        if (msg.value > availableToContribute(msg.sender)) {
            revert CannotContribute(msg.value, availableToContribute(msg.sender));
        }
        contributions[msg.sender] += msg.value;
        totalContribution += msg.value;
        emit Contributed(msg.sender, msg.value);
    }

    /// @notice Redeems the tokens
    /// @dev The tokens can only be redeemed if the contract is not paused and the phase is open
    function redeem() external notPaused {
        if (phase != Phase.OPEN) {
            revert CannotRedeem(phase, Phase.OPEN);
        }
        if (contributions[msg.sender] == 0) {
            revert NoContributions();
        }
        uint256 redeemed = contributions[msg.sender] * EXCHANGE_RATE;
        contributions[msg.sender] = 0;
        emit Redeemed(msg.sender, redeemed);
        (bool success) = spaceCoin.transfer(msg.sender, redeemed);
        if (!success) {
            revert FailedToTransferSpc();
        }
    }

    /// @notice Advances the phase
    /// @param _current The current phase
    /// @dev The phase can only be advanced if the sender is the owner
    function advancePhase(Phase _current) external onlyOwner {
        if (phase != _current) {
            revert CannotAdvance();
        }
        phase = Phase(uint8(_current) + 1);
        emit PhaseAdvanced(phase);
    }

    /// @notice Pauses the contract
    /// @dev The contract can only be paused if it is not already paused
    function pause() external onlyOwner notPaused {
        paused = true;
        emit Paused();
    }

    /// @notice Unpauses the contract
    /// @dev The contract can only be unpaused if it is already paused
    function unpause() external onlyOwner {
        if (!paused) {
            revert AlreadyUnpaused();
        }
        paused = false;
        emit Unpaused();
    }

    function withdraw(uint256 amount) external onlyOwner {
        if (address(this).balance < amount) {
            revert CannotWithdraw(amount, address(this).balance);
        }
        (bool sent,) = spaceCoin.treasury().call{value: amount}("");
        if (!sent) {
            revert FailedToWithdrawEth();
        }
    }

    /// @notice Returns the amount available to contribute for a user
    /// @param _user The user to check
    /// @return The amount available to contribute
    function availableToContribute(address _user) public view returns (uint256) {
        if (phase == Phase.SEED) {
            if (!allowList[_user]) {
                return 0;
            }
            return min(MAX_INDIVIDUAL_SEED_LIMIT - contributions[_user], fundingCapacity());
        } else if (phase == Phase.GENERAL) {
            if (contributions[_user] < MAX_INDIVIDUAL_GENERAL_LIMIT) {
                return min(MAX_INDIVIDUAL_GENERAL_LIMIT - contributions[_user], fundingCapacity());
            }
            return 0;
        } else {
            return fundingCapacity();
        }
    }

    /// @notice Returns the amount of funding capacity left
    /// @return The amount of funding capacity left
    function fundingCapacity() public view returns (uint256) {
        if (phase == Phase.SEED) {
            return MAX_TOTAL_SEED_LIMIT - totalContribution;
        }
        return MAX_CONTRIBUTION - totalContribution;
    }

    /// @notice Returns the minimum of two numbers
    /// @param _a The first number
    /// @param _b The second number
    function min(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a < _b ? _a : _b;
    }
}
