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
  SpaceRouter__factory,
  SpaceRouter,
} from '../typechain-types';

describe('SpaceRouter', function () {
  let SpaceCoin: SpaceCoin__factory;
  let ICO: ICO__factory;
  let Pool: Pool__factory;
  let SpaceRouter: SpaceRouter__factory;
  let spaceCoin: SpaceCoin;
  let pool: Pool;
  let ico: ICO;
  let spaceRouter: SpaceRouter;
  let owner: SignerWithAddress,
    treasury: SignerWithAddress,
    addr1: SignerWithAddress;

  const tokens = (count: string) => ethers.parseUnits(count, 18);

  function sqrt(value: bigint) {
    if (value < 0n) {
      throw 'square root of negative numbers is not supported';
    }

    if (value < 2n) {
      return value;
    }

    // Initial guess: Divide by 2n (bitwise right shift)
    let x = value >> 1n;
    let y = (x + value / x) >> 1n;
    while (x > y) {
      x = y;
      y = (x + value / x) >> 1n;
    }
    return x;
  }

  this.beforeEach(async function () {
    [owner, treasury, addr1] = await ethers.getSigners();
    SpaceCoin = (await ethers.getContractFactory(
      'SpaceCoin'
    )) as SpaceCoin__factory;
    spaceCoin = (await SpaceCoin.deploy(owner.address, treasury.address, [
      addr1,
    ])) as SpaceCoin;
    await spaceCoin.waitForDeployment();

    ICO = (await ethers.getContractFactory('ICO')) as ICO__factory;
    ico = ICO.attach(await spaceCoin.ico()) as ICO;
    await ico.waitForDeployment();

    Pool = (await ethers.getContractFactory('Pool')) as Pool__factory;
    pool = await Pool.deploy('Liquidity Pool', 'LP', spaceCoin);
    await pool.waitForDeployment();

    SpaceRouter = (await ethers.getContractFactory(
      'SpaceRouter'
    )) as SpaceRouter__factory;
    spaceRouter = (await SpaceRouter.deploy(pool, spaceCoin)) as SpaceRouter;
  });

  it('Constructors', async function () {
    expect(await spaceRouter.pool()).to.equal(await pool.getAddress());
    expect(await spaceRouter.spaceCoin()).to.equal(
      await spaceCoin.getAddress()
    );
    expect(await pool.name()).to.equal('Liquidity Pool');
    expect(await pool.symbol()).to.equal('LP');
    expect(await pool.spaceCoin()).to.equal(await spaceCoin.getAddress());
  });

  describe('Add Liquidity', function () {
    it('Send liquidity to lp from treasury - first time', async function () {
      await ico.connect(addr1).contribute({ value: tokens('1500') });
      await ico.connect(owner).withdraw(tokens('1500'));
      let ethReserve = await pool.ethReserve();
      let spcReserve = await pool.spcReserve();
      await spaceCoin
        .connect(treasury)
        .approve(spaceRouter.target, tokens('5'));
      await spaceRouter
        .connect(treasury)
        .addLiquidity(treasury.getAddress(), tokens('5'), {
          value: tokens('1'),
        });
      expect(await spaceCoin.balanceOf(pool.getAddress())).to.equal(
        tokens('5')
      );
      expect(await ethers.provider.getBalance(pool.getAddress())).to.equal(
        tokens('1')
      );
      expect(await pool.balanceOf(treasury)).to.equal(
        sqrt(tokens('5') * tokens('1'))
      );
      expect(await pool.ethReserve()).to.equal(ethReserve + tokens('1'));
      expect(await pool.spcReserve()).to.equal(spcReserve + tokens('5'));
    });

    it('emit Mint event', async function () {
      await ico.connect(addr1).contribute({ value: tokens('1500') });
      await ico.connect(owner).withdraw(tokens('1500'));
      await spaceCoin
        .connect(treasury)
        .approve(spaceRouter.target, tokens('5'));
      await expect(
        spaceRouter
          .connect(treasury)
          .addLiquidity(treasury.getAddress(), tokens('5'), {
            value: tokens('1'),
          })
      )
        .to.emit(pool, 'Mint')
        .withArgs(spaceRouter.target, tokens('1'), tokens('5'));
    });

    it('Second time adding liquidty', async function () {
      await ico.connect(addr1).contribute({ value: tokens('1500') });
      await ico.connect(owner).withdraw(tokens('1500'));
      await spaceCoin
        .connect(treasury)
        .approve(spaceRouter.target, tokens('5'));
      await spaceRouter
        .connect(treasury)
        .addLiquidity(treasury.getAddress(), tokens('5'), {
          value: tokens('1'),
        });
      await ico.advancePhase(0);
      await ico.advancePhase(1);
      await ico.connect(addr1).redeem();
      await spaceCoin.connect(addr1).approve(spaceRouter.target, tokens('5'));
      await spaceRouter
        .connect(addr1)
        .addLiquidity(addr1.address, tokens('5'), { value: tokens('1') });
    });
  });
});
