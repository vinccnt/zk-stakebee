import {deployContract, getWallet} from "./utils";
import {saveObjectToFile, loadObjectFromFile} from "./handleDeployments";

interface DeployConfig {
    address: string;
    reDeploy: boolean;
}

interface IDeployments {
    timelock: DeployConfig;
    bETH: DeployConfig;
    ztbETH: DeployConfig;
    minter: DeployConfig;
    referral: DeployConfig;
}

const defaultDeployments: IDeployments = {
    timelock: {address: "0x0", reDeploy: true},
    bETH: {address: "0x0", reDeploy: true},
    ztbETH: {address: "0x0", reDeploy: true},
    minter: {address: "0x0", reDeploy: true},
    referral: {address: "0x0", reDeploy: true},
};

// An example of a basic deploy script
// It will deploy a Greeter contract to selected network
// as well as verify it on Block Explorer if possible for the network
export default async function () {
    const deployedContracts = loadObjectFromFile("deploy/deployments.json", defaultDeployments);
    console.log(deployedContracts);
    const admin_wallet = await getWallet().getAddress();
    console.log(`Deploying by ${admin_wallet}...`);

    try {
        let contractArtifactName = "Timelock";
        let constructorArguments = [admin_wallet, 60 * 60 * 24 * 2];

        if (deployedContracts.timelock.reDeploy) {
            const timelock = await deployContract(contractArtifactName, constructorArguments);
            deployedContracts.timelock.address = await timelock.getAddress();
        }

        contractArtifactName = "bETH";
        constructorArguments = [admin_wallet, deployedContracts.timelock.address];
        if (deployedContracts.bETH.reDeploy) {
            const bEth = await deployContract(contractArtifactName, constructorArguments);
            deployedContracts.bETH.address = await bEth.getAddress();
        }

        contractArtifactName = "ztbETH";
        constructorArguments = [deployedContracts.bETH.address, 60 * 60 * 24 * 7];
        if (deployedContracts.ztbETH.reDeploy) {
            const ztbEth = await deployContract(contractArtifactName, constructorArguments);
            deployedContracts.ztbETH.address = await ztbEth.getAddress();
        }

        contractArtifactName = "bEthMinter";
        constructorArguments = [
            deployedContracts.bETH.address,
            deployedContracts.ztbETH.address,
            admin_wallet,
            deployedContracts.timelock.address
        ];
        if (deployedContracts.minter.reDeploy) {
            const minter = await deployContract(contractArtifactName, constructorArguments);
            deployedContracts.minter.address = await minter.getAddress();
        }

        contractArtifactName = "ReferralStorage";
        if (deployedContracts.referral.reDeploy) {
            const referralStorage = await deployContract(contractArtifactName);
            deployedContracts.referral.address = await referralStorage.getAddress();
        }

    } catch (err) {
        console.error(err);
    } finally {
        saveObjectToFile("deploy/deployments.json", deployedContracts);
    }
}
