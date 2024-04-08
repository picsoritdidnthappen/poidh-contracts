use anchor_lang::prelude::*;

#[error_code]
pub enum ErrorCode {
    #[msg("Only Open bounties can be joined")]
    NotOpenBounty,
    #[msg("Invalid Join Bounty Amount")]
    InvalidJoinAmount,
    #[msg("Participant already exists")]
    ParticipantAlreadyExists,
    #[msg("Participant does not exist")]
    ParticipantDoesNotExist,
    #[msg("Overflow")]
    ArithmeticOverflow,
    #[msg("Underflow")]
    ArithmeticUnderflow,
    #[msg("Insufficient Shares")]
    InsufficientShares,
}
