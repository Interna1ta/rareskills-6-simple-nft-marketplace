// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";
import {NFTMarketplace} from "../src/NFTMarketplace.sol";

contract NFTMarketplaceTest is Test {
    NFTMarketplace public marketplace;
    address public OWNER = makeAddr("OWNER");

    function setUp() public {
        marketplace = new NFTMarketplace();
    }
}
