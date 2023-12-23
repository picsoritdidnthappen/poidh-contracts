// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

interface PoidhV2Nft is IERC721 {
    function setTokenURI(uint256 tokenId, string memory _tokenURI) external;
    function mint(address to, uint256 claimCounter) external;
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

    struct ViewBounty {
        uint256 id;
        address issuer;
        string name;
        string description;
        uint256 amount;
        address claimer;
        uint256 createdAt;
        uint256 claimId;
        address[] participants;
        uint256[] participantAmounts;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 deadline;
    }

    struct Claim {
        uint256 id;
        address issuer;
        uint256 bountyId;
        address bountyIssuer;
        string name;
        string description;
        uint256 createdAt;
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

    uint256 public bountyCounter = 1;
    uint256 public claimCounter = 1;

    uint256 public votingPeriod = 2 days;

    address public immutable poidhAuthority;
    bool public poidhV2NftSet = false;
    PoidhV2Nft public immutable poidhV2Nft;

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
        if (bounty.claimer != address(0)) revert BountyClaimed();
        if (bounty.claimer == bounty.issuer) revert BountyClosed();
        _;
    }

    modifier openBountyChecks(uint256 bountyId) {
        if (bountyCurrentVotingClaim[bountyId] > 0) revert VotingOngoing();
        address[] memory p = participants[bountyId];
        if (p.length == 0) revert NotOpenBounty();
        _;
    }

    constructor(address _poidhV2Nft) {
        poidhV2Nft = PoidhV2Nft(_poidhV2Nft);
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

        uint256 bountyId = bountyCounter;

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

    /** Create Open Participation Bounty */
    function createOpenBounty(
        string calldata name,
        string calldata description
    ) external payable {
        if (msg.value == 0) revert NoEther();

        uint256 bountyId = bountyCounter;

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
        participants[bountyId].push(msg.sender);
        participantAmounts[bountyId].push(msg.value);

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

    /** Join Open Bounty
     * @dev Allows the sender join an open bounty as a participant with msg.value shares
     * @param bountyId the id of the bounty to be joined
     */
    function joinOpenBounty(
        uint256 bountyId
    ) external payable bountyChecks(bountyId) openBountyChecks(bountyId) {
        if (msg.value == 0) revert NoEther();

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
            block.timestamp
        );

        claims.push(claim);
        userClaims[msg.sender].push(claimId);
        bountyClaims[bountyId].push(claimId);

        poidhV2Nft.mint(address(this), claimId);
        poidhV2Nft.setTokenURI(claimId, uri);

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
                (votingTracker.yes + votingTracker.no) / 2
            ) {
                // accept claim and close out bounty
                acceptClaim(bountyId, currentClaim);
                return;
            }
            bountyVotingTracker[bountyId].yes += participantAmount;
        } else {
            bountyVotingTracker[bountyId].no += participantAmount;
        }
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
    ) public bountyChecks(bountyId) {
        if (claimId >= claimCounter) revert ClaimNotFound();

        Bounty memory bounty = bounties[bountyId];
        if (bounty.amount > address(this).balance) revert BountyAmountTooHigh();

        address claimIssuer = claims[claimId].issuer;
        uint256 bountyAmount = bounty.amount;

        // Close out the bounty
        bounties[bountyId].claimer = claimIssuer;
        bounties[bountyId].claimId = claimId;

        // Calculate the fee (2.5% of bountyAmount)
        uint256 fee = (bountyAmount * 25) / 1000;

        // Subtract the fee from the bountyAmount
        uint256 payout = bountyAmount - fee;

        // Store the claim issuer and bounty amount for use after external calls
        address payable pendingPayee = payable(claimIssuer);
        uint256 pendingPayment = payout;

        // Store the treasury address for use after external calls
        address payable t = payable(treasury); // replace 'treasury_address_here' with your actual treasury address

        // Transfer the claim NFT to the bounty issuer
        poidhV2Nft.safeTransfer(address(this), msg.sender, claimId, '');

        // Finally, transfer the bounty amount to the claim issuer
        (bool s1, ) = pendingPayee.call{value: pendingPayment}('');
        if (!s1) revert transferFailed();

        (bool s2, ) = t.call{value: fee}('');
        if (!s2) revert transferFailed();

        emit ClaimAccepted(bountyId, claimId, claimIssuer, bounty.issuer, fee); // update event parameters to include the fee
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
    ) public view returns (ViewBounty[10] memory result) {
        require(offset + 10 <= bounties.length, 'End index out of bounds');

        for (uint i = 0; i < 10; i++) {
            Bounty storage bounty = bounties[offset + i];

            Votes storage vote = bountyVotingTracker[bounty.id];

            result[i] = ViewBounty({
                id: bounty.id,
                issuer: bounty.issuer,
                name: bounty.name,
                description: bounty.description,
                amount: bounty.amount,
                claimer: bounty.claimer,
                createdAt: bounty.createdAt,
                claimId: bounty.claimId,
                participants: participants[bounty.id],
                participantAmounts: participantAmounts[bounty.id],
                yesVotes: vote.yes,
                noVotes: vote.no,
                deadline: vote.deadline
            });
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
        address user
    ) public view returns (Bounty[] memory) {
        uint256[] storage userBountyIndexes = userBounties[user];
        Bounty[] memory userBountiesArray = new Bounty[](
            userBountyIndexes.length
        );

        for (uint256 i = 0; i < userBountyIndexes.length; i++) {
            userBountiesArray[i] = bounties[userBountyIndexes[i]];
        }

        return userBountiesArray;
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
}
