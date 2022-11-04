// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract GasWriter {

    struct Test {
        uint amount1;
        uint amount2;
    }

    Test[] public testArr;

    function writeToStorage(Test[] memory _testArr) public {
        //delete testArr;

        uint length = _testArr.length;

        for (uint i; i < length; ) {
            testArr.push(_testArr[i]);

            unchecked { ++i; }
        }


    }

    function storageCopy() public {
        Test[] memory _testArr = testArr;
        
    }

}