import { utils, Wallet } from "zksync-ethers";
import { getWallet, getProvider } from "./utils";
import * as ethers from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";

// Put the address of the bEth Minter here
const bETHMinter = "0x2cABA947FB69fFfE6c4404682CB0512A94D22318";

// Put the address of the bEth Minter here
const bEth = "0x8Ca4a1c501A5d319d30a80a2aDf2226fd4f9A6A8";

// Put the address of the deployed paymaster here
const PAYMASTER_ADDRESS = "0xBce46B6E14679529881Af851dDEa6B9ba4fDD624";

// Put the address of the USDC token here:
const TOKEN_ADDRESS = "0xcE4b9A2e9dD0635c5980e1fa91e4057795e60f04";

function getToken(hre: HardhatRuntimeEnvironment, wallet: Wallet) {
  const artifact = hre.artifacts.readArtifactSync("MockUSDC");
  return new ethers.Contract(TOKEN_ADDRESS, artifact.abi, wallet);
}

function getMinter(hre: HardhatRuntimeEnvironment, wallet: Wallet) {
  const artifact = hre.artifacts.readArtifactSync("bEthMinter");
  return new ethers.Contract(bETHMinter, artifact.abi, wallet);
}

export default async function (hre: HardhatRuntimeEnvironment) {
  const provider = getProvider();
  const wallet = getWallet();

  console.log(
    `USDC token balance of the wallet before mint: ${await wallet.getBalance(
      TOKEN_ADDRESS
    )}`
  );

  let paymasterBalance = await provider.getBalance(PAYMASTER_ADDRESS);
  console.log(`Paymaster ETH balance is ${paymasterBalance.toString()}`);

  const usdc = getToken(hre, wallet);
  const bEthMinter = getMinter(hre, wallet);
  const gasPrice = await provider.getGasPrice();

  // Encoding the "ApprovalBased" paymaster flow's input
  const paymasterParams = utils.getPaymasterParams(PAYMASTER_ADDRESS, {
    type: "ApprovalBased",
    token: TOKEN_ADDRESS,
    minimalAllowance: BigInt("1"),
    innerInput: new Uint8Array(),
  });


  // Estimate gas fee for submit transaction
  const gasLimit = await bEthMinter.submit.estimateGas({
    value: 1000,
    customData: {
      gasPerPubdata: utils.DEFAULT_GAS_PER_PUBDATA_LIMIT,
      paymasterParams: paymasterParams,
    },
  });

  const fee = gasPrice * gasLimit;
  console.log("Transaction fee estimation is :>> ", fee.toString());

  console.log(`Deposit ETH to bEthMinter via paymaster...`);
  await (
    await bEthMinter.submit({
      // paymaster info
      value: 1000,
      customData: {
        paymasterParams: paymasterParams,
        gasPerPubdata: utils.DEFAULT_GAS_PER_PUBDATA_LIMIT,
      },
    })
  ).wait();

  console.log(
    `Paymaster USDC token balance is now ${await usdc.balanceOf(
      PAYMASTER_ADDRESS
    )}`
  );
  paymasterBalance = await provider.getBalance(PAYMASTER_ADDRESS);

  console.log(`Paymaster ETH balance is now ${paymasterBalance.toString()}`);
  console.log(
    `bETH balance of the the wallet after submit: ${await wallet.getBalance(
      bEth
    )}`
  );
}
