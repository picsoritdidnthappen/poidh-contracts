use anchor_lang::prelude::*;

pub mod state;

declare_id!("HFD3185JaPEQRXAcCgiwJT6amphebDJJRsCQtwCQyovZ");

#[program]
pub mod poidh {
    use super::*;

    pub fn initialize(_ctx: Context<Initialize>) -> Result<()> {
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize {}
