// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";
import {NFTMarketplace} from "../src/NFTMarketplace.sol";
import {MyNFT} from "../src/MyNFT.sol";

contract NFTMarketplaceTest is Test {
    NFTMarketplace public marketplace;
    MyNFT public nft;
    address public OWNER = makeAddr("OWNER");
    address public USER = makeAddr("USER");
    uint256 constant NFT_PRICE = 100;
    uint256 constant NFT_ID = 1;

    function setUp() public {
        marketplace = new NFTMarketplace();
        vm.prank(OWNER);
        nft = new MyNFT(OWNER);
    }

    function testSellCreatesSuccessfully() public {
        vm.startPrank(OWNER);
        nft.safeMint(OWNER, NFT_ID);
        //TODO: revise better way to approve
        nft.setApprovalForAll(address(marketplace), true);
        marketplace.sell(address(nft), NFT_ID, NFT_PRICE, block.timestamp + 1000);

        bytes32 saleHash = keccak256(
            abi.encodePacked(
                OWNER,
                address(nft),
                uint256(NFT_ID),
                uint256(NFT_PRICE),
                block.timestamp + 1000
            )
        );
        vm.stopPrank();

        // Assuming marketplace.s_sales() returns a struct with a price property
        assertEq(marketplace.getSale(saleHash).price, NFT_PRICE);
    }

    function testActiveSaleCreated() public {
        vm.startPrank(OWNER);
        nft.safeMint(OWNER, 1);
        nft.setApprovalForAll(address(marketplace), true);
        marketplace.sell(address(nft), NFT_ID, NFT_PRICE, block.timestamp + 1000);

        bytes32 saleHash = keccak256(
            abi.encodePacked(
                OWNER,
                address(nft),
                uint256(NFT_ID),
                uint256(NFT_PRICE),
                block.timestamp + 1000
            )
        );
        vm.stopPrank();
        assertEq(marketplace.getSale(saleHash).active, true);
    }

    function testCancelSaleSuccessfully() public {
        vm.startPrank(OWNER);
        nft.safeMint(OWNER, NFT_ID);
        nft.setApprovalForAll(address(marketplace), true);
        marketplace.sell(address(nft), NFT_ID, NFT_PRICE, block.timestamp + 1000);
        marketplace.cancel(
            keccak256(
                abi.encodePacked(
                    OWNER,
                    address(nft),
                    uint256(NFT_ID),
                    uint256(NFT_PRICE),
                    block.timestamp + 1000
                )
            )
        );
        vm.stopPrank();
    }

    function testCanBuySuccessfully() public {
        vm.startPrank(OWNER);
        nft.safeMint(OWNER, NFT_ID);
        nft.setApprovalForAll(address(marketplace), true);
        marketplace.sell(address(nft), NFT_ID, NFT_PRICE, block.timestamp + 1000);

        bytes32 saleHash = keccak256(
            abi.encodePacked(
                OWNER,
                address(nft),
                uint256(NFT_ID),
                uint256(NFT_PRICE),
                block.timestamp + 1000
            )
        );

        vm.startPrank(USER);
        vm.deal(USER, NFT_PRICE);
        marketplace.buy{value: NFT_PRICE}(saleHash);

        assertEq(nft.ownerOf(NFT_ID), USER);
    }
}
