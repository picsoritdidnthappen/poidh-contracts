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
    function joinOpenBounty(uint256 bountyId) external payable {
        if (msg.value == 0) revert NoEther();
        if (bountyId >= bountyCounter) revert BountyNotFound();
        if (bountyCurrentVotingClaim[bountyId] > 0) revert VotingOngoing();

        Bounty memory bounty = bounties[bountyId];
        if (bounty.claimer != address(0)) revert BountyClaimed();

        address[] memory p = participants[bountyId];
        if (p.length == 0) revert NotOpenBounty();

        participants[bountyId].push(msg.sender);
        participantAmounts[bountyId].push(msg.value);

        bounties[bountyId].amount = bounty.amount + msg.value;

        emit BountyJoined(bountyId, msg.sender, msg.value);
    }

    /** Cancel Solo Bounty
     * @dev Allows the sender to cancel a bounty with a given id
     * @param bountyId the id of the bounty to be canceled
     */
    function cancelSoloBounty(uint bountyId) external {
        if (bountyId >= bountyCounter) revert BountyNotFound();

        Bounty memory bounty = bounties[bountyId];
        if (msg.sender != bounty.issuer) revert WrongCaller();

        if (bounty.claimer != address(0)) revert BountyClaimed();
        if (bounty.claimer == msg.sender) revert BountyClosed();

        address[] memory p = participants[bountyId];
        if (p.length > 0) revert NotSoloBounty();

        uint refundAmount = bounty.amount;
        bounties[bountyId].claimer = msg.sender;

        (bool success, ) = bounty.issuer.call{value: refundAmount}('');
        if (!success) revert transferFailed();

        emit BountyCancelled(bountyId, bounty.issuer);
    }

    /** Cancel Open Bounty */
    function cancelOpenBounty(uint256 bountyId) external {
        if (bountyId >= bountyCounter) revert BountyNotFound();
        if (bountyCurrentVotingClaim[bountyId] > 0) revert VotingOngoing();

        Bounty memory bounty = bounties[bountyId];
        if (msg.sender != bounty.issuer) revert WrongCaller();
        if (bounty.claimer != address(0)) revert BountyClaimed();
        if (bounty.claimer == msg.sender) revert BountyClosed();

        address[] memory p = participants[bountyId];
        if (p.length == 0) revert NotOpenBounty();

        uint256[] memory amounts = participantAmounts[bountyId];
        uint256 i;

        do {
            address participant = p[i];
            uint256 amount = amounts[i];

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
    ) external {
        if (bountyId >= bountyCounter) revert BountyNotFound();

        Bounty memory bounty = bounties[bountyId];
        if (bounty.claimer != address(0)) revert BountyClaimed();
        if (bounty.claimer == msg.sender) revert BountyClosed();
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

        _mint(address(this), claimId);
        _setTokenURI(claimId, uri);

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
    function submitClaimForVote(uint256 bountyId, uint256 claimId) external {
        if (bountyId >= bountyCounter) revert BountyNotFound();
        if (claimId >= claimCounter) revert ClaimNotFound();

        Bounty memory bounty = bounties[bountyId];
        if (bounty.claimer != address(0)) revert BountyClaimed();
        if (bounty.claimer == bounty.issuer) revert BountyClosed();

        address[] memory p = participants[bountyId];
        if (p.length == 0) revert NotOpenBounty();

        uint256[] memory amounts = participantAmounts[bountyId];

        if (amounts[0] > bounty.amount / 2) {
            // Automatically accept claim if yes
            acceptClaim(bountyId, claimId);
            return;
        }

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
    function voteClaim(uint256 bountyId, bool vote) external {
        if (bountyId >= bountyCounter) revert BountyNotFound();

        Bounty memory bounty = bounties[bountyId];
        if (bounty.claimer != address(0)) revert BountyClaimed();
        if (bounty.claimer == bounty.issuer) revert BountyClosed();

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
     * @dev Reset the voting period for an open bounty
     * @param bountyId the id of the bounty being claimed
     */
    function resetVotingPeriod(uint256 bountyId) external {
        if (bountyId >= bountyCounter) revert BountyNotFound();

        Bounty memory bounty = bounties[bountyId];
        if (bounty.issuer != msg.sender) revert WrongCaller();
        if (bounty.claimer != address(0)) revert BountyClaimed();
        if (bounty.claimer == bounty.issuer) revert BountyClosed();

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

        Votes storage votingTracker = bountyVotingTracker[bountyId];

        if (block.timestamp < votingTracker.deadline) revert VotingOngoing();

        bountyCurrentVotingClaim[bountyId] = 0;
        bountyVotingTracker[bountyId].yes = 0;
        bountyVotingTracker[bountyId].no = 0;
        bountyVotingTracker[bountyId].deadline = 0;
    }

    /**
     * @dev Allow bounty participants to withdraw from a bounty that is not currently being voted on
     * @param bountyId the id of the bounty to withdraw from
     */
    function withdrawFromOpenBounty(uint256 bountyId) external {
        if (bountyId >= bountyCounter) revert BountyNotFound();

        Bounty memory bounty = bounties[bountyId];
        if (bounty.claimer != address(0)) revert BountyClaimed();
        if (bounty.claimer == bounty.issuer) revert BountyClosed();

        address[] memory p = participants[bountyId];
        if (p.length == 0) revert NotOpenBounty();

        if (bountyCurrentVotingClaim[bountyId] > 0) revert VotingOngoing();

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
    function acceptClaim(uint256 bountyId, uint256 claimId) public {
        if (bountyId >= bountyCounter) revert BountyNotFound();
        if (claimId >= claimCounter) revert ClaimNotFound();

        Bounty memory bounty = bounties[bountyId];
        if (bounty.claimer != address(0)) revert BountyClaimed();
        if (bounty.claimer == bounty.issuer) revert BountyClosed();
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
        _safeTransfer(address(this), msg.sender, claimId, '');

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
     * @param start the index to start fetching bounties from
     * @param end the index to stop fetching bounties at
     * @return result an array of Bounties from start to end index
     */
    function getBounties(
        uint start,
        uint end
    ) public view returns (Bounty[] memory) {
        require(
            start <= end,
            "Start index must be less than or equal to end index"
        );
        require(end < bounties.length, "End index out of bounds");

        // Calculate the size of the array to return
        uint size = end - start + 1;
        // Initialize an array of Bounties with the calculated size
        Bounty[] memory result = new Bounty[](size);

        // Loop from start to end index and populate the result array
        for (uint i = 0; i < size; i++) {
            result[i] = bounties[start + i];
        }

        return result;
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
