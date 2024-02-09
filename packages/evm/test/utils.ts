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

export const cancelSoloBounty = async (poidhV2: Contract, bountyId: string) => {
  await expect(poidhV2.cancelSoloBounty(bountyId)).to.emit(
    poidhV2,
    'BountyCancelled',
  );
};

export const cancelOpenBounty = async (poidhV2: Contract, bountyId: string) => {
  await expect(poidhV2.cancelOpenBounty(bountyId)).to.emit(
    poidhV2,
    'BountyCancelled',
  );
};

export const joinOpenBounty = async (
  poidhV2: Contract,
  bountyId: string,
  amount: string,
) => {
  await expect(
    poidhV2.joinOpenBounty(bountyId, {
      value: ethers.parseEther(amount),
    }),
  ).to.emit(poidhV2, 'BountyJoined');
};

export const createClaim = async (
  poidhV2: Contract,
  bountyId: string,
  name: string,
  uri: string,
  description: string,
) => {
  await expect(poidhV2.createClaim(bountyId, name, uri, description)).to.emit(
    poidhV2,
    'ClaimCreated',
  );
};

export const submitClaimForVote = async (
  poidhV2: Contract,
  bountyId: string,
  claimId: string,
) => {
  await expect(poidhV2.submitClaimForVote(bountyId, claimId)).to.emit(
    poidhV2,
    'ClaimSubmittedForVote',
  );
};

export const voteClaim = async (
  poidhV2: Contract,
  bountyId: string,
  vote: boolean,
) => {
  await expect(poidhV2.voteClaim(bountyId, vote)).to.emit(poidhV2, 'VoteClaim');
};

export const resetVotingPeriod = async (
  poidhV2: Contract,
  bountyId: string,
) => {
  await expect(poidhV2.resetVotingPeriod(bountyId)).to.emit(
    poidhV2,
    'VotingPeriodReset',
  );
};

export const withdrawFromOpenBounty = async (
  poidhV2: Contract,
  bountyId: string,
) => {
  await expect(poidhV2.withdrawFromOpenBounty(bountyId)).to.emit(
    poidhV2,
    'WithdrawFromOpenBounty',
  );
};

export const acceptClaim = async (
  poidhV2: Contract,
  bountyId: string,
  claimId: string,
) => {
  await expect(poidhV2.acceptClaim(bountyId, claimId)).to.emit(
    poidhV2,
    'ClaimAccepted',
  );
};
