const { expect } = require("chai");
const { ethers } = require("hardhat")
const { parseEther } = ethers.utils

describe("SpaceRouter.sol", function () {
    let SpaceRouter, sr, Pool, pool, SpaceICO, spaceICO, SpaceCoin, spaceCoin;
    let owner;
    let treas;
  
    beforeEach(async function () {

      [owner, addr0, addr1, addr2, treas] = await ethers.getSigners();

      Pool = await ethers.getContractFactory("Pool");
      pool = await Pool.deploy();
  
      SpaceRouter = await ethers.getContractFactory("SpaceRouter");
      sr = await SpaceRouter.deploy(pool.address);

      SpaceICO = await ethers.getContractFactory("SpaceICO");
      
      spaceICO = await SpaceICO.deploy(pool.address, treas.address);

      SpaceCoin = await ethers.getContractFactory("SpaceCoin");
      spaceCoin = await SpaceCoin.deploy(spaceICO.address, treas.address);

      await pool.initialize(spaceCoin.address, spaceICO.address);

      await spaceICO.setSpaceCoinAddress(spaceCoin.address);

      await spaceICO.setSpaceRouterAddress(sr.address);

      await spaceICO.toGeneral();
      await spaceICO.toOpen();

      await spaceICO.connect(owner).contribute({
        value: parseEther("30")
      });

    });

    describe("Adding liquidity  ", function () {

      it("first", async function() {
        await spaceICO.withdrawToPool();
        expect(await pool.balanceOf(spaceICO.address)).to.equal('67082039324993689892');
        expect(await pool.totalSupply()).to.equal('67082039324993689892');
      })

      it("second", async function() {
        await spaceICO.withdrawToPool();

        await spaceCoin.approve(sr.address, spaceCoin.balanceOf(owner.address));
        expect(await spaceCoin.balanceOf(owner.address)).to.equal('150000000000000000000');
        await sr.addLiquidity(spaceCoin.address, spaceCoin.balanceOf(owner.address), owner.address, {value: parseEther("30")});

        expect(await spaceCoin.balanceOf(owner.address)).to.equal(0);

        expect(await pool.balanceOf(owner.address)).to.equal('67082039324993689892');
        expect(await pool.totalSupply()).to.equal('134164078649987379784');


      });
    }); 


    describe("Removing Liquidity", function () {

        it("1st Remove", async function () {

          await spaceICO.withdrawToPool();

          await spaceCoin.approve(sr.address, spaceCoin.balanceOf(owner.address));
          expect(await spaceCoin.balanceOf(owner.address)).to.equal('150000000000000000000');
          await sr.addLiquidity(spaceCoin.address, spaceCoin.balanceOf(owner.address), owner.address, {value: parseEther("30")});
  
          expect(await spaceCoin.balanceOf(owner.address)).to.equal(0);
  
          expect(await pool.balanceOf(owner.address)).to.equal('67082039324993689892');
          expect(await pool.totalSupply()).to.equal('134164078649987379784');

          await pool.approve(sr.address, pool.balanceOf(owner.address));
          await sr.removeLiquidity(pool.balanceOf(owner.address), owner.address)  // cant test this unless owner is transferring
          expect(await pool.balanceOf(owner.address)).to.equal(0);
          expect(await pool.totalSupply()).to.equal('67082039324993689892');

          expect(await spaceCoin.balanceOf(owner.address)).to.equal('150000000000000000000');
        });
    
    });


    describe("Swapping", function () {

      it("Swapping tokens for eth", async function () {

        await spaceICO.withdrawToPool();
        expect(await pool.balanceOf(spaceICO.address)).to.equal('67082039324993689892');
        expect(await pool.totalSupply()).to.equal('67082039324993689892');

        await spaceCoin.approve(sr.address, "5000000000000000000");
        await sr.swapExactTokensForETH(spaceCoin.address, "5000000000000000000", owner.address);
        expect(await spaceCoin.balanceOf(pool.address)).to.equal("155000000000000000000");
        expect(await spaceCoin.balanceOf(owner.address)).to.equal("145000000000000000000");


      })

      it("Swapping eth for tokens", async function () {

        await spaceICO.withdrawToPool();
        expect(await pool.balanceOf(spaceICO.address)).to.equal('67082039324993689892');
        expect(await pool.totalSupply()).to.equal('67082039324993689892');

        await sr.swapExactETHForTokens(spaceCoin.address, owner.address, {value: parseEther("1")});

      })


    })

    
    

});