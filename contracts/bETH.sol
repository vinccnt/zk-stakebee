// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ERC20PermitPermissionedMint} from "./ERC20/ERC20PermitPermissionedMint.sol";

contract bETH is ERC20PermitPermissionedMint {
    /* ========== CONSTRUCTOR ========== */
    constructor(
        address _creator_address,
        address _timelock_address
    )
        ERC20PermitPermissionedMint(
            _creator_address,
            _timelock_address,
            "Bee ETH",
            "bETH"
        )
    {}
}
