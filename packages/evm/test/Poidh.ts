import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { Contract, ContractFactory } from "ethers";
import { ethers } from "hardhat";
import { expect } from "chai";

describe("PoidhV2", function () {

  let poidhV2: Contract;
  let poidhV2Factory: ContractFactory;

  let owner: SignerWithAddress;

  beforeEach(async function () {

    [owner] = await ethers.getSigners();

    poidhV2Factory = await ethers.getContractFactory("PoidhV2");
    poidhV2 = await poidhV2Factory.deploy(
      owner.address,
      1000 // fee numerator
    ) as Contract;

  });

  describe("Deployment", function () {

    it("Sets the right owner", async function() {
      expect(await poidhV2.treasury()).to.equal(owner.address);
    });

  });
});
