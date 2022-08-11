// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "./Authorizable.sol";
import "./MPLegacyToken.sol";


contract StakedKnife is ERC721, ERC721Enumerable, Pausable, Ownable, ERC721Burnable {


    mapping (uint => uint) public updatedAmount;
    // mapping (uint => uint) public claimed;
    mapping(uint => uint) public depositTimestamp;

    uint constant RATE_PER_SEC = 1;
    uint public constant MAX_CAP = 50 * 10**18;

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

    function deposit(uint256 tokenId, address user) internal
    {
        require (user == knives_legacy.ownerOf(tokenId), "Sender must be owner.");
        require(balanceOf(user) < 50, "Cannot stake more.");
        knives_legacy.transferFrom(user, address(this), tokenId);
        depositTimestamp[tokenId] = block.timestamp;
        _mint(user, tokenId);
        emit Deposit(user, tokenId);
    }

    function depositSelected(uint256[] calldata tokenIds) external {
        for (uint i = 0; i < tokenIds.length; i++){
            deposit(tokenIds[i], msg.sender);
        }
    }

    function withdraw(uint256 tokenId, address user) internal
    {
        require(ownerOf(tokenId) == user, "TokenId not staked by sender.");
        claim(user, tokenId);
        knives_legacy.transferFrom(address(this), user, tokenId);
        burn(tokenId);
        require(token.balanceOf(user) <= MAX_CAP * (balanceOf(user) + 1), "Can't withdraw, use your tokens first.");
        emit Withdraw(user, tokenId);
    }

    function withdrawSelected(uint256[] calldata tokenIds) external {
        for (uint i = 0; i < tokenIds.length; i++){
            withdraw(tokenIds[i], msg.sender);
        }
    }

    function claim(address user, uint tokenId) public {
        require(msg.sender == user || msg.sender == address(this), "Only sender or this contract can claim.");
        require(user == ownerOf(tokenId), "Not owner.");
        uint token_balance = token.balanceOf(user);
        uint amount = getLGCYMPAmount(tokenId);
        uint address_cap = MAX_CAP * (balanceOf(user) + 1);
        uint max_claimable_amount = address_cap - token_balance;
        require(amount <= max_claimable_amount, "Spend some tokens first.");
        depositTimestamp[tokenId] = block.timestamp;
        token.mint(user, amount);
        emit Claim(user, tokenId, amount);
    }


    function tokenIdsOfUser(address user) public view returns (uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(user);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(user, i);
        }
        return tokenIds;
    }
    

    function getLGCYMPAmount(uint tokenId) public view returns (uint) {
        if(depositTimestamp[tokenId] == 0) return 0;
        else {
            uint duration = block.timestamp - depositTimestamp[tokenId];
            uint amount_accumulated = duration * RATE_PER_SEC * 10**18;
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
}
