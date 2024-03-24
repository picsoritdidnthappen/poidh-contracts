import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { Poidh } from "../../../target/types/poidh";
import { expect } from "chai";
import {
  createMint,
  createAssociatedTokenAccount,
  mintTo,
} from "@solana/spl-token";

describe("poidh", () => {
  anchor.setProvider(anchor.AnchorProvider.env());
  const program = anchor.workspace.Poidh as Program<Poidh>;
  const authority = (
    (program.provider as anchor.AnchorProvider).wallet as anchor.Wallet
  ).payer;

  it("Creates a bounty", async () => {
    const mint = await createMint(
      program.provider.connection,
      authority,
      program.provider.publicKey,
      null,
      9
    );

    const tokenAccount = await createAssociatedTokenAccount(
      program.provider.connection,
      authority,
      mint,
      program.provider.publicKey
    );

    await mintTo(
      program.provider.connection,
      authority,
      mint,
      tokenAccount,
      program.provider.publicKey,
      1_000_000_000
    );

    const bountyKeypair = anchor.web3.Keypair.generate();
    const bountyPublicKey = bountyKeypair.publicKey;

    const createBountyParams = {
      name: "Test Bounty",
      description: "This is a test bounty",
      amount: new anchor.BN(1_000_000),
      bountyType: 0,
      voteType: 0,
    };

    await program.methods
      .createBounty(createBountyParams)
      .accounts({
        authority: program.provider.publicKey,
        bounty: bountyPublicKey,
        mint: mint,
        tokenAccount: tokenAccount,
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .signers([bountyKeypair])
      .rpc();

    const bountyAccount = await program.account.bounty.fetch(bountyPublicKey);

    expect(bountyAccount.authority.toString()).equal(
      program.provider.publicKey.toString()
    );
    expect(bountyAccount.name).equal(createBountyParams.name);
    expect(bountyAccount.description).equal(createBountyParams.description);
    expect(bountyAccount.amount.toNumber()).equal(
      createBountyParams.amount.toNumber()
    );
    expect(bountyAccount.bountyType).equal(createBountyParams.bountyType);
    expect(bountyAccount.voteType).equal(createBountyParams.voteType);

    // Check if the authority is added as a participant for an open bounty
    if (createBountyParams.bountyType === 1) {
      console.log("here");
      expect(bountyAccount.participants.length).equal(1);
      expect(bountyAccount.participants[0].address.toString()).equal(
        program.provider.publicKey.toString()
      );
      expect(bountyAccount.participants[0].amount.toNumber()).equal(
        createBountyParams.amount.toNumber()
      );
    } else {
      expect(bountyAccount.participants.length).equal(0);
    }
  });
});
