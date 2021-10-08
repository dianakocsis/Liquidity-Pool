const { expect } = require("chai");
const { ethers } = require("hardhat")

describe("SpaceCoin contract", function () {
  let SpaceCoin;
  let spaceCoin;
  let owner;
  let ico;
  let treas;

  const COINS = '300000000000000000000000';
  const MAX_COINS = '500000000000000000000000';
  const SUB = "200000000000000000000000";

  beforeEach(async function () {
    SpaceCoin = await ethers.getContractFactory("SpaceCoin");
    [owner, ico, treas] = await ethers.getSigners();
    spaceCoin = await SpaceCoin.deploy(ico.address, treas.address);
  });

  describe("Deployment", function () {

    it("Should set the right treasurer address", async function () {
      expect(await spaceCoin.treasury()).to.equal(treas.address);
    });

    it("New minted amount added on to supply", async function () {
      
      expect(await spaceCoin.balanceOf(ico.address)).to.equal(COINS);
      expect(await spaceCoin.balanceOf(treas.address)).to.equal(SUB);
      expect(await spaceCoin.totalSupply()).to.equal(MAX_COINS);
    });

  });


  describe("Toggle tax", function () {
      
    it("Can only be called by owner", async function () {
        await expect(spaceCoin.connect(ico).toggleTax(true)).to.be.revertedWith("Ownable: caller is not the owner");
    })

    it("Setting tax to true", async function () {
        await spaceCoin.toggleTax(true);
        expect(await spaceCoin.shouldTax()).to.equal(true);
    })
  })

  
  describe("Transferring", function () {

    it("2 percent tax", async function () {
        await spaceCoin.toggleTax(true);
        await spaceCoin.connect(ico).transfer(owner.address, '300000000000000000000000');
        expect(await spaceCoin.balanceOf(ico.address)).to.equal(0);
        expect(await spaceCoin.balanceOf(owner.address)).to.equal('294000000000000000000000');
        expect(await spaceCoin.balanceOf(spaceCoin.treasury())).to.equal('206000000000000000000000');
    })

    it("Without tax", async function () {
      await spaceCoin.connect(ico).transfer(owner.address, '300000000000000000000000');
      expect(await spaceCoin.balanceOf(ico.address)).to.equal(0);
      expect(await spaceCoin.balanceOf(owner.address)).to.equal('300000000000000000000000');
      expect(await spaceCoin.balanceOf(spaceCoin.treasury())).to.equal('200000000000000000000000');
    })

  });

});