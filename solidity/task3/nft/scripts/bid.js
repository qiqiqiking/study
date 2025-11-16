// scripts/bid.js
const { ethers } = require("hardhat");

async function main() {
  const auctionAddress = "0xD74321F80d23093b5A3341b08de5AF17275bAFBD";
  const nftAddress = "0xD4Ff4853BeB640C8F026ddECD37137C3741eB263"; 
  const tokenId = 0;

  // ✅ CORRECT: must use solidityPackedKeccak256 to match contract
  const auctionId = ethers.solidityPackedKeccak256(
    ["address", "uint256"],
    [nftAddress, tokenId]
  );

  console.log("Computed Auction ID:", auctionId);

  const [bidder] = await ethers.getSigners();
  const auction = await ethers.getContractAt("NFTAuction", auctionAddress);

  // Check if auction exists (endTime > 0)
  const auctionData = await auction.auctions(auctionId);
  if (auctionData.endTime === 0n) {
    throw new Error("❌ Auction not found! Make sure you used the correct auctionId.");
  }

  const bidAmount = ethers.parseEther("0.001"); // 0.001 ETH
  console.log(`Placing bid of ${ethers.formatEther(bidAmount)} ETH...`);

  const tx = await auction.bid(auctionId, { value: bidAmount });
  await tx.wait();

  console.log("✅ Bid successful!");
}

main().catch(console.error);