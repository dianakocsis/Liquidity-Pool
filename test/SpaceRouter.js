const { expect } = require("chai");
const { ethers } = require("hardhat")
const { parseEther } = ethers.utils

describe("SpaceRouter.sol", function () {
    let SpaceRouter, sr, Pool, pool, SpaceICO, spaceICO, SpaceCoin, spaceCoin;
    let owner;
    let treas;
    const provider = ethers.provider;
  
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

      await pool.initialize(spaceCoin.address);

      await spaceICO.setSpaceCoinAddress(spaceCoin.address);

      await spaceICO.setSpaceRouterAddress(sr.address);

      await spaceICO.toGeneral();
      await spaceICO.toOpen();

      await spaceICO.connect(owner).contribute({
        value: parseEther("30")
      });

      await spaceICO.withdrawToPool();

    });

    describe("Adding liquidity", function () {

      it("first adding of liquidity", async function() {
        
        // balance of eth in pool
        const liquidityPoolETHBalance = await provider.getBalance(pool.address);
        expect(await liquidityPoolETHBalance).to.equal(parseEther('30'));

        // balance of space coin in pool
        expect(await spaceCoin.balanceOf(pool.address)).to.equal('150000000000000000000');

        // space ico's balance of lp tokens
        expect(await pool.balanceOf(spaceICO.address)).to.equal('67082039324993689892');

        // total of lp tokens
        expect(await pool.totalSupply()).to.equal('67082039324993689892');
        

      })

      it("second adding of liquidity", async function() {

        // owner approving the space router to spend its space coins
        await spaceCoin.approve(sr.address, spaceCoin.balanceOf(owner.address));

        // owner has 150K space coin because owner contributed 30K eth
        expect(await spaceCoin.balanceOf(owner.address)).to.equal('150000000000000000000');
        // owner adding liquidity in space router: space coin amount and eth amount
        await sr.addLiquidity(spaceCoin.address, spaceCoin.balanceOf(owner.address), owner.address, {value: parseEther("30")});

        // balance of eth in pool
        const liquidityPoolETHBalance = await provider.getBalance(pool.address);
        expect(await liquidityPoolETHBalance).to.equal(parseEther('60'));
        
        // balance of space coin in pool
        expect(await spaceCoin.balanceOf(pool.address)).to.equal('300000000000000000000');

        // owner's balance of space coins should now be 0 
        expect(await spaceCoin.balanceOf(owner.address)).to.equal(0);

        // owner's balance of LP tokens
        expect(await pool.balanceOf(owner.address)).to.equal('67082039324993689892');

        // total supply of LP tokens updates
        expect(await pool.totalSupply()).to.equal('134164078649987379784');


        // Test the hack

        await spaceICO.connect(addr2).contribute({
          value: parseEther("30")
        });

        await spaceCoin.connect(addr2).transfer(pool.address, 150);
        await addr2.sendTransaction({to: pool.address, value: parseEther("30")});


        await pool.approve(sr.address, pool.balanceOf(owner.address));
        await sr.removeLiquidity(pool.balanceOf(owner.address), owner.address)  // cant test this unless owner is transferring
        expect(await spaceCoin.balanceOf(owner.address)).to.equal('150000000000000000000');

        expect(await pool.balanceOf(owner.address)).to.equal(0);
        expect(await pool.totalSupply()).to.equal('67082039324993689892');


      });
    }); 


    describe("Removing Liquidity", function () {

        it("1st Remove", async function () {

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

        expect(await pool.balanceOf(spaceICO.address)).to.equal('67082039324993689892');
        expect(await pool.totalSupply()).to.equal('67082039324993689892');

        await spaceCoin.approve(sr.address, "5000000000000000000");
        await sr.swapExactTokensForETH(spaceCoin.address, "5000000000000000000", owner.address);

        expect(await spaceCoin.balanceOf(pool.address)).to.equal("155000000000000000000");
        expect(await spaceCoin.balanceOf(owner.address)).to.equal("145000000000000000000");


      })

      it("Swapping eth for tokens", async function () {

        expect(await pool.balanceOf(spaceICO.address)).to.equal('67082039324993689892');
        expect(await pool.totalSupply()).to.equal('67082039324993689892');

        await sr.swapExactETHForTokens(spaceCoin.address, owner.address, {value: parseEther("1")});

      })


    })

    
    

});