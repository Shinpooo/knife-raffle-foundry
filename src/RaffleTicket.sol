// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "./MPLegacyToken.sol";
import "./Authorizable.sol";

/*
* @author Pooshin
* @notice This a Raffle contract for Knives Legacy. It allows for the owners to create & edit Raffles for NFT projects. Raffles entries are minted as an NFT
*/

contract RaffleTicket is ERC721, ERC721Enumerable, Authorizable, VRFConsumerBaseV2 {
    VRFCoordinatorV2Interface COORDINATOR;

    uint64 s_subscriptionId;
    address vrfCoordinator = 0x2eD832Ba664535e5886b75D64C46EB9a228C2610;
    bytes32 keyHash = 0x354d2f95da55398f44b7cff77da56283d9c6c829a4bdf1bbcaf2ad6a4d081f61;
    uint32 callbackGasLimit = 2500000;
    uint16 requestConfirmations = 3;


    uint256 public s_requestId;
    uint256 public current_raffle;

    MPLegacyToken token;

    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    Counters.Counter private _RaffleIdCounter;


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
        uint current_entries;
    }

    struct ProjectInfo {
        string twitter_url;
        string discord_url;
        string network;
        uint nft_price;
        uint mint_timestamp;
    }

    struct tokenInfo {
        uint tokenId;
        uint raffleId;
    }

    struct RaffleState {
        uint[] random_numbers;
        address[] participants;
        address[] winners;
    }

    mapping (uint => uint) public tokenIdToRaffleId;
    mapping (uint => Raffle) public raffleIdToRaffle;
    mapping (uint => mapping(address => bool)) public has_won;
    mapping (uint => ProjectInfo) public raffleIdToProjectInfo;
    mapping (uint => RaffleState) raffleIdToRaffleState;

    
    
    constructor(uint64 subscriptionId, address token_address) ERC721("KnivesLegacyTicket", "KLTICKET") VRFConsumerBaseV2(vrfCoordinator){
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_subscriptionId = subscriptionId;
        token = MPLegacyToken(token_address);
    }



    function requestRandomWords(uint raffleId) external onlyAuthorized {
        // Will revert if subscription is not set and funded.
        Raffle memory raffle = raffleIdToRaffle[raffleId];
        RaffleState memory raffle_state = raffleIdToRaffleState[raffleId];
        require(block.timestamp > raffle.close_timestamp, "Raffle should be finished.");
        require(raffle.winners_amount < raffle.current_entries, "Not enough participants.");
        require(raffle_state.random_numbers.length == 0, "Random Numbers already picked.");
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
        Raffle memory raffle = raffleIdToRaffle[current_raffle];
        RaffleState storage raffle_state = raffleIdToRaffleState[current_raffle];
        for (uint i=0; i < raffle.winners_amount; i++) {
            raffle_state.random_numbers.push(randomWords[i]);
        }
    }

    function pickWinners(uint raffleId) public onlyAuthorized {
        Raffle memory raffle = raffleIdToRaffle[raffleId];
        RaffleState storage raffle_state = raffleIdToRaffleState[raffleId];
        require(raffle_state.winners.length == 0, "Winners already set.");
        uint[] memory random_numbers = raffle_state.random_numbers;
        uint n_participants = raffle.current_entries;
        for (uint i=0; i < raffle.winners_amount; i++) {
            uint random_number = random_numbers[i];
            uint random_index = random_number % n_participants;
            address winner = raffle_state.participants[random_index];
            while (has_won[raffleId][winner]){
                random_number += 1;
                random_index = random_number % n_participants;
                winner = raffle_state.participants[random_index];
            }
            raffle_state.winners.push(winner);
            has_won[raffleId][winner] = true;
        }
    }
  

    function createRaffle(Raffle memory new_raffle, ProjectInfo memory new_project_info) public onlyAuthorized {
        _RaffleIdCounter.increment();
        uint raffle_id = _RaffleIdCounter.current();
        new_raffle.raffle_id = raffle_id;
        new_raffle.current_entries = 0;
        raffleIdToRaffle[raffle_id] = new_raffle;
        raffleIdToProjectInfo[raffle_id] = new_project_info;
    }

    function editRaffle(uint raffleId, Raffle memory new_raffle, ProjectInfo memory new_project_info) public onlyAuthorized {
        new_raffle.raffle_id = raffleId;
        new_raffle.current_entries = raffleIdToRaffle[raffleId].current_entries;
        raffleIdToRaffle[raffleId] = new_raffle;
        raffleIdToProjectInfo[raffleId] = new_project_info;
    }

    function safeMint(uint raffleId, uint amount) public payable {
        Raffle storage raffle = raffleIdToRaffle[raffleId];
        RaffleState storage raffle_state = raffleIdToRaffleState[raffleId];
        require(msg.value == raffle.mint_fee * amount, "AVAX mint fee not sent.");
        require(isRaffleOpen(raffleId), "Raffle is closed.");
        require(raffle.current_entries + amount <= raffle.max_ticket, "Raffle has reached max entries.");
        require(balanceOf(msg.sender) + amount <= raffle.max_ticket_wallet, "User has too many tickets.");
        require(token.balanceOf(msg.sender) >= raffle.price * amount, "Not enough SUPPLY tokens.");
        token.burnFrom(msg.sender, raffle.price * amount);
        uint tokenId;
        for (uint i = 0; i < amount; i++){
            _tokenIdCounter.increment();
            tokenId = _tokenIdCounter.current();
            _safeMint(msg.sender, tokenId);
            raffle_state.participants.push(msg.sender);
            tokenIdToRaffleId[tokenId] = raffleId;
        }
        raffle.current_entries += amount;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {   
        require(from == address(0) || to == address(0), "Non transferable NFT.");
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

    function withdraw() external onlyAuthorized {
        (bool os, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(os, "Failed to send Avax");
    }


    
    // VIEWS

    function getRaffleState(uint raffleId) public view returns (uint){
        Raffle memory raffle = raffleIdToRaffle[raffleId];
        if (block.timestamp < raffle.open_timestamp) return 1; // SOON
        else if (block.timestamp > raffle.close_timestamp) return 2; // CLOSED
        else return 3; // OPEN
    }

    function getWinners(uint raffle_id) external view returns (address[] memory) {
        RaffleState memory raffle_state = raffleIdToRaffleState[raffle_id];
        address[] memory winners = raffle_state.winners;
        return winners;
    }

    function getRandomNumbers(uint raffle_id) external view returns (uint[] memory) {
        RaffleState memory raffle_state = raffleIdToRaffleState[raffle_id];
        uint[] memory random_numbers = raffle_state.random_numbers;
        return random_numbers;
    }

    function getParticipants(uint raffle_id) external view returns (address[] memory) {
        RaffleState memory raffle_state = raffleIdToRaffleState[raffle_id];
        address[] memory participants = raffle_state.participants;
        return participants;
    }

    function isRaffleOpen(uint raffleId) public view returns (bool){
        Raffle memory raffle = raffleIdToRaffle[raffleId];
        return block.timestamp >= raffle.open_timestamp && block.timestamp <= raffle.close_timestamp;
    }

    function hasWon(uint raffleId, address user) external view returns (bool){
        return has_won[raffleId][user];
    }

    function tokenIdsOfUser(address user) public view returns (tokenInfo[] memory) {
        uint256 ownerTokenCount = balanceOf(user);
        tokenInfo[] memory userTokens = new tokenInfo[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            uint tokenId = tokenOfOwnerByIndex(user, i);
            userTokens[i].raffleId = tokenIdToRaffleId[tokenId];
            userTokens[i].tokenId = tokenId;
        }
        return userTokens;
    }


    function getDisplayedRaffles() public view returns (Raffle[] memory, ProjectInfo[] memory, RaffleState[] memory) {
        uint total_raffle_amount = _RaffleIdCounter.current();
        uint displayed_raffle_amount;
        uint currentIndex;

        for (uint i = 1; i <= total_raffle_amount; i++) {
            if ((raffleIdToRaffle[i].close_timestamp >= block.timestamp - 4 weeks && raffleIdToRaffle[i].close_timestamp <= block.timestamp) || (raffleIdToRaffle[i].open_timestamp <= block.timestamp + 4 weeks && raffleIdToRaffle[i].close_timestamp >= block.timestamp)) {
                displayed_raffle_amount += 1;
            }
        }

        Raffle[] memory raffles = new Raffle[](displayed_raffle_amount);
        ProjectInfo[] memory projectInfos = new ProjectInfo[](displayed_raffle_amount);
        RaffleState[] memory raffleStates = new RaffleState[](displayed_raffle_amount);
        for (uint256 i = 1; i <= total_raffle_amount; i++) {
            if ((raffleIdToRaffle[i].close_timestamp >= block.timestamp - 4 weeks && raffleIdToRaffle[i].close_timestamp <= block.timestamp) || (raffleIdToRaffle[i].open_timestamp <= block.timestamp + 4 weeks && raffleIdToRaffle[i].close_timestamp >= block.timestamp)) {
                raffles[currentIndex] = raffleIdToRaffle[i];
                projectInfos[currentIndex] = raffleIdToProjectInfo[i];
                raffleStates[currentIndex] = raffleIdToRaffleState[i];
                currentIndex += 1;
            }
        }

        return (raffles, projectInfos, raffleStates);
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