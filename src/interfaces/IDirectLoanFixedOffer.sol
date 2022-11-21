// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

/// @notice interface for https://github.com/NFTfi-Genesis/nftfi.eth/blob/main/V2/contracts/loans/direct/loanTypes/DirectLoanFixedOffer.sol
interface IDirectLoanFixedOffer {

    /// @notice NFTfi loan terms
    struct LoanTerms {
        uint256 loanPrincipalAmount;
        uint256 maximumRepaymentAmount;
        uint256 nftCollateralId;
        address loanERC20Denomination;
        uint32 loanDuration;
        uint16 loanInterestRateForDurationInBasisPoints;
        uint16 loanAdminFeeInBasisPoints;
        address nftCollateralWrapper;
        uint64 loanStartTime;
        address nftCollateralContract;
        address borrower;
    }

    /// @notice NFTfi offer struct
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

    /// @notice NFTfi signature
    struct Signature {
        uint256 nonce;
        uint256 expiry;
        address signer;
        bytes signature;
    }

    /// @notice NFTfi <-> GoblinSax term settings
    struct BorrowerSettings {
        address revenueSharePartner;
        uint16 referralFeeInBasisPoints;
    }

    /// @notice accepts Offer
    function acceptOffer(
        Offer memory _offer,
        Signature memory _signature,
        BorrowerSettings memory _borrowerSettings
    ) external;

    /// @notice pays back loan in full
    function payBackLoan(uint32 _loanId) external;

    function adminFeeInBasisPoints() external view returns(uint16);


    /// @notice getter for loan id => LoanTerms mapping
    function loanIdToLoan(uint32 _id) external view returns(LoanTerms memory _loan);

    /// @notice mins obligation receipt of loan
    function mintObligationReceipt(uint32 _loanId) external;

    function unpause() external;

}