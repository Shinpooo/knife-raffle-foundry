// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Authorizable.sol";
import "./StakedKnife.sol";

contract MPLegacyToken is ERC20, ERC20Burnable, Pausable, Ownable, Authorizable {

    StakedKnife staked_knife;
    constructor(address _staked_knife) ERC20("MPLegacyToken", "MPLGCY") {
        staked_knife = StakedKnife(_staked_knife);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) public Authorizable {
        // uint staked_amount = staked_knife.balanceOf(to);
        // uint balance = balanceOf(to);
        // require(balancestaked_amount * staked_knife.MAX_CAP);
        _mint(to, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        require(from == address(0) || to == address(0), "Not transferable.");
        super._beforeTokenTransfer(from, to, amount);
    }
}