// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "./ERC721ReadOnlyProxy.sol";
import "./IRentable.sol";
import "./IWRentableHooks.sol";

contract WRentable is ERC721ReadOnlyProxy {
    address internal _rentable;

    string constant PREFIX = "w";

    modifier onlyRentable() {
        require(_msgSender() == _rentable, "Only rentable");
        _;
    }

    constructor(address wrapped_) ERC721ReadOnlyProxy(wrapped_, PREFIX) {}

    function init(address wrapped, address owner) external virtual {
        _init(wrapped, PREFIX, owner);
    }

    function setRentable(address rentable_) external onlyOwner {
        _rentable = rentable_;
        _minter = rentable_;
    }

    function getRentable() external view returns (address) {
        return _rentable;
    }

    //TODO: balanceOf

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId)
        public
        view
        virtual
        override(ERC721Upgradeable, IERC721Upgradeable)
        returns (address)
    {
        if (
            IRentable(_rentable).expiresAt(_wrapped, tokenId) > block.timestamp
        ) {
            return super.ownerOf(tokenId);
        } else {
            return address(0);
        }
    }

    function exists(uint256 tokenId) external view virtual returns (bool) {
        return super._exists(tokenId);
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._transfer(from, to, tokenId);
        IWRentableHooks(_rentable).afterWTokenTransfer(
            _wrapped,
            from,
            to,
            tokenId
        );
    }
}
