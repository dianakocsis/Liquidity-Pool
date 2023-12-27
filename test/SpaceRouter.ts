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

describe('SwapRouter', function () {
  let SpaceCoin: SpaceCoin__factory;
  let ICO: ICO__factory;
  let Pool: Pool__factory;
  let SwapRouter: SpaceRouter__factory;
  let spaceCoin: SpaceCoin;
  let pool: Pool;
  let ico: ICO;
  let swapRouter: SpaceRouter;
  let owner: SignerWithAddress,
    treasury: SignerWithAddress,
    addr1: SignerWithAddress;

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

    SwapRouter = (await ethers.getContractFactory(
      'SwapRouter'
    )) as SpaceRouter__factory;
    swapRouter = (await SwapRouter.deploy(pool, spaceCoin)) as SpaceRouter;
  });
});
