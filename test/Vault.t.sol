// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

//import "forge-std/Test.sol";

import "./utils/Utils.sol";

import "src/Token.sol";

import "src/Vault.sol";

import "openzeppelin/utils/cryptography/SignatureChecker.sol";

// minimal receiver 5769
// current 255657

contract VaultTest is Test {
    Token public token;

    Vault public vault;

    Utils public utils;

    address[] public users;

    address public ryan;
    address public danny;
    address public val;
    address public jorg;
    address public paul;

    IERC721 ape;

    IERC20 weth;

    IDirectLoanFixedOffer nftfi;
    IDirectLoanCoordinator coordinator;

    function setUp() public {
        //      TOKENS      //
        weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        ape = IERC721(0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D);

        //      VAULT       //
        vault = new Vault(
            address(weth),
            "uri",
            0xf896527c49b44aAb3Cf22aE356Fa3AF8E331F280,
            0x0C90C8B4aa8549656851964d5fB787F0e4F54082,
            0x5660E206496808F7b5cDB8C56A696a96AE5E9b23,
            address(777)
        );

        coordinator = IDirectLoanCoordinator(0x0C90C8B4aa8549656851964d5fB787F0e4F54082);
        nftfi = IDirectLoanFixedOffer(0xf896527c49b44aAb3Cf22aE356Fa3AF8E331F280);

        //      USERS      //
        utils = new Utils();

        users = utils.createUsers(4);
        ryan = users[0];
        danny = users[1];
        val = users[2];
        jorg = users[3];

        vm.label(ryan, "Ryan");
        vm.label(danny, "Danny");
        vm.label(val, "Val");
        vm.label(jorg, "Jorg");

        //      DISTRIBUTE WETH      //
        vm.startPrank(0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E);
        weth.transfer(ryan, 100000 ether);
        weth.transfer(danny, 100000 ether);
        weth.transfer(val, 100000 ether);
        weth.transfer(jorg, 100000 ether);
        vm.stopPrank();

        //      TRANSFER APE      //
        vm.prank(0xb35d334B94e76E2E80B186F21eC9887084Ae1591);
        ape.transferFrom(0xb35d334B94e76E2E80B186F21eC9887084Ae1591, jorg, 1937);

        //      UNPAUSE     //
        vm.prank(0xDcA17eeDc1aa3dbB14361678566b2dA5A1Bb4C31);
        nftfi.unpause();
    }

    function testDeposit() public {
        vm.startPrank(danny);
        weth.approve(address(vault), 31 ether);
        vault.deposit(0, 31 ether);
        vm.stopPrank();

        vm.startPrank(val);
        weth.approve(address(vault), 28 ether);
        vault.deposit(0, 28 ether);
        vm.stopPrank();

        vm.startPrank(ryan);
        weth.approve(address(vault), 24 ether);
        vault.deposit(0, 24 ether);
        vm.stopPrank();

        assertEq(vault.ownerOf(1), danny);
        assertEq(vault.ownerOf(2), val);
        assertEq(vault.ownerOf(3), ryan);

        assertEq(vault._calculateBalance(3), 24 ether);
        assertEq(vault._calculateBalance(2), 28 ether);
        assertEq(vault._calculateBalance(1), 31 ether);

    }

    function testAcceptOffer() public {
        testDeposit();
        skip(300);

        IDirectLoanFixedOffer.Offer memory offer = IDirectLoanFixedOffer.Offer(
            60 ether,
            70 ether,
            1937,
            address(ape),
            7 days,
            500,
            address(weth),
            address(0)
        );

        IDirectLoanFixedOffer.Signature memory signature = IDirectLoanFixedOffer.Signature(
            1,
            block.timestamp + 10 weeks,
            address(vault),
            abi.encode("signature")
        );

        IDirectLoanFixedOffer.BorrowerSettings memory settings = IDirectLoanFixedOffer.BorrowerSettings(
            address(0),
            0
        );
        
        vm.prank(address(vault));
        weth.approve(address(nftfi), 60 ether);

        uint jorg_bal = weth.balanceOf(jorg);

        vm.startPrank(jorg);
        ape.approve(address(nftfi), 1937);
        nftfi.acceptOffer(offer, signature, settings);
        vm.stopPrank();

        uint32 id = coordinator.totalNumLoans();

        assertEq(ape.ownerOf(1937), address(nftfi));
        assertEq(weth.balanceOf(jorg), jorg_bal + 60 ether);

        skip(300);

        vm.startPrank(jorg);
        weth.approve(address(nftfi), 70 ether);
        nftfi.payBackLoan(id);
        vm.stopPrank();

        skip(300);

        vault.loanRepayed(id);

        assertEq(ape.ownerOf(1937), jorg);
    }
}
