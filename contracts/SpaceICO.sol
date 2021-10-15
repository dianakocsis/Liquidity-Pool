// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import './SpaceLib.sol';
import './SpaceCoin.sol';
import './Pool.sol';
import './SpaceRouter.sol';
import "@openzeppelin/contracts/utils/math/Math.sol";
import '@uniswap/lib/contracts/libraries/Babylonian.sol';
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract SpaceICO is Ownable, Pausable {
    uint constant public ICO_EXCHANGE_RATE = 5;
    uint constant public SEED_LIMIT = 15000 ether;
    uint constant public GENERAL_LIMIT = 30000 ether;

    uint constant public SEED_IND_LIMIT = 1500 ether;
    uint constant public GENERAL_IND_LIMIT = 100 ether;

    SpaceCoin spaceCoin;
    SpaceRouter sr;
    address payable lpool;
    address treasury;

    Phase public phase;
    uint public totalContributed;
    mapping(address=>uint) contributions;
    mapping(address=>bool) isSeedInvestor; 

    enum Phase {
        Seed,
        General,
        Open
    }

    constructor(address _lPool, address _treasury) {
        lpool = payable(_lPool);
        treasury = _treasury;
    }

    function setSpaceCoinAddress(SpaceCoin _spaceCoin) external {
        require(address(spaceCoin) == address(0x0), "WRITE_ONCE");
        spaceCoin = _spaceCoin;
    }

    function setSpaceRouterAddress(SpaceRouter _sr) external {
        require(address(sr) == address(0x0), "WRITE_ONCE");
        sr = _sr;
    }

    function toggleSeedInvestors(address[] calldata addresses, bool toggle) external onlyOwner {
        for (uint i = 0; i < addresses.length; i++) {
            isSeedInvestor[addresses[i]] = toggle;
        }
    } 

    function fundingCapacity() public view returns (uint) {
        if (phase == Phase.Seed) {
            return SEED_LIMIT - totalContributed;
        }
        if (phase == Phase.General) {
            return GENERAL_LIMIT - totalContributed;
        }
        return ((spaceCoin.balanceOf(address(this)) / 2 ) / ICO_EXCHANGE_RATE) - totalContributed;             // 150K / 5 = 30K 
    }

    function availableForMeToContribute() public view returns (uint) {
        return availableToContribute(msg.sender);
    }

    function availableToContribute(address user) public view returns (uint) {
        uint spent = contributions[user];
        uint available = fundingCapacity();

        if (phase == Phase.Seed) {
            if (!isSeedInvestor[msg.sender]) {
                return 0;
            }
            uint limit = Math.min(available, SEED_IND_LIMIT);
            return spent >= limit ? 0 : limit - spent;
        }
        if (phase == Phase.General) {
            uint limit = Math.min(available, GENERAL_IND_LIMIT);
            return spent >= limit ? 0 : limit - spent;
        }

        return available;
    }

    function toGeneral() external onlyOwner {
        require(phase == Phase.Seed, "INVALID_PHASE");
        phase = Phase.General;
    }

    function toOpen() external onlyOwner {
        require(phase == Phase.General, "INVALID_PHASE");
        phase = Phase.Open;
    }

   function contribute() external payable {
       if (phase == Phase.Seed) {
           require(isSeedInvestor[msg.sender], "UNAUTHORIZED");
       }
       uint available = availableForMeToContribute();
       require(msg.value <= available, "OVER_LIMIT");

       totalContributed += msg.value;
       contributions[msg.sender] += msg.value;
       if (phase == Phase.Open) {
           redeem();
       }
   }

   function redeem() public {
       require(phase == Phase.Open, "UNAUTHORIZED");
       require(contributions[msg.sender] > 0, "NO_FUNDS");

       uint owed = contributions[msg.sender] * ICO_EXCHANGE_RATE;
       contributions[msg.sender] = 0;
       spaceCoin.transfer(msg.sender, owed);
   }

   function treasuryWithdraw() external {
       require(msg.sender == treasury, "UNAUTHORIZED");
       (bool success, ) = treasury.call{ value: address(this).balance }("");
       require(success, "WITHDRAW_FAILED");
   }

    // contract has 300K space coins
    // 
   function withdrawToPool() external onlyOwner {
       uint spcTransferAmt = totalContributed * ICO_EXCHANGE_RATE; // get the equivalent amount of space tokens for eth contributed: 150K space coins, 30K ETH
       spaceCoin.approve(address(sr), spcTransferAmt);
       (uint liquidity) = sr.addLiquidity{value: totalContributed}(address(spaceCoin), spcTransferAmt, address(this));
       Pool(lpool).approve(address(sr), liquidity);
    }

    receive() external payable {}


   event PhaseChange(Phase phase);
   event Contribute(address indexed contributor, Phase indexed phase, uint eth);
   event Redeem(address indexed contributor, uint tokens);

}