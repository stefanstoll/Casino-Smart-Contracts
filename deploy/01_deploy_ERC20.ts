import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const deployment = await deploy("MockUSDT", {
    from: deployer,
    log: true,
  });

  await hre.run("verify:verify", {
    address: deployment.address,
    constructorArguments: []
  });
};

export default func;