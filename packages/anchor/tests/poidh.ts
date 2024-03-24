import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { Poidh } from "../../../target/types/poidh";
import { expect } from "chai";
import {
  createMint,
  createAssociatedTokenAccount,
  mintTo,
  getAccount,
  getAssociatedTokenAddressSync,
} from "@solana/spl-token";
import { Keypair } from "@solana/web3.js";

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

    const userTokenAccount = await createAssociatedTokenAccount(
      program.provider.connection,
      authority,
      mint,
      program.provider.publicKey
    );

    await mintTo(
      program.provider.connection,
      authority,
      mint,
      userTokenAccount,
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

    const id = Keypair.generate().publicKey;

    const bounty = anchor.web3.PublicKey.findProgramAddressSync(
      [Buffer.from("bounty"), authority.publicKey.toBytes(), id.toBytes()],
      program.programId
    )[0];

    const bountyAta = getAssociatedTokenAddressSync(mint, bounty, true);

    await program.methods
      .createBounty(createBountyParams)
      .accounts({
        authority: authority.publicKey,
        bounty: bounty,
        mint: id,
        paymentMint: mint,
        userTokenAccount,
        bountyAta,
        tokenProgram: anchor.utils.token.TOKEN_PROGRAM_ID,
        associatedTokenProgram: anchor.utils.token.ASSOCIATED_PROGRAM_ID,
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .rpc({ skipPreflight: true });

    const bountyAccount = await program.account.bounty.fetch(bounty);
    const bountyAtaAccount = await getAccount(
      program.provider.connection,
      bountyAta
    );

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
    expect(Number(bountyAtaAccount.amount.toString())).equal(
      createBountyParams.amount.toNumber()
    );

    // Check if the authority is added as a participant for an open bounty
    if (createBountyParams.bountyType === 1) {
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
