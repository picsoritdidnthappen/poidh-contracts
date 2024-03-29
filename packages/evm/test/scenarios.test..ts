// open bounty with x participants
import {
  cancelOpenBounty,
  createClaim,
  createOpenBounty,
  joinOpenBounty,
  submitClaimForVote,
  voteClaim,
  withdrawFromOpenBounty,
} from './utils';
import * as testData from './test-data.json';
import { Contract, ContractFactory } from 'ethers';
import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';
import { time } from '@nomicfoundation/hardhat-network-helpers';

import { ethers } from 'hardhat';
import { expect } from 'chai';

async function wait(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

interface Bounty {
  id: bigint;
  issuer: string;
  name: string;
  description: string;
  amount: bigint;
  claimer: string;
  createdAt: bigint;
  claimId: bigint;
}

interface Claim {
  id: number;
  issuer: string;
  bountyId: number;
  bountyIssuer: string;
  name: string;
  description: string;
  createdAt: number;
  accepted: boolean;
}

describe('Open Bounty Simulation', function () {
  let poidhV2: Contract;
  let poidhV2Nft: Contract;
  let poidhV2Factory: ContractFactory;
  let poidhV2NftFactory: ContractFactory;
  let owner: SignerWithAddress;

  before(async function () {
    [owner] = await ethers.getSigners();

    // create nft contract
    poidhV2NftFactory = await ethers.getContractFactory('PoidhV2Nft');
    poidhV2Nft = (await poidhV2NftFactory.deploy(
      owner.address,
      owner.address,
      '500',
    )) as Contract;

    poidhV2Factory = await ethers.getContractFactory('PoidhV2');
    poidhV2 = (await poidhV2Factory.deploy(
      await poidhV2Nft.getAddress(),
      owner.address,
    )) as Contract;

    await poidhV2Nft.setPoidhV2(await poidhV2.getAddress());
  });

  it('Simulates a Voting Cycle', async function () {
    const bounty = testData.bounties[0];
    const claims = testData.bounties[0].claims;
    if (!claims) throw new Error('No claims found in test data');

    await createOpenBounty(
      poidhV2,
      bounty.name,
      bounty.description,
      bounty.amount,
    );

    const signers = await ethers.getSigners();

    await signers.forEach(async (signer, index) => {
      if (index === 0 || index > 5) return;
      const claim = claims[index - 1];

      await createClaim(
        poidhV2.connect(signer) as Contract,
        '0',
        claim.name,
        claim.description,
        claim.uri,
      );
    });

    await wait(1000);

    const claimCounter = await poidhV2.claimCounter();
    expect(claimCounter).to.equal(3);

    await signers.forEach(async (signer, index) => {
      if (index === 0 || index > 5) return;
      await joinOpenBounty(
        poidhV2.connect(signer) as Contract,
        '0',
        bounty.participants![index - 1].amount,
      );
    });

    await wait(1000);

    const payload = await poidhV2.getParticipants(0);
    const participants: string[] = payload[0];
    const participantAmounts: bigint[] = payload[1];
    expect(participants.length).to.equal(6);
    expect(participantAmounts.length).to.equal(6);

    await submitClaimForVote(poidhV2, '0', '1');

    const bountyAfterSubmitClaim = await poidhV2.bountyVotingTracker(0);

    const timestamp = await time.latest();
    const twoDaysInSeconds = 172800;

    expect(bountyAfterSubmitClaim[2]).to.be.closeTo(
      timestamp + twoDaysInSeconds,
      100,
    );
    expect(bountyAfterSubmitClaim[0]).to.equal(ethers.parseEther('1'));

    // 2 votes, 1 yes, 1 no
    await voteClaim(poidhV2.connect(signers[1]) as Contract, '0', false);

    await wait(1000);

    await voteClaim(poidhV2.connect(signers[2]) as Contract, '0', true);

    await wait(1000);

    const bountyAfterVotes = await poidhV2
      .getBounties(0)
      .then((b: Bounty[]) =>
        b.filter((x: Bounty) => x.issuer !== ethers.ZeroAddress),
      )
      .then((x: Bounty[]) => x[0]);

    expect(bountyAfterVotes.claimer).to.equal(signers[2].address);
    expect(bountyAfterVotes.claimId).to.equal(1);

    const c: Claim[] = await poidhV2.getClaimsByBountyId(0);
    expect(c[1].accepted).to.equal(true);

    const balance = await poidhV2Nft.balanceOf(signers[0].address);
    expect(balance).to.equal(1);
  });
  it('Can withdraw from a public bounty', async function () {
    const bounty = testData.bounties[1];
    const claims = testData.bounties[1].claims;
    if (!claims) throw new Error('No claims found in test data');

    await createOpenBounty(
      poidhV2,
      bounty.name,
      bounty.description,
      bounty.amount,
    );

    const bountiesLength = await poidhV2.getBountiesLength();
    expect(bountiesLength).to.equal(2);

    const signers = await ethers.getSigners();

    await signers.forEach(async (signer, index) => {
      if (index === 0 || index > 5) return;
      await joinOpenBounty(
        poidhV2.connect(signer) as Contract,
        '1',
        bounty.participants![index - 1].amount,
      );
    });

    await wait(1000);

    const payload = await poidhV2.getParticipants(1);
    const participants: string[] = payload[0];
    const participantAmounts: bigint[] = payload[1];

    expect(participants.length).to.equal(6);
    expect(participantAmounts.length).to.equal(6);

    await withdrawFromOpenBounty(poidhV2.connect(signers[2]) as Contract, '1');

    await wait(1000);

    const payloadAfter = await poidhV2.getParticipants(1);

    expect(payloadAfter[0]).to.include(ethers.ZeroAddress);
  });
  it('Can cancel an open bounty and refund participants', async function () {
    const signers = await ethers.getSigners();

    await cancelOpenBounty(poidhV2, '1');

    const bAfterCancel = await poidhV2
      .getBounties(1)
      .then((b: Bounty[]) =>
        b.filter((x: Bounty) => x.issuer !== ethers.ZeroAddress),
      )
      .then((x: Bounty[]) => x[0]);

    expect(bAfterCancel.claimer).to.equal(signers[0].address);
  });
});
