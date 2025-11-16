// scripts/deploy.js
const { ethers, upgrades } = require("hardhat");

async function main() {
const ETH_USD_FEED = ethers.getAddress("0x694aa1769357215de4fac081bf1f309adc325306");
  const USDC_USD_FEED = ethers.getAddress("0xa2f78ab2355fe239112e9432e367c5ea29c862d4"); // 全小写！
  const USDC_DECIMALS = 6;

  // 获取部署者账户
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);

  // 部署可升级合约（UUPS 模式）
  const NFTAuction = await ethers.getContractFactory("NFTAuction");
  const auction = await upgrades.deployProxy(NFTAuction, [
    ETH_USD_FEED,
    USDC_USD_FEED,
    USDC_DECIMALS
  ], {
    initializer: 'initialize',
    kind: 'uups' // 必须指定 UUPS 模式
  });

  await auction.waitForDeployment();
  const proxyAddress = await auction.getAddress();

  console.log("NFTAuction proxy deployed to:", proxyAddress);

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });