// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./PriceConverter.sol";

contract NFTAuction is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using PriceConverter for uint256;

    struct Auction {
        address nftContract;
        uint256 tokenId;
        address seller;
        address payable highestBidder;
        uint256 highestBid;
        bool isEth; // true = ETH, false = ERC20
        IERC20Upgradeable erc20Token; // if !isEth
        uint256 endTime;
        bool settled;
    }

    mapping(bytes32 => Auction) public auctions;
    mapping(bytes32 => uint256) public bidUsdValue; // cache USD value for UI

    // Chainlink feeds
    address public ethUsdFeed; // e.g., 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
    address public erc20UsdFeed; // e.g., for USDC: 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6
    uint8 public erc20Decimals; // e.g., 6 for USDC

    modifier auctionExists(bytes32 auctionId) {
        require(auctions[auctionId].endTime > 0, "Auction not found");
        _;
    }

    modifier notSettled(bytes32 auctionId) {
        require(!auctions[auctionId].settled, "Auction already settled");
        _;
    }

    modifier onlySeller(bytes32 auctionId) {
        require(auctions[auctionId].seller == msg.sender, "Not seller");
        _;
    }

    function initialize(
        address _ethUsdFeed,
        address _erc20UsdFeed,
        uint8 _erc20Decimals
    ) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        ethUsdFeed = _ethUsdFeed;
        erc20UsdFeed = _erc20UsdFeed;
        erc20Decimals = _erc20Decimals;
    }

    function createAuction(
        address nftContract,
        uint256 tokenId,
        uint256 duration,
        bool isEth,
        address erc20TokenAddress // ignored if isEth == true
    ) external nonReentrant {
        require(duration >= 1 hours, "Duration too short");
        IERC721Upgradeable(nftContract).transferFrom(
            msg.sender,
            address(this),
            tokenId
        );

        bytes32 auctionId = keccak256(abi.encodePacked(nftContract, tokenId));
        require(auctions[auctionId].endTime == 0, "Auction already exists");

        auctions[auctionId] = Auction({
            nftContract: nftContract,
            tokenId: tokenId,
            seller: msg.sender,
            highestBidder: payable(address(0)),
            highestBid: 0,
            isEth: isEth,
            erc20Token: isEth
                ? IERC20Upgradeable(address(0))
                : IERC20Upgradeable(erc20TokenAddress),
            endTime: block.timestamp + duration,
            settled: false
        });
    }

    function bid(
        bytes32 auctionId
    )
        external
        payable
        auctionExists(auctionId)
        notSettled(auctionId)
        nonReentrant
    {
        Auction storage auction = auctions[auctionId];
        require(block.timestamp < auction.endTime, "Auction ended");
        require(auction.isEth, "Use bidWithAmount for ERC20"); 

        require(msg.value > 0, "Must send ETH");
        require(msg.value > auction.highestBid, "Bid too low");

        // Refund previous bidder
        if (auction.highestBidder != address(0)) {
            (bool sent, ) = auction.highestBidder.call{
                value: auction.highestBid
            }("");
            require(sent, "Refund failed");
        }

        auction.highestBidder = payable(msg.sender);
        auction.highestBid = msg.value;

        // Cache USD value
        bidUsdValue[auctionId] = msg.value.convertToUsd(18, ethUsdFeed);
    }

    function bidWithAmount(
        bytes32 auctionId,
        uint256 amount
    ) external auctionExists(auctionId) notSettled(auctionId) nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(!auction.isEth, "Use normal bid for ETH");
        require(block.timestamp < auction.endTime, "Auction ended");
        require(amount > auction.highestBid, "Bid too low");

        IERC20Upgradeable token = auction.erc20Token;
        token.transferFrom(msg.sender, address(this), amount);

        if (auction.highestBidder != address(0)) {
            token.transfer(auction.highestBidder, auction.highestBid);
        }

        auction.highestBidder = payable(msg.sender);
        auction.highestBid = amount;
        bidUsdValue[auctionId] = amount.convertToUsd(
            erc20Decimals,
            erc20UsdFeed
        );
    }

    function endAuction(
        bytes32 auctionId
    ) external auctionExists(auctionId) notSettled(auctionId) {
        Auction storage auction = auctions[auctionId];
        require(
            block.timestamp >= auction.endTime || msg.sender == auction.seller,
            "Not ended"
        );

        auction.settled = true;

        // Transfer NFT to winner
        if (auction.highestBidder != address(0)) {
            IERC721Upgradeable(auction.nftContract).transferFrom(
                address(this),
                auction.highestBidder,
                auction.tokenId
            );

            // Transfer funds to seller
            if (auction.isEth) {
                (bool sent, ) = payable(auction.seller).call{
                    value: auction.highestBid
                }("");
                require(sent, "Transfer to seller failed");
            } else {
                auction.erc20Token.transfer(auction.seller, auction.highestBid);
            }
        } else {
            // No bids: return NFT to seller
            IERC721Upgradeable(auction.nftContract).transferFrom(
                address(this),
                auction.seller,
                auction.tokenId
            );
        }
    }

    // Withdraw accidental ERC20 deposits (safety)
    function withdrawToken(
        IERC20Upgradeable token,
        uint256 amount
    ) external onlyOwner {
        token.transfer(owner(), amount);
    }

    // For ETH fallback
    receive() external payable {}

    // UUPS upgrade control
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
