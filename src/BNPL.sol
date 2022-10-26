// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import "./interfaces/IDirectLoanFixedOffer.sol";

import "./auth/GoblinOwned.sol";

/// @dev added totalNumLoans getter to retrieve NFTfi loan id
import "nftfi/interfaces/IDirectLoanCoordinator.sol";

import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/token/ERC721/IERC721.sol";
import "openzeppelin/token/ERC721/IERC721Receiver.sol";

/// @title GoblinSax NFT BNPL
/// @author Autocrat :)
contract BNPL is GoblinOwned, IERC721Receiver {

    /*///////////////////////////////////////////////////////////////
                              INITIALIZATION
    ///////////////////////////////////////////////////////////////*/

    constructor(
        address _nftfi, 
        address _nftfi_coordinator,
        address _goblinsax
    ) GoblinOwned(_goblinsax) {
        nftfi = IDirectLoanFixedOffer(_nftfi);
        nftfi = IDirectLoanCoordinator(_nftfi_coordinator);
    }

    /// @notice NFTfi's DirectLoanFixedOffer contract
    IDirectLoanFixedOffer public nftfi;

    /// @notice NFTfi's DirectLoanCoordinator contract
    IDirectLoanCoordinator public nftfi_coordinator;

    /// @notice GoblinSax loan id
    uint id;

    /// @notice loan id => Loan
    mapping(uint => Loan) public loan;

    /// @notice GoblinSax loan
    /// @param nft contract address
    /// @param id of nft
    /// @param nftfi_id NFTfi's loan id
    /// @param fee for GoblinSax, calculated with each payment (uint224 to pack into NFTfi's uint32 id)
    /// @param payoff amount, uncluding NFTfi fee, to fully payoff loan
    /// @param payed by borrower so far
    /// @param expiration of loan before default
    /// @param tranches for repayment
    /// @param denomination of token for NFTfi loan
    struct Loan {
        address borrower;
        address nft;
        uint id;
        uint32 nftfi_id;
        uint224 fee;
        uint payoff;
        uint payed;
        uint expiration;
        Tranche[] tranches;
        IERC20 denomination;
    }

    /// @notice purchase params
    /// @param borrower for GoblinSax BNPL
    /// @param price of purchase
    /// @param downpayment for purchase
    /// @param fee for GoblinSax
    /// @param tranches for repayment @dev should be in chronological order
    /// @param setup_fee including gas for initiating loan
    /// @param market enum
    /// @param signature struct for NFTfi
    /// @param borrower_settings struct for NFTfi
    struct Purchase {
        address borrower;
        uint price;
        uint downpayment;
        uint fee;
        Tranch[] tranches;
        uint setup_fee;
        uint gas;
        Market market;
        Signature signature;
        BorrowerSettings borrower_settings;
    }

    /// @notice payment tranche
    /// @param deadline to pay
    /// @param minimum amount needed to be payed by deadline
    struct Tranche {
        uint deadline;
        uint minimum;
    }

    /// @notice nft markets
    enum Market {
        sudoswap,
        seaport, 
        zora
    }

    /// @notice NFTfi offer
    struct Offer {
        uint256 loanPrincipalAmount;
        uint256 maximumRepaymentAmount;
        uint256 nftCollateralId;
        address nftCollateralContract;
        uint32 loanDuration;
        uint16 loanAdminFeeInBasisPoints;
        address loanERC20Denomination;
        address referrer;
    }

    /// todo: move to interface
    /// @notice NFTfi signature
    struct Signature {
        uint256 nonce;
        uint256 expiry;
        address signer;
        bytes signature;
    }

    // todo: move to interface
    /// @notice NFTfi <-> GoblinSax term settings
    struct BorrowerSettings {
        address revenueSharePartner;
        uint16 referralFeeInBasisPoints;
    }

    /// @notice fallback
    receive() external payable {}

    /*///////////////////////////////////////////////////////////////
                                  EVENTS
    ///////////////////////////////////////////////////////////////*/
    
    /// @notice new loan
    /// @param borrower 
    /// @param id of GoblinSax loan
    /// @param nftfi_id of NFTfi loan
    /// @param nft contract
    /// @param nft_id
    event LoanCreated(
        address indexed borrower, 
        uint indexed id, 
        uint32 indexed nftfi_id, 
        address nft, 
        uint nft_id
    );

    /*///////////////////////////////////////////////////////////////
                                LOAN LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @notice purchases nft & creates GoblinSax + NFTfi loan
    /// @param offer of from NFTfi
    /// @param purchase params
    function createLoan(Offer memory offer, Purchase memory purchase) public permissioned {
        // transfer initial payment from borrower
        // review: where to transfer initial payment
        IERC20(offer.loanERC20Denomination).transferFrom(
            purchase.borrower, 
            address(this), 
            purchase.downpayment + purchase.setup_fee
        );

        // todo: buy nft..

        // approve NFTfi
        IERC721(purchase.nft).approve(address(nftfi), purchase.id);

        // create NFTfi loan
        nftfi.acceptOffer(offer, purchase.signature, purchase.borrower_settings);

        // increment id & save to memory
        uint _id = ++id;

        // get NFTfi loan id
        uint32 nftfi_id = nftfi_coordinator.totalNumLoans();

        // set GoblinSax loan expiration to 12 hours before NFTfi loan expires
        uint expiration = offer.loanDuration + block.timestamp - .5 days;
            
        // create GoblinSax loan data
        Loan memory new_loan = Loan({
            borrower : purchase.borrower,
            nft : offer.nftCollateralContract,
            id : offer.nftCollateralId,
            nftfi_id : nftfi_id,
            fee : purchase.fee,
            payoff : offer.maximumRepaymentAmount,
            payed : purchase.downpayment, 
            expiration : expiration,
            tranches : purchase.tranches,
            denomination : offer.loanERC20Denomination
        });

        // save id => loan
        loan[_id] = new_loan;

        // todo: create vault token & transfer to borrower..

        emit LoanCreated(puchase.borrower, _id, nftfi_id, purchase.nft, purchase.id);
    }

    /*///////////////////////////////////////////////////////////////
                                GOBLINSAX
    ///////////////////////////////////////////////////////////////*/

    /// @notice checks if loan is in default
    /// @dev tranches must be in chronological order
    /// @param _id of loan
    /// @return defaulting bool
    /// @return amount in default
    /// @return elapsed seconds since first default
    function isDefaulting(uint _id) public view 
    returns (
        bool defaulting, 
        uint amount, 
        uint elapsed
    ) {
        // save loan to memory
        Loan memory _loan = loan[_id];

        // declare tranche variable
        Tranche memory tranche;

        // iterate through tranches
        for (uint i; i < _loan.tranches.length; ) {
            tranche = _loan.tranches[i];

            // if borrower hasn't payed minimum by deadline
            if (block.timestamp >= tranche.deadline && _loan.payed < tranche.minimum) {
                // only assign on first tranche default
                if (!defaulting) {
                    defauling = true;

                    elapsed = block.timestamp - tranche.deadline;
                }

                amount = tranche.minimum - _loan.payed;
            } else {
                break;
            }

            unchecked { ++i; }
        }
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
