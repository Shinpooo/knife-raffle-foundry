// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;


import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";


contract KLRead  {

    IERC721Enumerable KniveContract = IERC721Enumerable(0x114712E2813451f6eB64fee2Be26338d83Da56C0);

    constructor() {}

    function tokenIdsOfUser(address user) public view returns (uint256[] memory) {
        uint256 ownerTokenCount = KniveContract.balanceOf(user);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = KniveContract.tokenOfOwnerByIndex(user, i);
        }
        return tokenIds;
    }
}