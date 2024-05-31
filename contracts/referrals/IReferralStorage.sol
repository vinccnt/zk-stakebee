// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IReferralStorage {
    function codeOwners(bytes32 _code) external view returns (address);

    function codeUsers(bytes32 _code) external view returns (address[] memory);

    function userReferralCodes(
        address _account
    ) external view returns (bytes32);

    function getUserReferralInfo(
        address _account
    ) external view returns (bytes32, address);

    function registerCode(bytes32 _code) external;

    function isUserReferredBy(
        bytes32 _code,
        address _account
    ) external view returns (bool);
}
