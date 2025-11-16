// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestNFT is ERC721, Ownable {
    uint256 public tokenId = 0;

    constructor(address initialOwner) 
        ERC721("TestNFT", "TNFT")   // 初始化 ERC721
        Ownable(initialOwner)       // 初始化 Ownable
    {}

    function mint(address to) public onlyOwner {
        _safeMint(to, tokenId++);
    }
}