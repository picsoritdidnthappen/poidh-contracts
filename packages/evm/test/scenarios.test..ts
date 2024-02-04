// open bounty with x participants
import {
  createClaim,
  createOpenBounty,
  joinOpenBounty,
  submitClaimForVote,
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

interface ViewBounty {
  id: bigint;
  issuer: string;
  name: string;
  description: string;
  amount: bigint;
  claimer: string;
  createdAt: bigint;
  claimId: bigint;
  participants: string[];
  participantAmounts: { [key: string]: bigint };
  yesVotes: bigint;
  noVotes: bigint;
  deadline: bigint;
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
      if (index === 0) return;
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
      if (index === 0) return;
      if (index > 5) return;
      await joinOpenBounty(
        poidhV2.connect(signer) as Contract,
        '0',
        bounty.participants![index - 1].amount,
      );
    });

    await wait(1000);

    const b: ViewBounty = await poidhV2
      .getBounties(0)
      .then((b: ViewBounty[]) =>
        b.filter((x: ViewBounty) => x.issuer !== ethers.ZeroAddress),
      )
      .then((x: ViewBounty[]) => x[0]);
    expect(b.participants.length).to.equal(6);
    expect(b.participantAmounts.length).to.equal(6);

    bounty.participants!.forEach((p, i) => {
      expect(b.participants).to.include(p.address);
      expect(b.participantAmounts[i]).to.equal(ethers.parseEther(p.amount));
    });

    await submitClaimForVote(poidhV2, '0', '1');

    const bountyAfterSubmitClaim = await poidhV2
      .getBounties(0)
      .then((b: ViewBounty[]) =>
        b.filter((x: ViewBounty) => x.issuer !== ethers.ZeroAddress),
      )
      .then((x: ViewBounty[]) => x[0]);

    const timestamp = await time.latest();
    const twoDaysInSeconds = 172800;

    expect(bountyAfterSubmitClaim.deadline).to.be.closeTo(
      timestamp + twoDaysInSeconds,
      100,
    );
    expect(bountyAfterSubmitClaim.yesVotes).to.equal(ethers.parseEther('1'));
  });
});
