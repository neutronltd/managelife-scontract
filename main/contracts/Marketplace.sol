// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/// @title ManageLife Marketplace
/// @author https://managelife.io
/// @notice This smart contract is used within the ManageLife ecosystem for buying and selling MLRE properties
/// @dev A different marketplace contract needs to be built for the NFTi
contract Marketplace is ReentrancyGuard, Ownable, Pausable, IERC721Receiver {
    using SafeERC20 for IERC20;

    struct Listing {
        address seller;
        uint256 tokenId;
        address paymentToken; // ETH is represented by address(0)
        uint256 minPrice;
        bool active;
    }

    struct Bid {
        address bidder;
        uint256 amount;
    }

    uint256 public marketplaceFee = 200; // 2% scaled
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public MAX_FEE = 500; // 5% Initial max admin fee

    uint256 public adminsEthEarnings;
    mapping(address => uint256) public adminsTokenEarnings;
    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Bid) public currentBids;
    mapping(address => uint256) public ethRefundsForBidders;
    mapping(address => mapping(address => uint256)) public tokenRefundsForBidders;

    address public MLIFE;
    address public tokenUSDT;
    address public tokenUSDC;
    address public nftContract;

    // 支持的支付代币集合
    mapping(address => bool) public supportedTokens;

    event ListingCreated(
        address indexed seller,
        uint256 indexed tokenId,
        address paymentToken,
        uint256 minPrice
    );
    event ListingCancelled(uint256 indexed tokenId, address seller);
    event BidPlaced(uint256 indexed tokenId, address indexed bidder, uint256 amount);
    event BidWithdrawn(uint256 indexed tokenId, address indexed bidder);
    event NFTSold(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price);
    event AdminEthWithdrawals(address indexed admin, uint256 amount);
    event AdminTokenWithdrawals(address indexed admin, address indexed token, uint256 amount);
    event RefundIssued(address indexed receiver, address indexed tokenType, uint256 amount);
    event MarketplaceFeeUpdated(uint256 newFee);
    event NftAddressUpdated(address oldAddress, address newAddress);
    event MLifeTokenAddressUpdated(address oldAddress, address newAddress);
    event UsdtAddressUpdated(address oldAddress, address newAddress);
    event UsdcAddressUpdated(address oldAddress, address newAddress);
    event MaxFeeUpdated(uint256 newMaxFee);
    event RefundWithdrawn(address indexed paymentType, address indexed receiver, uint256 amount);
    event Paused();
    event Unpaused();
    event ContractInitialized(
        address nftContract,
        address MLIFE,
        address tokenUSDT,
        address tokenUSDC,
        string version
    );

    modifier onlyNFTOwner(uint256 tokenId) {
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not NFT owner");
        _;
    }

    modifier validPaymentToken(address token) {
        require(token == address(0) || supportedTokens[token], "Unsupported payment token");
        _;
    }

    modifier isListingActive(uint256 tokenId) {
        require(listings[tokenId].active, "Listing not active");
        _;
    }

    constructor(
        address _nftContract,
        address _MLIFE,
        address _tokenUSDT,
        address _tokenUSDC
    ) Ownable(msg.sender) {
        require(_nftContract != address(0), "Invalid NFT contract");
        require(_MLIFE != address(0), "Invalid MLIFE address");
        require(_tokenUSDT != address(0), "Invalid USDT address");
        require(_tokenUSDC != address(0), "Invalid USDC address");

        nftContract = _nftContract;
        MLIFE = _MLIFE;
        tokenUSDT = _tokenUSDT;
        tokenUSDC = _tokenUSDC;

        // 初始化支持的支付代币
        supportedTokens[MLIFE] = true;
        supportedTokens[tokenUSDT] = true;
        supportedTokens[tokenUSDC] = true;

        // 添加版本号
        string memory version = "1.0.0";
        // 触发初始化完成事件
        emit ContractInitialized(nftContract, MLIFE, tokenUSDT, tokenUSDC, version);
    }

    ///////////////////////
    // Admin Functions
    ///////////////////////

    function pause() external onlyOwner {
        _pause();
        emit Paused();
    }

    function unpause() external onlyOwner {
        _unpause();
        emit Unpaused();
    }

    function updateMarketplaceFee(uint256 newFee) external onlyOwner {
        require(newFee > 0 && newFee <= MAX_FEE, "Invalid fee");
        marketplaceFee = newFee;
        emit MarketplaceFeeUpdated(newFee);
    }

    function updateNftContract(address newAddress) external onlyOwner {
        require(newAddress != address(0), "Invalid address");
        emit NftAddressUpdated(nftContract, newAddress);
        nftContract = newAddress;
    }

    function updateMLifeTokenAddress(address newAddress) external onlyOwner {
        require(newAddress != address(0), "Invalid address");
        emit MLifeTokenAddressUpdated(MLIFE, newAddress);
        MLIFE = newAddress;
        if (newAddress != address(0)) {
            supportedTokens[newAddress] = true;
        }
    }

    function updateUsdtTokenAddress(address newAddress) external onlyOwner {
        require(newAddress != address(0), "Invalid address");
        emit UsdtAddressUpdated(tokenUSDT, newAddress);
        tokenUSDT = newAddress;
        if (newAddress != address(0)) {
            supportedTokens[newAddress] = true;
        }
    }

    function updateUsdcTokenAddress(address newAddress) external onlyOwner {
        require(newAddress != address(0), "Invalid address");
        emit UsdcAddressUpdated(tokenUSDC, newAddress);
        tokenUSDC = newAddress;
        if (newAddress != address(0)) {
            supportedTokens[newAddress] = true;
        }
    }

    function updateMaxFee(uint256 newMaxFee) external onlyOwner {
        require(newMaxFee > 0 && newMaxFee < 900, "Invalid max fee");
        MAX_FEE = newMaxFee;
        emit MaxFeeUpdated(newMaxFee);
    }

    function withdrawAdminEthEarnings() external onlyOwner nonReentrant {
        uint256 earnings = adminsEthEarnings;
        require(earnings > 0, "No ETH to withdraw");
        adminsEthEarnings = 0;

        (bool success, ) = owner().call{value: earnings}("");
        require(success, "ETH transfer failed");
        emit AdminEthWithdrawals(owner(), earnings);
    }

    function withdrawAdminTokenEarnings(address tokenAddress) external onlyOwner nonReentrant {
        uint256 earnings = adminsTokenEarnings[tokenAddress];
        require(earnings > 0, "No token earnings");

        adminsTokenEarnings[tokenAddress] = 0;
        IERC20(tokenAddress).safeTransfer(owner(), earnings);
        emit AdminTokenWithdrawals(owner(), tokenAddress, earnings);
    }

    function addSupportedToken(address token) external onlyOwner {
        require(token != address(0), "Invalid token address");
        require(!supportedTokens[token], "Token already supported");
        supportedTokens[token] = true;
    }

    function removeSupportedToken(address token) external onlyOwner {
        require(supportedTokens[token], "Token not supported");
        delete supportedTokens[token];
    }

    ///////////////////////
    // User Functions
    ///////////////////////

    function createListing(
        uint256 tokenId,
        address paymentToken,
        uint256 minPrice
    ) external whenNotPaused onlyNFTOwner(tokenId) validPaymentToken(paymentToken) {
        require(minPrice > 0, "Price should not be zero");
        require(
            IERC721(nftContract).isApprovedForAll(msg.sender, address(this)) ||
                IERC721(nftContract).getApproved(tokenId) == address(this),
            "NFT Approval required"
        );
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        listings[tokenId] = Listing({
            seller: msg.sender,
            tokenId: tokenId,
            paymentToken: paymentToken,
            minPrice: minPrice,
            active: true
        });

        emit ListingCreated(msg.sender, tokenId, paymentToken, minPrice);
    }

    function cancelListing(uint256 tokenId) external whenNotPaused nonReentrant {
        require(listings[tokenId].active, "Listing not active");
        require(listings[tokenId].seller == msg.sender, "Not listing owner");

        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
        delete listings[tokenId];
        emit ListingCancelled(tokenId, msg.sender);
    }

    function placeBid(
        uint256 tokenId,
        uint256 amount,
        address paymentType
    ) external payable whenNotPaused nonReentrant isListingActive(tokenId) validPaymentToken(paymentType) {
        Listing memory listing = listings[tokenId];
        require(amount >= listing.minPrice, "Your bid is below minimum price");
        require(
            (paymentType == address(0) && msg.value == amount) ||
            (paymentType != address(0) && msg.value == 0),
            "Invalid ETH value"
        );

        if (paymentType != address(0)) {
            IERC20(paymentType).safeTransferFrom(msg.sender, address(this), amount);
        }

        Bid memory currentBid = currentBids[tokenId];
        require(amount > currentBid.amount, "Bid must be higher than current bid");

        if (currentBid.amount > 0) {
            _refundBid(listing.paymentToken, currentBid.bidder, currentBid.amount);
        }

        currentBids[tokenId] = Bid({bidder: msg.sender, amount: amount});
        emit BidPlaced(tokenId, msg.sender, amount);
    }

    function acceptBid(uint256 tokenId) external nonReentrant whenNotPaused isListingActive(tokenId) {
        Listing storage listing = listings[tokenId];
        Bid memory bid = currentBids[tokenId];

        require(listing.seller == msg.sender, "Only seller can accept bid");
        require(bid.amount > 0, "No active bid");

        uint256 fee = (bid.amount * marketplaceFee) / FEE_DENOMINATOR;
        uint256 sellerProceeds = bid.amount - fee;

        if (listing.paymentToken == address(0)) {
            adminsEthEarnings += fee;
            (bool success, ) = listing.seller.call{value: sellerProceeds}("");
            require(success, "ETH transfer failed");
        } else {
            adminsTokenEarnings[listing.paymentToken] += fee;
            IERC20(listing.paymentToken).safeTransfer(listing.seller, sellerProceeds);
        }

        IERC721(nftContract).safeTransferFrom(address(this), bid.bidder, listing.tokenId);

        delete listings[tokenId];
        delete currentBids[tokenId];
        emit NFTSold(tokenId, bid.bidder, listing.seller, bid.amount);
    }

    function withdrawEthRefunds() external nonReentrant {
        uint256 amount = ethRefundsForBidders[msg.sender];
        require(amount > 0, "No refundable amount");
        require(amount <= address(this).balance, "Insufficient contract balance");

        ethRefundsForBidders[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH refund failed");
        emit RefundWithdrawn(address(0), msg.sender, amount);
    }

    function withdrawTokenRefunds(address paymentToken) external nonReentrant {
        uint256 amount = tokenRefundsForBidders[msg.sender][paymentToken];
        require(amount > 0, "No refundable token");
        require(IERC20(paymentToken).balanceOf(address(this)) >= amount, "Insufficient balance");

        tokenRefundsForBidders[msg.sender][paymentToken] = 0;
        IERC20(paymentToken).safeTransfer(msg.sender, amount);
        emit RefundWithdrawn(paymentToken, msg.sender, amount);
    }

    function onERC721Received(
        address /* operator */,
        address /* from */,
        uint256 /* tokenId */,
        bytes calldata /* data */
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    ///////////////////////
    // Internal Functions
    ///////////////////////

    function _refundBid(address paymentToken, address bidder, uint256 amount) internal {
        if (paymentToken == address(0)) {
            ethRefundsForBidders[bidder] += amount;
        } else {
            tokenRefundsForBidders[bidder][paymentToken] += amount;
        }
        emit RefundIssued(bidder, paymentToken, amount);
    }

    receive() external payable {}
}
