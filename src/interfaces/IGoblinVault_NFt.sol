// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

interface IGoblinVault_NFT {

    /*///////////////////////////////////////////////////////////////
                            GOBLINVAULT FACTORY
    ///////////////////////////////////////////////////////////////*/

    function createNFT(address _nft, uint id) external;

    function setURI(string memory uri) external;

    /*///////////////////////////////////////////////////////////////
                            GOBLINVAULT NFT
    ///////////////////////////////////////////////////////////////*/

    function mint(address borrower) external;

    function defaultLoan() external;

}