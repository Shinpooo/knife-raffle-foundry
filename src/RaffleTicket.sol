// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "./MPLegacyToken.sol";
import "./Authorizable.sol";

contract RaffleTicket is ERC721, ERC721Enumerable, Authorizable, VRFConsumerBaseV2 {
    VRFCoordinatorV2Interface COORDINATOR;

    // Your subscription ID.
    uint64 s_subscriptionId;
    address vrfCoordinator = 0x2eD832Ba664535e5886b75D64C46EB9a228C2610;
    bytes32 keyHash = 0x354d2f95da55398f44b7cff77da56283d9c6c829a4bdf1bbcaf2ad6a4d081f61;
    uint32 callbackGasLimit;
    uint16 requestConfirmations = 3;


    uint256 public s_requestId;
    uint256 public current_raffle;

    MPLegacyToken token;

    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    Counters.Counter private _RaffleIdCounter;

    mapping (uint => uint) public tokenIdToRaffleId;
    mapping (uint => Raffle) public raffleIdToRaffle;
        
    struct Raffle { 
        string project_name;
        string image_url;
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
        mapping (address => bool) has_won;
    }

    
    constructor(uint64 subscriptionId, address token_address) ERC721("KnivesLegacyTicket", "KLTICKET") VRFConsumerBaseV2(vrfCoordinator){
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_subscriptionId = subscriptionId;
        token = MPLegacyToken(token_address);
    }



      // Assumes the subscription is funded sufficiently.
    function requestRandomWords(uint raffleId) external onlyAuthorized {
        // Will revert if subscription is not set and funded.
        Raffle storage raffle = raffleIdToRaffle[raffleId];
        require(isRaffleOpen(raffleId), "Raffle is closed.");
        require(raffle.winners_amount < raffle.participants.length, "Not enough participants.");
        current_raffle = raffleId;
        uint32 numWords = raffle.winners_amount;
        uint32 _callbackGasLimit = callbackGasLimit == 0 ? 20000 * numWords : callbackGasLimit; // Default value = 20000 * n_random
        s_requestId = COORDINATOR.requestRandomWords(
        keyHash,
        s_subscriptionId,
        requestConfirmations,
        _callbackGasLimit,
        numWords
        );
    }


    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        Raffle storage raffle = raffleIdToRaffle[current_raffle];
        for (uint i=0; i < raffle.winners_amount; i++) {
            raffle.random_numbers.push(randomWords[i]);
        }
    }

    function pickWinners(uint raffleId) public onlyAuthorized {
        Raffle storage raffle = raffleIdToRaffle[raffleId];
        uint[] memory random_numbers = raffle.random_numbers;
        uint n_participants = raffle.participants.length;
        for (uint i=0; i < raffle.winners_amount; i++) {
            uint random_number = random_numbers[i];
            uint random_index = random_number % n_participants;
            address winner = raffle.participants[random_index];
            while (raffle.has_won[winner]){
                random_number += 1;
                random_index = random_number % n_participants;
                winner = raffle.participants[random_index];
            }
            raffle.winners.push(winner);
            raffle.has_won[winner] = true;
        }

    }



    // testing

    // function addParticipants(uint raffleId, address[] calldata participants) public {
    //     Raffle storage raffle = raffleIdToRaffle[raffleId];
    //     for (uint i = 0; i < participants.length; i++){
    //         raffle.participants.push(participants[i]);
    //     }
    // }
    

    function createRaffle(string memory project_name, string memory image_url, uint price, uint mint_fee, uint max_ticket, uint max_ticket_wallet, uint32 winners_amount, uint open_timestamp, uint close_timestamp) public onlyAuthorized {
        _RaffleIdCounter.increment();
        uint raffle_id = _RaffleIdCounter.current();
        Raffle storage new_raffle = raffleIdToRaffle[raffle_id];
        new_raffle.project_name = project_name;
        new_raffle.image_url = image_url;
        new_raffle.price = price;
        new_raffle.mint_fee = mint_fee;
        new_raffle.max_ticket = max_ticket;
        new_raffle.max_ticket_wallet = max_ticket_wallet;
        new_raffle.winners_amount = winners_amount;
        new_raffle.raffle_id = raffle_id;
        new_raffle.open_timestamp = open_timestamp;
        new_raffle.close_timestamp = close_timestamp;
    }

    function editRaffle(uint raffle_id, string memory project_name, string memory image_url, uint price, uint mint_fee, uint max_ticket, uint max_ticket_wallet, uint32 winners_amount, uint open_timestamp, uint close_timestamp) public onlyAuthorized {
        Raffle storage raffle = raffleIdToRaffle[raffle_id];
        raffle.project_name = project_name;
        raffle.image_url = image_url;
        raffle.price = price;
        raffle.mint_fee = mint_fee;
        raffle.max_ticket = max_ticket;
        raffle.max_ticket_wallet = max_ticket_wallet;
        raffle.winners_amount = winners_amount;
        raffle.open_timestamp = open_timestamp;
        raffle.close_timestamp = close_timestamp;
    }



    function safeMint(uint raffleId, uint amount) public payable {
        Raffle storage raffle = raffleIdToRaffle[raffleId];
        require(msg.value == raffle.mint_fee * amount, "AVAX mint fee not sent.");
        require(isRaffleOpen(raffleId), "Raffle is closed.");
        require(raffle.participants.length + amount <= raffle.max_ticket, "Raffle has reached max entries.");
        require(balanceOf(msg.sender) + amount <= raffle.max_ticket_wallet, "User has too many tickets.");
        require(token.balanceOf(msg.sender) >= raffle.price * amount, "Not enough SUPPLY tokens.");
        token.burnFrom(msg.sender, raffle.price * amount);
        uint tokenId;
        for (uint i = 0; i < amount; i++){
            _tokenIdCounter.increment();
            tokenId = _tokenIdCounter.current();
            _safeMint(msg.sender, tokenId);
            raffle.participants.push(msg.sender);
            tokenIdToRaffleId[tokenId] = raffleId;
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {   
        require(from == address(0), "Non transferable NFT.");
        super._beforeTokenTransfer(from, to, tokenId);
    }



    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }


    
    // VIEWS

    function getRaffleState(uint raffleId) external view returns (string memory){
        Raffle storage raffle = raffleIdToRaffle[raffleId];
        if (block.timestamp < raffle.open_timestamp) return "SOON";
        else if (block.timestamp > raffle.close_timestamp) return "CLOSED";
        else return "OPEN";
    }

    function getWinners(uint raffle_id) external view returns (address[] memory) {
        Raffle storage raffle = raffleIdToRaffle[raffle_id];
        address[] memory winners = raffle.winners;
        return winners;
    }

    function getRandomNumbers(uint raffle_id) external view returns (uint[] memory) {
        Raffle storage raffle = raffleIdToRaffle[raffle_id];
        uint[] memory random_numbers = raffle.random_numbers;
        return random_numbers;
    }

    function getParticipants(uint raffle_id) external view returns (address[] memory) {
        Raffle storage raffle = raffleIdToRaffle[raffle_id];
        address[] memory participants = raffle.participants;
        return participants;
    }

    function isRaffleOpen(uint raffleId) public view returns (bool){
        Raffle storage raffle = raffleIdToRaffle[raffleId];
        return block.timestamp >= raffle.open_timestamp && block.timestamp <= raffle.close_timestamp ? true : false;
    }

    function hasWon(uint raffleId, address user) external view returns (bool){
        Raffle storage raffle = raffleIdToRaffle[raffleId];
        return raffle.has_won[user];
    }

    // VRF PARAMS SETTERS

    function setRequestConfirmation(uint16 _requestConfirmation) external onlyAuthorized {
        requestConfirmations = _requestConfirmation;
    }

    function setcallbackGasLimit(uint32 _callbackGasLimit) external onlyAuthorized {
        callbackGasLimit = _callbackGasLimit;
    }

    function setKeyHash(bytes32 _keyHash) external onlyAuthorized {
        keyHash = _keyHash;
    }

    function setSubscriptionId(uint64 _subscriptionId) external onlyAuthorized {
        s_subscriptionId = _subscriptionId;
    }

    function setVrfCoordinator(address _vrfCoordinator) external onlyAuthorized {
        vrfCoordinator = _vrfCoordinator;
    }
}