import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';
import { Contract, ContractFactory } from 'ethers';
import { ethers } from 'hardhat';
import { expect } from 'chai';
import {
  compareBountyData,
  createSoloBounty,
  createOpenBounty,
  cancelSoloBounty,
  joinOpenBounty,
  withdrawFromOpenBounty,
  createClaim,
} from './utils';
import * as testData from './test-data.json';

describe('PoidhV2', function () {
  let poidhV2: Contract;
  let poidhV2Factory: ContractFactory;
  let poidhV2Nft: Contract;
  let poidhV2NftFactory: ContractFactory;
  let owner: SignerWithAddress;
  let alice: SignerWithAddress;

  before(async function () {
    [owner, alice] = await ethers.getSigners();

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
      0,
    )) as Contract;

    await poidhV2Nft.setPoidhContract(await poidhV2.getAddress(), true);
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

      const participants = await poidhV2.participants(1, 0);
      expect(participants).to.equal(owner.address);

      const participantAmounts = await poidhV2.participantAmounts(1, 0);
      expect(participantAmounts).to.equal(ethers.parseEther(bounty.amount));
    });
  });
  describe('Canceling Solo Bounties', function () {
    it('should revert if the bounty does not exist', async function () {
      await expect(
        cancelSoloBounty(poidhV2, '10'),
      ).to.be.revertedWithCustomError(poidhV2, 'BountyNotFound()');
    });

    it('should revert if wrong caller', async function () {
      const poidhV2AsAlice = poidhV2.connect(alice) as Contract;
      await expect(
        cancelSoloBounty(poidhV2AsAlice, '1'),
      ).to.be.revertedWithCustomError(poidhV2, 'WrongCaller()');
    });

    it('should revert if cancel function for solo bounties called on an open bounty', async function () {
      await expect(
        cancelSoloBounty(poidhV2, '1'),
      ).to.be.revertedWithCustomError(poidhV2, 'NotSoloBounty()');
    });

    it('should allow canceling a bounty', async function () {
      const balanceBefore = await ethers.provider.getBalance(owner.address);
      await cancelSoloBounty(poidhV2, '0');
      const balanceAfter = await ethers.provider.getBalance(owner.address);
      expect(balanceAfter - balanceBefore).to.be.approximately(
        ethers.parseEther('1'),
        ethers.parseEther('0.1'),
      );
    });

    it('should revert if the bounty is already canceled', async function () {
      await expect(
        cancelSoloBounty(poidhV2, '0'),
      ).to.be.revertedWithCustomError(poidhV2, 'BountyClosed()');
    });
  });

  describe('Join Open Bounties', function () {
    it('should revert if the bounty does not exist', async function () {
      await expect(poidhV2.joinOpenBounty('10')).to.be.revertedWithCustomError(
        poidhV2,
        'BountyNotFound()',
      );
    });

    it('should revert if no ether is sent', async function () {
      await expect(poidhV2.joinOpenBounty('1')).to.be.revertedWithCustomError(
        poidhV2,
        'NoEther()',
      );
    });

    it('should revert if the bounty is a solo bounty', async function () {
      await createSoloBounty(poidhV2, 'Bounty', 'Description', '1');
      await expect(
        poidhV2.joinOpenBounty('2', { value: ethers.parseEther('1') }),
      ).to.be.revertedWithCustomError(poidhV2, 'NotOpenBounty()');
    });

    it('should revert if user already joined, or is issuer', async function () {
      await expect(
        poidhV2.joinOpenBounty('1', { value: ethers.parseEther('1') }),
      ).to.be.revertedWithCustomError(poidhV2, 'WrongCaller()');
    });

    it('should allow joining a bounty', async function () {
      const balanceBefore = await ethers.provider.getBalance(alice.address);
      await joinOpenBounty(poidhV2.connect(alice) as Contract, '1', '1');
      const balanceAfter = await ethers.provider.getBalance(alice.address);
      expect(balanceBefore - balanceAfter).to.be.approximately(
        ethers.parseEther('1'),
        ethers.parseEther('0.1'),
      );
    });
    it('should allow the issuer to accept a claim if there is only one active participant', async function () {
      await createOpenBounty(poidhV2, 'Open Bounty', 'Description', '1');

      const bountyLength = await poidhV2.getBountiesLength();
      expect(bountyLength).to.equal(4);

      await joinOpenBounty(poidhV2.connect(alice) as Contract, '3', '1');

      await withdrawFromOpenBounty(poidhV2.connect(alice) as Contract, '3');

      await createClaim(
        poidhV2.connect(alice) as Contract,
        '3',
        'Claim',
        'Description',
        'lololol',
      );

      await poidhV2.acceptClaim('3', '0');
    });
  });
});
