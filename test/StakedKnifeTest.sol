// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/StakedKnife.sol";
import "../src/Knife.sol";
import "../src/MPLegacyToken.sol";

import {console} from "forge-std/console.sol";


contract DepositTest is Test {

    StakedKnife public stakedKnife;
    Knife public knife;
    MPLegacyToken public token;

    function setUp() public {
        knife = new Knife();
        token = new MPLegacyToken();
        stakedKnife = new StakedKnife(address(knife), address(token));
        token.addAuthorized(address(stakedKnife));
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
    MPLegacyToken public token;

    function setUp() public {
        knife = new Knife();
        token = new MPLegacyToken();
        stakedKnife = new StakedKnife(address(knife), address(token));
        token.addAuthorized(address(stakedKnife));
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
    MPLegacyToken public token;


    function setUp() public {
        knife = new Knife();
        token = new MPLegacyToken();
        stakedKnife = new StakedKnife(address(knife), address(token));
        token.addAuthorized(address(stakedKnife));
    }

    function testLGCY() public {
        // mint & deposit
        knife.mint(1);
        knife.setApprovalForAll(address(stakedKnife), true);
        uint256[] memory tokenIds = knife.tokenIdsOfUser(address(this));
        stakedKnife.depositSelected(tokenIds);

        // Check amount accumalated after 10sec
        vm.warp(block.timestamp + 10);
        assertEq(stakedKnife.getLGCYMPAmount(0), 10 * 10**18);

        // after 30
        vm.warp(block.timestamp + 20);
        assertEq(stakedKnife.getLGCYMPAmount(0), 30 * 10**18);
        
        // after 50
        vm.warp(block.timestamp + 20);
        assertEq(stakedKnife.getLGCYMPAmount(0), 50 * 10**18);

        // after 60
        vm.warp(block.timestamp + 10);
        assertEq(stakedKnife.getLGCYMPAmount(0), 50 * 10**18); //knife MAXCAP reached



        // Claim
        stakedKnife.claim(address(this), 0);
        assertEq(stakedKnife.getLGCYMPAmount(0), 0);
        assertEq(token.balanceOf(address(this)), 50 * 10**18);

        // wait 50 s and check amounts
        vm.warp(block.timestamp + 50);
        assertEq(stakedKnife.getLGCYMPAmount(0), 50 * 10**18);
        assertEq(token.balanceOf(address(this)), 50 * 10**18);

        // claim
        stakedKnife.claim(address(this), 0);

        assertEq(stakedKnife.getLGCYMPAmount(0), 0 * 10**18);
        assertEq(token.balanceOf(address(this)), 100 * 10**18);

        // wait 10 sec claim should revert as address max cap is reached
        vm.warp(block.timestamp + 10);

        vm.expectRevert(bytes("Spend some tokens first."));
        stakedKnife.claim(address(this), 0);

        assertEq(stakedKnife.getLGCYMPAmount(0), 10 * 10**18);
        assertEq(token.balanceOf(address(this)), 100 * 10**18);

        // burn 10 tokens, so you can claim
        token.burn(10 * 10 **18);
        assertEq(token.balanceOf(address(this)), 90 * 10**18);
        stakedKnife.claim(address(this), 0);

        assertEq(stakedKnife.getLGCYMPAmount(0), 0 * 10**18);
        assertEq(token.balanceOf(address(this)), 100 * 10**18);


        // wait 10 sec and withdraw, this should revert as in claim within the withdraw.
        vm.warp(block.timestamp + 10);
        assertEq(stakedKnife.getLGCYMPAmount(0), 10 * 10**18);
        uint256[] memory stakedTokenIds = stakedKnife.tokenIdsOfUser(address(this));
        vm.expectRevert(bytes("Spend some tokens first."));
        stakedKnife.withdrawSelected(stakedTokenIds);

        // burn 10 tokens to have enough space. However this should revert again as withrawing reduces the address max cap to 50 instead of 100 
        token.burn(10 * 10 **18);
        assertEq(token.balanceOf(address(this)), 90 * 10**18);
        vm.expectRevert(bytes("Can't withdraw, use your tokens first."));
        stakedKnife.withdrawSelected(stakedTokenIds);

        // burn 50 token & withdraw 
        token.burn(50 * 10 **18);
        assertEq(token.balanceOf(address(this)), 40 * 10**18);
        stakedKnife.withdrawSelected(stakedTokenIds);
    }
}