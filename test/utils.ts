import { config, network } from "hardhat";

export const forkToMatic = async () => {
  const matic = config.networks.matic;
  console.log("### switch to forking matic ###");
  await network.provider.request({
    method: "hardhat_reset",
    params: [
      {
        forking: {
          jsonRpcUrl: matic.forking.url,
          blockNumber: matic.forking.blockNumber,
        },
      },
    ],
  });
};

export const forkToCanto = async () => {
  const canto = config.networks.canto;
  console.log("### switch to forking canto ###");
  await network.provider.request({
    method: "hardhat_reset",
    params: [
      {
        forking: {
          jsonRpcUrl: canto.forking.url,
          blockNumber: canto.forking.blockNumber,
        },
      },
    ],
  });
};
