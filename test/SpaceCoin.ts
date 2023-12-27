import { expect } from 'chai';
import { ethers } from 'hardhat';
import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';
import { SpaceCoin__factory, SpaceCoin } from '../typechain-types';

describe('SpaceCoin', function () {
  let SpaceCoin: SpaceCoin__factory;
  let spaceCoin: SpaceCoin;
  let owner: SignerWithAddress, treasury: SignerWithAddress;
  let addr1: SignerWithAddress,
    addr2: SignerWithAddress,
    addr3: SignerWithAddress,
    addr4: SignerWithAddress,
    addr5: SignerWithAddress;

  const tokens = (count: string) => ethers.parseUnits(count, 18);

  this.beforeEach(async function () {
    [owner, treasury, addr1, addr2, addr3, addr4, addr5] =
      await ethers.getSigners();
    SpaceCoin = (await ethers.getContractFactory(
      'SpaceCoin'
    )) as SpaceCoin__factory;
    spaceCoin = await SpaceCoin.deploy(owner.address, treasury.address, [
      addr1,
      addr2,
      addr3,
      addr4,
      addr5,
    ]);
    await spaceCoin.waitForDeployment();
  });

  it('Constructor', async function () {
    expect(await spaceCoin.owner()).to.equal(owner.address);
    expect(await spaceCoin.treasury()).to.equal(treasury.address);
    expect(await spaceCoin.balanceOf(treasury.address)).to.equal(
      tokens('350000')
    );
    expect(await spaceCoin.balanceOf(await spaceCoin.ico())).to.equal(
      tokens('150000')
    );
  });

  describe('Toggle Tax', function () {
    it('Only owner can toggle the tax', async function () {
      await expect(spaceCoin.connect(treasury).toggleTax(true))
        .to.be.revertedWithCustomError(spaceCoin, 'OnlyOwner')
        .withArgs(treasury.address, owner.address);
    });

    it('If tax is not enabled, toggleTax sets it to true', async function () {
      expect(await spaceCoin.taxEnabled()).to.equal(false);
      await spaceCoin.connect(owner).toggleTax(true);
      expect(await spaceCoin.taxEnabled()).to.equal(true);
    });

    it('If tax is enabled, toggleTax sets it to false', async function () {
      expect(await spaceCoin.taxEnabled()).to.equal(false);
      await spaceCoin.connect(owner).toggleTax(true);
      expect(await spaceCoin.taxEnabled()).to.equal(true);
      await spaceCoin.connect(owner).toggleTax(false);
      expect(await spaceCoin.taxEnabled()).to.equal(false);
    });

    it('Toggle tax event is emitted when set to true', async function () {
      const txResponse = await spaceCoin.connect(owner).toggleTax(true);
      const tx = await txResponse.wait();
      await expect(tx).to.emit(spaceCoin, 'TaxToggled').withArgs(true);
    });

    it('Toggle tax event is emitted when set to false', async function () {
      await spaceCoin.connect(owner).toggleTax(true);
      const txResponse = await spaceCoin.connect(owner).toggleTax(false);
      const tx = await txResponse.wait();
      await expect(tx).to.emit(spaceCoin, 'TaxToggled').withArgs(false);
    });

    it('Cannot toggle tax to false if already false', async function () {
      await expect(spaceCoin.toggleTax(false)).to.be.revertedWithCustomError(
        spaceCoin,
        'NoChangeInTax'
      );
    });

    it('Cannot toggle tax to true if already true', async function () {
      await spaceCoin.connect(owner).toggleTax(true);
      await expect(spaceCoin.toggleTax(true)).to.be.revertedWithCustomError(
        spaceCoin,
        'NoChangeInTax'
      );
    });
  });

  describe('Transfer', function () {
    it('Normal transfer when tax is not enabled', async function () {
      await spaceCoin.connect(treasury).transfer(addr1, tokens('50000'));
      expect(await spaceCoin.balanceOf(treasury.address)).to.equal(
        tokens('300000')
      );
      expect(await spaceCoin.balanceOf(addr1)).to.equal(tokens('50000'));
    });
    it('Transfer when tax is enabled', async function () {
      await spaceCoin
        .connect(treasury)
        .transfer(owner.address, tokens('350000'));
      await spaceCoin.connect(owner).toggleTax(true);
      await spaceCoin.connect(owner).transfer(addr1, tokens('350000'));
      expect(await spaceCoin.balanceOf(treasury.address)).to.equal(
        tokens('7000')
      );
      expect(await spaceCoin.balanceOf(addr1)).to.equal(tokens('343000'));
    });
  });
});
