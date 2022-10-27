// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

/// @dev commented out tokenURI function
import "solmate/tokens/ERC721.sol";

import "../auth/GoblinOwned.sol";

import "openzeppelin/utils/Strings.sol";

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
        string memory _baseURI
    ) GoblinOwned(_goblin)
    ERC721(
        "GoblinSax BNPL Vault",
        string(abi.encodePacked("GBSX-", ERC721(_nft).symbol(),"#", Strings.toString(_id)))
    ) {
        baseURI = _baseURI;
    }

    string public baseURI;

    uint constant public id = 1;

    /*///////////////////////////////////////////////////////////////
                                GOBLINSAX
    ///////////////////////////////////////////////////////////////*/

    /// @notice mints nft
    /// @param borrower address
    function mint(address borrower) public permissioned {
        _mint(borrower, id);
    }

    /// @notice burns nft on default
    /// note: can only be run by BNPL contract in the event of default
    function defaultLoan() public permissioned {
        _burn(id);
    }

}