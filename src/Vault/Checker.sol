// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/mixins/ERC4626.sol";

contract Checker is ERC4626 {


    constructor(ERC20 _asset) ERC4626(_asset, "GoblinSax", "GSAX"){}

    
    
    function totalAssets() public pure override returns (uint256) {
        return 5;
    }

}