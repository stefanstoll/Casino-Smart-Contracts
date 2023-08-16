import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, get } = deployments;
  const { deployer } = await getNamedAccounts();

  const usdtToken = await get("MockUSDT");
  console.log("MUSDT", usdtToken.address)

  const deployment = await deploy("CasinoBase", {
    from: deployer,
    args: [usdtToken.address],
    log: true,
  });

  await hre.run("verify:verify", {
    address: deployment.address,
    constructorArguments: [usdtToken.address]
  });
};

export default func;