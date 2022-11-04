// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import "src/BNPL.sol";
import "src/vault_nft/GoblinVault_Factory.sol";

import "forge-std/Test.sol";

import "./utils/Utils.sol";

contract BNPLTest is Test {
    // nft factory
    GoblinVault_Factory public factory;

    // bnpl
    BNPL public bnpl;

    // GS multisig
    address public goblin;

    // address of buyer
    address public buyer;

    Utils public utils;

    address[] users;

    function setUp() public {
        goblin = address(777);
        factory = new GoblinVault_Factory(goblin, "uri");
        
        buyer = address(666);

        vm.deal(goblin, 100 ether);
        vm.deal(buyer, 100 ether);

        bnpl = new BNPL(
            0x8252Df1d8b29057d1Afe3062bf5a64D503152BC8, // direct loan fixed offer
            0x0C90C8B4aa8549656851964d5fB787F0e4F54082, // direct loan cooridnator
            goblin,                                     // goblinsax multisig  
            address(factory)                            // vault nft factory
        );


        //factory.transferOwnership(goblin);
    }

    function testThis() public {

    }
}