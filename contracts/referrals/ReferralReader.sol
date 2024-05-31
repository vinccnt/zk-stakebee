// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IReferralStorage.sol";

contract ReferralReader {
    IReferralStorage public referralStorage;
    constructor(address _referralStorageAddress){
        referralStorage = IReferralStorage(_referralStorageAddress);
    }
    function getCodeOwners(bytes32[] memory _codes) public view returns (address[] memory) {
        address[] memory owners = new address[](_codes.length);

        for (uint256 i = 0; i < _codes.length; i++) {
            bytes32 code = _codes[i];
            owners[i] = referralStorage.codeOwners(code);
        }

        return owners;
    }
}