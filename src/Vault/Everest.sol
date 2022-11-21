// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/mixins/ERC4626.sol";
import "solmate/utils/LibString.sol";
import "solmate/tokens/ERC721.sol";

import "openzeppelin/interfaces/IERC1271.sol";

import "../interfaces/IVaultManager.sol";
import "../interfaces/IDirectLoanFixedOffer.sol";
import "../interfaces/IPromissoryNote.sol";


import "forge-std/Test.sol";

contract Everest is ERC4626, IERC1271, ERC721TokenReceiver {

    /*//////////////////////////////////////////////////////////////
                             INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    using FixedPointMathLib for uint256;

    /// @notice repsonse for valid signature
    bytes4 constant internal valid = 0x1626ba7e;

    /// @notice response for invalid signature
    bytes4 constant internal invalid = 0xffffffff;

    IVaultManager public manager;

    /// @notice NFTfi's DirectLoanFixedOffer.sol
    IDirectLoanFixedOffer public nftfi;

    /// @notice NFTfi's promissory SmartNFT.sol
    IPromissoryNote public promissoryNote;

    constructor(
        uint vault_id,
        ERC20 _asset,
        address _manager,
        address _nftfi,
        address _promissoryNote,
        uint _maximum
    ) ERC4626(
        _asset,
        string(abi.encodePacked("GoblinSax ", _asset.name() , " Vault ",LibString.toString(vault_id))), // e.g. GoblinSax Wrapped Ether Vault 10
        string(abi.encodePacked("gsax", _asset.symbol(),"-", LibString.toString(vault_id)))             // e.g. gsaxWETH-10
    ) {
        manager = IVaultManager(_manager);
        nftfi = IDirectLoanFixedOffer(_nftfi);
        promissoryNote = IPromissoryNote(_promissoryNote);

        // todo: test this..
        // give unlimited approval to NFTfi
        _asset.approve(_nftfi, 1000000 ether);

        // temp
        manager.makeValid(address(this));

        manager.addToQueue();

        maximum = _maximum;
    }

    /*//////////////////////////////////////////////////////////////
                               VAULT STATE
    //////////////////////////////////////////////////////////////*/
    
    uint public maximum;

    bool public loan_active;

    bool public loan_repayed;

    Contribution[] public contributions;

    /*//////////////////////////////////////////////////////////////
                               STATE PARAMS
    //////////////////////////////////////////////////////////////*/

    struct Whitelist {
        address collection;
        uint principal; 
    }

    struct Contribution {
        address account;
        uint amount;
        uint previousTotal;
    }

    /*//////////////////////////////////////////////////////////////
                               STATE PARAMS
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        require(!loan_active, "LOAN_ACTIVE");

        require(assets + asset.balanceOf(address(this)) <= maximum, "MAXIMUM_REACHED");

        uint total = asset.balanceOf(address(this));

        shares = ERC4626.deposit(assets, receiver);

        contributions.push( Contribution(receiver, assets, total) );
    }


    function onERC721Received(
        address, 
        address, 
        uint, 
        bytes calldata /* _loan_id */
    ) external override returns (bytes4) {

        if (msg.sender == address(promissoryNote)) {
            Contribution[] memory _contributions = contributions;

            Contribution memory contribution;

            uint length = _contributions.length;

            contribution = _contributions[length - 1];
            
            uint unspent = asset.balanceOf(address(this));

            uint total_assets = contribution.amount + contribution.previousTotal;

            uint spent = total_assets - unspent;

            uint i;
            // find contributors
            while (i < length) {
                contribution = _contributions[i];

                if (contribution.amount + contribution.previousTotal == spent) {
                    unchecked { ++i; }

                    break;
                } else if (contribution.amount + contribution.previousTotal > spent) {
                    // leave only the unspent from contribution 
                    contribution.amount -= (spent - contribution.previousTotal);

                    // assign it to array
                    _contributions[i] = contribution;

                    break;
                }

                unchecked { ++i; }
            }

            manager.removeFromQueue();

            // get destination vault
            Everest new_vault = Everest( manager.getNextInQueue() );

            asset.approve(address(new_vault), unspent);

            uint shares;

            uint supply = totalSupply;

            // burn unused shares from this vault & mint shares to new vault
            while (i < length) {
                contribution = _contributions[i];

                shares = _previewWithdraw(contribution.amount, supply, total_assets);

                _burn(contribution.account, shares);

                supply -= shares;

                new_vault.deposit(contribution.amount, contribution.account);

                total_assets -= contribution.amount;

                unchecked { ++i; }
            }
            
            loan_active = true;
        }

        return ERC721TokenReceiver.onERC721Received.selector;
    }

    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function isValidSignature(bytes32, bytes memory) public override pure returns (bytes4 magicValue) {
        // temp: 
        return valid;
    }

    /// @notice modififed previewWithdraw
    function _previewWithdraw(
        uint256 assets, 
        uint256 supply, 
        uint256 total_assets
    ) public pure returns (uint256) {
        return supply == 0 ? assets : assets.mulDivUp(supply, total_assets);
    }

}
