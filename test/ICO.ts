import { expect } from 'chai';
import { ethers } from 'hardhat';
import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';
import {
  SpaceCoin__factory,
  SpaceCoin,
  ICO__factory,
  ICO,
  Pool__factory,
  Pool,
} from '../typechain-types';

describe('ICO', function () {
  let SpaceCoin: SpaceCoin__factory;
  let ICO: ICO__factory;
  let Pool: Pool__factory;
  let spaceCoin: SpaceCoin;
  let pool: Pool;
  let ico: ICO;
  let owner: SignerWithAddress, treasury: SignerWithAddress;
  let addr1: SignerWithAddress,
    addr2: SignerWithAddress,
    addr3: SignerWithAddress,
    addr4: SignerWithAddress,
    addr5: SignerWithAddress,
    addr6: SignerWithAddress,
    addr7: SignerWithAddress,
    addr8: SignerWithAddress,
    addr9: SignerWithAddress,
    addr10: SignerWithAddress,
    addr11: SignerWithAddress,
    addr12: SignerWithAddress,
    addr13: SignerWithAddress,
    addr14: SignerWithAddress,
    addr15: SignerWithAddress,
    addr16: SignerWithAddress,
    addr17: SignerWithAddress,
    addr18: SignerWithAddress,
    addr19: SignerWithAddress,
    addr20: SignerWithAddress,
    addr21: SignerWithAddress,
    addr22: SignerWithAddress,
    addr23: SignerWithAddress,
    addr24: SignerWithAddress,
    addr25: SignerWithAddress,
    addr26: SignerWithAddress;

  const tokens = (count: string) => ethers.parseUnits(count, 18);

  this.beforeEach(async function () {
    [
      owner,
      treasury,
      addr1,
      addr2,
      addr3,
      addr4,
      addr5,
      addr6,
      addr7,
      addr8,
      addr9,
      addr10,
      addr11,
      addr12,
      addr13,
      addr14,
      addr15,
      addr16,
      addr17,
      addr18,
      addr19,
      addr20,
      addr21,
      addr22,
      addr23,
      addr24,
      addr25,
      addr26,
    ] = await ethers.getSigners();

    SpaceCoin = (await ethers.getContractFactory(
      'SpaceCoin'
    )) as SpaceCoin__factory;
    spaceCoin = (await SpaceCoin.deploy(owner.address, treasury.address, [
      addr1,
      addr2,
      addr3,
      addr4,
      addr5,
      addr6,
      addr7,
      addr8,
      addr9,
      addr10,
      addr11,
    ])) as SpaceCoin;
    await spaceCoin.waitForDeployment();

    ICO = (await ethers.getContractFactory('ICO')) as ICO__factory;
    ico = ICO.attach(await spaceCoin.ico()) as ICO;
    await ico.waitForDeployment();
  });

  it('Constructor', async function () {
    expect(await ico.owner()).to.equal(owner.address);
    expect(await ico.allowList(addr1)).to.equal(true);
    expect(await ico.allowList(addr2)).to.equal(true);
    expect(await ico.allowList(addr3)).to.equal(true);
    expect(await ico.allowList(addr4)).to.equal(true);
    expect(await ico.allowList(addr5)).to.equal(true);
    expect(await ico.allowList(addr6)).to.equal(true);
    expect(await ico.allowList(addr7)).to.equal(true);
    expect(await ico.allowList(addr8)).to.equal(true);
    expect(await ico.allowList(addr9)).to.equal(true);
    expect(await ico.allowList(addr10)).to.equal(true);
    expect(await ico.allowList(addr11)).to.equal(true);
    expect(await ico.allowList(addr12)).to.equal(false);
  });

  describe('Phases', function () {
    it('Seed Phase is Default', async function () {
      expect(await ico.phase()).to.equal(0);
    });
    it('Seed -> General', async function () {
      await ico.advancePhase(0);
      expect(await ico.phase()).to.equal(1);
    });
    it('General -> Open', async function () {
      await ico.advancePhase(0);
      await ico.advancePhase(1);
      expect(await ico.phase()).to.equal(2);
    });

    it('Only the owner can advance', async function () {
      await expect(ico.connect(addr1).advancePhase(0))
        .to.be.revertedWithCustomError(ico, 'OnlyOwner')
        .withArgs(addr1.address, owner.address);
    });

    it('Cannot advance if owner specifies wrong current phase', async function () {
      await expect(ico.advancePhase(1)).to.be.revertedWithCustomError(
        ico,
        'CannotAdvance'
      );
    });

    it('Cannot advance in open phase', async function () {
      await ico.advancePhase(0);
      await ico.advancePhase(1);
      await expect(ico.advancePhase(2)).to.be.reverted;
    });

    it('Phase advanced event is emitted', async function () {
      const txResponse = await ico.advancePhase(0);
      const tx = await txResponse.wait();
      await expect(tx).to.emit(ico, 'PhaseAdvanced').withArgs(1);
    });
  });

  describe('Contributing in Seed phase', function () {
    it('User not on allowlist cannot contribute', async function () {
      await expect(ico.connect(addr12).contribute({ value: tokens('1') }))
        .to.be.revertedWithCustomError(ico, 'CannotContribute')
        .withArgs(tokens('1'), 0);
    });

    it('Cannot go over individual contribution limit', async function () {
      await expect(ico.connect(addr1).contribute({ value: tokens('1501') }))
        .to.be.revertedWithCustomError(ico, 'CannotContribute')
        .withArgs(tokens('1501'), await ico.MAX_INDIVIDUAL_SEED_LIMIT());
    });

    it('Cannot go over total contribution limit', async function () {
      await ico.connect(addr1).contribute({ value: tokens('1500') });
      await ico.connect(addr2).contribute({ value: tokens('1500') });
      await ico.connect(addr3).contribute({ value: tokens('1500') });
      await ico.connect(addr4).contribute({ value: tokens('1500') });
      await ico.connect(addr5).contribute({ value: tokens('1500') });
      await ico.connect(addr6).contribute({ value: tokens('1500') });
      await ico.connect(addr7).contribute({ value: tokens('1500') });
      await ico.connect(addr8).contribute({ value: tokens('1500') });
      await ico.connect(addr9).contribute({ value: tokens('1500') });
      await ico.connect(addr10).contribute({ value: tokens('1500') });
      await expect(ico.connect(addr11).contribute({ value: tokens('1') }))
        .to.be.revertedWithCustomError(ico, 'CannotContribute')
        .withArgs(tokens('1'), 0);
    });

    it('Udpates contributions and total contributions', async function () {
      await ico.connect(addr1).contribute({ value: tokens('1500') });
      expect(await ico.contributions(addr1)).to.equal(tokens('1500'));
      expect(await ico.totalContribution()).to.equal(tokens('1500'));
    });

    it('Contributed event is emitted', async function () {
      const txResponse = await ico
        .connect(addr10)
        .contribute({ value: tokens('1500') });
      const tx = await txResponse.wait();
      await expect(tx)
        .to.emit(ico, 'Contributed')
        .withArgs(addr10.address, tokens('1500'));
    });
  });

  describe('Contributing in General phase', function () {
    it('User not on allowlist can contribute', async function () {
      await ico.connect(owner).advancePhase(await ico.phase());
      await ico.connect(addr12).contribute({ value: tokens('1') });
      expect(await ico.contributions(addr12)).to.equal(tokens('1'));
      expect(await ico.totalContribution()).to.equal(tokens('1'));
    });

    it('Cannot go over individual contribution limit', async function () {
      await ico.connect(owner).advancePhase(await ico.phase());
      await expect(ico.connect(addr1).contribute({ value: tokens('1001') }))
        .to.be.revertedWithCustomError(ico, 'CannotContribute')
        .withArgs(tokens('1001'), tokens('1000'));
    });

    it('Individual contribution limit is inclusive of seed phase', async function () {
      await ico.connect(addr1).contribute({ value: tokens('1500') });
      await ico.connect(owner).advancePhase(await ico.phase());
      await expect(ico.connect(addr1).contribute({ value: tokens('1000') }))
        .to.be.revertedWithCustomError(ico, 'CannotContribute')
        .withArgs(tokens('1000'), 0);
    });

    it('Cannot go over total contribution limit', async function () {
      await ico.connect(addr1).contribute({ value: tokens('1500') });
      await ico.connect(addr2).contribute({ value: tokens('1500') });
      await ico.connect(addr3).contribute({ value: tokens('1500') });
      await ico.connect(addr4).contribute({ value: tokens('1500') });
      await ico.connect(addr5).contribute({ value: tokens('1500') });
      await ico.connect(addr6).contribute({ value: tokens('1500') });
      await ico.connect(addr7).contribute({ value: tokens('1500') });
      await ico.connect(addr8).contribute({ value: tokens('1500') });
      await ico.connect(addr9).contribute({ value: tokens('1500') });
      await ico.connect(addr10).contribute({ value: tokens('1500') });
      await ico.connect(owner).advancePhase(await ico.phase());
      await ico.connect(addr11).contribute({ value: tokens('1000') });
      await ico.connect(addr12).contribute({ value: tokens('1000') });
      await ico.connect(addr13).contribute({ value: tokens('1000') });
      await ico.connect(addr14).contribute({ value: tokens('1000') });
      await ico.connect(addr15).contribute({ value: tokens('1000') });
      await ico.connect(addr16).contribute({ value: tokens('1000') });
      await ico.connect(addr17).contribute({ value: tokens('1000') });
      await ico.connect(addr18).contribute({ value: tokens('1000') });
      await ico.connect(addr19).contribute({ value: tokens('1000') });
      await ico.connect(addr20).contribute({ value: tokens('1000') });
      await ico.connect(addr21).contribute({ value: tokens('1000') });
      await ico.connect(addr22).contribute({ value: tokens('1000') });
      await ico.connect(addr23).contribute({ value: tokens('1000') });
      await ico.connect(addr24).contribute({ value: tokens('1000') });
      await ico.connect(addr25).contribute({ value: tokens('1000') });
      await expect(ico.connect(addr26).contribute({ value: tokens('1') }))
        .to.be.revertedWithCustomError(ico, 'CannotContribute')
        .withArgs(tokens('1'), 0);
    });

    it('Udpates contributions and total contributions', async function () {
      await ico.connect(owner).advancePhase(await ico.phase());
      await ico.connect(addr1).contribute({ value: tokens('1000') });
      expect(await ico.contributions(addr1)).to.equal(tokens('1000'));
      expect(await ico.totalContribution()).to.equal(tokens('1000'));
    });

    it('Contributed event is emitted', async function () {
      const txResponse = await ico
        .connect(addr10)
        .contribute({ value: tokens('1500') });
      const tx = await txResponse.wait();
      await expect(tx)
        .to.emit(ico, 'Contributed')
        .withArgs(addr10.address, tokens('1500'));
    });
  });

  describe('Contributing in Open phase', function () {
    it('User not on allowlist can contribute', async function () {
      await ico.connect(owner).advancePhase(await ico.phase());
      await ico.connect(owner).advancePhase(await ico.phase());
      await ico.connect(addr12).contribute({ value: tokens('2000') });
      expect(await ico.contributions(addr12)).to.equal(tokens('2000'));
      expect(await ico.totalContribution()).to.equal(tokens('2000'));
    });

    it('Cannot go over total contribution limit', async function () {
      await ico.connect(addr1).contribute({ value: tokens('1500') });
      await ico.connect(addr2).contribute({ value: tokens('1500') });
      await ico.connect(addr3).contribute({ value: tokens('1500') });
      await ico.connect(addr4).contribute({ value: tokens('1500') });
      await ico.connect(addr5).contribute({ value: tokens('1500') });
      await ico.connect(addr6).contribute({ value: tokens('1500') });
      await ico.connect(addr7).contribute({ value: tokens('1500') });
      await ico.connect(addr8).contribute({ value: tokens('1500') });
      await ico.connect(addr9).contribute({ value: tokens('1500') });
      await ico.connect(addr10).contribute({ value: tokens('1500') });
      await ico.connect(owner).advancePhase(await ico.phase());
      await ico.connect(owner).advancePhase(await ico.phase());
      await ico.connect(addr11).contribute({ value: tokens('1000') });
      await ico.connect(addr12).contribute({ value: tokens('1000') });
      await ico.connect(addr13).contribute({ value: tokens('1000') });
      await ico.connect(addr14).contribute({ value: tokens('1000') });
      await ico.connect(addr15).contribute({ value: tokens('1000') });
      await ico.connect(addr16).contribute({ value: tokens('1000') });
      await ico.connect(addr17).contribute({ value: tokens('1000') });
      await ico.connect(addr18).contribute({ value: tokens('1000') });
      await ico.connect(addr19).contribute({ value: tokens('1000') });
      await ico.connect(addr20).contribute({ value: tokens('1000') });
      await ico.connect(addr21).contribute({ value: tokens('1000') });
      await ico.connect(addr22).contribute({ value: tokens('1000') });
      await ico.connect(addr23).contribute({ value: tokens('1000') });
      await ico.connect(addr24).contribute({ value: tokens('1000') });
      await ico.connect(addr25).contribute({ value: tokens('1000') });
      await expect(ico.connect(addr26).contribute({ value: tokens('1') }))
        .to.be.revertedWithCustomError(ico, 'CannotContribute')
        .withArgs(tokens('1'), 0);
    });

    it('Contributed event is emitted', async function () {
      const txResponse = await ico
        .connect(addr10)
        .contribute({ value: tokens('1500') });
      const tx = await txResponse.wait();
      await expect(tx)
        .to.emit(ico, 'Contributed')
        .withArgs(addr10.address, tokens('1500'));
    });
  });

  describe('Pausing and Unpausing', function () {
    it('Default is not paused', async function () {
      expect(await ico.paused()).to.be.equal(false);
    });

    it('Owner can pause', async function () {
      await ico.pause();
      expect(await ico.paused()).to.be.equal(true);
    });

    it('Owner can unpause', async function () {
      await ico.pause();
      await ico.unpause();
      expect(await ico.paused()).to.be.equal(false);
    });

    it('Only owner can pause', async function () {
      await expect(ico.connect(addr1).pause())
        .to.be.revertedWithCustomError(ico, 'OnlyOwner')
        .withArgs(addr1.address, owner.address);
    });

    it('Only owner can unpause', async function () {
      await ico.pause();
      await expect(ico.connect(addr1).unpause())
        .to.be.revertedWithCustomError(ico, 'OnlyOwner')
        .withArgs(addr1.address, owner.address);
    });

    it('Cannot contribute if paused', async function () {
      await ico.pause();
      await expect(
        ico.connect(addr1).contribute({ value: tokens('1') })
      ).to.be.revertedWithCustomError(ico, 'AlreadyPaused');
    });

    it('Cannot redeem if paused', async function () {
      await ico.pause();
      await expect(ico.connect(addr1).redeem()).to.be.revertedWithCustomError(
        ico,
        'AlreadyPaused'
      );
    });

    it('Cannot pause if already paused', async function () {
      await ico.pause();
      await expect(ico.pause()).to.be.revertedWithCustomError(
        ico,
        'AlreadyPaused'
      );
    });

    it('Cannot unpause if aleady not paused', async function () {
      await expect(ico.unpause()).to.be.revertedWithCustomError(
        ico,
        'AlreadyUnpaused'
      );
    });

    it('Paused event is emitted', async function () {
      const txResponse = await ico.pause();
      const tx = await txResponse.wait();
      await expect(tx).to.emit(ico, 'Paused');
    });

    it('Unpaused event is emitted', async function () {
      await ico.pause();
      const txResponse = await ico.unpause();
      const tx = await txResponse.wait();
      await expect(tx).to.emit(ico, 'Unpaused');
    });
  });

  describe('Redeeming', function () {
    it('Can only redeem in open phase', async function () {
      await expect(ico.redeem())
        .to.be.revertedWithCustomError(ico, 'CannotRedeem')
        .withArgs(await ico.phase(), 2);
    });

    it('Redeem 5 times the amount of space coins than ether contributed', async function () {
      await ico.connect(addr11).contribute({ value: tokens('1500') });
      await ico.advancePhase(0);
      await ico.advancePhase(1);
      expect(await spaceCoin.balanceOf(addr11)).to.be.equal(0);
      await ico.connect(addr11).redeem();
      expect(await spaceCoin.balanceOf(addr11)).to.be.equal(tokens('7500'));
    });

    it('Cannot redeem if no contributions', async function () {
      await ico.advancePhase(0);
      await ico.advancePhase(1);
      await expect(ico.redeem()).to.be.revertedWithCustomError(
        ico,
        'NoContributions'
      );
    });

    it('Redeemed event is emitted', async function () {
      await ico.connect(addr11).contribute({ value: tokens('1500') });
      await ico.advancePhase(0);
      await ico.advancePhase(1);
      const txResponse = await ico.connect(addr11).redeem();
      const tx = await txResponse.wait();
      await expect(tx)
        .to.emit(ico, 'Redeemed')
        .withArgs(addr11.address, tokens('1500') * BigInt(5));
    });
  });

  describe('Withdrawing', function () {
    it('Send to treasury', async function () {
      let treasuryBalance = await ethers.provider.getBalance(treasury);
      await ico.connect(addr1).contribute({ value: tokens('1500') });
      expect(await ethers.provider.getBalance(ico)).to.be.equal(tokens('1500'));
      await ico.connect(owner).withdraw(tokens('1500'));
      expect(await ethers.provider.getBalance(ico)).to.be.equal(0);
      expect(await ethers.provider.getBalance(treasury)).to.be.equal(
        treasuryBalance + tokens('1500')
      );
    });
  });
});
