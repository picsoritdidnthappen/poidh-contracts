#![allow(clippy::too_many_arguments)]
#![allow(clippy::new_ret_no_self)]
use anchor_lang::prelude::*;

pub mod instructions;
pub mod state;

use instructions::*;
use state::*;

declare_id!("HFD3185JaPEQRXAcCgiwJT6amphebDJJRsCQtwCQyovZ");

#[program]
pub mod poidh {
    use super::*;

    pub fn create_bounty(ctx: Context<CreateBounty>, args: CreateBountyParams) -> Result<()> {
        instructions::create_bounty(ctx, args)
    }

    pub fn close_bounty(ctx: Context<CloseBounty>) -> Result<()> {
        instructions::close_bounty(ctx)
    }
}
