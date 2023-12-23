// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol';

contract PoidhV2Nft is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    IERC721Receiver,
    ERC721Royalty
{
    address public immutable poidhV2Authority;
    address public poidh;

    /**
     * @dev Constructor function
     * @param _poidhV2Authority the address of the royalty recipient
     * @param _treasury the address of the royalty recipient
     * @param _feeNumerator the fee numerator for the royalty (1000 ~ 10%)
     */
    constructor(
        address _treasury,
        address _poidhV2Authority,
        uint96 _feeNumerator
    ) ERC721('pics or it didnt happen', 'POIDH V2') {
        poidhV2Authority = _poidhV2Authority;
        _setDefaultRoyalty(_treasury, _feeNumerator);
    }

    function setPoidhV2(address _poidhV2) external {
        require(
            msg.sender == poidhV2Authority,
            'only poidhV2Authority can set poidhV2'
        );
        poidh = _poidhV2;
    }

    function mint(
        address to,
        uint256 claimCounter
    ) external {
        if (msg.sender != poidh) {
            revert('only poidh can mint');
        }

        _mint(to, claimCounter);
        ++claimCounter;
    }

    /** get claims by bounty */
    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
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

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal virtual override(ERC721, ERC721Enumerable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(
        address account,
        uint128 amount
    ) internal virtual override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, amount);
    }
}
