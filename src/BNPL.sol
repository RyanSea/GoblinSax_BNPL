// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import "./interfaces/IDirectLoanFixedOffer.sol";

/// @dev added totalNumLoans getter to retrieve NFTfi loan id
import "nftfi/interfaces/IDirectLoanCoordinator.sol";

import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/token/ERC721/IERC721.sol";
import "openzeppelin/token/ERC721/IERC721Receiver.sol";

/// @title GoblinSax NFT BNPL
/// @author Autocrat :)
contract BNPL is IERC721Receiver {

    /*///////////////////////////////////////////////////////////////
                              INITIALIZATION
    ///////////////////////////////////////////////////////////////*/

    constructor(address _nftfi, address _nftfi_coordinator) {
        nftfi = IDirectLoanFixedOffer(_nftfi);
        nftfi = IDirectLoanCoordinator(_nftfi_coordinator);
        goblinsax = msg.sender;
    }

    /// @notice NFTfi's DirectLoanFixedOffer contract
    IDirectLoanFixedOffer public nftfi;

    /// @notice NFTfi's DirectLoanCoordinator contract
    IDirectLoanCoordinator public nftfi_coordinator;

    /// @notice GoblinSax wallet
    address public goblinsax;

    /// @notice GoblinSax loan id
    uint id;

    /// @notice borrower => loan id => Loan
    mapping(address => mapping(uint => Loan)) public loan;

    /// @notice GoblinSax loan
    /// @param nft contract address
    /// @param id of nft
    /// @param nftfi_id NFTfi's loan id
    /// @param fee for GoblinSax, calculated with each payment (uint224 to pack into NFTfi's uint32 id)
    /// @param payoff amount, uncluding NFTfi fee, to fully payoff loan
    /// @param payed by borrower so far
    /// @param expiration of loan before default
    /// @param denomination of token for NFTfi loan
    struct Loan {
        address nft;
        uint id;
        uint32 nftfi_id;
        uint224 fee;
        uint payoff;
        uint payed;
        uint expiration;
        IERC20 denomination;
    }

    /// @notice purchase params
    /// @param borrower for GoblinSax BNPL
    /// @param nft contract address
    /// @param id of nft
    /// @param price of purchase
    /// @param downpayment for purchase
    /// @param fee for GoblinSax
    /// @param denomination of token for NFTfi loan
    /// @param market enum
    struct Purchase {
        address borrower;
        address nft;
        uint id;
        uint price;
        uint downpayment;
        uint fee;
        IERC20 denomination;
        Market market;
    }

    /// @notice nft markets
    enum Market {
        sudoswap,
        seaport, 
        zora
    }

    /*///////////////////////////////////////////////////////////////
                                  EVENTS
    ///////////////////////////////////////////////////////////////*/
    
    event LoanCreated(
        address indexed borrower, 
        uint indexed _id, 
        uint32 indexed nftfi_id, 
        address nft, 
        uint id
    );

    /*///////////////////////////////////////////////////////////////
                                LOAN LOGIC
    ///////////////////////////////////////////////////////////////*/

    function createLoan(/* Offer memory offer, */ Purchase memory purchase) public {
        //buy..

        //nftfi..

        // increment id & save to memory
        uint _id = ++id;

        // get NFTfi loan id
        uint32 nftfi_id = nftfi_coordinator.totalNumLoans();



        emit LoanCreated(puchase.borrower, _id, nftfi_id, purchase.nft, purchase.id);
    }

    /*///////////////////////////////////////////////////////////////
                             ERC721 RECEIVER
    ///////////////////////////////////////////////////////////////*/

    function onERC721Received(
        address, 
        address, 
        uint, 
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }


}
