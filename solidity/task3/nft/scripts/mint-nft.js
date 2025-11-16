const { ethers } = require("hardhat");

async function main() {
  const nftAddress = "0xD4Ff4853BeB640C8F026ddECD37137C3741eB263"; // 替换为实际地址
  const [signer] = await ethers.getSigners();

  const nft = await ethers.getContractAt("TestNFT", nftAddress, signer);
  console.log(`Minting NFT to ${signer.address}...`);

  const tx = await nft.mint(signer.address);
  await tx.wait();
  console.log("✅ NFT minted!");
}

main();