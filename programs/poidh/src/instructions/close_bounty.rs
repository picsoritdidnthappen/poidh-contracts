use crate::state::Bounty;
use anchor_lang::prelude::*;
use anchor_spl::token::{self, Token, TokenAccount, Transfer};

#[derive(Accounts)]
pub struct CloseBounty<'info> {
    #[account(
        mut,
        address = bounty.authority,
    )]
    pub authority: Signer<'info>,
    #[account(
        mut,
        seeds = [b"bounty", authority.key().as_ref(), bounty.mint.as_ref()],
        bump = bounty.bump[0],
        has_one = authority,
        close = authority,
    )]
    pub bounty: Account<'info, Bounty>,
    #[account(mut, associated_token::mint = bounty.payment_mint, associated_token::authority = authority)]
    pub authority_ata: Account<'info, TokenAccount>,
    #[account(mut, associated_token::mint = bounty.payment_mint, associated_token::authority = bounty)]
    pub bounty_ata: Account<'info, TokenAccount>,
    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
}

impl<'info> CloseBounty<'info> {
    pub fn transfer_ctx(
        &self,
        to: AccountInfo<'info>,
    ) -> CpiContext<'_, '_, '_, 'info, Transfer<'info>> {
        let program = self.token_program.to_account_info();
        let accounts = Transfer {
            authority: self.bounty.to_account_info(),
            from: self.bounty_ata.to_account_info(),
            to,
        };
        CpiContext::new(program, accounts)
    }
}

pub fn close_bounty(ctx: Context<CloseBounty>) -> Result<()> {
    let bounty = &ctx.accounts.bounty;
    match bounty.bounty_type {
        0 => {
            let authority_ata = ctx.accounts.authority_ata.to_account_info();
            let seeds = &[&bounty.as_seeds()[..]];
            token::transfer(
                ctx.accounts.transfer_ctx(authority_ata).with_signer(seeds),
                bounty.amount,
            )?;
        }
        1 => {
            bounty.validate_participants_empty()?;
        }
        _ => panic!("Invalid bounty type"),
    }

    Ok(())
}
