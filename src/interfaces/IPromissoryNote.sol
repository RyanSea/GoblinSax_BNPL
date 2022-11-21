// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

interface IPromissoryNote {
    function ownerOf(uint id) external returns (address);

    function exists(uint id) external returns (bool);
}