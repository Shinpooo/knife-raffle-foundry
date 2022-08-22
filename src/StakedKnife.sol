// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "./MPLegacyToken.sol";


/*
* @author Pooshin
* @notice This a staking contract for Knives Legact. When knive a knife is staked, it generates a non-transferable NFT to the depositor as a proof of its ownership. Staked knives accumulates $SUPPLY tokens until a MAX CAP is reached.
*/

contract StakedKnife is ERC721, ERC721Enumerable, Pausable, Ownable, ERC721Burnable {


    mapping (uint => uint) public updatedAmount;
    mapping(uint => uint) public depositTimestamp;

    uint public RATE_PER_DAY = 200 * 10**18;
    uint public MAX_CAP = 1000 * 10**18;
    string public baseURI = "https://ipfs.io/ipfs/QmTkBPfbkpQwaTCfYGPVi7kQ9zYEPNkYwrGo3qX3QUJPy2";

    IERC721 knives_legacy;
    MPLegacyToken token;

    event Deposit(address indexed user, uint256 tokenId);
    event Withdraw(address indexed user, uint256 tokenId);
    event Claim(address indexed user, uint256 indexed tokenId, uint amount);
    event ClaimAll(address indexed user, uint amount);

    constructor(address _knives_legacy, address _token) ERC721("StakedKnife", "SKNIFE") {
        knives_legacy = IERC721(_knives_legacy);
        token = MPLegacyToken(_token);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    /*
    * @notice Deposit a Knife in this contract called by. Mint an NFT as a proof of deposit.
    * @dev Limit of 50 knives deposited per wallet. Can only be called by depositSelected().
    * @param tokenId The token ID of the deposited token.
    * @param user the address of the knife owner
    */
    function deposit(uint256 tokenId, address user) internal
    {
        require (user == knives_legacy.ownerOf(tokenId), "User must be owner.");
        knives_legacy.transferFrom(user, address(this), tokenId);
        depositTimestamp[tokenId] = block.timestamp;
        _mint(user, tokenId);
        emit Deposit(user, tokenId);
    }

    /*
    * @notice Deposit selected knives. Called by the end-user.
    * @param tokenIds The token IDs of the selected tokens.
    */
    function depositSelected(uint256[] calldata tokenIds) external whenNotPaused {
        uint length = tokenIds.length;
        require(balanceOf(msg.sender) + length < 50, "Cannot stake more.");
        for (uint i = 0; i < length; i++){
            deposit(tokenIds[i], msg.sender);
        }
    }

    /*
    * @notice Withdraw a knife from the staking contract. Burn the related proof of ownership nft.
    * @dev Supply tokens are claimed when withdrawing.
    * @param tokenId The token ID of the withdrawn token.
    */
    function withdraw(uint256 tokenId, address user) internal
    {
        require(user == ownerOf(tokenId), "User must be owner.");
        claim(user, tokenId);
        knives_legacy.transferFrom(address(this), user, tokenId);
        burn(tokenId);
        emit Withdraw(user, tokenId);
    }

    /*
    * @notice Withdraw selected knives. Called by the end-user.
    * @param tokenIds The token IDs of the selected tokens.
    */
    function withdrawSelected(uint256[] calldata tokenIds) external whenNotPaused {
        uint length = tokenIds.length;
        for (uint i = 0; i < length; i++){
            withdraw(tokenIds[i], msg.sender);
        }
    }

    /*
    * @notice Claim & transfer the $SUPPLY tokens associated to a staked knife.
    * @param user the knife staker.
    * @param tokenId the knife Id.
    */
    function claim(address user, uint tokenId) public whenNotPaused {
        require(msg.sender == user || msg.sender == address(this), "Only sender or this contract can claim.");
        require(user == ownerOf(tokenId), "Not owner.");
        uint amount = getSupplyAmount(tokenId);
        depositTimestamp[tokenId] = block.timestamp;
        token.mint(user, amount);
        emit Claim(user, tokenId, amount);
    }

    /*
    * @notice Claim & transfer the $SUPPLY tokens for every knives.
    */
    function claimAll() external whenNotPaused {
        uint[] memory tokenIds = tokenIdsOfUser(msg.sender);
        uint amount;
        for (uint i = 0; i < tokenIds.length; i++){
            amount += getSupplyAmount(tokenIds[i]);
            depositTimestamp[tokenIds[i]] = block.timestamp;
        }
        token.mint(msg.sender, amount);
        emit ClaimAll(msg.sender, amount);
    }

    /*
    * @notice View the list of tokenIds minted as a proof of ownershup of a user.
    * @param user the user address.
    * @return A list of token Ids owner by the user.
    */
    function tokenIdsOfUser(address user) public view returns (uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(user);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(user, i);
        }
        return tokenIds;
    }
    
    /*
    * @notice Calculate the amount of $SUPPLY tokens accumulated by a staked knife.
    * @dev The amount increase linearly with time until it reaches a MAX_CAP where it does not increase anymore
    * @param tokenId the tokenId whose we want to get the accumulated amount
    * @return The accumulated $SUPPLY amount.
    */
    function getSupplyAmount(uint tokenId) public view returns (uint) {
        if(depositTimestamp[tokenId] == 0) return 0;
        else {
            uint duration = block.timestamp - depositTimestamp[tokenId];
            uint amount_accumulated = duration * RATE_PER_DAY / 1 days;
            return amount_accumulated >= MAX_CAP  ? MAX_CAP : amount_accumulated;
        }
    }

    /*
    * @notice Get the claimable $SUPPLY amount of an address.
    * @param user the user address.
    * @return The claimable amount.
    */
    function getClaimableAmount(address user) public view returns (uint) {
        uint[] memory tokenIds = tokenIdsOfUser(user);
        uint amount;
        for (uint i = 0; i < tokenIds.length; i++){
            amount += getSupplyAmount(tokenIds[i]);
        }
        return amount;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        require(from == address(0) || to == address(0), "Not transferable.");
        super._beforeTokenTransfer(from, to, tokenId);
    }


    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }


    function setMaxCap(uint _cap) public onlyOwner {
        MAX_CAP = _cap;
    }

    function setRate(uint _rate) public onlyOwner {
        RATE_PER_DAY = _rate;
    }
}
