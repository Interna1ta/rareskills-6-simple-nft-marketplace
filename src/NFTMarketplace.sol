// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

error NFTMarketplace__OnlySeller();
error NFTMarketplace__PriceGreaterThanZero();
error NFTMarketplace__ExpirationInTheFuture();
error NFTMarketplace__TokenAlreadyOnSale();
error NFTMarketplace__NoActiveSaleFound();
error NFTMarketplace__SaleExpired();
error NFTMarketplace__InsufficientFunds();
error NFTMarketplace__TransferFailed();

/// @title A Simple NFT Marketplace
/// @author Pere Serra and Sergi Roca
/// @notice This contract will list and sell NFTs for everyone
/// @dev Implements IERC721 library from OpenZeppelin
contract NFTMarketplace {
    struct Sale {
        address seller;
        address nftAddress;
        uint256 nftId;
        uint256 price;
        uint256 expiration;
        bool active;
    }

    mapping(bytes32 => Sale) public s_sales;

    modifier onlyActiveSale(bytes32 _saleId) {
        if (s_sales[_saleId].active != true) {
            revert NFTMarketplace__NoActiveSaleFound();
        }
        _;
    }

    event SaleCreated(
        bytes32 indexed saleId,
        address indexed seller,
        address indexed nftAddress,
        uint256 nftId,
        uint256 price,
        uint256 expiration
    );
    event SaleCancelled(
        bytes32 indexed saleId,
        address indexed seller,
        address nftAddress,
        uint256 nftId
    );
    event SaleCompleted(
        bytes32 indexed saleId,
        address indexed seller,
        address indexed buyer,
        address nftAddress,
        uint256 nftId,
        uint256 price
    );

    /// @notice List an item for sale
    /// @dev Creates a sell linked to a bytes32 id
    /// @param _nftAddress The address of the NFT contract
    /// @param _nftId The unique identifier of the NFT within the contract
    /// @param _price The price at which the NFT is being sold
    /// @param _expiration The timestamp at which the sale listing expires
    function sell(
        address _nftAddress,
        uint256 _nftId,
        uint256 _price,
        uint256 _expiration
    ) external {
        if (_price <= 0) {
            revert NFTMarketplace__PriceGreaterThanZero();
        }
        if (_expiration <= block.timestamp) {
            revert NFTMarketplace__ExpirationInTheFuture();
        }

        bytes32 saleId = keccak256(
            abi.encodePacked(
                msg.sender,
                _nftAddress,
                _nftId,
                _price,
                _expiration
            )
        );

        if (s_sales[saleId].active == true) {
            revert NFTMarketplace__TokenAlreadyOnSale();
        }

        IERC721(_nftAddress).approve(address(this), _nftId);
        s_sales[saleId] = Sale({
            seller: msg.sender,
            nftAddress: _nftAddress,
            nftId: _nftId,
            price: _price,
            expiration: _expiration,
            active: true
        });

        emit SaleCreated(
            saleId,
            msg.sender,
            _nftAddress,
            _nftId,
            _price,
            _expiration
        );
    }

    /// @notice Cancel a sale listing
    /// @dev Allows the seller to cancel an active sale listing
    /// @param _saleId The unique identifier of the sale listing to be cancelled
    function cancel(bytes32 _saleId) external onlyActiveSale(_saleId) {
        if (msg.sender != s_sales[_saleId].seller) {
            revert NFTMarketplace__OnlySeller();
        }

        delete s_sales[_saleId];

        emit SaleCancelled(
            _saleId,
            msg.sender,
            s_sales[_saleId].nftAddress,
            s_sales[_saleId].nftId
        );
    }

    /// @notice Purchase an NFT from a sale listing
    /// @dev Allows a buyer to purchase an NFT from an active sale listing
    /// @param _saleId The unique identifier of the sale listing to be purchased
    function buy(bytes32 _saleId) external payable onlyActiveSale(_saleId) {
        if (block.timestamp >= s_sales[_saleId].expiration) {
            revert NFTMarketplace__SaleExpired();
        }
        if (msg.value < s_sales[_saleId].price) {
            revert NFTMarketplace__InsufficientFunds();
        }

        address seller = s_sales[_saleId].seller;
        address nftAddress = s_sales[_saleId].nftAddress;
        uint256 price = s_sales[_saleId].price;
        uint256 nftId = s_sales[_saleId].nftId;

        IERC721(nftAddress).safeTransferFrom(seller, msg.sender, nftId);

        (bool success, ) = payable(seller).call{value: price}("");
        if (!success) {
            revert NFTMarketplace__TransferFailed();
        }

        delete s_sales[_saleId];

        emit SaleCompleted(
            _saleId,
            seller,
            msg.sender,
            nftAddress,
            nftId,
            price
        );
    }

    /// @notice Retrieve the details of a sale listing
    /// @dev Allows anyone to view the details of an active sale listing
    /// @param _saleId The unique identifier of the sale listing to be retrieved
    /// @return sale A struct containing the details of the sale listing
    function getSale(bytes32 _saleId) external view returns (Sale memory sale) {
        return s_sales[_saleId];
    }
}
