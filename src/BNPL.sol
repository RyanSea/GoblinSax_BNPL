// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import "./auth/GoblinOwned.sol";

import "./interfaces/IDirectLoanFixedOffer.sol";
import "./interfaces/IMarketInterface.sol";
import "./interfaces/IDirectLoanCoordinator.sol";
import "./interfaces/IGoblinVault_NFT.sol";

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
        address _goblinsax,
        address _nft_factory,
        address _smartnft
    ) GoblinOwned(_goblinsax) {
        nftfi = IDirectLoanFixedOffer(_nftfi);
        nftfi_coordinator = IDirectLoanCoordinator(_nftfi_coordinator);
        nft_factory = IGoblinVault_NFT(_nft_factory);
        smartnft = IERC721(_smartnft);
    }

    /// @notice NFTfi's DirectLoanFixedOffer contract
    IDirectLoanFixedOffer public nftfi;

    /// @notice NFTfi's DirectLoanCoordinator contract
    IDirectLoanCoordinator public nftfi_coordinator;

    /// @notice BNPL vault token factory
    IGoblinVault_NFT public nft_factory;

    /// @notice NFTfi's SmartNFT contract
    IERC721 public smartnft;

    /// @notice GoblinSax loan id
    uint id;

    /// @notice loan id => Loan
    mapping(uint => Loan) public loan;

    /// @notice market name => market contract
    mapping(string => address) public market;

    /// @notice GoblinSax loan
    /// @param nft contract address
    /// @param id of nft
    /// @param nftfi_id NFTfi's loan id
    /// @param fee for GoblinSax, calculated with each payment
    /// @param owed to NFTfi to fully payoff loan
    /// @param payed by borrower so far
    /// @param expiration of loan before default
    /// @param terms for default
    /// @param tranches for repayment
    /// @param vault_nft GoblinSax loan receipt 
    /// @param denomination of token for NFTfi loan
    struct Loan {
        address borrower;
        address nft;
        uint id;
        uint32 nftfi_id;
        uint fee;
        uint owed;
        uint payed;
        uint expiration;
        DefaultTerms terms;
        Tranche[] tranches;
        IGoblinVault_NFT vault_nft;
        IERC20 denomination;
    }

    /// @notice purchase params
    /// @param borrower for GoblinSax BNPL
    /// @param price of purchase
    /// @param downpayment for purchase
    /// @param fee for GoblinSax
    /// @param terms for default
    /// @param tranches for repayment @dev should be in chronological order
    /// @param setup_fee including gas for initiating loan
    /// @param market name
    /// @param signature struct for NFTfi
    /// @param borrower_settings struct for NFTfi
    struct Purchase {
        address borrower;
        uint price;
        uint downpayment;
        uint fee;
        DefaultTerms terms;
        Tranche[] tranches;
        uint setup_fee;
        uint gas;
        string market;
        IDirectLoanFixedOffer.Signature signature;
        IDirectLoanFixedOffer.BorrowerSettings borrower_settings;

        IERC20 denomination;
    }

    /// @notice payment tranche
    /// @param deadline to pay
    /// @param minimum amount needed to be payed by deadline
    struct Tranche {
        uint deadline;
        uint minimum;
    }

    /// review: if exceeding one or both should count as a default
    /// @notice parameters of a default
    /// @param maximum_amount that can be in default
    /// @param maximum_amount to be in default
    struct DefaultTerms {
        uint maximum_amount;
        uint maximum_time;
    }

    /// @notice fallback
    receive() external payable {}

    /*///////////////////////////////////////////////////////////////
                                  EVENTS
    ///////////////////////////////////////////////////////////////*/
    
    /// @notice new loan
    /// @param id of GoblinSax loan
    /// @param new_loan struct
    event LoanCreated(uint indexed id, Loan new_loan);

    /// @notice new loan payment
    /// @param id of loan
    /// @param payor of loan
    /// @param amount payed
    event PaymentMade(
        uint indexed id, 
        address indexed payor, 
        uint amount
    );

    /// @notice loan settled
    /// @param id of loan
    /// @param nftfi_id NFTfi's loan id
    event LoanSettled(uint indexed id, uint32 indexed nftfi_id);
    
    /// @notice loan defaulted
    /// @param id of loan
    /// @param amount owed to NFTfi
    /// @param unpayed amount for NFTfi
    event LoanDefaulted(uint indexed id, uint amount, uint unpayed);

    /*///////////////////////////////////////////////////////////////
                                LOAN LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @notice purchases nft & creates GoblinSax + NFTfi loan
    /// @param offer of from NFTfi
    /// @param purchase params
    function createLoan(IDirectLoanFixedOffer.Offer memory offer, Purchase memory purchase) public permissioned {
        // transfer initial payment from borrower
        IERC20(offer.loanERC20Denomination).transferFrom(
            purchase.borrower, 
            address(this), 
            purchase.downpayment + purchase.setup_fee
        );

        // temp: using Zora for POC
        // buy nft
        zoraBuyer(purchase, offer.nftCollateralContract, offer.nftCollateralId);

        // approve NFTfi
        IERC721(offer.nftCollateralContract).approve(address(nftfi), offer.nftCollateralId);

        // create NFTfi loan
        nftfi.acceptOffer(offer, purchase.signature, purchase.borrower_settings);

        // note: all money is transfered in and out of contract atomically
        // transfer loan principal to GoblinSax 
        IERC20(offer.loanERC20Denomination).transfer(goblinsax, offer.loanPrincipalAmount);

        // increment id & save to memory
        uint _id = ++id;

        // get NFTfi loan id
        uint32 nftfi_id = nftfi_coordinator.totalNumLoans();

        // set GoblinSax loan expiration to 12 hours before NFTfi loan expires
        uint expiration = offer.loanDuration + block.timestamp - .5 days;

        // todo: create vault token & transfer to borrower..
        // create vault nft
        IGoblinVault_NFT vault_nft = nft_factory.createNFT(
            offer.nftCollateralContract, 
            offer.nftCollateralId,
            purchase.borrower
        );
            
        // create GoblinSax loan data
        Loan memory new_loan = Loan({
            borrower : purchase.borrower,
            nft : offer.nftCollateralContract,
            id : offer.nftCollateralId,
            nftfi_id : nftfi_id,
            fee : purchase.fee,
            owed : offer.maximumRepaymentAmount,
            payed : purchase.downpayment, 
            expiration : expiration,
            terms : purchase.terms,
            tranches : purchase.tranches,
            vault_nft : vault_nft,
            denomination : IERC20(offer.loanERC20Denomination)
        });

        // save id => loan
        loan[_id] = new_loan;

        emit LoanCreated(_id, new_loan);
    }

    /// @notice makes payment to loan
    /// @param _id of loan
    /// @param amount of payment
    function pay(uint _id, uint amount) public {
        // save loan to memory
        Loan memory _loan = loan[_id];

        // require loan exists
        require(loan[_id].borrower != address(0), "NO_LOAN");

        // note: fee should be displayed on frontend before function call
        // save amount - fee
        uint payment = amount - (amount / _loan.fee);

        // ensure borrower isn't overpaying
        require(_loan.payed + payment >= _loan.owed, "PAYMENT_TOO_HIGH");

        // transfer amount of payment in loan denomination 
        loan[_id].denomination.transferFrom(msg.sender, goblinsax, amount);

        // add payment to loan
        loan[_id].payed += payment;

        emit PaymentMade(_id, msg.sender, amount);
    }

    /// @notice settles loan & distributes nft
    /// @param _id of loan
    function settle(uint _id) public {
        // save loan to memory
        Loan memory _loan = loan[_id];

        // require loan exists
        require(_loan.borrower != address(0), "NO_LOAN");

        // require loan fulfillment
        require(_loan.payed == _loan.owed, "LOAN_UNFULFILLED");

        // remove loan from storage
        delete loan[_id];

        // transfer loan denomination to this contract
        IERC20(_loan.denomination).transferFrom(goblinsax, address(this), _loan.owed);

        // approve NFTfi 
        IERC20(_loan.denomination).approve(address(nftfi), _loan.owed);
        
        // payoff NFTfi loan
        nftfi.payBackLoan(_loan.nftfi_id);

        // burn vault nft
        _loan.vault_nft.resolveLoan();

        // transfer loan nft to borrower
        IERC721(_loan.nft).safeTransferFrom(address(this), _loan.borrower, _loan.id);

        emit LoanSettled(_id, _loan.nftfi_id);
    }

    /*///////////////////////////////////////////////////////////////
                                MARKET BUYERS
    ///////////////////////////////////////////////////////////////*/
    
    // todo: decide on scaleable implementation..
    /* function marketSelector(
        Purchase memory purchase, 
        address nft, 
        uint _id
    ) internal returns (bool) {
        require(market[purchase.market] != address(0), "MARKET_UNRECOGNIZED");
    } 
    */

    // temp: Zora buyer for POC
    function zoraBuyer(
        Purchase memory purchase, 
        address nft, 
        uint _id
    ) internal {
        // save Zora contract to memory
        address zora = market["zora"];

        // approve Zora
        IERC20(purchase.denomination).approve(zora, purchase.price);

        // buy nft
        IMarketInterface(zora).fillAsk(
            nft,
            _id,
            address(purchase.denomination),
            purchase.price,
            goblinsax // set GS as finder for potential fee
        );
    }

    /*///////////////////////////////////////////////////////////////
                                GOBLINSAX
    ///////////////////////////////////////////////////////////////*/
    
    /// review: how to liquidate loan receipt
    /// @notice defualts loan and 
    function initiateDefault(uint _id) public permissioned {
        // get default params
        // note: also reverst is loan  doesn't exist
        (bool defaulting, , ) = isDefaulting(_id);

        // save loan to memory
        Loan memory _loan = loan[_id];

        require(defaulting, "NOT_DEFAULTING");

        // remove loan from storage
        delete loan[_id];

        // burn vault nft
        _loan.vault_nft.resolveLoan();

        // mint NFTfi obligation receipt
        nftfi.mintObligationReceipt(_loan.nftfi_id);

        // transfer receipt to GoblinSax
        smartnft.safeTransferFrom(address(this), goblinsax, _loan.nftfi_id);

        loan[_id].borrower = goblinsax;

        emit LoanDefaulted(_id, _loan.owed, _loan.owed - _loan.payed);
    }

    /*///////////////////////////////////////////////////////////////
                            INTERNAL ACCOUNTING
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

        // require loan exists
        require(_loan.borrower != address(0), "NO_LOAN");

        // declare tranche variable
        Tranche memory tranche;

        // iterate through tranches
        for (uint i; i < _loan.tranches.length; ) {
            tranche = _loan.tranches[i];

            // if borrower hasn't payed minimum by deadline
            if (_loan.payed < tranche.minimum && block.timestamp >= tranche.deadline) {
                amount = tranche.minimum - _loan.payed;
                
                // only assign on first tranche default
                if (elapsed = 0) {
                    elapsed = block.timestamp - tranche.deadline;
                }
            } else {
                // if amount in default and elapsed time since default exceed maximum
                if (elapsed > _loan.terms.maximum_time && amount > _loan.terms.maximum_amount) {
                    defaulting = true;
                }

                // end loop to avoid needless checks
                break;
            }
            unchecked { ++i; }
        }

    }

    /// todo: add public sortTranches as a safety net / borrower assurance in the event tranches aren't sorted chronologically..


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
