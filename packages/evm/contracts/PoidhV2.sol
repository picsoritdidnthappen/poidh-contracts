// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol';

abstract contract PoidhV2 is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    IERC721Receiver,
    ERC721Royalty
{
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

    /**
     * @dev Constructor function
     * @param _treasury the address of the treasury wallet
     * @param _feeNumerator the fee numerator for the royalty (1000 ~ 10%)
     */
    constructor(
        address _treasury,
        uint96 _feeNumerator
    ) ERC721("pics or it didn't happen", 'POIDH V2') {
        treasury = _treasury;
        _setDefaultRoyalty(_treasury, _feeNumerator);
    }

    /** Create Solo Bounty */
    /**
     * @dev Allows the sender to create a bounty with a given name and description
     * @param name the name of the bounty
     * @param description the description of the bounty
     */
    function createSoloBounty(
        string memory name,
        string memory description
    ) external payable {
        require(msg.value > 0, 'Bounty amount must be greater than 0');

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

        // Store the bounty index in the user's array
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
        require(msg.value > 0, 'Bounty amount must be greater than 0');

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
    function joinOpenBounty(uint256 bountyId) external payable {
        require(msg.value > 0, 'Bounty amount must be greater than 0');
        require(bountyCounter > bountyId, 'Bounty does not exist');
        require(bountyCurrentVotingClaim[bountyId] == 0, 'Voting is ongoing');

        Bounty memory bounty = bounties[bountyId];
        require(bounty.claimer == address(0), 'Bounty already claimed');

        address[] memory p = participants[bountyId];
        require(p.length > 0, 'Bounty is not open');

        participants[bountyId].push(msg.sender);
        participantAmounts[bountyId].push(msg.value);

        bounties[bountyId].amount = bounties[bountyId].amount + msg.value;

        emit BountyJoined(bountyId, msg.sender, msg.value);
    }

    /** Cancel Solo Bounty
     * @dev Allows the sender to cancel a bounty with a given id
     * @param bountyId the id of the bounty to be canceled
     */
    function cancelSoloBounty(uint bountyId) external {
        require(bountyCounter > bountyId, 'Bounty does not exist');
        address[] memory p = participants[bountyId];
        require(p.length == 0, 'Bounty is open');
        Bounty memory bounty = bounties[bountyId];
        require(
            msg.sender == bounty.issuer,
            'Only the bounty issuer can cancel the bounty'
        );
        require(bounty.claimer == address(0), 'Bounty already claimed');
        require(bounty.amount > 0, 'Bounty closed');

        uint refundAmount = bounty.amount;
        bounties[bountyId].claimer = msg.sender;

        (bool success, ) = bounty.issuer.call{value: refundAmount}('');
        require(success, 'Transfer failed.');

        emit BountyCancelled(bountyId, bounty.issuer);
    }

    /** Cancel Open Bounty */
    function cancelOpenBounty(uint256 bountyId) external {
        require(bountyCounter > bountyId, 'Bounty does not exist');
        require(bountyCurrentVotingClaim[bountyId] == 0, 'Voting is ongoing');
        Bounty memory bounty = bounties[bountyId];
        require(
            msg.sender == bounty.issuer,
            'Only the bounty issuer can cancel the bounty'
        );
        require(bounty.claimer == address(0), 'Bounty claimed or closed');
        address[] memory p = participants[bountyId];
        require(p.length > 0, 'Bounty is not open');

        uint256[] memory amounts = participantAmounts[bountyId];
        uint256 i;

        do {
            address participant = p[i];
            uint256 amount = amounts[i];

            (bool success, ) = participant.call{value: amount}('');
            require(success, 'Refund failed');

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
    ) public {
        require(bountyCounter > bountyId, 'Bounty does not exist');
        require(
            bounties[bountyId].claimer == address(0),
            'Bounty already claimed'
        );
        require(
            bounties[bountyId].amount > 0,
            'Bounty does not exist or has been cancelled'
        );
        require(bounties[bountyId].issuer != msg.sender, 'Issuer cannot claim');

        uint256 claimId = claimCounter;

        Claim memory claim = Claim(
            claimId,
            msg.sender,
            bountyId,
            bounties[bountyId].issuer,
            name,
            description, // new field
            block.timestamp
        );

        claims.push(claim);
        userClaims[msg.sender].push(claimId);
        bountyClaims[bountyId].push(claimId);

        _mint(address(this), claimId);
        _setTokenURI(claimId, uri);

        emit ClaimCreated(
            claimId,
            msg.sender,
            bountyId,
            bounties[bountyId].issuer,
            name,
            description,
            block.timestamp
        );
    }

    /**
     * @dev Bounty issuer submits claim for voting and casts their vote
     * @param bountyId the id of the bounty being claimed
     */
    function submitClaimForVote(uint256 bountyId, uint256 claimId) external {
        require(bountyCounter > bountyId, 'Bounty does not exist');
        require(claimCounter > claimId, 'Claim does not exist');
        Bounty memory bounty = bounties[bountyId];
        require(
            msg.sender == bounty.issuer,
            'Only the bounty issuer can cancel the bounty'
        );
        require(bounty.claimer == address(0), 'Bounty claimed or closed');
        address[] memory p = participants[bountyId];
        require(p.length > 0, 'Bounty is not open');

        uint256[] memory amounts = participantAmounts[bountyId];

        if (amounts[0] > bounty.amount / 2) {
            // Automatically accept claim if yes
            acceptClaim(bountyId, claimId);
            return;
        }

        bountyVotingTracker[bountyId].yes += amounts[0];
        bountyVotingTracker[bountyId].deadline = block.timestamp + votingPeriod;
        bountyCurrentVotingClaim[bountyId] = claimId;

        emit ClaimSubmittedForVote(bountyId, claimId);
    }

    /**
     * @dev Vote on an open bounty
     * @param bountyId the id of the bounty to vote for
     */
    function voteClaim(uint256 bountyId, bool vote) external {
        require(bountyCounter > bountyId, 'Bounty does not exist');
        Bounty memory bounty = bounties[bountyId];
        require(bounty.amount > 0, 'Bounty closed');
        require(bounty.claimer == address(0), 'Bounty already claimed');
        address[] memory p = participants[bountyId];
        require(p.length > 0, 'Bounty is not open');

        uint256 currentClaim = bountyCurrentVotingClaim[bountyId];
        require(currentClaim > 0, 'No claim is active');

        uint256[] memory amounts = participantAmounts[bountyId];
        uint256 i;
        bool isParticipant;
        uint256 participantAmount;

        do {
            if (msg.sender == p[i]) {
                isParticipant = true;
                participantAmount = amounts[i];
            }

            ++i;
        } while (i < p.length);

        require(isParticipant, 'Not an active participant');

        Votes memory votingTracker = bountyVotingTracker[bountyId];

        if (block.timestamp > votingTracker.deadline) {
            // reset for new vote cycle
            bountyCurrentVotingClaim[bountyId] = 0;
            bountyVotingTracker[bountyId].yes = 0;
            bountyVotingTracker[bountyId].no = 0;
            bountyVotingTracker[bountyId].deadline = 0;

            return;
        }

        if (vote) {
            if (votingTracker.yes + participantAmount > bounty.amount / 2) {
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
     * @dev Allows the sender to accept a claim on their bounty
     * @param bountyId the id of the bounty being claimed
     * @param claimId the id of the claim being accepted
     */
    function acceptClaim(uint256 bountyId, uint256 claimId) public {
        require(bountyId < bounties.length, 'Bounty does not exist');
        require(claimId < claims.length, 'Claim does not exist');

        Bounty storage bounty = bounties[bountyId];
        require(bounty.claimer == address(0), 'Bounty already claimed');
        require(
            bounty.issuer == msg.sender,
            'Only the bounty issuer can accept a claim'
        );
        require(
            bounty.amount <= address(this).balance,
            'Bounty amount is greater than contract balance'
        );
        require(bounty.amount > 0, 'Bounty has been cancelled');

        address claimIssuer = claims[claimId].issuer;
        uint256 bountyAmount = bounty.amount;

        // Close out the bounty
        bounty.claimer = claimIssuer;
        bounty.claimId = claimId;

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
        _safeTransfer(address(this), msg.sender, claimId, '');

        // Finally, transfer the bounty amount to the claim issuer
        (bool s1, ) = pendingPayee.call{value: pendingPayment}('');
        require(s1, 'Transfer failed.');

        (bool s2, ) = t.call{value: fee}('');
        require(s2, 'Transfer failed.');

        emit ClaimAccepted(bountyId, claimId, claimIssuer, bounty.issuer, fee); // update event parameters to include the fee
    }

    /** get bounties */
    /** get claims */
    /** get bounties by user */
    /** get claims by user */
    /** get claims by bounty */
    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage, ERC721Royalty)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _increaseBalance(
        address account,
        uint128 amount
    ) internal virtual override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, amount);
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal virtual override(ERC721, ERC721Enumerable) returns (address) {
        return super._update(to, tokenId, auth);
    }
}
