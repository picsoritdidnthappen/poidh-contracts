import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';
import { Contract, ContractFactory } from 'ethers';
import { ethers } from 'hardhat';
import { expect } from 'chai';
import { compareBountyData, createSoloBounty, createOpenBounty } from './utils';
import * as testData from './test-data.json';

describe('PoidhV2', function () {
  let poidhV2: Contract;
  let poidhV2Factory: ContractFactory;
  let owner: SignerWithAddress;

  before(async function () {
    [owner] = await ethers.getSigners();

    poidhV2Factory = await ethers.getContractFactory('PoidhV2');
    poidhV2 = (await poidhV2Factory.deploy(
      owner.address,
      owner.address,
    )) as Contract;
  });

  describe('Deployment', function () {
    it('Sets the right owner', async function () {
      expect(await poidhV2.treasury()).to.equal(owner.address);
    });
  });
  describe('Creating Solo Bounties', function () {
    it('should revert if no ether is sent', async function () {
      await expect(
        createSoloBounty(poidhV2, 'Bounty', 'Description', '0'),
      ).to.be.revertedWithCustomError(poidhV2, 'NoEther()');
    });

    it('should allow creating an open bounty', async function () {
      const bounty = testData.bounties[0];

      await createSoloBounty(
        poidhV2,
        bounty.name,
        bounty.description,
        bounty.amount,
      );

      const bounties = await poidhV2.getBounties(0);
      compareBountyData(bounty, bounties[0]);
    });
  });
  describe('Creating Group Bounties', function () {
    it('should revert if no ether is sent', async function () {
      await expect(
        createOpenBounty(poidhV2, 'Bounty', 'Description', '0'),
      ).to.be.revertedWithCustomError(poidhV2, 'NoEther()');
    });

    it('should allow creating an open bounty', async function () {
      const bounty = testData.bounties[1];

      await createOpenBounty(
        poidhV2,
        bounty.name,
        bounty.description,
        bounty.amount,
      );

      const bounties = await poidhV2.getBounties(0);
      compareBountyData(bounty, bounties[1]);

      const bountyLength = await poidhV2.getBountiesLength();
      expect(bountyLength).to.equal(2);

      const participants = await poidhV2.participants(2, 0);
      expect(participants).to.equal(owner.address);

      const participantAmounts = await poidhV2.participantAmounts(2, 0);
      expect(participantAmounts).to.equal(ethers.parseEther(bounty.amount));
    });
  });
});
