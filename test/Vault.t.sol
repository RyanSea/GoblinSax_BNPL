// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// import "forge-std/Test.sol";

// import "./utils/Utils.sol";

// import "src/Token.sol";

// import "src/Vault.sol";

// contract VaultTest is Test {
//     Token public token;

//     Vault public vault;

//     Vault public vault2;

//     Vault public vault3;

//     Utils public utils;

//     address[] public users;

//     address public ryan;
//     address public danny;
//     address public val;
//     address public joerg;

//     function setUp() public {
//         token = new Token();

//         vault = new Vault(token);

//         utils = new Utils();

//         users = utils.createUsers(4);
//         ryan = users[0];
//         danny = users[1];
//         val = users[2];
//         joerg = users[3];

//         vm.label(ryan, "Ryan");
//         vm.label(danny, "Danny");
//         vm.label(val, "Val");
//         vm.label(joerg, "Joerg");

//         token.mint(ryan, 100 ether);
//         token.mint(danny, 100 ether);
//         token.mint(val, 100 ether);
//         token.mint(joerg, 100 ether);
//     }

//     function testCorrectWithdraw() public {
//         // deposit
//         vm.startPrank(ryan);
//         token.approve(address(vault), 15 ether);
//         vault.deposit(20 ether, ryan);
//         vm.stopPrank();

//         vm.startPrank(danny);
//         token.approve(address(vault), 15 ether);
//         vault.deposit(15 ether, danny);
//         vm.stopPrank();

//         vm.startPrank(val);
//         token.approve(address(vault), 20 ether);
//         vault.deposit(20 ether, val);
//         vm.stopPrank();

//         vm.startPrank(joerg);
//         token.approve(address(vault), 12 ether);
//         vault.deposit(12 ether, joerg);
//         vm.stopPrank();

//         // redeem
//         uint danny_shares = vault.balanceOf(danny);

//         vm.prank(danny);
//         vault.redeem(danny_shares, danny, danny);

//         assertEq(token.balanceOf(danny), 100 ether);
//     }
// }
