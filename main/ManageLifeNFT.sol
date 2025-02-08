// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ManageLifeNFT is ERC721, Ownable {
    struct Property {
        uint256 tokenId;
        string title;
        string description;
        string imageURI;
        uint256 price;
        address owner;
    }

    mapping(uint256 => Property) private properties;
    uint256 private _tokenCounter;

    constructor(
        string memory name,
        string memory symbol,
        address initialOwner
    ) ERC721(name, symbol) Ownable(initialOwner) {
        _tokenCounter = 0;
    }

    // 创建NFT
    function createProperty(string memory title, string memory description, string memory imageURI, uint256 price) external onlyOwner returns (uint256) {
        uint256 tokenId = _tokenCounter;
        _tokenCounter++;
        _safeMint(msg.sender, tokenId);
        properties[tokenId] = Property(tokenId, title, description, imageURI, price, msg.sender);
        return tokenId;
    }

    // 获取词条信息
    function getProperty(uint256 tokenId) external view returns (Property memory) {
        return properties[tokenId];
    }

    // 转移NFT ownership
    function transfer(address to, uint256 tokenId) external {
        safeTransferFrom(msg.sender, to, tokenId);
    }
}
