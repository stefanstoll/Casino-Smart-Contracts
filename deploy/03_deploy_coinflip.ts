import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, get } = deployments;
  const { deployer } = await getNamedAccounts();
  
  const supraRouterAddress = "0xe0c0c4b7fe7d07fcde1a4f0959006a71c0ebe787";

  const CasinoBase = await get("CasinoBase");

  const deployment = await deploy("CoinFlip", {
    from: deployer,
    args: [
      CasinoBase.address, 
      supraRouterAddress, 
      deployer
    ],
    log: true,
  });

  await hre.run("verify:verify", {
    address: deployment.address,
    constructorArguments: [
      CasinoBase.address, 
      supraRouterAddress, 
      deployer
    ]
  });
};

export default func;
func.tags = ["CoinFlip"];
func.dependencies = ["CasinoBase"];