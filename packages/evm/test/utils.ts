import { expect } from 'chai';
import { Contract } from 'ethers';
import { ethers } from 'hardhat';

type Bounty = {
  name: string;
  description: string;
  amount: string;
};

export const compareBountyData = (testBounty: Bounty, evmBounty: Bounty) => {
  const evmBountyAmount = Number(ethers.formatEther(evmBounty.amount)).toFixed(
    0,
  );
  expect(testBounty.name).to.equal(evmBounty.name);
  expect(testBounty.description).to.equal(evmBounty.description);
  expect(testBounty.amount).to.equal(evmBountyAmount);
};

export const createSoloBounty = async (
  poidhV2: Contract,
  name: string,
  description: string,
  amount: string,
) => {
  await expect(
    poidhV2.createSoloBounty(name, description, {
      value: ethers.parseEther(amount),
    }),
  ).to.emit(poidhV2, 'BountyCreated');
};

export const createOpenBounty = async (
  poidhV2: Contract,
  name: string,
  description: string,
  amount: string,
) => {
  await expect(
    poidhV2.createOpenBounty(name, description, {
      value: ethers.parseEther(amount),
    }),
  ).to.emit(poidhV2, 'BountyCreated');
};
