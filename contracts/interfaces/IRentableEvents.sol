// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

/// @title Rentable protocol events
/// @author Rentable Team <hello@rentable.world>
interface IRentableEvents {
    /// @notice Emitted on token deposit
    /// @param who depositor
    /// @param tokenAddress wrapped token address
    /// @param tokenId wrapped token id
    event Deposit(
        address indexed who,
        address indexed tokenAddress,
        uint256 indexed tokenId
    );

    /// @notice Emitted on withdrawal
    /// @param tokenAddress wrapped token address
    /// @param tokenId wrapped token id
    event Withdraw(address indexed tokenAddress, uint256 indexed tokenId);

    /// @notice Emitted on rental conditions changes
    /// @param tokenAddress wrapped token address
    /// @param tokenId wrapped token id
    /// @param paymentTokenAddress payment token address allowed for the rental
    /// @param paymentTokenId payment token id allowed for the rental (0 for ETH and ERC20)
    /// @param maxTimeDuration max duration allowed for the rental
    /// @param pricePerSecond price per second in payment token units
    /// @param privateRenter rental allowed only for this renter
    event UpdateRentalConditions(
        address indexed tokenAddress,
        uint256 indexed tokenId,
        address paymentTokenAddress,
        uint256 paymentTokenId,
        uint256 maxTimeDuration,
        uint256 pricePerSecond,
        address privateRenter
    );

    /// @notice Emitted on a successful rent
    /// @param from rentee
    /// @param to renter
    /// @param tokenAddress wrapped token address
    /// @param tokenId wrapped token id
    /// @param paymentTokenAddress payment token address allowed for the rental
    /// @param paymentTokenId payment token id allowed for the rental (0 for ETH and ERC20)
    /// @param expiresAt rental expiration time
    event Rent(
        address from,
        address indexed to,
        address indexed tokenAddress,
        uint256 indexed tokenId,
        address paymentTokenAddress,
        uint256 paymentTokenId,
        uint256 expiresAt
    );

    /// @notice Emitted on expiration settlement on-chain
    /// @param tokenAddress wrapped token address
    /// @param tokenId wrapped token id
    event RentEnds(address indexed tokenAddress, uint256 indexed tokenId);
}
