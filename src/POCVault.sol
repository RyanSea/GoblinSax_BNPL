// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin/token/ERC20/IERC20.sol";

import "./Token.sol";

import "forge-std/Test.sol";

contract POCVault {

    /*//////////////////////////////////////////////////////////////
                             INITIALIZATION
    //////////////////////////////////////////////////////////////*/

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
        // temp:
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
        // temp
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


    // add all deposits by sender before loan accepted  ✅
    // subtract any withdraws before loan accepted  ✅
    // get percentage of sender's deposit used in loan + subtract it from sender's total deposits ✅
    // distribute loan repayment amount by percentage of deposits used 
    // factor loan repayment into the principal for the next accepted offer
    
    // 1 initalize total assets counter to zero
    // 2 loop to the first deposit
    // 3 add deposits / subtract withdraws from total assets counter until loan — save id of *first* loan
    // 4 get percentage of senders contribution into loan and subtract from total assets counter
    // 5 loop to the first repayment matching the id of the first loan — save timestamp 
    // 6 continue until first sender repayment is before next loan — 
    // ..add repayement percentage to total assets, save timestamp of next repayment & repeat from step 3


    /*//////////////////////////////////////////////////////////////
                          INTERNAL
    //////////////////////////////////////////////////////////////*/
    
    function _calculateBalance(address sender) internal view returns (uint balance) {
        // save history to memory
        VaultAction[] memory _history = history;

        LoanResolved[] memory _resolved = resolved;

        // index of history
        uint i;
        
        uint r_idx;

        // temp: while it's required to set a static length of the array, 100 is arbitrary and may be too few 
        Contribution[] memory contributions = new Contribution[](100);

        uint loan_counter;

        uint contribution;

        for ( ; i < _history.length; ++i ) {
            // if deposit or withdraw, add to sender_balance
            if (_history[i].action == ActionType.deposit && _history[i].deposit_withdraw.account == sender) {

                balance += _history[i].deposit_withdraw.amount;
            } else if (_history[i].action == ActionType.withdraw && _history[i].deposit_withdraw.account == sender){
                balance -= _history[i].deposit_withdraw.amount;

                // if new loan
            } else if (_history[i].action == ActionType.loan) {
                // iterate through resolved loans before caulcating account's contribution to new loan
                for (; r_idx < _resolved.length; ++r_idx) {
                    // if resolution before new loan
                    if (_resolved[r_idx].time < _history[i].time) {
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

                    } else if (_resolved[r_idx].time >= _history[i].time) {
                        break;
                    }
                }
                
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

        // get resolutions after new last loan
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

    function _calculateReturn(
        uint contribution, 
        uint principal, 
        uint repayed
    ) internal pure returns(uint total_return) {
        // temp: using * 10 ** 18 to account for lack of floating point nums
        // todo: integrated a fixed point math library..
        uint percent_returned = repayed * 10 ** 18 / principal;

        total_return = contribution * percent_returned / 10 ** 18;
    }

    function _calculateContribution(
        uint principal,
        uint contributor_balance,
        uint total_assets
    ) internal pure returns(uint contribution) {
        uint percent_used = total_assets * 10 ** 18 / principal;

        contribution = contributor_balance * 10 ** 18 / percent_used;
    }

}
    

