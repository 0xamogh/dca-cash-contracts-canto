import { ethers } from "hardhat";
import { AUTOMATION } from "../test/constants";

async function main() {
  const DCA = await ethers.getContractFactory("DcaCashCanto");
  const dca = await DCA.deploy();
  console.log("DCA was deployed at", dca.address);
  console.log("TimedAllowance", await dca.timedAllowance());
  return { dca };
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
