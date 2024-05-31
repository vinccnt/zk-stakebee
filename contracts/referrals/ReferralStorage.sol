// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../Utils/Owned.sol";

import "./IReferralStorage.sol";

contract ReferralStorage is Owned, IReferralStorage {
    using SafeMath for uint256;

    mapping(bytes32 => address) public override codeOwners;
    mapping(bytes32 => address[]) private _codeUsers;
    mapping(bytes32 => mapping(address => bool)) private codeUserExists;
    mapping(address => bytes32) public override userReferralCodes;

    event SetUserReferralCode(address account, bytes32 code);
    event RegisterCode(address account, bytes32 code);
    event SetCodeOwner(address account, address newAccount, bytes32 code);
    event GovSetCodeOwner(bytes32 code, address newAccount);
    event UserReferredBy(address account, bytes32 code);

    constructor() Owned(msg.sender) {}

    function setUserReferralCodeByUser(bytes32 _code) external {
        _setUserReferralCode(msg.sender, _code);
    }

    function registerCode(bytes32 _code) external {
        require(_code != bytes32(0), "ReferralStorage: invalid _code");
        require(
            codeOwners[_code] == address(0),
            "ReferralStorage: code already exists"
        );

        codeOwners[_code] = msg.sender;
        emit RegisterCode(msg.sender, _code);
    }

    function getUserReferralInfo(
        address _account
    ) external view override returns (bytes32, address) {
        bytes32 code = userReferralCodes[_account];
        address referrer;
        if (code != bytes32(0)) {
            referrer = codeOwners[code];
        }
        return (code, referrer);
    }

    function _setUserReferralCode(address _account, bytes32 _code) private {
        require(_account != address(0), "Invalid Address");
        require(
            !codeUserExists[_code][_account],
            "User already referrered this code"
        );
        require(
            userReferralCodes[_account] == bytes32(0),
            "User already using other referral codes"
        );
        _codeUsers[_code].push(_account);
        codeUserExists[_code][_account] = true;
        userReferralCodes[_account] = _code;
        emit SetUserReferralCode(_account, _code);
    }

    function isUserReferredBy(
        bytes32 _code,
        address _account
    ) public view override returns (bool) {
        return codeUserExists[_code][_account];
    }

    function codeUsers(
        bytes32 _code
    ) public view override returns (address[] memory) {
        return _codeUsers[_code];
    }
}
