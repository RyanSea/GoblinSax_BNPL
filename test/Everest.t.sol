// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

//import "forge-std/Test.sol";

import "src/Vault/Everest.sol";
import "src/Vault/VaultManager.sol";
import "src/Vault/Checker.sol";

import "./utils/Utils.sol";

contract EverestTest is Test {

    VaultManager manager;

    Everest vault1;
    Everest vault2;
    Everest vault3;

    ERC20 weth;

    IDirectLoanFixedOffer nftfi;

    ERC721 promissoryNote;

    Utils utils;

    ERC721 ape;

    address[] users;

    address ryan;
    address danny;
    address jorg;
    address val;
    address lying_cat;
    address ishan;

    address ape1937;
    address ape5682;

    function setUp() public {
        weth = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

        ape = ERC721(0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D);

        ape1937 = 0xb35d334B94e76E2E80B186F21eC9887084Ae1591;
        ape5682 = 0x5d5335e6bEA4B12dCB942Cec1DA951aE63f2ae64;

        nftfi = IDirectLoanFixedOffer(0xf896527c49b44aAb3Cf22aE356Fa3AF8E331F280);

        promissoryNote = ERC721(0x5660E206496808F7b5cDB8C56A696a96AE5E9b23);

        manager = new VaultManager();

        vault1 = new Everest(
            1,
            weth,
            address(manager),
            address(nftfi),
            address(promissoryNote),
            1000 ether
        );

        vault2 = new Everest(
            2,
            weth,
            address(manager),
            address(nftfi),
            address(promissoryNote),
            100 ether
        );

        vault3 = new Everest(
            3,
            weth,
            address(manager),
            address(nftfi),
            address(promissoryNote),
            100 ether
        );

        utils = new Utils();
        users = utils.createUsers(6);
        ryan = users[0];
        danny = users[1];
        val = users[2];
        jorg = users[3];
        lying_cat = users[4];
        ishan = users[5];

        vm.label(ryan, "Ryan");
        vm.label(danny, "Danny");
        vm.label(val, "Val");
        vm.label(jorg, "Jorg");
        vm.label(lying_cat, "Lying Cat");
        vm.label(ishan, "Ishan");

        //      DISTRIBUTE WETH      //
        vm.startPrank(0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E);
        weth.transfer(ryan, 50000 ether);
        weth.transfer(danny, 50000 ether);
        weth.transfer(val, 50000 ether);
        weth.transfer(jorg, 50000 ether);
        weth.transfer(lying_cat, 50000 ether);
        weth.transfer(ishan, 50000 ether);
        vm.stopPrank();

        //      UNPAUSE     //
        vm.prank(0xDcA17eeDc1aa3dbB14361678566b2dA5A1Bb4C31);
        nftfi.unpause();
    }

    function testDeposit() public {
        vm.startPrank(danny);
        weth.approve(address(vault1), 20 ether);
        vault1.deposit(20 ether, danny);
        vm.stopPrank();

        vm.startPrank(val);
        weth.approve(address(vault1), 20 ether);
        vault1.deposit(20 ether, val);
        vm.stopPrank();

        vm.startPrank(ryan);
        weth.approve(address(vault1), 20 ether);
        vault1.deposit(20 ether, ryan);
        vm.stopPrank();

        vm.startPrank(jorg);
        weth.approve(address(vault1), 20 ether);
        vault1.deposit(20 ether, jorg);
        vm.stopPrank();

        vm.startPrank(lying_cat);
        weth.approve(address(vault3), 20 ether);
        vault3.deposit(20 ether, lying_cat);
        vm.stopPrank();
    }

    

    function testAcceptOffer() public {
        testDeposit();
        
        assertEq(vault1.balanceOf(ryan), 20 ether);
        assertEq(vault1.balanceOf(jorg), 20 ether);

        IDirectLoanFixedOffer.Offer memory offer = IDirectLoanFixedOffer.Offer(
            50 ether,
            55 ether,
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
            address(vault1),
            abi.encode("signature")
        );

        IDirectLoanFixedOffer.BorrowerSettings memory settings = IDirectLoanFixedOffer.BorrowerSettings(
            address(0),
            0
        );

        uint bal_before = weth.balanceOf(ape1937);

        vm.startPrank(ape1937);
        ape.approve(address(nftfi), 1937);
        nftfi.acceptOffer(offer, signature, settings);
        vm.stopPrank();

        uint bal_after = weth.balanceOf(ape1937);

        // ape1937 gets a loan of 50 ether
        assertEq(bal_after, bal_before + 50 ether);

        assertEq(vault1.balanceOf(ryan), 10 ether);
        assertEq(vault1.balanceOf(jorg), 0);

        assertEq(vault3.balanceOf(ryan), 10 ether);
        assertEq(vault3.balanceOf(jorg), 20 ether);


        vm.startPrank(ishan);
        weth.approve(address(vault3), 20 ether);
        vault3.deposit(20 ether, ishan);
        vm.stopPrank();

        offer = IDirectLoanFixedOffer.Offer(
            50 ether,
            55 ether,
            5682,
            address(ape),
            7 days,
            500,
            address(weth),
            address(0)
        );

        signature = IDirectLoanFixedOffer.Signature(
            1,
            block.timestamp + 10 weeks,
            address(vault3),
            abi.encode("signature")
        );

        settings = IDirectLoanFixedOffer.BorrowerSettings(
            address(0),
            0
        );

        assertEq(vault3.balanceOf(ishan), 20 ether);
        
        assertEq(weth.balanceOf(address(vault3)), 70 ether);

        bal_before = weth.balanceOf(ape5682);

        vm.startPrank(ape5682);
        ape.approve(address(nftfi), 5682);
        nftfi.acceptOffer(offer, signature, settings);
        vm.stopPrank();

        bal_after = weth.balanceOf(ape5682);

        assertEq(bal_after, bal_before + 50 ether);

        assertEq(vault3.balanceOf(ishan), 0);
        assertEq(vault2.balanceOf(ishan), 20 ether);
        
    }

}