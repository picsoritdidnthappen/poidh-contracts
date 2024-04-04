// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';

interface IPoidhV2Nft is IERC721, IERC721Receiver {
    function mint(address to, uint256 claimCounter, string memory uri) external;
    function safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) external;
}

contract PoidhV2 {
    /** Data structures */
    struct Bounty {
        uint256 id;
        address issuer;
        string name;
        string description;
        uint256 amount;
        address claimer;
        uint256 createdAt;
        uint256 claimId;
    }

    struct Claim {
        uint256 id;
        address issuer;
        uint256 bountyId;
        address bountyIssuer;
        string name;
        string description;
        uint256 createdAt;
        bool accepted;
    }

    struct Votes {
        uint256 yes;
        uint256 no;
        uint256 deadline;
    }

    /** State variables */
    Bounty[] public bounties;
    Claim[] public claims;

    address public immutable treasury;

    uint256 public bountyCounter = 0;
    uint256 public claimCounter = 0;

    uint256 public votingPeriod = 2 days;
    bool public poidhV2NftSet = false;
    IPoidhV2Nft public immutable poidhV2Nft;

    /** mappings */
    mapping(address => uint256[]) public userBounties;
    mapping(address => uint256[]) public userClaims;
    mapping(uint256 => uint256[]) public bountyClaims;
    mapping(uint256 => address[]) public participants;
    mapping(uint256 => uint256[]) public participantAmounts;
    mapping(uint256 => uint256) public bountyCurrentVotingClaim;
    mapping(uint256 => Votes) public bountyVotingTracker;

    /** Events */
    event BountyCreated(
        uint256 id,
        address issuer,
        string name,
        string description,
        uint256 amount,
        uint256 createdAt
    );
    event ClaimCreated(
        uint256 id,
        address issuer,
        uint256 bountyId,
        address bountyIssuer,
        string name,
        string description,
        uint256 createdAt
    );
    event ClaimAccepted(
        uint256 bountyId,
        uint256 claimId,
        address claimIssuer,
        address bountyIssuer,
        uint256 fee
    );
    event BountyJoined(uint256 bountyId, address participant, uint256 amount);
    event ClaimSubmittedForVote(uint256 bountyId, uint256 claimId);
    event BountyCancelled(uint256 bountyId, address issuer);
    event ResetVotingPeriod(uint256 bountyId);
    event VoteClaim(address voter, uint256 bountyId, uint256 claimId);
    event WithdrawFromOpenBounty(
        uint256 bountyId,
        address participant,
        uint256 amount
    );

    /** Errors */
    error NoEther();
    error BountyNotFound();
    error ClaimNotFound();
    error VotingOngoing();
    error BountyClaimed();
    error NotOpenBounty();
    error NotSoloBounty();
    error WrongCaller();
    error BountyClosed();
    error transferFailed();
    error IssuerCannotClaim();
    error NoVotingPeriodSet();
    error NotActiveParticipant();
    error BountyAmountTooHigh();
    error IssuerCannotWithdraw();

    /** modifiers */
    /** @dev
     * Checks if the bounty exists
     * Checks if the bounty is claimed
     * Checks if the bounty is open
     * Checks if the bounty is currently being voted on
     */

    modifier bountyChecks(uint256 bountyId) {
        if (bountyId >= bountyCounter) revert BountyNotFound();
        Bounty memory bounty = bounties[bountyId];
        if (bounty.claimer == bounty.issuer) revert BountyClosed();
        if (bounty.claimer != address(0)) revert BountyClaimed();
        _;
    }

    modifier openBountyChecks(uint256 bountyId) {
        if (bountyCurrentVotingClaim[bountyId] > 0) revert VotingOngoing();
        address[] memory p = participants[bountyId];
        if (p.length == 0) revert NotOpenBounty();
        _;
    }

    constructor(address _poidhV2Nft, address _treasury) {
        poidhV2Nft = IPoidhV2Nft(_poidhV2Nft);
        treasury = _treasury;
    }

    /**
     * @dev Internal function to create a bounty
     * @param name the name of the bounty
     * @param description the description of the bounty
     * @return bountyId the id of the created bounty
     */
    function _createBounty(
        string calldata name,
        string calldata description
    ) internal returns (uint256 bountyId) {
        bountyId = bountyCounter;
        Bounty memory bounty = Bounty(
            bountyId,
            msg.sender,
            name,
            description,
            msg.value,
            address(0),
            block.timestamp,
            0
        );
        bounties.push(bounty);
        userBounties[msg.sender].push(bountyId);
        ++bountyCounter;

        emit BountyCreated(
            bountyId,
            msg.sender,
            name,
            description,
            msg.value,
            block.timestamp
        );
    }

    /** Create Solo Bounty */
    /**
     * @dev Allows the sender to create a bounty with a given name and description
     * @param name the name of the bounty
     * @param description the description of the bounty
     */
    function createSoloBounty(
        string calldata name,
        string calldata description
    ) external payable {
        if (msg.value == 0) revert NoEther();

        _createBounty(name, description);
    }

    /** Create Open Participation Bounty */
    function createOpenBounty(
        string calldata name,
        string calldata description
    ) external payable {
        if (msg.value == 0) revert NoEther();

        uint256 bountyId = _createBounty(name, description);

        participants[bountyId].push(msg.sender);
        participantAmounts[bountyId].push(msg.value);
    }

    /** Join Open Bounty
     * @dev Allows the sender join an open bounty as a participant with msg.value shares
     * @param bountyId the id of the bounty to be joined
     */
    function joinOpenBounty(
        uint256 bountyId
    ) external payable bountyChecks(bountyId) openBountyChecks(bountyId) {
        if (msg.value == 0) revert NoEther();

        address[] memory p = participants[bountyId];

        uint256 i;
        do {
            if (msg.sender == p[i]) {
                revert WrongCaller();
            }
            ++i;
        } while (p.length > i);

        Bounty memory bounty = bounties[bountyId];

        participants[bountyId].push(msg.sender);
        participantAmounts[bountyId].push(msg.value);

        bounties[bountyId].amount = bounty.amount + msg.value;

        emit BountyJoined(bountyId, msg.sender, msg.value);
    }

    /** Cancel Solo Bounty
     * @dev Allows the sender to cancel a bounty with a given id
     * @param bountyId the id of the bounty to be canceled
     */
    function cancelSoloBounty(uint bountyId) external bountyChecks(bountyId) {
        Bounty memory bounty = bounties[bountyId];
        if (msg.sender != bounty.issuer) revert WrongCaller();

        address[] memory p = participants[bountyId];
        if (p.length > 0) revert NotSoloBounty();

        uint refundAmount = bounty.amount;
        bounties[bountyId].claimer = msg.sender;

        (bool success, ) = bounty.issuer.call{value: refundAmount}('');
        if (!success) revert transferFailed();

        emit BountyCancelled(bountyId, bounty.issuer);
    }

    /** Cancel Open Bounty */
    function cancelOpenBounty(
        uint256 bountyId
    ) external bountyChecks(bountyId) openBountyChecks(bountyId) {
        Bounty memory bounty = bounties[bountyId];
        if (msg.sender != bounty.issuer) revert WrongCaller();

        address[] memory p = participants[bountyId];
        uint256[] memory amounts = participantAmounts[bountyId];
        uint256 i;

        do {
            address participant = p[i];
            uint256 amount = amounts[i];

            if (participant == address(0)) {
                ++i;
                continue;
            }

            (bool success, ) = participant.call{value: amount}('');
            if (!success) revert transferFailed();

            ++i;
        } while (i < p.length);

        bounties[bountyId].claimer = msg.sender;

        emit BountyCancelled(bountyId, bounty.issuer);
    }

    /**
     * @dev Allows the sender to create a claim on a given bounty
     * @param bountyId the id of the bounty being claimed
     * @param name the name of the claim
     * @param uri the URI of the claim
     * @param description the description of the claim
     */
    function createClaim(
        uint256 bountyId,
        string calldata name,
        string calldata uri,
        string calldata description
    ) external bountyChecks(bountyId) {
        Bounty memory bounty = bounties[bountyId];
        if (bounty.issuer == msg.sender) revert IssuerCannotClaim();

        uint256 claimId = claimCounter;

        Claim memory claim = Claim(
            claimId,
            msg.sender,
            bountyId,
            bounty.issuer,
            name,
            description, // new field
            block.timestamp,
            false
        );

        claims.push(claim);
        userClaims[msg.sender].push(claimId);
        bountyClaims[bountyId].push(claimId);

        poidhV2Nft.mint(address(this), claimId, uri);

        claimCounter++;

        emit ClaimCreated(
            claimId,
            msg.sender,
            bountyId,
            bounty.issuer,
            name,
            description,
            block.timestamp
        );
    }

    /**
     * @dev Bounty issuer submits claim for voting and casts their vote
     * @param bountyId the id of the bounty being claimed
     */
    function submitClaimForVote(
        uint256 bountyId,
        uint256 claimId
    ) external bountyChecks(bountyId) openBountyChecks(bountyId) {
        if (claimId >= claimCounter) revert ClaimNotFound();

        uint256[] memory amounts = participantAmounts[bountyId];

        Votes storage votingTracker = bountyVotingTracker[bountyId];
        votingTracker.yes += amounts[0];
        votingTracker.deadline = block.timestamp + votingPeriod;
        bountyCurrentVotingClaim[bountyId] = claimId;

        emit ClaimSubmittedForVote(bountyId, claimId);
    }

    /**
     * @dev Vote on an open bounty
     * @param bountyId the id of the bounty to vote for
     */
    function voteClaim(
        uint256 bountyId,
        bool vote
    ) external bountyChecks(bountyId) {
        address[] memory p = participants[bountyId];
        if (p.length == 0) revert NotOpenBounty();

        uint256 currentClaim = bountyCurrentVotingClaim[bountyId];
        if (currentClaim == 0) revert NoVotingPeriodSet();

        uint256[] memory amounts = participantAmounts[bountyId];
        uint256 i;
        uint256 participantAmount;

        do {
            if (msg.sender == p[i]) {
                participantAmount = amounts[i];
                break;
            }

            ++i;
        } while (i < p.length);

        if (participantAmount == 0) revert NotActiveParticipant();

        Votes memory votingTracker = bountyVotingTracker[bountyId];
        if (vote) {
            if (
                votingTracker.yes + participantAmount >
                (votingTracker.yes + participantAmount + votingTracker.no) / 2
            ) {
                // accept claim and close out bounty
                _acceptClaim(bountyId, currentClaim);
            }
            bountyVotingTracker[bountyId].yes += participantAmount;
        } else {
            bountyVotingTracker[bountyId].no += participantAmount;
        }

        emit VoteClaim(msg.sender, bountyId, currentClaim);
    }

    /**
     * @dev Reset the voting period for an open bounty
     * @param bountyId the id of the bounty being claimed
     */
    function resetVotingPeriod(
        uint256 bountyId
    ) external bountyChecks(bountyId) {
        if (participants[bountyId].length == 0) revert NotOpenBounty();

        uint256 currentClaim = bountyCurrentVotingClaim[bountyId];
        if (currentClaim == 0) revert NoVotingPeriodSet();

        Votes storage votingTracker = bountyVotingTracker[bountyId];
        if (block.timestamp < votingTracker.deadline) revert VotingOngoing();

        bountyCurrentVotingClaim[bountyId] = 0;
        delete bountyVotingTracker[bountyId];

        emit ResetVotingPeriod(bountyId);
    }

    /**
     * @dev Allow bounty participants to withdraw from a bounty that is not currently being voted on
     * @param bountyId the id of the bounty to withdraw from
     */
    function withdrawFromOpenBounty(
        uint256 bountyId
    ) external bountyChecks(bountyId) openBountyChecks(bountyId) {
        Bounty memory bounty = bounties[bountyId];
        if (bounty.issuer == msg.sender) revert IssuerCannotWithdraw();
        address[] memory p = participants[bountyId];
        uint256[] memory amounts = participantAmounts[bountyId];
        uint256 i;

        do {
            if (msg.sender == p[i]) {
                uint256 amount = amounts[i];
                participants[bountyId][i] = address(0);
                participantAmounts[bountyId][i] = 0;
                bounties[bountyId].amount -= amount;

                (bool success, ) = p[i].call{value: amount}('');
                if (!success) revert transferFailed();

                emit WithdrawFromOpenBounty(bountyId, msg.sender, amount);

                break;
            }

            ++i;
        } while (i < p.length);
    }

    /**
     * @dev Allows the sender to accept a claim on their bounty
     * @param bountyId the id of the bounty being claimed
     * @param claimId the id of the claim being accepted
     */
    function acceptClaim(
        uint256 bountyId,
        uint256 claimId
    ) external bountyChecks(bountyId) {
        if (claimId >= claimCounter) revert ClaimNotFound();

        Bounty storage bounty = bounties[bountyId];
        /**
         * @dev note: if the bounty has more than one participant, it is considered truly open, and the issuer cannot accept the claim without a vote.
         */
        if (participants[bountyId].length > 1) {
            revert NotSoloBounty();
        } else {
            if (msg.sender != bounty.issuer) revert WrongCaller();
        }

        _acceptClaim(bountyId, claimId);
    }

    /**
     * @dev Internal function to accept a claim
     * @param bountyId the id of the bounty being claimed
     * @param claimId the id of the claim being accepted
     */
    function _acceptClaim(uint256 bountyId, uint256 claimId) internal {
        if (claimId >= claimCounter) revert ClaimNotFound();
        Bounty storage bounty = bounties[bountyId];
        if (bounty.amount > address(this).balance) revert BountyAmountTooHigh();

        Claim memory claim = claims[claimId];
        if (claim.bountyId != bountyId) revert ClaimNotFound();

        address claimIssuer = claim.issuer;
        uint256 bountyAmount = bounty.amount;

        // Close out the bounty
        bounty.claimer = claimIssuer;
        bounty.claimId = claimId;
        claims[claimId].accepted = true;

        // Calculate the fee (2.5% of bountyAmount)
        uint256 fee = (bountyAmount * 25) / 1000;

        // Subtract the fee from the bountyAmount
        uint256 payout = bountyAmount - fee;

        // Transfer the claim NFT to the bounty issuer
        poidhV2Nft.safeTransfer(address(this), bounty.issuer, claimId, '');

        // Transfer the bounty amount to the claim issuer
        (bool success, ) = claimIssuer.call{value: payout}('');
        if (!success) revert transferFailed();

        // Transfer the fee to the treasury
        (bool feeSuccess, ) = treasury.call{value: fee}('');
        if (!feeSuccess) revert transferFailed();

        emit ClaimAccepted(bountyId, claimId, claimIssuer, bounty.issuer, fee);
    }

    /** Getter for the length of the bounties array */
    function getBountiesLength() public view returns (uint256) {
        return bounties.length;
    }

    /**
     * @dev Returns an array of Bounties from start to end index
     * @param offset the index to start fetching bounties from
     * @return result an array of Bounties from start to end index
     */
    function getBounties(
        uint offset
    ) public view returns (Bounty[10] memory result) {
        uint256 length = bounties.length;
        uint256 remaining = length - offset;
        uint256 numBounties = remaining < 10 ? remaining : 10;

        for (uint i = 0; i < numBounties; i++) {
            Bounty storage bounty = bounties[offset + i];

            result[i] = bounty;
        }
    }

    /** get claims by bountyId*/
    /** 
        @dev Returns all claims associated with a bounty
        @param bountyId the id of the bounty to fetch claims for 
    */
    function getClaimsByBountyId(
        uint256 bountyId
    ) public view returns (Claim[] memory) {
        uint256[] memory bountyClaimIndexes = bountyClaims[bountyId];
        Claim[] memory bountyClaimsArray = new Claim[](
            bountyClaimIndexes.length
        );

        for (uint256 i = 0; i < bountyClaimIndexes.length; i++) {
            bountyClaimsArray[i] = claims[bountyClaimIndexes[i]];
        }

        return bountyClaimsArray;
    }

    /** get bounties by user */
    /** 
        @dev Returns all bounties for a given user 
        @param user the address of the user to fetch bounties for
    */
    function getBountiesByUser(
        address user,
        uint256 offset
    ) public view returns (Bounty[10] memory result) {
        uint256[] memory bountyIds = userBounties[user];
        uint256 length = bountyIds.length;
        uint256 remaining = length - offset;
        uint256 numBounties = remaining < 10 ? remaining : 10;

        for (uint i = 0; i < numBounties; i++) {
            result[i] = bounties[bountyIds[offset + i]];
        }
    }

    /** get claims by user */
    /** 
        @dev Returns all claims for a given user 
        @param user the address of the user to fetch claims for
    */
    function getClaimsByUser(
        address user
    ) public view returns (Claim[] memory) {
        uint256[] storage userClaimIndexes = userClaims[user];
        Claim[] memory userClaimsArray = new Claim[](userClaimIndexes.length);

        for (uint256 i = 0; i < userClaimIndexes.length; i++) {
            userClaimsArray[i] = claims[userClaimIndexes[i]];
        }

        return userClaimsArray;
    }

    /** get bounty participants */
    /** 
        @dev Returns all participants for a given bounty 
        @param bountyId the id of the bounty to fetch participants for
    */
    function getParticipants(
        uint256 bountyId
    ) public view returns (address[] memory, uint256[] memory) {
        address[] memory p = participants[bountyId];
        uint256[] memory a = participantAmounts[bountyId];
        uint256 pLength = p.length;

        address[] memory result = new address[](pLength);
        uint256[] memory amounts = new uint256[](pLength);

        for (uint256 i = 0; i < pLength; i++) {
            result[i] = p[i];
            amounts[i] = a[i];
        }

        return (result, amounts);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
