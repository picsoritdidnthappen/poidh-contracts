use crate::state::{Bounty, CreateBountyParams};
use anchor_lang::prelude::*;
use anchor_spl::associated_token::AssociatedToken;
use anchor_spl::{
    token,
    token::{Mint, Token, TokenAccount, Transfer},
};

#[derive(Accounts)]
pub struct CreateBounty<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,
    #[account(
        init,
        payer = authority,
        space = Bounty::SIZE,
        seeds = [b"bounty", authority.key().as_ref(), mint.key().as_ref()],
        bump,
    )]
    pub bounty: Account<'info, Bounty>,
    /// CHECK: just serves as an identifier for the bounty
    pub mint: AccountInfo<'info>,
    pub payment_mint: Account<'info, Mint>,
    #[account(
        mut,
        associated_token::mint = payment_mint,
        associated_token::authority = authority,
    )]
    pub user_token_account: Account<'info, TokenAccount>,
    #[account(
        init,
        payer = authority,
        associated_token::mint = payment_mint,
        associated_token::authority = bounty,
    )]
    pub bounty_ata: Box<Account<'info, TokenAccount>>,
    pub token_program: Program<'info, Token>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub system_program: Program<'info, System>,
}

impl<'info> CreateBounty<'info> {
    pub fn transfer_ctx(&self) -> CpiContext<'_, '_, '_, 'info, Transfer<'info>> {
        let program = self.token_program.to_account_info();
        let accounts = Transfer {
            authority: self.authority.to_account_info(),
            from: self.user_token_account.to_account_info(),
            to: self.bounty_ata.to_account_info(),
        };
        CpiContext::new(program, accounts)
    }
}

pub fn create_bounty(ctx: Context<CreateBounty>, args: CreateBountyParams) -> Result<()> {
    let bounty = &ctx.accounts.bounty;
    let mint = &ctx.accounts.mint;
    let payment_mint = &ctx.accounts.payment_mint;

    let CreateBountyParams {
        name,
        description,
        amount,
        bounty_type,
        vote_type,
    } = args;

    bounty.validate_bounty_type(bounty_type);
    bounty.validate_vote_type(vote_type);

    let created_at = Clock::get()?.unix_timestamp;

    token::transfer(ctx.accounts.transfer_ctx(), amount)?;

    let bounty = &mut ctx.accounts.bounty;

    **bounty = Bounty::new(
        ctx.accounts.authority.key(),
        mint.key(),
        payment_mint.key(),
        name,
        description,
        amount,
        created_at,
        bounty_type,
        vote_type,
    );

    Ok(())
}
