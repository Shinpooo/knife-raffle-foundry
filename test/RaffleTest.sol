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

    struct Raffle { 
        string project_name;
        string image_url;
        string raffle_type;
        uint price;
        uint mint_fee;
        uint max_ticket;
        uint max_ticket_wallet;
        uint32 winners_amount;
        uint raffle_id;
        uint open_timestamp;
        uint close_timestamp;
        uint[] random_numbers;
        address[] participants;
        address[] winners;
    }

    function setUp() public {
        knife = new Knife();
        token = new MPLegacyToken();
        stakedKnife = new StakedKnife(address(knife), address(token));
        token.addAuthorized(address(stakedKnife));
        raffleTicket = new RaffleTicket(327, address(token));
        raffleTicket.addAuthorized(Ororys);

        
    }

    // function testCreateRaffle() public {
    //     uint raffle1_price = 1000 * 10**18;
    //     uint raffle2_price = 1000 * 10**18;


    //     // Random dude mint a knife and deposit it in the staking contract
    //     vm.startPrank(RandomDude);
    //     knife.mint(1);
    //     knife.setApprovalForAll(address(stakedKnife), true);
    //     uint256[] memory tokenIds = knife.tokenIdsOfUser(RandomDude);
    //     stakedKnife.depositSelected(tokenIds);
    //     // wait 1 day for the knife to earn some SUPPLY tokens
    //     vm.warp(block.timestamp + 20 weeks);
    //     // Claim them
    //     stakedKnife.claim(RandomDude, tokenIds[0]);
    //     vm.stopPrank();


    //     // Create raffle as owner()
    //     raffleTicket.createRaffle("Project1", "test1.png", "Whitelist", raffle1_price, 10**16, 500, 5, 20, block.timestamp + 10, block.timestamp + 100);

    //     vm.prank(Ororys);
    //     // create raffle as admin
    //     raffleTicket.createRaffle("Project2", "test2.png", "Whitelist", raffle2_price, 10**16, 500, 5, 20, block.timestamp, block.timestamp + 100);
    //     vm.prank(RandomDude);
        

    //     // create raffle as random -> should fail
    //     vm.expectRevert(bytes("caller is not authorized"));
    //     raffleTicket.createRaffle("Project3", "test3", "NFT", 50 * 10**18, 10**16, 500, 5, 20, block.timestamp + 10, block.timestamp + 100);

    //     raffleTicket.createRaffle("Project4", "test4", "NFT", 50 * 10**18, 10**16, 500, 5, 20, block.timestamp + 3 weeks, block.timestamp + 4 weeks);

    //     raffleTicket.createRaffle("Project5", "test5", "NFT", 50 * 10**18, 10**16, 500, 5, 20, block.timestamp + 4 weeks, block.timestamp + 5 weeks);

    //     raffleTicket.createRaffle("Project6", "test6", "NFT", 50 * 10**18, 10**16, 500, 5, 20, block.timestamp - 5 weeks, block.timestamp - 4 weeks);

    //     raffleTicket.createRaffle("Project7", "test7", "NFT", 50 * 10**18, 10**16, 500, 5, 20, block.timestamp - 4 weeks, block.timestamp - 3 weeks);

    //     raffleTicket.createRaffle("Project8", "test8", "NFT", 50 * 10**18, 10**16, 500, 5, 20, block.timestamp - 4 weeks, block.timestamp + 3 weeks);

        

    //     // Check raffle open condition with respect to timestamp
    //     assertFalse(raffleTicket.isRaffleOpen(1));
    //     assertTrue(raffleTicket.isRaffleOpen(2));

    //     vm.warp(block.timestamp + 50);

    //     // Check raffle open condition with respect to timestamp
    //     assertTrue(raffleTicket.isRaffleOpen(1));
    //     assertTrue(raffleTicket.isRaffleOpen(2));

    //     // Random dude buy its ticket with paying the AVAX fee + SUPPLY fee
    //     vm.startPrank(RandomDude);
    //     // check random dude has claimed 1000 tokens (THE CAP) after 5days and more
    //     assertEq(token.balanceOf(RandomDude), 1000 * 10**18);
    //     // Set random dude to 1 ether
    //     vm.deal(RandomDude, 1 ether);
    //     token.approve(address(raffleTicket), 1000 * 10**18);
    //     raffleTicket.safeMint{value: 10**16}(1, 1);
    //     // Mint should burn 1000 tokens from random dude
    //     assertEq(token.balanceOf(RandomDude), 0 * 10**18);
    //     // Mint should send 0.01 AVAX to the contract
    //     assertEq(RandomDude.balance, 1 ether - 10 ** 16);
    //     assertEq(address(raffleTicket).balance, 10 ** 16);

    //     vm.stopPrank();

    //     // Check raffle open condition with respect to timestamp
    //     vm.warp(block.timestamp + 60);
        
    //     assertFalse(raffleTicket.isRaffleOpen(1));
    //     assertFalse(raffleTicket.isRaffleOpen(2));


    //     // Displayed : 1 2 4 5 7 8
    //     // Closed : 1 2 6 7
    //     // open : 8
    //     // Coming : 4 5

    //     // Raffle[] memory displayed_raffles = raffleTicket.getDisplayedRaffleIds();
    //     // Raffle[] memory closed_raffles = raffleTicket.getClosedRaffleIds();
    //     // Raffle[] memory open_raffles = raffleTicket.getOpenRaffleIds();
    //     // Raffle[] memory coming_raffles = raffleTicket.getComingRaffleIds();
    //     // console.log(displayed_raffles.length);
    //     // console.log(closed_raffles.length);
    //     // console.log(open_raffles.length);
    //     // console.log(coming_raffles.length);
    //     // console.log(raffleTicket.getClosedRaffleIds());
    //     // console.log(raffleTicket.getOpenRaffleIds());
    //     // console.log(raffleTicket.getComingRaffleIds());

    //     // raffleTicket.requestRandomWords(1);
    // }
}