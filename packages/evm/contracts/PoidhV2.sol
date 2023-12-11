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
        uint256 tokenId;
        uint256 createdAt;
    }

    struct Participants {
        address[] participants;
        address issuer;
    }

    /** State variables */
    Bounty[] public bounties;
    Claim[] public claims;

    address public immutable treasury;

    /** mappings */
    mapping(address => uint256[]) public userBounties;
    mapping(address => uint256[]) public userClaims;
    mapping(uint256 => uint256[]) public bountyClaims;
    mapping(uint256 => Participants) public bountyParticipants;

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
        uint256 tokenId,
        uint256 createdAt
    );
    event BountyClaimed(uint256 bountyId, address claimer, uint256 claimId);
    event BountyCancelled(uint256 bountyId, address issuer);

    /**
     * @dev Constructor function
     * @param _treasury the address of the treasury wallet
     * @param _feeNumerator the fee numerator for the royalty (1000 ~ 10%)
     * @param _poidhV1 the address of the PoidhV1 contract
     */
    constructor(
        address _treasury,
        uint96 _feeNumerator,
        address _poidhV1
    ) ERC721("pics or it didn't happen", 'POIDH V2') {
        treasury = _treasury;
        _setDefaultRoyalty(_treasury, _feeNumerator);
    }

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

    /** Create Solo Bounty */
    /** Create Open Participation Bounty */
    /** Create Private Bounty */

    /** Join Open Bounty */
    /** Join Private Bounty */

    /** Cancel Solo Bounty */
    /** Cancel Open Bounty */
    /** Cancel Private Bounty */

    /** Create Claim Solo Bounty */
    /** Create Claim Open Bounty */
    /** Create Claim Private Bounty */

    /** get bounties */
    /** get claims */
    /** get bounties by user */
    /** get claims by user */
    /** get claims by bounty */
}
