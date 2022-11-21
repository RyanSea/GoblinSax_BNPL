// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin/utils/structs/EnumerableSet.sol";

contract VaultManager {
    
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet queue;

    mapping(address => bool) public valid_vault;

    function addToQueue() public {
        require(valid_vault[msg.sender], "ADDRESS_UNRECOGNIZED");

        require(!queue.contains(msg.sender), "ALREADY_QUEUED");

        queue.add(msg.sender);
    }

    function removeFromQueue() public {
        require(queue.contains(msg.sender),"ALREADY_UNQUEUED");

        queue.remove(msg.sender);
    }

    function getNextInQueue() public view returns (address) {
        return queue.at(0);
    }

    /// temp:
    function makeValid(address vault) public {
        valid_vault[vault] = true;
    }
}