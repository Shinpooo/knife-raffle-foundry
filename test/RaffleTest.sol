// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/StakedKnife.sol";
import "../src/Knife.sol";
import "../src/MPLegacyToken.sol";
import "../src/RaffleTicket.sol";

import {console} from "forge-std/console.sol";


contract RaffleTest is Test {
    
    StakedKnife public stakedKnife;
    Knife public knife;
    MPLegacyToken public token;
    RaffleTicket public raffleTicket;
    address Ororys = address(1);
    address RandomDude = address(2);

    function setUp() public {
        knife = new Knife();
        token = new MPLegacyToken();
        stakedKnife = new StakedKnife(address(knife), address(token));
        token.addAuthorized(address(stakedKnife));
        token.setStakedKnife(address(stakedKnife));
        raffleTicket = new RaffleTicket(327, address(token));
        raffleTicket.addAuthorized(Ororys);

        vm.startPrank(RandomDude);
        knife.mint(1);
        knife.setApprovalForAll(address(stakedKnife), true);
        uint256[] memory tokenIds = knife.tokenIdsOfUser(RandomDude);
        // console.Log(tokenIds);
        stakedKnife.depositSelected(tokenIds);
        vm.warp(block.timestamp + 1 days);
        stakedKnife.claim(RandomDude, tokenIds[0]);
        vm.stopPrank();

    }

    function testCreateRaffle() public {
        raffleTicket.createRaffle("Project1", "test1", 200 * 10**18, 10**16, 500, 5, 20, block.timestamp + 10, block.timestamp + 100);
        vm.prank(Ororys);
        raffleTicket.createRaffle("Project2", "test2", 200 * 10**18, 10**16, 500, 5, 20, block.timestamp, block.timestamp + 100);
        vm.prank(RandomDude);
        vm.expectRevert(bytes("caller is not authorized"));
        raffleTicket.createRaffle("Project3", "test3", 50 * 10**18, 10**16, 500, 5, 20, block.timestamp + 10, block.timestamp + 100);

        assertFalse(raffleTicket.isRaffleOpen(1));
        assertTrue(raffleTicket.isRaffleOpen(2));

        vm.warp(block.timestamp + 50);

        assertTrue(raffleTicket.isRaffleOpen(1));
        assertTrue(raffleTicket.isRaffleOpen(2));

        vm.startPrank(RandomDude);
        assertEq(token.balanceOf(RandomDude), 200 * 10**18);
        vm.deal(RandomDude, 1 ether);
        token.approve(address(raffleTicket), 200 * 10**18);
        raffleTicket.safeMint{value: 10**16}(1, 1);
        assertEq(token.balanceOf(RandomDude), 0 * 10**18);
        assertEq(RandomDude.balance, 1 ether - 10 ** 16);
        console.log(RandomDude.balance);
        assertEq(address(raffleTicket).balance, 10 ** 16);

        vm.stopPrank();


        vm.warp(block.timestamp + 60);

        assertFalse(raffleTicket.isRaffleOpen(1));
        assertFalse(raffleTicket.isRaffleOpen(2));


    }
}