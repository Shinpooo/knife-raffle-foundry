// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/StakedKnife.sol";
import "../src/Knife.sol";
import {console} from "forge-std/console.sol";


contract DepositTest is Test {

    StakedKnife public stakedKnife;
    Knife public knife;

    function setUp() public {
        knife = new Knife();
        stakedKnife = new StakedKnife(address(knife));
    }

    function testDepositKnivesAmount(uint8 amountDeposited, uint8 amountMinted) public {
        vm.assume(amountDeposited <= 50);
        vm.assume(amountMinted > amountDeposited);
        knife.mint(amountMinted);
        uint256[] memory tokenIds = tokenIdsOfUser(address(this), amountDeposited);
        knife.setApprovalForAll(address(stakedKnife), true);
        stakedKnife.depositSelected(tokenIds);
        assertTrue(knife.balanceOf(address(this)) == amountMinted - amountDeposited);
        assertTrue(stakedKnife.balanceOf(address(this)) == amountDeposited);
    }

    function tokenIdsOfUser(address user, uint8 amount) public view returns (uint256[] memory) {
        uint256[] memory tokenIds = new uint256[](amount);
        for (uint256 i; i < amount; i++) {
            tokenIds[i] = knife.tokenOfOwnerByIndex(user, i);
        }
        return tokenIds;
    }
}

contract WithdrawTest is Test {

    StakedKnife public stakedKnife;
    Knife public knife;

    function setUp() public {
        knife = new Knife();
        stakedKnife = new StakedKnife(address(knife));
        knife.mint(50);
        knife.setApprovalForAll(address(stakedKnife), true);
        uint256[] memory tokenIds = knife.tokenIdsOfUser(address(this));
        stakedKnife.depositSelected(tokenIds);

    }

    function testWithdrawKnivesAmount(uint8 amountWithdrawn) public {
        uint amount_staked = stakedKnife.balanceOf(address(this));
        vm.assume(amountWithdrawn <= amount_staked);
        uint256[] memory tokenIds = tokenIdsOfUser(address(this), amountWithdrawn);
        stakedKnife.withdrawSelected(tokenIds);
        assertTrue(knife.balanceOf(address(this)) == amountWithdrawn);
        assertTrue(stakedKnife.balanceOf(address(this)) == amount_staked - amountWithdrawn);
    }

    function tokenIdsOfUser(address user, uint8 amount) public view returns (uint256[] memory) {
        uint256[] memory tokenIds = new uint256[](amount);
        for (uint256 i; i < amount; i++) {
            tokenIds[i] = stakedKnife.tokenOfOwnerByIndex(user, i);
        }
        return tokenIds;
    }
}

contract MPLGCYTest is Test {

    StakedKnife public stakedKnife;
    Knife public knife;

    function setUp() public {
        knife = new Knife();
        stakedKnife = new StakedKnife(address(knife));
    }

    function testLGCY() public {
        // mint & deposit
        knife.mint(5);
        knife.setApprovalForAll(address(stakedKnife), true);
        uint256[] memory tokenIds = knife.tokenIdsOfUser(address(this));
        stakedKnife.depositSelected(tokenIds);

        vm.warp(block.timestamp + 500);
        uint mplgcy_amount = stakedKnife.getLGCYMPAmount(1);
        console.log(mplgcy_amount);
        
        assertTrue(mplgcy_amount == 500 * 50);
    }
}