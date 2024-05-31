import { deployContract, getWallet, getProvider } from "./utils";
import * as ethers from "ethers";

export default async function () {
  const usdc = await deployContract("MockUSDC", ["USDC", "USDC", 18]);
  const usdcAddress = await usdc.getAddress();

  const paymaster = await deployContract("UsdcPaymaster", [usdcAddress]);

  const paymasterAddress = await paymaster.getAddress();

  // Supplying paymaster with ETH
  console.log("Funding paymaster with ETH...");
  const wallet = getWallet();
  await (
    await wallet.sendTransaction({
      to: paymasterAddress,
      value: ethers.parseEther("0.06"),
    })
  ).wait();

  const provider = getProvider();
  const paymasterBalance = await provider.getBalance(paymasterAddress);
  console.log(`Paymaster ETH balance is now ${paymasterBalance.toString()}`);

  // Supplying the ERC20 tokens to the wallet:
  // We will give the wallet 3 units of the token:
  await (await usdc.mint(wallet.address, 3)).wait();

  console.log("Minted 3 usdc for the wallet");
  console.log(`Done!`);
}
