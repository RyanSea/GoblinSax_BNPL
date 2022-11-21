// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin/token/ERC20/IERC20.sol";

import "openzeppelin/utils/Strings.sol";

import "./Token.sol";

import "forge-std/Test.sol";

import "solmate/utils/FixedPointMathLib.sol";

contract POCVault {

    /*//////////////////////////////////////////////////////////////
                             INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    using FixedPointMathLib for uint;

    constructor(
        address _asset
    ) {
        asset = Token(_asset);
    }

    /*//////////////////////////////////////////////////////////////
                               VAULT STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice balance before accepted offer
    uint vault_balance;

    Token public asset;

    uint public total_loans;

    /// @notice all deposits, withdraws, accepted loans
    VaultAction[] public history;

    /// @notice all resolved loans
    /// note: separate because new resolved loans may not
    ///       be pushed chronologically
    LoanResolved[] public resolved;

    /// @notice loan id => loan
    mapping(uint => LoanAccepted) public loans;

    /*//////////////////////////////////////////////////////////////
                               STATE PARAMS
    //////////////////////////////////////////////////////////////*/

    /// @notice account data for LP's
    /// @param _id of LP NFT
    struct DepositOrWithdraw {
        //uint _id; todo: make vault nft..
        uint amount;
        address account; // temp
    }

    struct LoanAccepted {
        uint loan_id;
        uint principal;
        uint treasury_before_loan;
    }

    struct VaultAction {
        DepositOrWithdraw deposit_withdraw;
        LoanAccepted loan;
        uint time;
        ActionType action;
    }

    struct LoanResolved {
        uint loan_id;
        uint amount;
        uint principal;
        uint time;
    }

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
                                NFTfi
    //////////////////////////////////////////////////////////////*/

    /// @notice loan offer accepted
    function acceptOffer(uint _id, uint principal) public {
        ++total_loans;

        // temp: for testing
        asset.burn(address(this), principal);

        // todo: confirm offer is accepted..

        // save balance to memory
        uint _balance = vault_balance;

        // update storage balance
        vault_balance = asset.balanceOf(address(this));

        LoanAccepted memory _loan = LoanAccepted(_id, principal, _balance);

        loans[_id] = _loan;

        DepositOrWithdraw memory deposit_withdraw;

        // update history
        history.push(  VaultAction(deposit_withdraw, _loan, block.timestamp, ActionType.loan) );
    }

    /// @notice loan repayed
    function loanRepayed(uint _id, uint repayment) public {
        // temp: for testing
        asset.mint(address(this), repayment);

        // todo: confirm loan is resolved..
        
        vault_balance = asset.balanceOf(address(this));

        LoanAccepted memory _loan = loans[_id];

        resolved.push( LoanResolved(_id, repayment, _loan.principal, block.timestamp) );
    }
    
    /*//////////////////////////////////////////////////////////////
                            DEPOSIT / WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function deposit(/* uint _id, */ uint256 assets) public {
        asset.transferFrom(msg.sender, address(this), assets);

        vault_balance += assets;

        DepositOrWithdraw memory _deposit = DepositOrWithdraw(assets, msg.sender);

        LoanAccepted memory _loan;

        history.push( VaultAction(_deposit, _loan, block.timestamp, ActionType.deposit) );
    }

    function withdraw(/* uint _id, */ uint256 assets) public {
        // temp: sender will be vault nft id
        address sender = msg.sender;

        uint balance = _calculateBalance(msg.sender);

        require(balance >= assets, "NOT_ENOUGH_MONEY");

        vault_balance -= assets;

        history.push(VaultAction( DepositOrWithdraw(assets, sender), LoanAccepted(0,0,0), block.timestamp, ActionType.withdraw ));
        
        asset.transfer(sender, assets);
    }


    /*//////////////////////////////////////////////////////////////
                          INTERNAL
    //////////////////////////////////////////////////////////////*/
    
    /// review: this function requires repayements to be ordered chronoligically, and breaks if they aren't
    ///         should this function work even with non-ordered repayments?

    /// @notice reads history of vault and caulcates the balance of account
    function _calculateBalance(address sender) public view returns (uint balance) {
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
            if (_history[i].action == ActionType.deposit && _history[i].deposit_withdraw.account == sender) {
                balance += _history[i].deposit_withdraw.amount;
            } else if (_history[i].action == ActionType.withdraw && _history[i].deposit_withdraw.account == sender){
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

                    } else if (_resolved[r_idx].time >= _history[i].time) {
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

    function _calculateContribution(
        uint principal,
        uint contributor_balance,
        uint total_assets
    ) public pure returns(uint contribution) {
        uint WAD = 10 ** 30;

        // note: equivalent to total_assets * 10 ** 18 / principal
        uint percent_used = total_assets * WAD / principal;//total_assets.mulDivDown(1000000000000000000, principal);

        // // note: equivalent to contributor_balance * 10 ** 18 / percent_used
        contribution = contributor_balance * WAD / percent_used; //contributor_balance.mulDivDown(1000000000000000000, percent_used);
        // uint percent_spent = contributor_balance * WAD / principal; 
        // contribution = contributor_balance * WAD / percent_spent;
    }

    function _calculateReturn(
        uint contribution, 
        uint principal, 
        uint repayed
    ) public pure returns(uint total_return) {

        uint WAD = 10 ** 30;

        // note: equivalent to repayed * 10 ** 18 / principal
        uint percent_returned = repayed * WAD / principal;//repayed.mulDivDown(1000000000000000000, principal);

        // note: equivalent contribution * percent_returned / 10 ** 18
        total_return = contribution * percent_returned / WAD;//contribution.mulWadDown(percent_returned);
    }

    

}
    


