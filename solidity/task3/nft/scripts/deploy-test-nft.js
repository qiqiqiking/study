// scripts/deploy-test-nft.js
const { ethers } = require("hardhat");

async function main() {
  // 获取部署者账户
  const [deployer] = await ethers.getSigners();
  console.log("Deploying TestNFT with the account:", deployer.address);

  // 获取合约工厂
  const TestNFT = await ethers.getContractFactory("TestNFT");

  // 部署合约，并将 deployer 设为初始 owner
  const testNFT = await TestNFT.deploy(deployer.address);

  // 等待部署完成
  await testNFT.waitForDeployment();

  const nftAddress = await testNFT.getAddress();
  console.log("✅ TestNFT deployed to:", nftAddress);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });