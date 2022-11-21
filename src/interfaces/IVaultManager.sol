// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

interface IVaultManager {
    function getNextInQueue() external view returns (address);

    function removeFromQueue() external;

    function addToQueue() external;

    /// temp:
    function makeValid(address vault) external;
}