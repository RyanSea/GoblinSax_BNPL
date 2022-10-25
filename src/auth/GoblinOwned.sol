// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice clone of Solmate's Owned.sol with a goblin theme
abstract contract GoblinOwned {

    /*//////////////////////////////////////////////////////////////
                                 EVENT
    //////////////////////////////////////////////////////////////*/

    event NewGoblin(address indexed user, address indexed newGoblin);

    /*//////////////////////////////////////////////////////////////
                            OWNERSHIP STORAGE
    //////////////////////////////////////////////////////////////*/

    address public goblinsax;

    modifier permissioned() virtual {
        require(msg.sender == goblinsax, "NOT_GOBLIN");

        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _goblinsax) {
        goblinsax = _goblinsax;

        emit NewGoblin(address(0), _goblinsax);
    }

    /*//////////////////////////////////////////////////////////////
                             OWNERSHIP LOGIC
    //////////////////////////////////////////////////////////////*/

    function transferOwnership(address new_goblin) public virtual permissioned {
        goblinsax = new_goblin;

        emit NewGoblin(msg.sender, new_goblin);
    }
}