// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// import "forge-std/Test.sol";

import "./utils/Utils.sol";

import "src/Token.sol";

import "src/POCVault.sol";

contract POCVaulterTest is Test {

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

        utils = new Utils();

        users = utils.createUsers(30);

        ryan = users[0];
        danny = users[1];
        val = users[2];
        jorg = users[3];

        vm.label(ryan, "Ryan");
        vm.label(danny, "Daniel");
        vm.label(val, "Valerie");
        vm.label(jorg, "Jorg");

        token.mint(ryan, 5000000000000000000 ether);
        //token.mint(danny, 5000000000000000000 ether);
        //token.mint(val, 5000000000000000000 ether);
        token.mint(jorg, 5000000000000000000 ether);
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
       
        uint bal = vault._calculateBalance(danny);
        console.log(bal);

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

        while (amount < 1000) {
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

    function testRoundingError() public {
        
        uint x = 8492873.391 ether; //5323198.2321 ether;
        uint x1 = 3123178.32 ether;
        uint x2 = 4328994.91 ether;
        uint x3 = 1773281.982 ether;

        uint y = 3992954.54054 ether;
        uint z = 4134909.3390834 ether;

        token.mint(danny, x);
        token.mint(val, x1);
        token.mint(jorg, x2);
        token.mint(ryan,x3);

        vm.startPrank(danny);
        token.approve(address(vault), x );
        vault.deposit(x );
        vm.stopPrank();

        // vm.startPrank(val);
        // token.approve(address(vault), x1);
        // vault.deposit(x1);
        // vm.stopPrank();

        // vm.startPrank(jorg);
        // token.approve(address(vault), x2);
        // vault.deposit(x2);
        // vm.stopPrank();

        // vm.startPrank(ryan);
        // token.approve(address(vault), x3);
        // vault.deposit(x3);
        // vm.stopPrank();

        for (uint i; i < 1000; ++i) {
            vault.acceptOffer(i + 1, y);
            skip(300);
            vault.loanRepayed(i + 1, z);
            skip(300);
        }

        uint bal = vault._calculateBalance(danny);
        // uint bal1 = vault._calculateBalance(val);
        // uint bal2 = vault._calculateBalance(jorg);
        // uint bal3 = vault._calculateBalance(ryan);

        uint expected = x + (z * 1000) - (y * 1000);

        console.log(bal /*+ bal1 + bal2 + bal3*/);
        console.log(expected);
        
        //62684
    }

    
}