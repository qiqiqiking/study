// scripts/approve-nft.js
const { ethers } = require("hardhat");

async function main() {
  const auctionAddress = "0xD74321F80d23093b5A3341b08de5AF17275bAFBD";
  const nftAddress = "0xD4Ff4853BeB640C8F026ddECD37137C3741eB263"; 
  const tokenId = 0;

  const [signer] = await ethers.getSigners();
  const nft = await ethers.getContractAt("IERC721", nftAddress);

  console.log("Approving NFT for auction...");
  const tx = await nft.approve(auctionAddress, tokenId);
  await tx.wait();
  console.log("✅ Approved!");
}

main().catch(console.error);