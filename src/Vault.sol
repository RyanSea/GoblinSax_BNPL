// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/token/ERC721/ERC721.sol";
import "openzeppelin/token/ERC721/IERC721Receiver.sol";
import "openzeppelin/utils/cryptography/ECDSA.sol";
import "openzeppelin/interfaces/IERC1271.sol";

import "solmate/utils/SafeTransferLib.sol";
import "solmate/utils/FixedPointMathLib.sol";

import "./interfaces/IDirectLoanCoordinator.sol";
import "./interfaces/IDirectLoanFixedOffer.sol";
import "./interfaces/IPromissoryNote.sol";

import "./Token.sol";

import "forge-std/Test.sol";

contract Vault is ERC721, IERC1271 ,IERC721Receiver {

    /*//////////////////////////////////////////////////////////////
                             INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    using ECDSA for bytes32;
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    bytes4 constant internal MAGICVALUE = 0x1626ba7e;
    bytes4 constant internal INVALID_SIGNATURE = 0xffffffff;

    /// @notice NFTfi's DirectLoanFixedOffer.sol
    IDirectLoanFixedOffer private NFTFI_DIRECT_LOAN;

    /// @notice NFTfi's DirectLoanCoordinator.sol
    IDirectLoanCoordinator private NFTFI_COORDINATOR;

    /// @notice NFTfi's SmartNft.sol PromissoryNoteToken
    IPromissoryNote private NFTFI_NOTE;

    /// temp: will be IERC20
    /// @notice underlying asset
    IERC20 public immutable asset;

    /// @notice base uri for vault token
    string public baseURI;

    /// @notice vault manager
    address public manager;

    /// @notice whether vault is private
    bool public private_vault;

    constructor(
        address _asset,
        string memory _uri,
        address _NFTFI_DIRECT_LOAN,
        address _NFTFI_COORDINATOR, 
        address _NFTFI_NOTE, 
        address _manager,
        address[] memory whitelist

    ) ERC721(
        string(abi.encodePacked("GoblinSax ", IERC20(_asset).symbol(), " Vault")), // e.g. "GoblinSax WETH Vault"
        string(abi.encodePacked("gsax", IERC20(_asset).symbol()))                  // e.g. "gsaxWETH"
    ) {

        //      ASSIGN BASE     //
        asset = IERC20(_asset);
        baseURI = _uri;
        manager = _manager; 
        NFTFI_DIRECT_LOAN = IDirectLoanFixedOffer(_NFTFI_DIRECT_LOAN);
        NFTFI_COORDINATOR = IDirectLoanCoordinator(_NFTFI_COORDINATOR);
        NFTFI_NOTE = IPromissoryNote(_NFTFI_NOTE);

        //      HANDLE WHITELIST        //
        uint length = whitelist.length;

        if (length > 0) {
            private_vault = true;

            for(uint i; i < length; ) {
                whitelisted[whitelist[i]] = true;

                unchecked { ++i; }
            }
        }

        //      APPROVE NFTFI       //
        // review: is this how approval should be handled?
        // give NFTfi's DirectLoanFixedOffer.sol unlimited approval
        asset.approve(_NFTFI_DIRECT_LOAN, type(uint256).max);
    }

    /// @notice id of vault token
    uint public id;

    /*//////////////////////////////////////////////////////////////
                               VAULT STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice internal balance counter
    /// note: used to know balance before offer accepted
    uint public vault_balance;

    /// @notice loan counter
    /// note: used to make size of memory array in _calculateBalance
    uint public total_loans;

    /// @notice all deposits, withdraws, accepted loans
    VaultAction[] public history;

    /// @notice all resolved loans
    /// note: must be chonological or will need to change _calculateBalance
    LoanResolved[] public resolved;

    /// @notice loan id => loan
    mapping(uint => LoanAccepted) public loans;

    /// @notice address => whether it's whitelisted
    mapping(address => bool) public whitelisted;

    /*//////////////////////////////////////////////////////////////
                               STATE PARAMS
    //////////////////////////////////////////////////////////////*/

    /// @notice account data for LP's
    /// @param account nft id
    /// @param amount of deposit/withdraw
    struct DepositOrWithdraw {
        uint account; 
        uint amount;
    }

    /// @notice data for when a loan is accepted
    /// @param nft contract underlying the loan
    /// @param id of underlying nft
    /// @param promissory_id of promissorynote
    /// @param principal amount lended
    /// @param loan_id for NFTfi loan
    /// @param totalReturn amount for loan fulfillment 
    /// @param duration of loan
    /// @param start time
    /// @param treasury_before_loan; balance before princiapl was taken from vault
    struct LoanAccepted {
        IERC721 nft;
        uint id;
        uint promissory_id; 
        uint principal;
        uint loan_id;
        uint totalReturn;
        uint duration;
        uint start;
        uint treasury_before_loan;
    }

    /// @notice general vault action to be pushed to history
    /// @param deposit_withdraw data, if action = depoist/withdraw
    /// @param loan data, if action = loan
    /// @param time of vault action
    /// @param action type
    struct VaultAction {
        DepositOrWithdraw deposit_withdraw;
        LoanAccepted loan;
        uint time;
        ActionType action;
    }

    /// @notice loan resolution data
    /// @param loan_id for NFTfi loan
    /// @param amount repayed
    /// @param principal amount for loan
    /// @param time of resolution
    struct LoanResolved {
        uint loan_id;
        uint amount;
        uint principal;
        uint time;
    }

    /// @notice contribution data used in _calculateBalance
    /// @param loan_id for NFTfi loan
    /// @param contribution amount
    struct Contribution {
        uint loan_id;
        uint contribution;
    }

    enum ActionType {
        deposit,
        withdraw,
        loan
    }

    /*//////////////////////////////////////////////////////////////
                               LOAN UPDATES
    //////////////////////////////////////////////////////////////*/

    /// @notice loan repayed
    function loanRepayed(uint _id) public {
        // temp: for testing
        //asset.mint(address(this), repayment);

        // save loan to memory
        LoanAccepted memory _loan = loans[_id];

        require(!NFTFI_NOTE.exists(_loan.promissory_id), "LOAN_ACTIVE");

        vault_balance = asset.balanceOf(address(this));

        resolved.push( LoanResolved(_id, _loan.totalReturn, _loan.principal, block.timestamp) );

        delete loans[_id];
    }
    
    /*//////////////////////////////////////////////////////////////
                            DEPOSIT / WITHDRAW
    //////////////////////////////////////////////////////////////*/

    /// @notice initiates a deposit to account
    /// @notice if account id is 0, mints nft to sender and assigns account to nft id
    /// @param _id of account / nft
    /// @param amount to deposit
    function deposit(uint _id, uint256 amount) public {
        // if private vault, require whitelisted depositor
        // note: went with the latter method
        // if(private_vault) {
        //     address account = _exists(_id) ? ownerOf(_id) : msg.sender;

        //     require(whitelisted[account], "NOT_WHITELISTED");
        // }

        asset.transferFrom(msg.sender, address(this), amount);

        if (_id == 0) {
            // if private vault, require sender to be whitelisted before minting LP token
            if (private_vault) require(whitelisted[msg.sender], "NOT_WHITELISTED");
            
            // increment id and assign to _id
            _id = ++id;

            // mint vault nft
            _safeMint(msg.sender, _id);
        } 

        vault_balance += amount;

        DepositOrWithdraw memory _deposit = DepositOrWithdraw(_id, amount);

        LoanAccepted memory _loan;

        history.push( VaultAction(_deposit, _loan, block.timestamp, ActionType.deposit) );
    }

    /// @notice initiates a withdraw from account
    /// @param _id of account / nft
    /// @param amount to withdraw
    function withdraw(uint _id, uint256 amount) public {
        require(_id > 0, "ACCOUNT_DOESN'T_EXIST");

        // todo: create allowance..?

        address account_owner = ownerOf(_id);

        require(msg.sender == account_owner, "NOT_OWNER");

        uint balance = _calculateBalance(_id);

        require(balance >= amount, "BALANCE_TOO_LOW");

        vault_balance -= amount;

        LoanAccepted memory _loan;

        history.push(VaultAction( DepositOrWithdraw(_id, amount), _loan, block.timestamp, ActionType.withdraw ));
        
        asset.transfer(account_owner, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            NFT METADATA
    //////////////////////////////////////////////////////////////*/

    /// @notice sets new baseURI
    /// @param _uri to set to baseURI
    function setBaseURI(string memory _uri) public {
        baseURI = _uri;
    }

    /// @notice override for OZ's baseURI getter
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL CALCULATIONS
    //////////////////////////////////////////////////////////////*/
    
    /// review: this function requires repayements to be ordered chronoligically, and breaks if they aren't
    ///         should this function work even with non-ordered repayments?

    /// @notice reads history of vault and caulcates the balance of an account
    /// @param account nft id
    function _calculateBalance(uint account) public view returns (uint balance) {
        // save history to memory
        VaultAction[] memory _history = history;

        LoanResolved[] memory _resolved = resolved;

        // index of history
        uint i;
        
        uint r_idx;

        // temp: while it's required to set a static length of the array, 100 is arbitrary and may be too few 
        Contribution[] memory contributions = new Contribution[](total_loans);

        uint loan_counter;

        uint contribution;

        for ( ; i < _history.length; ++i ) {
            // if deposit or withdraw, add to account's balance
            if (_history[i].action == ActionType.deposit && _history[i].deposit_withdraw.account == account) {
                balance += _history[i].deposit_withdraw.amount;
            } else if (_history[i].action == ActionType.withdraw && _history[i].deposit_withdraw.account == account){
                balance -= _history[i].deposit_withdraw.amount;
                // if new loan with a poistive account balance
            } else if (_history[i].action == ActionType.loan && balance > 0) {
                // first, factor in any new repayments to account

                // iterate through resolved loans before caulcating account's contribution to new loan
                for (; r_idx < _resolved.length; ++r_idx) {
                    // if resolution before new loan
                    if (_resolved[r_idx].time < _history[i].time) {
                        // iterate through contributed loans to find a matching loan id that account contributed to
                        for (uint _i; _i < loan_counter; ++_i) {
                            // if resolution id matches id that account has contributed to
                            if (contributions[_i].loan_id == _resolved[r_idx].loan_id) {  
                                // add repayment to account's balance                         
                                balance += _calculateReturn(
                                    contributions[_i].contribution, 
                                    _resolved[r_idx].principal, 
                                    _resolved[r_idx].amount
                                );
                            } 
                        } 
                    } else {
                        break;
                    }
                }
                

                // after factoring in new repayments to account, calculate contribution to new loan
                contribution = _calculateContribution(
                    _history[i].loan.principal, 
                    balance, 
                    _history[i].loan.treasury_before_loan
                );
    
                if (contribution > 0) {
                    
                    balance -= contribution;

                    contributions[loan_counter] = Contribution(_history[i].loan.loan_id, contribution);

                    unchecked { ++loan_counter; }
                }
            }
        }

        // after iterating through history, check for any remaining repayements
        for ( ; r_idx < _resolved.length; ++r_idx) {

            // check if resolution loan id is a loan account contributed to
            for (uint _i; _i < loan_counter; ++_i) {
                // if resolution id matches id that account has contributed to
                if (contributions[_i].loan_id == _resolved[r_idx].loan_id) {
                    balance += _calculateReturn(
                        contributions[_i].contribution,  
                        _resolved[r_idx].principal,
                        _resolved[r_idx].amount
                    );
                    
                } 
            } 
        }
    }

    /// @notice calculates account's contribution to loan
    /// @param principal of loan
    /// @param contributor_balance before loan
    /// @param total_assets in treasury at time of loan
    function _calculateContribution(
        uint principal,
        uint contributor_balance,
        uint total_assets
    ) internal pure returns(uint contribution) {
        uint RAY = 10 ** 27;

        uint percent_used = total_assets * RAY / principal;

        contribution = contributor_balance * RAY / percent_used;
    }

    /// @notice calculates return of resolved loan
    /// @param contribution of account to loan
    /// @param principal of loan
    /// @param repayed amount from loan
    function _calculateReturn(
        uint contribution, 
        uint principal, 
        uint repayed
    ) internal pure returns(uint total_return) {
        uint RAY = 10 ** 27;

        uint percent_returned = repayed * RAY / principal;

        total_return = contribution * percent_returned / RAY;
    }

    /*//////////////////////////////////////////////////////////////
                            ERC721 RECEIVER
    //////////////////////////////////////////////////////////////*/

    /// @param _id of nft
    /// @param _loan_id of nftfi loan
    function onERC721Received(
        address, 
        address, 
        uint _id, 
        bytes calldata _loan_id
    ) external returns (bytes4) {
        // if sender is loan coordinator 
        if (msg.sender == address(NFTFI_NOTE)) {
            // note: not necessary with a trusted NFTFI_NOTE
            // ensure vault owns promissorynote id
            require(NFTFI_NOTE.ownerOf(_id) == address(this), "NOT_PROMISSORY_NOTE");

            // increment active loans
            ++total_loans;

            // decode NFTfi loan id
            uint32 loan_id = abi.decode(_loan_id, (uint32));

            // note: not necessary with a trusted NFTFI_NOTE
            // ensure loan hasn't already been processed 
            require(address(loans[loan_id].nft) == address(0), "LOAN_ALREADY_PROCESSED");
            
            // save NFTfi loan terms to memory
            IDirectLoanFixedOffer.LoanTerms memory terms = NFTFI_DIRECT_LOAN.loanIdToLoan(loan_id);

            uint previous_balance = vault_balance;

            uint current_balance = asset.balanceOf(address(this));

            uint principal = previous_balance - current_balance;
            
            // initialize loan
            LoanAccepted memory _loan = LoanAccepted({
                nft : IERC721(terms.nftCollateralContract),
                id : terms.nftCollateralId,
                promissory_id : _id,
                principal : principal,
                loan_id : loan_id,
                totalReturn : terms.maximumRepaymentAmount,
                duration : terms.loanDuration,
                start : terms.loanStartTime,
                treasury_before_loan : previous_balance
            });

            vault_balance = current_balance;
            
            // store loan
            loans[loan_id] = _loan;

            // update history
            history.push(VaultAction( DepositOrWithdraw(0, 0), _loan, block.timestamp, ActionType.loan ));
        }

        return IERC721Receiver.onERC721Received.selector;
    }

    /*//////////////////////////////////////////////////////////////
                                GOBLINSAX
    //////////////////////////////////////////////////////////////*/

    function openVault() public /* onlyOwner */{
        private_vault = false;
    }

    /*//////////////////////////////////////////////////////////////
                            VAULT SIGNATURE
    //////////////////////////////////////////////////////////////*/

    function isValidSignature(bytes32, bytes memory) public override pure returns (bytes4 magicValue) {

        // if (_hash.recover(_signature) == manager) {
        //     return MAGICVALUE;
        // } else {
        //     return INVALID_SIGNATURE;
        // }

        // temp:
        return MAGICVALUE;

    }

    /*//////////////////////////////////////////////////////////////
                                SOULBOUND
    //////////////////////////////////////////////////////////////*/

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 _id, 
        uint256 batchSize
    ) internal override {
        if(private_vault) {
            revert("SOULBOUND");
            
        } else {
            ERC721._beforeTokenTransfer(from, to, _id , batchSize);
        }
    }
}