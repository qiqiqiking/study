// scripts/create-auction.js
const { ethers } = require("hardhat");

async function main() {
  const auctionAddress = "0xD74321F80d23093b5A3341b08de5AF17275bAFBD";
  const nftAddress = "0xD4Ff4853BeB640C8F026ddECD37137C3741eB263"; 
  const tokenId = 0;
  const duration = 3600; // 1 hour (must be >= 1 hour per contract)

  const [seller] = await ethers.getSigners();
  const auction = await ethers.getContractAt("NFTAuction", auctionAddress);

  console.log("Creating auction...");
  const tx = await auction.createAuction(
    nftAddress,
    tokenId,
    duration,
    true,               // ETH auction
    ethers.ZeroAddress  // ignored for ETH
  );
  await tx.wait();
  console.log("✅ Auction created!");

  // ✅ CORRECT: matches keccak256(abi.encodePacked(nft, tokenId)) in Solidity
  const auctionId = ethers.solidityPackedKeccak256(
    ["address", "uint256"],
    [nftAddress, tokenId]
  );
  console.log("📝 Auction ID:", auctionId);
}

main().catch(console.error);