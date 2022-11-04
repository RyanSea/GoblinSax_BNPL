// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/mixins/ERC4626.sol";

import "./Token.sol";

contract Vault is ERC4626 {

    /*//////////////////////////////////////////////////////////////
                             INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    constructor(
        Token _asset
    ) ERC4626(
        _asset,
        string(abi.encodePacked(_asset.name(), " Vault")),
        string(abi.encodePacked(_asset.symbol(), "-VAULT"))
    ){}

    /*//////////////////////////////////////////////////////////////
                               VAULT STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice if offer has been accepted for vault
    bool public closed;

    modifier notClosed {
        require(!closed, "VAULT_CLOSED");
        _;
    }

    /// @notice all vault deposits
    DepositData[] public all_deposits;

    struct DepositData {
        uint assets;
        uint shares;
    }

    function afterDeposit(uint256 assets, uint256 shares) internal virtual override {
        all_deposits.push( DepositData(assets,shares) );
    }


    /*//////////////////////////////////////////////////////////////
                               STATE PARAMS
    //////////////////////////////////////////////////////////////*/

    

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT / WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 assets, address receiver) 
        public virtual override notClosed returns (uint256 shares)  {
        shares = ERC4626.deposit(assets, receiver);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual override notClosed returns (uint256 shares) {
        // todo: calculate shares & implement beforeWithdraw..
        // todo: look into if the above todo is necessary..

        shares = ERC4626.withdraw(assets, receiver, owner);
    }

    // function redeem(
    //     uint256 shares,
    //     address receiver,
    //     address owner
    // ) public virtual override notClosed returns (uint256 assets) {
    //     beforeWithdraw(assets, shares, owner);

    //     assets = ERC4626.redeem(shares, receiver, owner);
    // }

    /*//////////////////////////////////////////////////////////////
                            ........
    //////////////////////////////////////////////////////////////*/

    // function offerAccepted(uint price/*, address newVault */) public {
    //     //DepositData[] memory _deposits = deposits;

    //     //uint length = _deposits.length;

    //     uint counter;

    //     //DepositsData memory _deposit;

    //     // for (uint i; i < length; ) {
    //     //     _depoist = _deposits[i];

    //     //     counter += _deposit.assets;

    //     //     //if (counter ==)
    //     // }
    // }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL ACCOUNTING
    //////////////////////////////////////////////////////////////*/

    function totalAssets() public view virtual override returns (uint256) {
        return asset.balanceOf(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HOOKS LOGIC
    //////////////////////////////////////////////////////////////*/

    // function afterDeposit(uint256 assets, uint256 shares) internal virtual override {
    //     deposits.push( DepositData(assets,shares) );
    // }

    // function beforeWithdraw(
    //     uint256 , 
    //     uint256 shares, 
    //     address owner
    // ) internal virtual {
    //     // todo: optimize for less storage reads..

    //     // save locked shares to memory
    //     uint locked = locked_shares[owner];

    //     // save share balance to memory
    //     uint total_shares = balanceOf[owner];

    //     require(shares + locked <= total_shares, "SHARES_LOCKED");
    // }

}
