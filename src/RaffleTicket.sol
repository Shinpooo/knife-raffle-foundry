// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "./MPLegacyToken.sol";
import "./Authorizable.sol";

/*
* @author Pooshin
* @notice This a Raffle contract for Knives Legacy. It allows for the owners to create & edit Raffles for NFT projects. Winners are picked based on Chainlink VRF V2 Randomness.
*/

contract RaffleTicket is Authorizable, VRFConsumerBaseV2 {

    uint256 public s_requestId;
    uint256 public current_raffle;
    bytes32 keyHash = 0x89630569c9567e43c4fe7b1633258df9f2531b62f2352fa721cf3162ee4ecb46;
    address vrfCoordinator = 0xd5D517aBE5cF79B7e95eC98dB0f0277788aFF634;  
    uint64 s_subscriptionId = 72;
    uint32 callbackGasLimit = 30000;
    uint16 requestConfirmations = 3;

    MPLegacyToken token;
    VRFCoordinatorV2Interface COORDINATOR;

    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    Counters.Counter private _RaffleIdCounter;

    // Raffle Info
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

    // Additional raffle info related to the project
    struct ProjectInfo {
        string twitter_url;
        string discord_url;
        string network;
        uint nft_price;
        uint mint_timestamp;
    }

    // raffle state that will be update through the smart contract
    struct RaffleState {
        uint random_number;
        address[] participants;
        address[] winners;
    }

    mapping (uint => Raffle) public raffleIdToRaffle;
    mapping (uint => mapping(address => bool)) public has_won;
    mapping (uint => ProjectInfo) public raffleIdToProjectInfo;
    mapping (uint => RaffleState) raffleIdToRaffleState;
    mapping (uint => mapping(address => uint)) raffleIdToUserBalance;
    
    event ClaimFees(address indexed claimer, uint amount);
    event WinnersPicked(uint raffleId, address[] winners);
    event EnteredRaffle(uint indexed raffleId, address indexed user, uint amount);

    constructor(uint64 subscriptionId, address token_address) VRFConsumerBaseV2(vrfCoordinator){
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_subscriptionId = subscriptionId;
        token = MPLegacyToken(token_address);
    }


    /*
    * @notice Request a random number from Chainlink VRF V2
    * @param raffleId the id of the raffle we want to get a random number for.
    */
    function requestRandomWords(uint raffleId) external onlyAuthorized {
        // Will revert if subscription is not set and funded.
        Raffle memory raffle = raffleIdToRaffle[raffleId];
        RaffleState memory raffle_state = raffleIdToRaffleState[raffleId];
        require(block.timestamp > raffle.close_timestamp, "Raffle should be finished.");
        require(raffle.winners_amount < raffle.current_entries, "Not enough participants.");
        require(raffle_state.random_number == 0, "Random Number already requested.");
        current_raffle = raffleId;
        uint32 numWords = 1;
        uint32 _callbackGasLimit = callbackGasLimit; 
        s_requestId = COORDINATOR.requestRandomWords(
        keyHash,
        s_subscriptionId,
        requestConfirmations,
        _callbackGasLimit,
        numWords
        );
    }

    /*
    * @notice Receive the random number & update the according storage.
    */
    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        RaffleState storage raffle_state = raffleIdToRaffleState[current_raffle];
        raffle_state.random_number = randomWords[0];
    }


    /*
    * @notice Pick the winners for the specified raffle. Can only be called if the random numbers has been picked.
    * @param raffleId the raffle Id.
    * @param new_project_info the new project information data.
    */
    function pickWinners(uint raffleId) public onlyAuthorized {
        Raffle memory raffle = raffleIdToRaffle[raffleId];
        RaffleState storage raffle_state = raffleIdToRaffleState[raffleId];
        require(raffle_state.winners.length == 0, "Winners already set.");
        require(raffle_state.random_number != 0, "request a random number first.");
        uint true_random_number = raffle_state.random_number;
        uint n_participants = raffle.current_entries;
        uint pseudo_random_number;
        for (uint i=0; i < raffle.winners_amount; i++) {
            pseudo_random_number = uint(keccak256(abi.encodePacked(i, pseudo_random_number,true_random_number)));
            uint random_index = pseudo_random_number % n_participants;
            address winner = raffle_state.participants[random_index];
            while (has_won[raffleId][winner]){
                pseudo_random_number += 1;
                random_index = pseudo_random_number % n_participants;
                winner = raffle_state.participants[random_index];
            }
            raffle_state.winners.push(winner);
            has_won[raffleId][winner] = true;
        }
        emit WinnersPicked(raffleId, raffle_state.winners);
    }
  
    /*
    * @notice Create a raffle.
    * @param new_raffle the new raffle data.
    * @param new_project_info the new project information data.
    */
    function createRaffle(Raffle memory new_raffle, ProjectInfo memory new_project_info) public onlyAuthorized {
        _RaffleIdCounter.increment();
        uint raffle_id = _RaffleIdCounter.current();
        new_raffle.raffle_id = raffle_id;
        new_raffle.current_entries = 0;
        raffleIdToRaffle[raffle_id] = new_raffle;
        raffleIdToProjectInfo[raffle_id] = new_project_info;
    }

    /*
    * @notice Edit a raffle.
    * @param raffleId the id of the raffle to edit.
    * @param new_raffle the edited raffle data.
    * @param new_project_info the edited project information data.
    */
    function editRaffle(uint raffleId, Raffle memory new_raffle, ProjectInfo memory new_project_info) public onlyAuthorized {
        new_raffle.raffle_id = raffleId;
        new_raffle.current_entries = raffleIdToRaffle[raffleId].current_entries;
        raffleIdToRaffle[raffleId] = new_raffle;
        raffleIdToProjectInfo[raffleId] = new_project_info;
    }

    /*
    * @notice Enter a raffle.
    * @param raffleId the id of the raffle we want to enter.
    * @param amount the amount of entries we want to get.
    */
    function safeMint(uint raffleId, uint amount) public payable {
        Raffle storage raffle = raffleIdToRaffle[raffleId];
        RaffleState storage raffle_state = raffleIdToRaffleState[raffleId];
        require(msg.value == raffle.mint_fee * amount, "AVAX mint fee not sent.");
        require(isRaffleOpen(raffleId), "Raffle is closed.");
        require(raffle.current_entries + amount <= raffle.max_ticket, "Raffle has reached max entries.");
        require(raffleIdToUserBalance[raffleId][msg.sender] + amount <= raffle.max_ticket_wallet, "User has too many tickets.");
        require(token.balanceOf(msg.sender) >= raffle.price * amount, "Not enough SUPPLY tokens.");
        token.burnFrom(msg.sender, raffle.price * amount);
        uint tokenId;
        for (uint i = 0; i < amount; i++){
            _tokenIdCounter.increment();
            tokenId = _tokenIdCounter.current();
            raffle_state.participants.push(msg.sender);
        }
        raffle.current_entries += amount;
        raffleIdToUserBalance[raffleId][msg.sender] += amount;
        emit EnteredRaffle(raffleId, msg.sender, amount);
    }


    // @notice Withdraw all AVAX from the contract.
    function withdraw() external onlyAuthorized {
        uint amount = address(this).balance;
        (bool os, ) = payable(msg.sender).call{value: amount}("");
        require(os, "Failed to send Avax");
        emit ClaimFees(msg.sender, amount);
    }


    // VIEWS //
    /*
    * @notice Get the current state (open, coming soon, closed) of the raffle.
    * @param raffleId the id of the raffle.
    * @return the state of the raffle
    */
    function getRaffleState(uint raffleId) public view returns (uint){
        Raffle memory raffle = raffleIdToRaffle[raffleId];
        if (block.timestamp < raffle.open_timestamp) return 1; // SOON
        else if (block.timestamp > raffle.close_timestamp) return 2; // CLOSED
        else return 3; // OPEN
    }

    /*
    * @notice Get the winners of a given raffle.
    * @param raffleId the id of the raffle.
    * @return an array of the winners adresses of the given raffle, empty if raffle is not finished.
    */
    function getWinners(uint raffle_id) external view returns (address[] memory) {
        RaffleState memory raffle_state = raffleIdToRaffleState[raffle_id];
        address[] memory winners = raffle_state.winners;
        return winners;
    }

    /*
    * @notice Get the random number picked by chainlink of a raffle.
    * @param raffleId the id of the raffle.
    * @return the random number, 0 if the number has not been picked yet.
    */
    function getRandomNumber(uint raffle_id) external view returns (uint) {
        RaffleState memory raffle_state = raffleIdToRaffleState[raffle_id];
        return raffle_state.random_number;
    }

    /*
    * @notice Get the winners of a given raffle.
    * @param raffleId the id of the raffle.
    * @return an array of the participants addresses of the given raffle.
    */
    function getParticipants(uint raffle_id) external view returns (address[] memory) {
        RaffleState memory raffle_state = raffleIdToRaffleState[raffle_id];
        address[] memory participants = raffle_state.participants;
        return participants;
    }

    /*
    * @notice Get the winners of a given raffle.
    * @param raffleId the id of the raffle.
    * @return an array of the participants addresses of the given raffle.
    */
    function isRaffleOpen(uint raffleId) public view returns (bool){
        Raffle memory raffle = raffleIdToRaffle[raffleId];
        return block.timestamp >= raffle.open_timestamp && block.timestamp <= raffle.close_timestamp;
    }

    /*
    * @notice Check if an address has won a raffle.
    * @param raffleId the id of the raffle.
    * @param user the user address.
    * @return bool - true if the user has won, else fale
    */
    function hasWon(uint raffleId, address user) external view returns (bool){
        return has_won[raffleId][user];
    }

    /*
    * @notice Display all the raffles info with a [-4 weeks, + 4 weeks] range from the current date
    * @param raffleId the id of the raffle.
    * @param user the user address.
    * @return arrays of Raffles, ProjectInfos, RaffleStates.
    */
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

     /*
    * @notice Display all the raffles infos.
    * @return arrays of Raffles, ProjectInfos, RaffleStates.
    */
    function getAllRaffles() public view returns (Raffle[] memory, ProjectInfo[] memory, RaffleState[] memory) {
        uint total_raffle_amount = _RaffleIdCounter.current();
        Raffle[] memory raffles = new Raffle[](total_raffle_amount);
        ProjectInfo[] memory projectInfos = new ProjectInfo[](total_raffle_amount);
        RaffleState[] memory raffleStates = new RaffleState[](total_raffle_amount);
        for (uint256 i = 1; i <= total_raffle_amount; i++) {
                raffles[i-1] = raffleIdToRaffle[i];
                projectInfos[i-1] = raffleIdToProjectInfo[i];
                raffleStates[i-1] = raffleIdToRaffleState[i];
        }

        return (raffles, projectInfos, raffleStates);
    }


    // VRF PARAMS SETTERS //
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
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
    }
}