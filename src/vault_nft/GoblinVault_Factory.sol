// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import "./GoblinVault_NFT.sol";

import "../interfaces/IGoblinVault_NFT.sol";

contract GoblinVault_Factory is GoblinOwned {

    /*///////////////////////////////////////////////////////////////
                              INITIALIZATION
    ///////////////////////////////////////////////////////////////*/

    constructor(address _goblin, string memory _baseURI) GoblinOwned(_goblin) {
        baseURI = _baseURI;
    }

    string public baseURI;

    /*///////////////////////////////////////////////////////////////
                                CREATE NFT
    ///////////////////////////////////////////////////////////////*/

    function createNFT(
        address _nft, 
        uint id,
        address borrower
    ) public permissioned returns (IGoblinVault_NFT) {
        GoblinVault_NFT nft = new GoblinVault_NFT(
            _nft,
            id,
            goblinsax,
            baseURI,
            borrower
        );

        return IGoblinVault_NFT(address(nft));
    }

    /*///////////////////////////////////////////////////////////////
                                SETTINGS
    ///////////////////////////////////////////////////////////////*/

    /// @notice sets new baseURI
    /// @param uri to be set
    function setURI(string memory uri) public permissioned {
        baseURI = uri;
    }

}