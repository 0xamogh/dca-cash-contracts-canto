import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";
import {
  DAY,
  NOTE_WHALE,
  inputTokenAddress,
  USDC_ADDRESS,
  outputTokenAddress,
  NOTE_ADDRESS,
  ETH_ADDRESS,
  WCANTO_ADDRESS,
  ATOM_ADDRESS,
} from "./constants";
import { BigNumber, Contract } from "ethers";
import { forkToCanto, forkToMatic } from "./utils";
import erc20Abi from "./abi/erc20.abi.json";

describe("DcaCashCanto", function () {
  async function deployDcaCash() {
    const DCA = await ethers.getContractFactory("DcaCashCanto");
    const dca = await DCA.deploy();
    return { dca };
  }

  describe("Deployment", function () {
    beforeEach(forkToCanto);

    it("Create task", async function () {
      this.timeout(100000000);
      let tx;

      let { dca } = await loadFixture(deployDcaCash);
      const timedAllowance = await dca.timedAllowance();
      const owner = await dca.owner();
      const whale = await ethers.getImpersonatedSigner(NOTE_WHALE);
      console.log(
        "🚀 ~ file: DcaCash.test.ts:33 ~ whale",
        await whale.getBalance()
      );

      const approveAmount = BigNumber.from("10000000000000000000");
      const inputAmount = BigNumber.from("10000000000000000000");
      console.log("🚀 ~ file: DcaCash.test.ts:35 ~ inputAmount", inputAmount);
      const inputTokenAddress = WCANTO_ADDRESS;
      const outputTokenAddress = USDC_ADDRESS;
      const inputTokenContract = new Contract(
        inputTokenAddress,
        erc20Abi,
        whale
      );

      console.log(
        "🚀 ~ file: DcaCash.test.ts:36 ~ timedAllowance",
        timedAllowance
      );
      // const prevBalance = await inputTokenContract.balanceOf(NOTE_WHALE);
      // console.log("inputTokenContract balance", prevBalance.toString());

      tx = await inputTokenContract.approve(timedAllowance, approveAmount);
      await tx.wait();
      tx = await inputTokenContract.approve(owner, approveAmount);
      await tx.wait();

      tx = await inputTokenContract.transfer(owner, inputAmount);
      await tx.wait();

      console.log(
        "inputTokenContract allowance",
        await inputTokenContract.allowance(NOTE_WHALE, timedAllowance),
        await inputTokenContract.balanceOf(owner)
      );

      console.log("Gas used :", tx.gasPrice.toString());

      dca = await dca.connect(whale);

      tx = await dca.createTask(
        inputTokenAddress,
        outputTokenAddress,
        inputAmount,
        DAY
      );
      const id = await tx.wait();

      //@ts-ignore
      console.log("🚀 ~ file: DcaCash.test.ts:41 ~ id", id.txHash);
      console.log("Gas used :", tx.gasPrice!.toString());
      let dedicatedSenderAddress = await dca.owner();
      console.log("dedicatedMsgSender is ", dedicatedSenderAddress);

      const dedicatedSender = await ethers.getImpersonatedSigner(owner);

      tx = await whale.sendTransaction({
        to: dedicatedSenderAddress,
        value: ethers.utils.parseEther("2"),
      });
      await tx.wait();
      console.log("Balance :", (await dedicatedSender.getBalance()).toString());

      dca = await dca.connect(dedicatedSender);

      const outputTokenContract = new Contract(
        outputTokenAddress,
        erc20Abi,
        dedicatedSender
      );
      console.log(
        "🚀 ~ file: DcaCash.test.ts:76 ~ whale.address",
        whale.address
      );
      console.log(await inputTokenContract.balanceOf(whale.address));
      const prevBalance = await outputTokenContract.balanceOf(whale.address);
      const prevOwnerBalance = await inputTokenContract.balanceOf(owner);

      tx = await dca.swapBatcher(
        [whale.address],
        [inputTokenAddress],
        [outputTokenAddress],
        [inputAmount],
        [DAY]
      );
      await tx.wait();

      console.log(
        "Output :",
        ethers.utils.formatEther(
          (await outputTokenContract.balanceOf(whale.address)).sub(prevBalance)
        )
      );
      console.log(
        "owner dev fee",
        ethers.utils.formatEther(
          (await inputTokenContract.balanceOf(owner)).sub(prevOwnerBalance)
        )
      );
      console.log("Gas used :", tx.gasPrice!.toString());

      console.log(
        ethers.utils.formatEther(
          await inputTokenContract.balanceOf(dca.address)
        )
      );
      // tx = await dca.payDevFee(
      //   inputTokenAddress,
      //   await inputTokenContract.balanceOf(dca.address)
      // );
      // await tx.wait();
      console.log(
        "owner dev fee",
        ethers.utils.formatEther(await inputTokenContract.balanceOf(owner))
      );
      // console.log("Gas used :", tx.gasPrice!.toString());
    });
  });
});
