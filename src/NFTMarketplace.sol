// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

error NFTMarketplace__OnlySeller(string message);
error NFTMarketplace__PriceGreaterThanZero(string message);
error NFTMarketplace__ExpirationInTheFuture(string message);
error NFTMarketplace__TokenAlreadyOnSale(string message);
error NFTMarketplace__NoActiveSaleFound(string message);
error NFTMarketplace__SaleExpired(string message);
error NFTMarketplace__InsufficientFunds(string message);
error NFTMarketplace__TransferFailed(string message);

contract NFTMarketplace {
    struct Sale {
        address seller;
        address nft;
        uint256 id;
        uint256 price;
        uint256 expiration;
        bool active;
    }

    mapping(bytes32 => Sale) public s_sales;

    modifier onlySeller(bytes32 saleId) {
        if (msg.sender != s_sales[saleId].seller) {
            revert NFTMarketplace__OnlySeller("You are not the seller");
        }
        _;
    }

    event SaleCreated(
        bytes32 indexed saleId,
        address indexed seller,
        address indexed nft,
        uint256 id,
        uint256 price,
        uint256 expiration
    );
    event SaleCancelled(
        bytes32 indexed saleId,
        address indexed seller,
        address nft,
        uint256 id
    );
    event SaleCompleted(
        bytes32 indexed saleId,
        address indexed seller,
        address indexed buyer,
        address nft,
        uint256 id,
        uint256 price
    );

    function sell(
        address _nft,
        uint256 _id,
        uint256 _price,
        uint256 _expiration
    ) external {
        if (_price <= 0) {
            revert NFTMarketplace__PriceGreaterThanZero(
                "Price must be greater than zero"
            );
        }
        if (_expiration <= block.timestamp) {
            revert NFTMarketplace__ExpirationInTheFuture(
                "Expiration must be in the future"
            );
        }

        bytes32 saleId = keccak256(
            abi.encodePacked(msg.sender, _nft, _id, _price, _expiration)
        );

        if (s_sales[saleId].active == true) {
            revert NFTMarketplace__TokenAlreadyOnSale(
                "Token is already on sale"
            );
        }

        IERC721(_nft).approve(address(this), _id);
        s_sales[saleId] = Sale({
            seller: msg.sender,
            nft: _nft,
            id: _id,
            price: _price,
            expiration: _expiration,
            active: true
        });

        emit SaleCreated(saleId, msg.sender, _nft, _id, _price, _expiration);
    }

    function cancel(bytes32 _saleId) external onlySeller(_saleId) {
        if (s_sales[_saleId].active != true) {
            revert NFTMarketplace__NoActiveSaleFound("No active sale found");
        }

        delete s_sales[_saleId];
        IERC721(s_sales[_saleId].nft).approve(
            address(this),
            s_sales[_saleId].id
        );

        emit SaleCancelled(
            _saleId,
            msg.sender,
            s_sales[_saleId].nft,
            s_sales[_saleId].id
        );
    }

    function buy(bytes32 _saleId) external payable {
        if (s_sales[_saleId].active != true) {
            revert NFTMarketplace__NoActiveSaleFound("No active sale found");
        }
        if (block.timestamp >= s_sales[_saleId].expiration) {
            revert NFTMarketplace__SaleExpired("Sale expired");
        }
        if (msg.value < s_sales[_saleId].price) {
            revert NFTMarketplace__InsufficientFunds("Insufficient funds");
        }

        address seller = s_sales[_saleId].seller;
        address nft = s_sales[_saleId].nft;
        uint256 price = s_sales[_saleId].price;
        uint256 id = s_sales[_saleId].id;

        IERC721(nft).safeTransferFrom(seller, msg.sender, id);

        (bool success, ) = payable(seller).call{value: price}("");
        if (!success) {
            revert NFTMarketplace__TransferFailed("Transfer failed");
        }

        delete s_sales[_saleId];

        emit SaleCompleted(_saleId, seller, msg.sender, nft, id, price);
    }
}
