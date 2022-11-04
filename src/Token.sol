// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/tokens/ERC20.sol";

contract Token is ERC20 {

    constructor() ERC20("Mana", "MANA", 18) {}

    function mint(address to, uint amount) public {
        _mint(to, amount);
    }

    function burn(address from, uint amount) public {
        _burn(from, amount);
    }

}