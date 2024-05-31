// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * Interface defined for Admin to deposit bMetis into stbMetis for reward distribution
 */
interface IAdminDepositReward {
    // withdraw metis from other protocol like enki and artimis
    function withdrawMetisFrom(address stakedContractAddress) external;
    // send metis to bMetis and get bMetis
    function wrapMetis() payable external;
    // send bMetis to stbMetis contract
    function depositReward() external;
}