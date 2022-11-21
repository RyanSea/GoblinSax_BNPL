// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

// import { Ownable2Step } from "openzeppelin/access/Ownable2Step.sol";
// import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
// import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
// import { IERC721 } from "openzeppelin/token/ERC721/IERC721.sol";
// import { IERC1155 } from "openzeppelin/token/ERC1155/IERC1155.sol";
// import { ECDSA } from "openzeppelin/utils/cryptography/ECDSA.sol";
// import { SignatureChecker } from "openzeppelin/utils/cryptography/SignatureChecker.sol";
// import { Address } from "openzeppelin/utils/Address.sol";
// import { ReentrancyGuard } from "openzeppelin/security/ReentrancyGuard.sol";

// import { NftReceiver } from "./utils/NftReceiver.sol";
// import { INftfiFixedLoan, Offer, Signature, BorrowerSettings } from "./interfaces/INftfiFixedLoan.sol";
// import { IDirectLoanCoordinator } from "./interfaces/IDirectLoanCoordinator.sol";
// import { IMarketModule } from "./interfaces/IMarketModule.sol";

// /**
//  * @title  Bnpl
//  * @author GoblinSax
//  * @dev Main contract for GS BNPL. This contract allows the `buyer` to buy a given NFT from an allowed market, using a
//  * loan from `NFTfi` to pay a portion of the NFT price, the remaining portion should be provided by the `buyer`. The NFT
//  * remains in escrow on NFTfi contract during the loan period until it is paid back or defaulted.
//  *
//  * The `buyer` becomes the `borrower` in the `NFTfi loan`, having the obligation to payback the principal-plus-interest
//  * in order to be able to claim the NFT, otherwise the lender will be able to do so.
//  */
// contract Bnpl is NftReceiver, Ownable2Step, ReentrancyGuard {
//     using SafeERC20 for IERC20;
//     using Address for address;

//     bytes32 public constant ASSET_TYPE_ERC721 = bytes32("ERC721");
//     bytes32 public constant ASSET_TYPE_ERC1155 = bytes32("ERC1155");

//     /**
//      * @notice The address that receives the service fee on each BNPL execution.
//      */
//     address public feeReceiver;

//     /**
//      * @notice A mapping from an MarketModule contract address to whether that module
//      * is allowed to be used by the BNPL.
//      */
//     mapping(address => bool) public isModuleAllowed;

//     /**
//      * @notice A mapping that takes both a user's address and a service fee nonce used when signing off-chain
//      * the service that should be charge when executing a BNPL. Such nonce is invalidated when used on a BNPL or
//      * specifically set as so by the signer.
//      * The nonce referred to here is not the same as an Ethereum account's nonce.
//      */
//     mapping(address => mapping(uint256 => bool)) private _usedNonce;

//     // ========== Structs ==========

//     /**
//      * @notice Service fee data to be used as as parameter when executing a BNPL.
//      *
//      * @param amount - An amount charged as fee on top of the buyer portion and sent to the `feeReceiver`.
//      * @param nonce - Nonce used by the `feeReceiver` when signing the off-chain service fee.
//      * @param expiry - Date when the signature expires
//      * @param signature - The ECDSA signature of the `feeReceiver`, obtained off-chain signing the following combination
//      * of parameters:
//      * - amount,
//      * - feeReceiver address
//      * - feeReceiver nonce
//      * - expiry
//      * - this contract address
//      * - chainId
//      */
//     struct ServiceFee {
//         uint256 amount;
//         uint256 nonce;
//         uint256 expiry;
//         bytes signature;
//     }

//     /**
//      * @notice BNPL execution data used as as parameter when executing a BNPL.
//      *
//      * @param module - Address of an allowed MarketModule used for buying the NFT.
//      * @param assetType - Type of NFT, whether it is an ERC721 or ERC1155.
//      * @param buyData - Bytes used as parameters to call `buyAsset` function from the `module`.
//      * @param totalPrice - Price at which the NFT is offered in the market.
//      * @param loanContract - NFTfi loan contract address.
//      * @param loanCoordinator - NFTfi loan coordinator contract address.
//      * @param serviceFeeData - Service fee data params.
//      * @param offer - The offer made by the lender to be used when beginning the loan on NFTfi.
//      * @param lenderSignature - Lender signature related params used when beginning the loan on NFTfi.
//      * @param borrowerSettings - Some extra parameters that the borrower needs to set when accepting an offer on NFTfi.
//      */
//     struct Execution {
//         address module;
//         bytes32 assetType;
//         bytes buyData;
//         uint256 totalPrice;
//         address loanContract;
//         address loanCoordinator;
//         ServiceFee serviceFeeData;
//         Offer offer;
//         Signature lenderSignature;
//         BorrowerSettings borrowerSettings;
//     }

