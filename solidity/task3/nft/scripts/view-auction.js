// scripts/view-auction.js
const { ethers } = require("hardhat");

async function main() {
  const auctionAddress = "0xD74321F80d23093b5A3341b08de5AF17275bAFBD";
  const nftAddress = "0xD4Ff4853BeB640C8F026ddECD37137C3741eB263";
  const tokenId = 0;

  const auctionId = ethers.solidityPackedKeccak256(
    ["address", "uint256"],
    [nftAddress, tokenId]
  );

  const auction = await ethers.getContractAt("NFTAuction", auctionAddress);
  const data = await auction.auctions(auctionId);

  console.log("=== Auction Status ===");
  console.log("NFT Contract:", data.nftContract);
  console.log("Token ID:", data.tokenId.toString());
  console.log("Seller:", data.seller);
  console.log("Highest Bidder:", data.highestBidder);
  console.log("Highest Bid (ETH):", ethers.formatEther(data.highestBid));
  console.log("End Time:", new Date(Number(data.endTime) * 1000).toISOString());
  console.log("Settled:", data.settled);
}

main().catch(console.error);