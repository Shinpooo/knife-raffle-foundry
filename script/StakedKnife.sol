// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "./Authorizable.sol";

contract StakedKnife is ERC721, ERC721Enumerable, Pausable, Ownable, ERC721Burnable, Authorizable {


    mapping (uint => uint) public updatedAmount;
    mapping(uint => uint) public refreshTimestamp;

    uint constant RATE_PER_SEC = 1;
    uint constant MAX_CAP = 200;

    IERC721 knives_legacy;

    event Deposit(address user, uint256 tokenId);
    event Withdraw(address user, uint256 tokenId);

    constructor(address _knives_legacy) ERC721("StakedKnife", "SKNIFE") {
        knives_legacy = IERC721(_knives_legacy);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function safeMint(address to, uint tokenId) internal {
        _safeMint(to, tokenId);
    }

    function deposit(uint256 tokenId, address user) internal
    {
        require (user == knives_legacy.ownerOf(tokenId), "Sender must be owner.");
        require(balanceOf(user) < 50, "Cannot stake more.");
        knives_legacy.transferFrom(user, address(this), tokenId);
        refreshTimestamp[tokenId] = block.timestamp;
        safeMint(user, tokenId);
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
        knives_legacy.transferFrom(address(this), user, tokenId);
        refreshTimestamp[tokenId] = block.timestamp;
        burn(tokenId);
        emit Withdraw(user, tokenId);
    }

    function withdrawSelected(uint256[] calldata tokenIds) external {
        for (uint i = 0; i < tokenIds.length; i++){
            withdraw(tokenIds[i], msg.sender);
        }
    }


    function tokenIdsOfUser(address user) public view returns (uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(user);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(user, i);
        }
        return tokenIds;
    }
    

    function getLGCYMPAmount(uint tokenId) external view returns (uint) {
        if(refreshTimestamp[tokenId] == 0) return 0;
        else {
            uint duration = block.timestamp - refreshTimestamp[tokenId];
            uint amount_accumulated = duration * RATE_PER_SEC + updatedAmount[tokenId];
            return amount_accumulated >= MAX_CAP  ? MAX_CAP : amount_accumulated;
        }
    }

    function setLGCYMPAmount(uint amount, uint tokenId) external onlyAuthorized {
        updatedAmount[tokenId] = amount;
        refreshTimestamp[tokenId] = block.timestamp;
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