//     // ========== Events ===========

//     event SetFeeReceiver(address indexed feeReceiver);
//     event SetAllowedMarketModules(address indexed module);
//     event BnplExecuted(
//         address indexed borrower,
//         address indexed lender,
//         uint256 loanId,
//         address obligationReceipt,
//         uint256 smartNftId
//     );

//     /**
//      * @notice This event is emitted whenever the owner sets a module allowance.
//      *
//      * @param module - Address of the MarketModule contract.
//      * @param allowed - Signals module allowance.
//      */
//     event ModuleAllowance(address indexed module, bool allowed);

//     // ========== Custom Errors ===========
//     error Bnpl__setFeeReceiver_invalidAddress();

//     error Bnpl__setModuleAllowance_invalidAddress();

//     error Bnpl__execute_invalidAssetType();
//     error Bnpl__execute_invalidModule();
//     error Bnpl__execute_unsuccessfulBuy();

//     error Bnpl__validateServiceFee_expired();
//     error Bnpl__validateServiceFee_invalidSigner();
//     error Bnpl__validateServiceFee_invalidNonce();
//     error Bnpl__validateServiceFee_invalidSignature();

//     // ========== Constructor ==========

//     /**
//      * @notice Initialize the `feeReceiver` and the `deployer` as the `admin`.
//      */
//     constructor(address _feeReceiver) {
//         _setFeeReceiver(_feeReceiver);
//     }

//     // ========== Public Functions ==========

//     /**
//      * @notice This function can be called by admins to change the feeReceiver address.
//      *
//      * @param _feeReceiver - The address of the new feeReceiver.
//      */
//     function setFeeReceiver(address _feeReceiver) external onlyOwner {
//         _setFeeReceiver(_feeReceiver);
//     }

//     /**
//      * @notice This function can be called by admins to change the allowance status of an MarketModule contract.
//      * This includes both adding a module to the allowance list and removing it.
//      *
//      * @param _module - The address of the MarketModule contract whose allowance list status changed.
//      * @param _allowed - The new status of whether the module is allowed or not.
//      */
//     function setModuleAllowance(address _module, bool _allowed) external onlyOwner {
//         if (!_module.isContract()) revert Bnpl__setModuleAllowance_invalidAddress();
//         isModuleAllowed[_module] = _allowed;
//         emit ModuleAllowance(_module, _allowed);
//     }

//     /**
//      * @notice This function executes the BNPL process.
//      *
//      * 1- Collects the necessary amount of payment tokens to buy the NFT, from the buyer and the lender
//      * 2- Buys the NFT using the indicated market module
//      * 3- Begins the NFTfi loan
//      * 4- Returns the loaned amount (plus service fee) to the lender
//      * 5- Transfer NFTfi Obligation Receipt to the buyer turning it into the borrower
//      *
//      * @param _params - A struct of type `Execution`.
//      */
//     function execute(Execution calldata _params) external nonReentrant returns (bool) {
//         if (_params.assetType != ASSET_TYPE_ERC721 && _params.assetType != ASSET_TYPE_ERC1155)
//             revert Bnpl__execute_invalidAssetType();
//         if (!isModuleAllowed[_params.module]) revert Bnpl__execute_invalidModule();

//         _validateServiceFee(_params);

//         uint256 buyerDeposit = _params.totalPrice - _params.offer.loanPrincipalAmount;
//         IERC20(_params.offer.loanERC20Denomination).safeTransferFrom(msg.sender, address(this), buyerDeposit);

//         // transfer service fee to fee receiver
//         IERC20(_params.offer.loanERC20Denomination).safeTransferFrom(
//             msg.sender,
//             feeReceiver,
//             _params.serviceFeeData.amount
//         );

