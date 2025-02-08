// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Admin.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Marketplace is ReentrancyGuard {
    // Admin contract interface
    Admin public adminContract;

    // Enum for order statuses
    enum OrderStatus {
        Created,          // Order created
        Completed,        // Order completed
        Cancelled         // Order cancelled
    }

    // Order struct
    struct Order {
        address seller;         // Seller's address
        address nftContract;   // NFT contract address
        uint256 tokenId;       // NFT token ID
        uint256 amount;        // Quantity listed
        uint256 price;         // Price per NFT
        OrderStatus status;    // Order status
        string currency;       // Currency type (MLIFE, MLUSDT, MLUSDC)
        uint256 timestamp;    // Order timestamp
    }

    // Order mapping: orderID => Order
    mapping(uint256 => Order) public orders;

    // Order ID counter
    uint256 private _orderCounter;

    // Constant hash values for currency strings
    bytes32 constant MLIFE_HASH = keccak256("MLIFE");
    bytes32 constant MLUSDT_HASH = keccak256("MLUSDT");
    bytes32 constant MLUSDC_HASH = keccak256("MLUSDC");

    // Events
    event OrderCreated(
        uint256 indexed orderID,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 amount,
        uint256 price,
        string currency,
        OrderStatus status
    );

    event OrderCompleted(
        uint256 indexed orderID,
        address indexed buyer,
        address indexed seller,
        uint256 tokenId,
        uint256 amount,
        uint256 price,
        string currency
    );

    event OrderCancelled(
        uint256 indexed orderID,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 amount,
        uint256 price,
        string currency
    );

    // Constructor
    constructor(address _adminContract) {
        adminContract = Admin(_adminContract);
    }

    // Function to create a new order
    function createOrder(
        address nftContract,
        uint256 tokenId,
        uint256 amount,
        uint256 price,
        string calldata currency
    ) external nonReentrant {
        require(!adminContract.isMarketPaused(), "Market is paused");

        bytes32 currencyHash = keccak256(abi.encodePacked(currency));
        require(
            currencyHash == MLIFE_HASH || currencyHash == MLUSDT_HASH || currencyHash == MLUSDC_HASH,
            "Invalid currency type"
        );

        require(amount > 0, "Amount must be greater than 0");
        require(price > 0, "Price must be greater than 0");

        uint256 fee = (price * adminContract.marketFee()) / 10000;

        IERC721 nft = IERC721(nftContract);
        require(nft.ownerOf(tokenId) == msg.sender, "You do not own this NFT");

        _orderCounter++;
        orders[_orderCounter] = Order({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            amount: amount,
            price: price,
            status: OrderStatus.Created,
            currency: currency,
            timestamp: block.timestamp
        });

        emit OrderCreated(
            _orderCounter,
            msg.sender,
            nftContract,
            tokenId,
            amount,
            price,
            currency,
            OrderStatus.Created
        );

        _transferFee(fee, currencyHash);
    }

    // Function to buy an order
    function buyOrder(uint256 orderID) external payable nonReentrant {
        Order storage order = orders[orderID];
        require(order.status == OrderStatus.Created, "Order is not active");
        require(!adminContract.isMarketPaused(), "Market is paused");
        require(msg.sender != order.seller, "Cannot buy your own order");

        bytes32 currencyHash = keccak256(abi.encodePacked(order.currency));
        require(
            currencyHash == MLIFE_HASH || currencyHash == MLUSDT_HASH || currencyHash == MLUSDC_HASH,
            "Invalid currency type"
        );

        try IERC20(adminContract.mlifeToken()).transferFrom(
            msg.sender,
            order.seller,
            order.price
        ) {
            _transferNft(order, msg.sender);
            order.status = OrderStatus.Completed;
            emit OrderCompleted(
                orderID,
                msg.sender,
                order.seller,
                order.tokenId,
                order.amount,
                order.price,
                order.currency
            );
        } catch {
            revert("Token transfer failed");
        }
    }

    // Private function to transfer fees
    function _transferFee(uint256 fee, bytes32 currencyHash) private {
        if (currencyHash == MLIFE_HASH) {
            IERC20(adminContract.mlifeToken()).transferFrom(
                msg.sender,
                address(adminContract),
                fee
            );
        } else if (currencyHash == MLUSDT_HASH) {
            IERC20(adminContract.mlusdtToken()).transferFrom(
                msg.sender,
                address(adminContract),
                fee
            );
        } else if (currencyHash == MLUSDC_HASH) {
            IERC20(adminContract.mlusdcToken()).transferFrom(
                msg.sender,
                address(adminContract),
                fee
            );
        } else {
            revert("Invalid currency type");
        }
    }

    // Private function to transfer NFT
    function _transferNft(Order storage order, address buyer) private {
        IERC721(order.nftContract).safeTransferFrom(
            order.seller,
            buyer,
            order.tokenId,
            ""
        );
    }

    // Function to cancel an order
    function cancelOrder(uint256 orderID) external nonReentrant {
        Order storage order = orders[orderID];
        require(order.status == OrderStatus.Created, "Order cannot be cancelled");
        require(order.seller == msg.sender, "Only seller can cancel");

        order.status = OrderStatus.Cancelled;
        emit OrderCancelled(
            orderID,
            msg.sender,
            order.nftContract,
            order.tokenId,
            order.amount,
            order.price,
            order.currency
        );
    }

    // Function to get order details
    function getOrder(uint256 orderID) external view returns (Order memory) {
        return orders[orderID];
    }
}
