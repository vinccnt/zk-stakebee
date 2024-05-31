// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import {SERC20} from "./ERC20/SimplifiedERC20.sol";
import {ERC4626} from "./ERC4626/ERC4626.sol";
import {xERC4626} from "./ERC4626/xERC4626.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ztbETH is xERC4626, ReentrancyGuard {
    modifier andSync() {
        if (block.timestamp >= rewardsCycleEnd) {
            syncRewards();
        }
        _;
    }

    /* ========== CONSTRUCTOR ========== */
    constructor(
        SERC20 _underlying,
        uint32 _rewardsCycleLength
    )
        ERC4626(_underlying, "zkStaked Bee Eth", "ztbETH")
        xERC4626(_rewardsCycleLength)
    {}

    /// @notice inlines syncRewards with deposits when able
    function deposit(
        uint256 assets,
        address receiver
    ) public override andSync returns (uint256 shares) {
        return super.deposit(assets, receiver);
    }

    /// @notice inlines syncRewards with mints when able
    function mint(
        uint256 shares,
        address receiver
    ) public override andSync returns (uint256 assets) {
        return super.mint(shares, receiver);
    }

    /// @notice inlines syncRewards with withdrawals when able
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override andSync returns (uint256 shares) {
        return super.withdraw(assets, receiver, owner);
    }

    /// @notice inlines syncRewards with redemptions when able
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override andSync returns (uint256 assets) {
        unchecked {
            return super.redeem(shares, receiver, owner);
        }
    }

    /// @notice How much frxETH is 1E18 sfrxETH worth. Price is in ETH, not USD
    function pricePerShare() public view returns (uint256) {
        return convertToAssets(1e18);
    }

    /// @notice Approve and deposit() in one transaction
    function depositWithSignature(
        uint256 assets,
        address receiver,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant returns (uint256 shares) {
        uint256 amount = approveMax ? type(uint256).max : assets;
        asset.permit(msg.sender, address(this), amount, deadline, v, r, s);
        return (deposit(assets, receiver));
    }
}
