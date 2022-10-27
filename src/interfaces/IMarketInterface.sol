// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

interface IMarketInterface {
    
    /// @notice Zora AsksV1_1
    function fillAsk(
        address _tokenContract,
        uint256 _tokenId,
        address _fillCurrency,
        uint256 _fillAmount,
        address _finder
    ) external payable;

}