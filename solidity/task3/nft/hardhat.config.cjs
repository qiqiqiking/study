require("@nomicfoundation/hardhat-toolbox");
require("hardhat-deploy");
require("@nomicfoundation/hardhat-ethers");
require("dotenv").config();
require("@openzeppelin/hardhat-upgrades");
// 🔑 标准化私钥函数
function getAccounts() {
  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    throw new Error("❌ Missing PRIVATE_KEY in .env file");
  }

  // 去掉可能存在的 0x 前缀，统一处理
  const cleanKey = privateKey.startsWith("0x") 
    ? privateKey.slice(2) 
    : privateKey;

  if (cleanKey.length !== 64) {
    throw new Error(
      `❌ Invalid private key length: ${cleanKey.length} (expected 64 hex chars). ` +
      `Value preview: ${privateKey.substring(0, 10)}...`
    );
  }

  return [`0x${cleanKey}`]; // 确保带 0x
}

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.21",
  namedAccounts: {
    deployer: { default: 0 }
  },
  remappings: [
    "@openzeppelin/contracts/=node_modules/@openzeppelin/contracts/"
  ],
  networks: {
    sepolia: {
      url: `https://sepolia.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
      accounts: getAccounts(), // ✅ 安全加载
      chainId: 11155111,
    }
  }
};