//         // get GS portion of the total
//         IERC20(_params.offer.loanERC20Denomination).safeTransferFrom(
//             _params.lenderSignature.signer,
//             address(this),
//             _params.offer.loanPrincipalAmount
//         );

//         // buy the NFT using the module
//         bytes memory payload = abi.encodeWithSelector(IMarketModule.buyAsset.selector, _params.assetType, _params.buyData, _params.offer);
//         bytes memory returnData = _params.module.functionDelegateCall(payload);
//         bool successfulBuy = abi.decode(returnData, (bool));
//         if (!successfulBuy) revert Bnpl__execute_unsuccessfulBuy();

//         if (_params.assetType == ASSET_TYPE_ERC721) {
//             IERC721(_params.offer.nftCollateralContract).approve(_params.loanContract, _params.offer.nftCollateralId);
//         } else {
//             IERC1155(_params.offer.nftCollateralContract).setApprovalForAll(_params.loanContract, true);
//         }

//         // NFTfi acceptOffer
//         INftfiFixedLoan(_params.loanContract).acceptOffer(
//             _params.offer,
//             _params.lenderSignature,
//             _params.borrowerSettings
//         );

//         // return loan principal to lender
//         IERC20(_params.offer.loanERC20Denomination).safeTransferFrom(
//             address(this),
//             _params.lenderSignature.signer,
//             _params.offer.loanPrincipalAmount
//         );

//         // transfer Obligation Receipt to buyer
//         IDirectLoanCoordinator loanCoordinator = IDirectLoanCoordinator(_params.loanCoordinator);
//         address obligationReceipt = loanCoordinator.obligationReceiptToken();
//         uint32 loanId = loanCoordinator.totalNumLoans();

//         INftfiFixedLoan(_params.loanContract).mintObligationReceipt(loanId);

//         IDirectLoanCoordinator.Loan memory loanData = loanCoordinator.getLoanData(loanId);
//         IERC721(obligationReceipt).safeTransferFrom(address(this), msg.sender, loanData.smartNftId);

//         emit BnplExecuted(msg.sender, _params.lenderSignature.signer, loanId, obligationReceipt, loanData.smartNftId);

//         return true;
//     }

//     /**
//      * @notice Sets a given `_nonce` as invalid for the caller.
//      *
//      * @param _nonce - The nonce.
//      */
//     function invalidateNonce(uint256 _nonce) external {
//         _invalidateNonce(msg.sender, _nonce);
//     }

//     /**
//      * @notice Determines if a given `_nonce` is valid for the caller.
//      *
//      * @param _nonce - The nonce.
//      */
//     function isValidNonce(address _lender, uint256 _nonce) public view returns (bool) {
//         return !_usedNonce[_lender][_nonce];
//     }

//     // ========== Internal Functions ==========

//     function _setFeeReceiver(address _feeReceiver) internal {
//         if (_feeReceiver == address(0)) revert Bnpl__setFeeReceiver_invalidAddress();
//         feeReceiver = _feeReceiver;
//         emit SetFeeReceiver(_feeReceiver);
//     }

//     function _validateServiceFee(Execution calldata _params) internal {
//         if (block.timestamp > _params.serviceFeeData.expiry) revert Bnpl__validateServiceFee_expired();
//         if (!isValidNonce(feeReceiver, _params.serviceFeeData.nonce)) revert Bnpl__validateServiceFee_invalidNonce();

//         _invalidateNonce(feeReceiver, _params.serviceFeeData.nonce);

//         bytes32 message = keccak256(
//             abi.encodePacked(
//                 _params.serviceFeeData.amount,
//                 feeReceiver,
//                 _params.serviceFeeData.nonce,
//                 _params.serviceFeeData.expiry,
//                 address(this),
//                 block.chainid
//             )
//         );

//         bool isValidSignature = SignatureChecker.isValidSignatureNow(
//             feeReceiver,
//             ECDSA.toEthSignedMessageHash(message),
//             _params.serviceFeeData.signature
//         );

//         if (!isValidSignature) revert Bnpl__validateServiceFee_invalidSignature();
//     }

//     function _invalidateNonce(address _lender, uint256 _nonce) internal {
//         _usedNonce[_lender][_nonce] = true;
//     }
// }