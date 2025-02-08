// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ManageLifeNFT.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Admin is Ownable, ReentrancyGuard {
    // 市场参数
    uint256 public marketFee; // 市场手续费百分比，如500代表5%
    bool public isMarketPaused; // 市场是否暂停

    // 代币地址
    address public mlifeToken; // MLIFE代币地址
    address public mlusdtToken; // MLUSDT代币地址
    address public mlusdcToken; // MLUSDC代币地址
    address public nftContract; // 管理NFT合约的地址

    // 事件
    event MarketFeeUpdated(uint256 previousFee, uint256 newFee);
    event TokenAddressUpdated(string tokenName, address previousAddress, address newAddress);
    event MarketPaused(bool isPaused);
    event RevenueWithdrawn(address withdrawer, uint256 amount, string tokenType);

    // 预先计算的目标字符串哈希值
    // 预先计算的目标字符串哈希值
    bytes32 constant MLIFE_HASH = keccak256("mlife");
    bytes32 constant MLUSDT_HASH = keccak256("mlusdt");
    bytes32 constant MLUSDC_HASH = keccak256("mlusdc");

    constructor(
        uint256 initialMarketFee,
        address _mlifeToken,
        address _mlusdtToken,
        address _mlusdcToken,
        address _nftContract,
        address initialOwner
    ) Ownable(initialOwner) ReentrancyGuard() {
        marketFee = initialMarketFee;
        mlifeToken = _mlifeToken;
        mlusdtToken = _mlusdtToken;
        mlusdcToken = _mlusdcToken;
        nftContract = _nftContract;
        isMarketPaused = false;
    }

    // 更新市场手续费
    function updateMarketFee(uint256 newFee) external onlyOwner {
        emit MarketFeeUpdated(marketFee, newFee);
        marketFee = newFee;
    }

    // 更新代币地址
    function updateTokenAddress(string memory tokenName, address newAddress) external onlyOwner {
        bytes32 nameHash = keccak256(abi.encodePacked(tokenName));
        if (nameHash == MLIFE_HASH) {
            emit TokenAddressUpdated("mlife", mlifeToken, newAddress);
            mlifeToken = newAddress;
        } else if (nameHash == MLUSDT_HASH) {
            emit TokenAddressUpdated("mlusdt", mlusdtToken, newAddress);
            mlusdtToken = newAddress;
        } else if (nameHash == MLUSDC_HASH) {
            emit TokenAddressUpdated("mlusdc", mlusdcToken, newAddress);
            mlusdcToken = newAddress;
        } else if (nameHash == keccak256("nft")) {
            emit TokenAddressUpdated("nft", nftContract, newAddress);
            nftContract = newAddress;
        } else {
            revert("Invalid token name");
        }
    }

    // 暂停市场
    function pauseMarket() external onlyOwner {
        isMarketPaused = true;
        emit MarketPaused(true);
    }

    // 恢复市场
    function resumeMarket() external onlyOwner {
        isMarketPaused = false;
        emit MarketPaused(false);
    }

    // 提取平台收益 - 以太坊
    function withdrawETHRevenue(address payable recipient, uint256 amount) external onlyOwner nonReentrant {
        require(amount <= address(this).balance, "Insufficient balance for withdraw");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Transfer failed");
        emit RevenueWithdrawn(recipient, amount, "ETH");
    }

    // 提取平台收益 - 代币
    function withdrawTokenRevenue(address payable recipient, string memory tokenType, uint256 amount) external onlyOwner nonReentrant {
        bytes32 tokenHash = keccak256(abi.encodePacked(tokenType)); // 计算传入字符串的哈希值
        if (tokenHash == MLIFE_HASH) {
            IERC20(mlifeToken).transfer(recipient, amount);
            emit RevenueWithdrawn(recipient, amount, "MLIFE");
        } else if (tokenHash == MLUSDT_HASH) {
            IERC20(mlusdtToken).transfer(recipient, amount);
            emit RevenueWithdrawn(recipient, amount, "MLUSDT");
        } else if (tokenHash == MLUSDC_HASH) {
            IERC20(mlusdcToken).transfer(recipient, amount);
            emit RevenueWithdrawn(recipient, amount, "MLUSDC");
        } else {
            revert("Invalid token type");
        }
    }
}

