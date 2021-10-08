const { ethers } = require("hardhat");

async function main() {

    const [deployer] = await ethers.getSigners();
  
    console.log("Deploying contracts with the account:", deployer.address);
  
    console.log("Account balance:", (await deployer.getBalance()).toString());

    const Lib = await ethers.getContractFactory("SpaceLib");
    const lib = await Lib.deploy();
  
    const Pool = await ethers.getContractFactory("Pool");
    const pool = await Pool.deploy();

    const SpaceRouter = await ethers.getContractFactory("SpaceRouter");
    const sr = await SpaceRouter.deploy(pool.address);

    const SpaceICO = await ethers.getContractFactory("SpaceICO");
    const spaceICO = await SpaceICO.deploy(pool.address, deployer.address);

    const SpaceCoin = await ethers.getContractFactory("SpaceCoin");
    const spaceCoin = await SpaceCoin.deploy(spaceICO.address, deployer.address);
  
    console.log("Space Lib address", lib.address);
    console.log("Pool address:", pool.address);
    console.log("Space Router address:", sr.address);
    console.log("Space ICO address:", spaceICO.address);
    console.log("Space Coin address:", spaceCoin.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });