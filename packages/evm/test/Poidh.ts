/* eslint-disable @typescript-eslint/no-explicit-any */
import { ethers } from "hardhat";
import { expect } from "chai";

describe("PoidhV2", function () {

  let poidhV2: any;
  let owner: any;


  beforeEach(async function () {

    [owner] = await ethers.getSigners();

    poidhV2 = await ethers.getContractFactory("PoidhV2");
    poidhV2 = await poidhV2.deploy(
      owner.address, 
      1000 // fee numerator
    );

  });

  describe("Deployment", function () {
    it("Sets the right owner", async function() {
      expect(await poidhV2.treasury()).to.equal(owner.address);
    });
  });
});
