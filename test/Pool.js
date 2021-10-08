const { expect } = require("chai");
const { providers } = require("ethers");
const { ethers } = require("hardhat")
const { parseEther } = ethers.utils

describe("Pool.sol", function () {
    let Pool;
    let pool;
    let owner;
    let addr1;
    let addr2;
    let ico;
    let treas;
  
    beforeEach(async function () {
      Pool = await ethers.getContractFactory("Pool");
      [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
      pool = await Pool.deploy();

      SpaceICO = await ethers.getContractFactory("SpaceICO");
      [owner, ico, treas] = await ethers.getSigners();
      spaceICO = await SpaceICO.deploy(pool.address, treas.address);

      SpaceCoin = await ethers.getContractFactory("SpaceCoin");
      [owner, ico, treas] = await ethers.getSigners();
      spaceCoin = await SpaceCoin.deploy(ico.address, treas.address);

      await pool.initialize(spaceCoin.address, spaceICO.address);


      //spaceICO.toGeneral();
      //spaceICO.toOpen();
      //await spaceICO.connect(addr2).contribute({
      //  value: parseEther("1000")
      //});
      
    });

    describe("SpaceCoin token", function () {

        it("Initialized", async function () {
            expect(await pool.spaceCoin()).to.equal(spaceCoin.address);
        });
    
    });
    

});