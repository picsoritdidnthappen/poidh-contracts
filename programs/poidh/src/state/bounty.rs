use anchor_lang::prelude::*;

const MAX_NAME_LENGTH: usize = 20;
const MAX_DESCRIPTION_LENGTH: usize = 200;
const MAX_PARTICPANTS: usize = 10;

#[derive(AnchorDeserialize, AnchorSerialize, Clone)]
pub struct Votes {
    pub yes: u64,
    pub no: u64,
    pub deadline: i64,
}

#[derive(AnchorDeserialize, AnchorSerialize, Clone)]
pub struct Participant {
    pub address: Pubkey,
    pub amount: u64,
}

impl Votes {
    pub const SIZE: usize = 8 + // yes
        8 + // no
        8; // deadline
}

impl Participant {
    pub const SIZE: usize = 32 + // address
        8; // amount
}

#[account]
pub struct Bounty {
    pub id: u64,
    pub issuer: Pubkey,
    pub name: String,
    pub description: String,
    pub amount: u64,
    pub claimer: Pubkey,
    pub created_at: i64,
    pub claim_id: u64,
    pub votes: Votes,
    pub participants: Vec<Participant>,
}

impl Bounty {
    pub const SIZE: usize = 8 + // id
        32 + // issuer
        4 + MAX_NAME_LENGTH + // name (string prefix + max length)
        4 + MAX_DESCRIPTION_LENGTH + // description (string prefix + max length)
        8 + // amount
        32 + // claimer
        8 + // created_at
        8 + // claim_id
        Votes::SIZE + // votes
        4 + (Participant::SIZE * MAX_PARTICPANTS); // participants (vec prefix + max 10 participants)

    pub fn new(
        id: u64,
        issuer: Pubkey,
        name: String,
        description: String,
        amount: u64,
        created_at: i64,
    ) -> Self {
        Bounty {
            id,
            issuer,
            name,
            description,
            amount,
            claimer: Pubkey::default(),
            created_at,
            claim_id: 0,
            votes: Votes {
                yes: 0,
                no: 0,
                deadline: 0,
            },
            participants: vec![],
        }
    }
}
