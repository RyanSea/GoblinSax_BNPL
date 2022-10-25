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
    /// @param gas fee
    /// @param market enum
    struct Purchase {
        address borrower;
        uint price;
        uint downpayment;
        uint fee;
        uint gas;
        Market market;
    }

    /// @notice payment tranche
    /// @param deadline to pay
    /// @param minimum amount needed to be payed by deadline
    struct Tranche {
        uint deadline;
        uint minimum;
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

    /// @notice nft markets
    enum Market {
        sudoswap,
        seaport, 
        zora
    }

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
    /// temp: permission
    function createLoan(Offer memory offer, Purchase memory purchase) public {
        // transfer downpayment + fee + gas from borrower..

        // buy nft..

        // approve NFTfi
        IERC721(purchase.nft).approve(address(nftfi), purchase.id);

        // create nftfi loan..

        // increment id & save to memory
        uint _id = ++id;

        // get NFTfi loan id
        uint32 nftfi_id = nftfi_coordinator.totalNumLoans();

        // set GoblinSax loan duration to 12 hours before NFTfi loan expires
        uint duration = offer.loanDuration - .5 days;

        uint expiration = duration + block.timestamp;

        // create payment tranches
        // temp: discuss number of tranches (5 is arbitrary)
        Tranche[] memory tranches = new Tranch[](5);

        uint time;
        uint amount;
        for (uint i; i < 5; ) {
            // temp: account for percentage error
            // temp: discuss how to set minimums (e.g. higher minimums at start of loan)
            // temp: account for downpayment when calculating tranches
            time = duration / 5 * (i + 1);
            
            amount = offer.maximumRepaymentAmount / 5 * (i + 1);

            tranches[i] = Tranche({ deadline : time + block.timestamp, minimum : amount });
        }

        // create GoblinSax loan data
        Loan memory new_loan = Loan({
            borrower : purchase.borrower,
            nft : offer.nftCollateralContract,
            id : offer.nftCollateralId,
            nftfi_id : nftfi_id,
            fee : purchase.fee,
            payoff : offer.maximumRepaymentAmount,
            payed : purchase.downpayment, // temp: subtract fee
            expiration : expiration,
            tranches : tranches,
            denomination : offer.loanERC20Denomination
        });

        // save id => loan
        loan[_id] = new_loan;

        // create vault token & transfer to borrower..

        unchecked { ++i; }

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
