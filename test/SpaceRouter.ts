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

  describe('Removing liquidity', function () {
    it('removing liquidity', async function () {
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
      let liquidityTreasuryAmt = await pool.balanceOf(treasury.address);
      console.log('liquiduty treasury amt is ', liquidityTreasuryAmt);
      await pool.connect(treasury).approve(spaceRouter.target, tokens('5'));
      let totalSupply = await pool.totalSupply();
      let liquidity = tokens('1');
      let ethPoolBalance = await ethers.provider.getBalance(pool.getAddress());
      let spcPoolBalance = await spaceCoin.balanceOf(pool.target);
      let spcTreasuryBalance = await spaceCoin.balanceOf(treasury);
      let ethAmount = (liquidity * ethPoolBalance) / totalSupply;
      let spcAmount = (liquidity * spcPoolBalance) / totalSupply;
      await spaceRouter
        .connect(treasury)
        .removeLiquidity(tokens('1'), treasury.address);
      let expectedEthBalance = ethPoolBalance - ethAmount;
      let expectedSpcBalance = spcPoolBalance - spcAmount;
      expect(await ethers.provider.getBalance(pool.target)).to.equal(
        expectedEthBalance
      );
      expect(await spaceCoin.balanceOf(pool.target)).to.equal(
        expectedSpcBalance
      );
      expect(await spaceCoin.balanceOf(treasury)).to.equal(
        spcTreasuryBalance + spcAmount
      );
    });

    it('Emit event', async function () {
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
      await pool.connect(treasury).approve(spaceRouter.target, tokens('5'));
      let totalSupply = await pool.totalSupply();
      let liquidity = tokens('1');
      let ethPoolBalance = await ethers.provider.getBalance(pool.getAddress());
      let spcPoolBalance = await spaceCoin.balanceOf(pool.target);
      let ethAmount = (liquidity * ethPoolBalance) / totalSupply;
      let spcAmount = (liquidity * spcPoolBalance) / totalSupply;
      await expect(
        spaceRouter
          .connect(treasury)
          .removeLiquidity(tokens('1'), treasury.address)
      )
        .to.emit(pool, 'Burn')
        .withArgs(spaceRouter.target, ethAmount, spcAmount, treasury.address);
    });

    it('Insufficient Liquidity Burned', async function () {
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
      await pool.connect(treasury).approve(spaceRouter.target, tokens('5'));
      await expect(
        spaceRouter.connect(treasury).removeLiquidity(1n, treasury.address)
      ).to.be.revertedWithCustomError(pool, 'InsufficientLiquidityBurned');
    });
  });

  describe('Swap eth for tokens', function () {
    it('cannot swap for 0 eth', async function () {
      await expect(
        spaceRouter.swapEthForSpc(tokens('1'), owner, { value: 0 })
      ).to.be.revertedWithCustomError(spaceRouter, 'InsufficientAmount');
    });

    it('Cannot swap if no reserves', async function () {
      await expect(
        spaceRouter.swapEthForSpc(tokens('1'), owner, { value: tokens('5') })
      ).to.be.revertedWithCustomError(spaceRouter, 'InsufficientLiquidity');
    });

    it('Spc output less than min', async function () {
      await ico.connect(addr1).contribute({ value: tokens('1500') });
      await ico.connect(owner).withdraw(tokens('1500'));

      await spaceCoin
        .connect(treasury)
        .approve(spaceRouter.target, tokens('10'));
      await spaceRouter
        .connect(treasury)
        .addLiquidity(treasury.getAddress(), tokens('10'), {
          value: tokens('1'),
        });
      let amountEthWithFee = tokens('1') * 99n;
      let numerator = amountEthWithFee * (await pool.spcReserve());
      let denominator = (await pool.ethReserve()) * 100n + amountEthWithFee;
      let amtSpcOut = numerator / denominator;
      await expect(
        spaceRouter.swapEthForSpc(tokens('5'), owner, {
          value: tokens('1'),
        })
      )
        .to.be.revertedWithCustomError(spaceRouter, 'InsufficientOutputAmount')
        .withArgs(amtSpcOut, tokens('5'));
    });

    it('Receiving spc', async function () {
      await ico.connect(addr1).contribute({ value: tokens('1500') });
      await ico.connect(owner).withdraw(tokens('1500'));

      await spaceCoin
        .connect(treasury)
        .approve(spaceRouter.target, tokens('10'));
      await spaceRouter
        .connect(treasury)
        .addLiquidity(treasury.getAddress(), tokens('10'), {
          value: tokens('1'),
        });
      let amountEthWithFee = tokens('1') * 99n;
      let numerator = amountEthWithFee * (await pool.spcReserve());
      let denominator = (await pool.ethReserve()) * 100n + amountEthWithFee;
      let amtSpcOut = numerator / denominator;

      let beforeEthReserve = await pool.ethReserve();
      let beforeSpcReserve = await pool.spcReserve();

      await spaceRouter.swapEthForSpc(tokens('4'), owner, {
        value: tokens('1'),
      });
      expect(await pool.ethReserve()).to.equal(beforeEthReserve + tokens('1'));
      expect(await pool.spcReserve()).to.equal(beforeSpcReserve - amtSpcOut);
      expect(await spaceCoin.balanceOf(owner)).to.equal(amtSpcOut);
    });
  });

  describe('Swap spc for eth', function () {
    it('cannot swap for 0 spc', async function () {
      await expect(
        spaceRouter.swapSpcForEth(0, tokens('1'), owner)
      ).to.be.revertedWithCustomError(spaceRouter, 'InsufficientAmount');
    });

    it('Cannot swap if no reserves', async function () {
      await expect(
        spaceRouter.swapSpcForEth(tokens('5'), tokens('1'), owner)
      ).to.be.revertedWithCustomError(spaceRouter, 'InsufficientLiquidity');
    });

    it('Eth output less than min', async function () {
      await ico.connect(addr1).contribute({ value: tokens('1500') });
      await ico.connect(owner).withdraw(tokens('1500'));

      await spaceCoin
        .connect(treasury)
        .approve(spaceRouter.target, tokens('20'));
      await spaceRouter
        .connect(treasury)
        .addLiquidity(treasury.getAddress(), tokens('10'), {
          value: tokens('1'),
        });
      let amountSpcWithFee = tokens('10') * 99n;
      let numerator = amountSpcWithFee * (await pool.ethReserve());
      let denominator = (await pool.spcReserve()) * 100n + amountSpcWithFee;
      let amtEthOut = numerator / denominator;
      await expect(
        spaceRouter
          .connect(treasury)
          .swapSpcForEth(tokens('10'), tokens('1'), owner)
      )
        .to.be.revertedWithCustomError(spaceRouter, 'InsufficientOutputAmount')
        .withArgs(amtEthOut, tokens('1'));
    });

    it('Receiving eth', async function () {
      await ico.connect(addr1).contribute({ value: tokens('1500') });
      await ico.connect(owner).withdraw(tokens('1500'));

      await spaceCoin
        .connect(treasury)
        .approve(spaceRouter.target, tokens('20'));
      await spaceRouter
        .connect(treasury)
        .addLiquidity(treasury.getAddress(), tokens('10'), {
          value: tokens('1'),
        });
      let amountSpcWithFee = tokens('5') * 99n;
      let numerator = amountSpcWithFee * (await pool.ethReserve());
      let denominator = (await pool.spcReserve()) * 100n + amountSpcWithFee;
      let amtEthOut = numerator / denominator;

      let beforeEthReserve = await pool.ethReserve();
      let beforeSpcReserve = await pool.spcReserve();

      let beforeEthBalance = await ethers.provider.getBalance(owner);

      await spaceRouter
        .connect(treasury)
        .swapSpcForEth(tokens('5'), tokens('.3'), owner);
      expect(await pool.ethReserve()).to.equal(beforeEthReserve - amtEthOut);
      expect(await pool.spcReserve()).to.equal(beforeSpcReserve + tokens('5'));
      expect(await ethers.provider.getBalance(owner)).to.equal(
        beforeEthBalance + amtEthOut
      );
    });
  });
});
