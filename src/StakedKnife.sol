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

    IERC721 knives_legacy;
    MPLegacyToken token;

    event Deposit(address indexed user, uint256 tokenId);
    event Withdraw(address indexed user, uint256 tokenId);
    event Claim(address indexed user, uint256 indexed tokenId, uint amount);

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

    /*
    * @notice Deposit a Knife in this contract called by. Mint an NFT as a proof of deposit.
    * @dev Limit of 50 knives deposited per wallet. Can only be called by depositSelected().
    * @param tokenId The token ID of the deposited token.
    * @param user the address of the knife owner
    */
    function deposit(uint256 tokenId, address user) internal
    {
        require (user == knives_legacy.ownerOf(tokenId), "Sender must be owner.");
        require(balanceOf(user) < 50, "Cannot stake more.");
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
        for (uint i = 0; i < tokenIds.length; i++){
            deposit(tokenIds[i], msg.sender);
        }
    }

    /*
    * @notice Withdraw a knife from the staking contract. Burn the related proof of ownership nft.
    * @dev Supply tokens are claimed when withdrawing. Hence, when withdrawing, the end-user should not exceed its $SUPPLY token max cap. The max cap supply tokens of a given address is calculated by: address $SUPPLY Cap = Knife $SUPPLY Cap * (Staked knives amount + 1).
    * @param tokenId The token ID of the withdrawn token.
    */
    function withdraw(uint256 tokenId) external whenNotPaused
    {
        require(msg.sender == ownerOf(tokenId),"Not owner.");
        claim(msg.sender, tokenId);
        knives_legacy.transferFrom(address(this), msg.sender, tokenId);
        burn(tokenId);
        require(token.balanceOf(msg.sender) <= MAX_CAP * (balanceOf(msg.sender) + 1), "Can't withdraw, use your tokens first.");
        emit Withdraw(msg.sender, tokenId);
    }

    /*
    * @notice Claim & transfer the $SUPPLY tokens associated to a staked knife.
    * @dev Claimable amount should not exceed the user address cap.
    * @param user the knife staker.
    * @param tokenId the knife Id.
    */
    function claim(address user, uint tokenId) public whenNotPaused {
        require(msg.sender == user || msg.sender == address(this), "Only sender or this contract can claim.");
        require(user == ownerOf(tokenId), "Not owner.");
        uint token_balance = token.balanceOf(user);
        uint amount = getSupplyAmount(tokenId);
        uint address_cap = MAX_CAP * (balanceOf(user) + 1);
        uint max_claimable_amount = address_cap - token_balance;
        require(amount <= max_claimable_amount, "Spend some tokens first.");
        depositTimestamp[tokenId] = block.timestamp;
        token.mint(user, amount);
        emit Claim(user, tokenId, amount);
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
