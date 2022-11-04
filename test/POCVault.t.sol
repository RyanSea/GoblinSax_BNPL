// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// import "forge-std/Test.sol";

import "./utils/Utils.sol";

import "src/Token.sol";

import "src/POCVault.sol";

contract POCVaultTest is Test {

    Token token;
    POCVault vault;
    Utils utils;
    address[] users;
    address ryan;
    address danny;
    address val;
    address jorg;



    function setUp() public {
        token = new Token();

        vault = new POCVault(address(token));

        utils = new Utils(token);

        users = utils.createUsers(30);

        ryan = users[0];
        danny = users[1];
        val = users[2];
        jorg = users[3];

        vm.label(ryan, "Ryan");
        vm.label(danny, "Daniel");
        vm.label(val, "Valerie");
        vm.label(jorg, "Jorg");

        token.mint(ryan, 1000 ether);
        token.mint(danny, 1000 ether);
        token.mint(val, 1000 ether);
        token.mint(jorg, 1000 ether);
    }

    function testRun() public {
        vm.startPrank(danny);
        token.approve(address(vault), 20 ether);
        vault.deposit(20 ether);
        vm.stopPrank();

        vm.startPrank(val);
        token.approve(address(vault), 10 ether);
        vault.deposit(10 ether);
        vm.stopPrank();

        vm.startPrank(jorg);
        token.approve(address(vault), 10 ether);
        vault.deposit(10 ether);
        vm.stopPrank();

        vault.acceptOffer(1, 20 ether);

        vm.prank(danny);
        vault.withdraw(10 ether);

        vm.expectRevert("NOT_ENOUGH_MONEY");
        vm.prank(danny);
        vault.withdraw(1);

        vault.loanRepayed(1, 40 ether);

        vm.expectRevert("NOT_ENOUGH_MONEY");
        vm.prank(danny);
        vault.withdraw(20 ether + 1);

        vm.prank(danny);
        vault.withdraw(20 ether);

        vm.startPrank(ryan);
        token.approve(address(vault), 10 ether);
        vault.deposit(10 ether);
        vm.stopPrank();

        vault.acceptOffer(2, 20 ether);

        vm.prank(ryan);
        vault.withdraw(5 ether);




    }

    function testGas() public {
        uint amount;

        while (amount < 300) {
            for (uint i; i < users.length; ++i) {
                amount += 2;

                vm.startPrank(users[i]);
                token.approve(address(vault), amount * 1e18);
                vault.deposit(amount * 1e18);
                vm.stopPrank();

            
            }

            
        }

        vm.prank(users[10]);
        vault.withdraw(5 ether);
    }

}