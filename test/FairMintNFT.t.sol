// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {FairMintNFT} from "../src/FairMintNFT.sol";

contract FairMintNFTTest is Test {
    FairMintNFT fairMintNFT;
    address dev;
    address alice;
    address bob;

    function setUp() external {
        dev = makeAddr("dev");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        fairMintNFT = new FairMintNFT(dev, 10);
    }

    function test_CanMintExactlyMaxSupply() public {
        vm.prank(alice);
        fairMintNFT.mint(10);
        assertEq(fairMintNFT.balanceOf(alice), 10);
        assertEq(fairMintNFT.totalSupply(), 10);
        assertEq(fairMintNFT.ownerOf(1), alice);
        assertEq(fairMintNFT.ownerOf(10), alice);
    }

    function test_RevertWhen_ExceedsMaxSupply() public {
        vm.startPrank(alice);
        fairMintNFT.mint(8);
        assertEq(fairMintNFT.balanceOf(alice), 8);
        assertEq(fairMintNFT.totalSupply(), 8);
        vm.expectRevert(FairMintNFT.MaxSupplyExceeded.selector);
        fairMintNFT.mint(5);
        assertEq(fairMintNFT.balanceOf(alice), 8);
        assertEq(fairMintNFT.totalSupply(), 8);
        vm.stopPrank();
    }

    function test_RevertWhen_ZeroQuantity() public {
        vm.expectRevert(FairMintNFT.QuantityZero.selector);
        vm.prank(alice);
        fairMintNFT.mint(0);
    }

    function test_RevertWhen_MintAfterSoldOut() public {
        vm.startPrank(alice);
        fairMintNFT.mint(10);
        vm.expectRevert(FairMintNFT.MaxSupplyExceeded.selector);
        fairMintNFT.mint(1);
        vm.stopPrank();
    }

    function test_CanMint_TwoUsers() public {
        vm.prank(alice);
        fairMintNFT.mint(3);
        assertEq(fairMintNFT.ownerOf(3), alice);
        vm.prank(bob);
        fairMintNFT.mint(2);
        assertEq(fairMintNFT.ownerOf(4), bob);
        assertEq(fairMintNFT.balanceOf(bob), 2);
        assertEq(fairMintNFT.totalSupply(), 5);
    }
}
