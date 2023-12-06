use anchor_lang::prelude::*;

declare_id!("HFD3185JaPEQRXAcCgiwJT6amphebDJJRsCQtwCQyovZ");

#[program]
pub mod poidh {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize {}
