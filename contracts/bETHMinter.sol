// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {bETH} from "./bETH.sol";
import {ztbETH} from "./ztbETH.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IL2ERC20Bridge} from "./IL2ERC20Bridge.sol";
import {OperatorRegistry} from "./OperatorRegistry.sol";
import {DeployedContracts} from "./libraries/DeployedContracts.sol";
import "./Utils/Owned.sol";
import {IReferralStorage} from "./referrals/IReferralStorage.sol";
import {ReferralReader} from "./referrals/ReferralReader.sol";

contract bEthMinter is ReentrancyGuard, OperatorRegistry {
    uint256 public constant DEPOSIT_SIZE = 10 ether; // METIS minimum deposit size
    uint256 public constant BRIDGE_FEE = 0.01 ether;
    uint256 public constant RATIO_PRECISION = 1e6; // 1,000,000

    uint256 public withholdRatio; // What we keep and don't deposit whenever someone submit()'s ETH
    uint256 public currentWithheldMETIS; // Needed for internal tracking
    mapping(address => bool) public activeValidators; // Tracks validators (via their pubkeys) that already have 32 ETH in them


    bETH public immutable bETHToken;
    ztbETH public immutable stbMETISToken;

    bool public submitPaused;
    bool public depositMetisPaused;

    constructor(
        address _bMETISAddress,
        address _stbMETISAddress,
        address _owner,
        address _timelock_address
    ) OperatorRegistry(_owner, _timelock_address) {
        // bridge = IL2ERC20Bridge(_l2StandardBridgeAddress);
        bETHToken = bETH(_bMETISAddress);
        stbMETISToken = ztbETH(_stbMETISAddress);
        withholdRatio = 0; // No ETH is withheld initially
        currentWithheldMETIS = 0;
        timelock_address = _timelock_address;
    }

    /// @notice Mint bMETIS and deposit it to receive ztbETH.sol in one transaction
    /** @dev Could try using EIP-712 / EIP-2612 here in the future if you replace this contract,
        but you might run into msg.sender vs tx.origin issues with the ERC4626 */
    function submitAndDeposit(
        address recipient
    ) external payable returns (uint256 shares) {
        // Give the frxETH to this contract after it is generated
        _submit(address(this));

        // Approve frxETH to sfrxETH for staking
        bETHToken.approve(address(stbMETISToken), msg.value);

        // Deposit the frxETH and give the generated sfrxETH to the final recipient
        uint256 stbMetis_recieved = stbMETISToken.deposit(msg.value, recipient);
        require(stbMetis_recieved > 0, "No stbMetis was returned");

        return stbMetis_recieved;
    }

    /// @notice Mint bMETIS to the recipient using sender's funds. Internal portion
    function _submit(address recipient) internal nonReentrant {
        // Initial pause and value checks
        require(!submitPaused, "Submit is paused");
        require(msg.value != 0, "Cannot submit 0");

        // Give the sender bMETIS
        bETHToken.minter_mint(recipient, msg.value);
        // Track the amount of ETH that we are keeping
        uint256 withheld_amt = 0;
        if (withholdRatio != 0) {
            withheld_amt = (msg.value * withholdRatio) / RATIO_PRECISION;
            currentWithheldMETIS += withheld_amt;
        }

        emit MetisSubmitted(msg.sender, recipient, msg.value, withheld_amt);
    }

    /// @notice Mint bMETIS to the sender depending on the ETH value sent
    function submit() external payable {
        _submit(msg.sender);
    }

    /// @notice Mint bMETIS to the recipient using sender's funds
    function submitAndGive(address recipient) external payable {
        _submit(recipient);
    }

    /// @notice Fallback to minting bMETIS to the sender
    receive() external payable {
        _submit(msg.sender);
    }

    /// @notice Deposit batches of ETH to the ETH 2.0 deposit contract
    /// @dev Usually a bot will call this periodically
    /// @param max_deposits Used to prevent gassing out if a whale drops in a huge amount of ETH. Break it down into batches.
    function depositMetis(uint256 max_deposits) external nonReentrant {
        require(!depositMetisPaused, "Depositing METIS is paused");

        // See how many deposits can be made. Truncation desired.
        uint256 numDeposits = (address(this).balance - currentWithheldMETIS) /
            (DEPOSIT_SIZE + BRIDGE_FEE);
        require(numDeposits > 0, "Not enough ETH in contract");

        uint256 loopsToUse = numDeposits;
        if (max_deposits == 0) loopsToUse = numDeposits;
        else if (numDeposits > max_deposits) loopsToUse = max_deposits;

        // Give each deposit chunk to an empty validator
        for (uint256 i = 0; i < loopsToUse; ++i) {
            // Get validator information
            address validator = getNextValidator(); // Will revert if there are not enough free validators

            // Make sure the validator hasn't been deposited into already, to prevent stranding an extra 32 eth
            // until withdrawals are allowed
            require(
                !activeValidators[validator],
                "Validator already has 12000 METIS"
            );

            // TODO: where to send the METIS?
            // // bridge metis to layer 1 via L2BridgeContract
            // bridge.withdrawTo{value: BRIDGE_FEE}(
            //     DeployedContracts.METIS_TOKEN,
            //     validator,
            //     DEPOSIT_SIZE,
            //     0,
            //     ""
            // );

            // Set the validator as used so it won't get an extra 32 ETH
            activeValidators[validator] = true;

            emit DepositSent(validator);
        }
    }

    /// @param newRatio of ETH that is sent to deposit contract vs withheld, 1e6 precision
    /// @notice An input of 1e6 results in 100% of Eth deposited, 0% withheld
    function setWithholdRatio(uint256 newRatio) external onlyByOwnGov {
        require(newRatio <= RATIO_PRECISION, "Ratio cannot surpass 100%");
        withholdRatio = newRatio;
    }

    /// @notice Give the withheld ETH to the "to" address
    function moveWithheldMETIS(
        address payable to,
        uint256 amount
    ) external onlyByOwnGov {
        require(
            amount <= currentWithheldMETIS,
            "Not enough withheld ETH in contract"
        );
        currentWithheldMETIS -= amount;

        (bool success, ) = payable(to).call{value: amount}("");
        require(success, "Invalid transfer");

        emit WithheldMetisMoved(to, amount);
    }

    /// @notice Toggle allowing submites
    function togglePauseSubmits() external onlyByOwnGov {
        submitPaused = !submitPaused;

        emit SubmitPaused(submitPaused);
    }

    /// @notice Toggle allowing depositing ETH to validators
    function togglePauseDepositMetis() external onlyByOwnGov {
        depositMetisPaused = !depositMetisPaused;

        emit DepositMetisPaused(depositMetisPaused);
    }

    /// @notice For emergencies if something gets stuck
    function recoverMetis(uint256 amount) external onlyByOwnGov {
        (bool success, ) = address(owner).call{value: amount}("");
        require(success, "Invalid transfer");

        emit EmergencyMetisRecovered(amount);
    }

    /// @notice For emergencies if someone accidentally sent some ERC20 tokens here
    function recoverERC20(
        address tokenAddress,
        uint256 tokenAmount
    ) external onlyByOwnGov {
        require(
            IERC20(tokenAddress).transfer(owner, tokenAmount),
            "recoverERC20: Transfer failed"
        );

        emit EmergencyERC20Recovered(tokenAddress, tokenAmount);
    }

    event EmergencyMetisRecovered(uint256 amount);
    event EmergencyERC20Recovered(address tokenAddress, uint256 tokenAmount);
    event MetisSubmitted(
        address indexed sender,
        address indexed recipient,
        uint256 sent_amount,
        uint256 withheld_amt
    );
    event DepositMetisPaused(bool new_status);
    event DepositSent(address pubKey);
    event SubmitPaused(bool new_status);
    event WithheldMetisMoved(address indexed to, uint256 amount);
    event WithholdRatioSet(uint256 newRatio);
}
