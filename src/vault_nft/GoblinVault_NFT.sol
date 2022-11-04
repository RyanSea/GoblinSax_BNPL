// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

/// @dev commented out tokenURI function
import "solmate/tokens/ERC721.sol";

import "../auth/GoblinOwned.sol";

import "openzeppelin/utils/Strings.sol";

/// review: should it be soulbound or not? if not then there's a few things todo..
/// @title GoblinSax BNPL Vault NFT
/// @notice promissary nft representing a GoblinSax BNPL loan
contract GoblinVault_NFT is ERC721, GoblinOwned {

    /*///////////////////////////////////////////////////////////////
                              INITIALIZATION
    ///////////////////////////////////////////////////////////////*/

    /// @param _nft underlying nft
    /// @param _id of nft underlying vault
    constructor(
        address _nft, 
        uint _id,
        address _goblin,
        string memory _baseURI, 
        address borrower
    ) GoblinOwned(_goblin)
    ERC721(
        "GoblinSax BNPL Vault",
        string(abi.encodePacked("GBSX-", ERC721(_nft).symbol(),"#", Strings.toString(_id)))
    ) {
        baseURI = _baseURI;
        // mint to borrower
        _mint(borrower, 1);
    }

    string public baseURI;


    /*///////////////////////////////////////////////////////////////
                                GOBLINSAX
    ///////////////////////////////////////////////////////////////*/


    /// @notice burns nft on either settlement or default of loan
    /// note: can only be run by BNPL contract in the event of default
    function resolveLoan() public permissioned {
        _burn(1);
    }

    /*///////////////////////////////////////////////////////////////
                                SOULBOUND
    ///////////////////////////////////////////////////////////////*/

    /// @notice overrides all transfer calls and reverts
    function transferFrom(
        address,
        address,
        uint256
    ) public virtual override {
        revert("SOULBOUND");
    }

}